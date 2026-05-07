import os
import sys
from pathlib import Path
import numpy as np
from scipy.io import loadmat

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))
from project_paths import FIGURES, STAGE1


def setup_plot_style():
    candidate_fonts = [
        'Microsoft YaHei',
        'SimHei',
        'Noto Sans CJK SC',
        'Source Han Sans SC',
        'WenQuanYi Zen Hei',
        'Arial Unicode MS',
        'DejaVu Sans',
    ]
    available_fonts = {f.name for f in font_manager.fontManager.ttflist}
    chosen_font = None
    for font_name in candidate_fonts:
        if font_name in available_fonts:
            chosen_font = font_name
            break

    if chosen_font is not None:
        plt.rcParams['font.sans-serif'] = [chosen_font]
        print(f'Using font: {chosen_font}')
    else:
        print('Warning: No preferred font found. Chinese may not display correctly.')

    plt.rcParams['axes.unicode_minus'] = False
    plt.rcParams['figure.dpi'] = 120
    plt.rcParams['savefig.dpi'] = 200


def save_figure(path: str):
    plt.tight_layout()
    plt.savefig(path, dpi=200, bbox_inches='tight')
    plt.close()


def _to_1d(x):
    return np.asarray(x).squeeze()


def _ensure_dir(path: str):
    os.makedirs(path, exist_ok=True)


def _get_band_labels(coverage_vec):
    return [f'{cov:.2f}' for cov in coverage_vec]


def plot_stage1_cqr_results(
    results_mat: str = str(STAGE1 / 'stage1_cqr_tree_tuned_parallel_results.mat'),
    stage2_mat: str | None = str(STAGE1 / 'stage1_cqr_for_stage2.mat'),
    output_dir: str = str(FIGURES),
    coverage_to_show: float = 0.90,
    prefix: str = 'replot',
    show_all_coverages_in_example: bool = True,
    show_all_coverages_in_hour_band: bool = True,
):
    """
    读取 stage1_cqr.py 已经生成的 .mat 结果文件，单独重绘图像，不重新训练模型。

    新增：
    - 24h 示例图可叠加所有 coverage 的区间带；
    - 小时级区间图也可叠加所有 coverage 的区间带。
    """
    setup_plot_style()
    _ensure_dir(output_dir)

    mat = loadmat(results_mat, squeeze_me=True, struct_as_record=False)

    H = int(mat['H'])
    coverage_vec = _to_1d(mat['coverage_vec']).astype(float)
    coverage_test = np.asarray(mat['coverage_test'], dtype=float)
    width_test = np.asarray(mat['width_test'], dtype=float)
    avg_coverage_test = _to_1d(mat['avg_coverage_test']).astype(float)
    avg_width_test = _to_1d(mat['avg_width_test']).astype(float)
    mae_test = _to_1d(mat['mae_test']).astype(float)

    example_origin_index = int(np.asarray(mat['example_origin_index']).squeeze())
    example_y_true_future = _to_1d(mat['example_y_true_future']).astype(float)
    example_yhat_med = _to_1d(mat['example_yhat_med']).astype(float)
    example_L = np.asarray(mat['example_L'], dtype=float)
    example_U = np.asarray(mat['example_U'], dtype=float)

    if example_L.ndim == 1:
        example_L = example_L[:, None]
    if example_U.ndim == 1:
        example_U = example_U[:, None]

    colors = plt.cm.tab10.colors
    saved_files: list[str] = []

    # 图1：各 horizon 经验覆盖率
    fig1 = os.path.join(output_dir, f'{prefix}_fig1_coverage.png')
    plt.figure(figsize=(10, 5))
    for ic, cov in enumerate(coverage_vec):
        plt.plot(np.arange(1, H + 1), coverage_test[:, ic], label=f'target={cov:.2f}', color=colors[ic % len(colors)])
        plt.axhline(cov, linestyle='--', color=colors[ic % len(colors)], alpha=0.7)
    plt.xlabel('预测步长 k（15min）')
    plt.ylabel('经验覆盖率')
    plt.title('Stage1-CQR：Test集各 horizon 的经验覆盖率')
    plt.grid(True, alpha=0.3)
    plt.legend()
    save_figure(fig1)
    saved_files.append(fig1)

    # 图2：各 horizon 平均区间宽度
    fig2 = os.path.join(output_dir, f'{prefix}_fig2_width.png')
    plt.figure(figsize=(10, 5))
    for ic, cov in enumerate(coverage_vec):
        plt.plot(np.arange(1, H + 1), width_test[:, ic], label=f'coverage={cov:.2f}', color=colors[ic % len(colors)])
    plt.xlabel('预测步长 k（15min）')
    plt.ylabel('平均区间宽度（室温单位）')
    plt.title('Stage1-CQR：Test集各 horizon 的平均区间宽度')
    plt.grid(True, alpha=0.3)
    plt.legend()
    save_figure(fig2)
    saved_files.append(fig2)

    # 图3：指定起点 24h 区间预测（支持多置信度叠加）
    ic_show = int(np.argmin(np.abs(coverage_vec - coverage_to_show)))
    tt = np.arange(1, H + 1) / 4.0
    fig3 = os.path.join(output_dir, f'{prefix}_fig3_example_overlay.png')
    plt.figure(figsize=(12, 5.5))
    plt.plot(tt, example_y_true_future, label='真实未来室温', color='black', linewidth=2.0, zorder=10)
    plt.plot(tt, example_yhat_med, '--', label='树模型点预测', linewidth=1.8, color=colors[0], zorder=11)

    if show_all_coverages_in_example:
        order = np.argsort(coverage_vec)[::-1]  # 先画宽的，再画窄的
        alpha_list = np.linspace(0.10, 0.28, len(order))
        for jj, ic in enumerate(order):
            plt.fill_between(
                tt,
                example_L[:, ic],
                example_U[:, ic],
                color=colors[ic % len(colors)],
                alpha=float(alpha_list[jj]),
                label=f'CQR区间 ({coverage_vec[ic]:.2f})',
                zorder=2 + jj,
            )
    else:
        plt.fill_between(
            tt,
            example_L[:, ic_show],
            example_U[:, ic_show],
            alpha=0.25,
            color=colors[ic_show % len(colors)],
            label=f'CQR区间 ({coverage_vec[ic_show]:.2f})',
            zorder=3,
        )

    plt.xlabel('未来时间（h）')
    plt.ylabel('室温')
    plt.title(f'Stage1-CQR：指定起点({example_origin_index})的24h室温区间预测')
    plt.grid(True, alpha=0.3)
    plt.legend(ncol=2)
    save_figure(fig3)
    saved_files.append(fig3)

    # 图4：如果有 stage2 文件，则补一张小时级温度区间图
    if stage2_mat is not None and os.path.exists(stage2_mat):
        mat2 = loadmat(stage2_mat, squeeze_me=True, struct_as_record=False)
        H2 = int(np.asarray(mat2['H']).squeeze())
        Nh = int(np.asarray(mat2['Nh']).squeeze())
        coverage_vec_2 = _to_1d(mat2['coverage_vec']).astype(float)
        T_true_hour = _to_1d(mat2['T_true_hour']).astype(float)
        T_pred_hour = _to_1d(mat2['T_pred_hour']).astype(float)
        T_low_hour = np.asarray(mat2['T_low_hour'], dtype=float)
        T_up_hour = np.asarray(mat2['T_up_hour'], dtype=float)
        selected_origin_index = int(np.asarray(mat2['selected_origin_index']).squeeze())

        if T_low_hour.ndim == 1:
            T_low_hour = T_low_hour[:, None]
        if T_up_hour.ndim == 1:
            T_up_hour = T_up_hour[:, None]

        ic_show_2 = int(np.argmin(np.abs(coverage_vec_2 - coverage_to_show)))
        th = np.arange(1, Nh + 1)

        fig4 = os.path.join(output_dir, f'{prefix}_fig4_hour_band_overlay.png')
        plt.figure(figsize=(10.5, 5.5))
        plt.plot(th, T_true_hour, 'o-', label='真实小时均值室温', linewidth=1.8, markersize=4, color='black', zorder=10)
        plt.plot(th, T_pred_hour, '--', label='预测小时均值室温', linewidth=1.6, color=colors[0], zorder=11)

        if show_all_coverages_in_hour_band:
            order2 = np.argsort(coverage_vec_2)[::-1]
            alpha_list2 = np.linspace(0.10, 0.28, len(order2))
            for jj, ic in enumerate(order2):
                plt.fill_between(
                    th,
                    T_low_hour[:, ic],
                    T_up_hour[:, ic],
                    color=colors[ic % len(colors)],
                    alpha=float(alpha_list2[jj]),
                    label=f'小时级区间 ({coverage_vec_2[ic]:.2f})',
                    zorder=2 + jj,
                )
        else:
            plt.fill_between(
                th,
                T_low_hour[:, ic_show_2],
                T_up_hour[:, ic_show_2],
                alpha=0.25,
                color=colors[ic_show_2 % len(colors)],
                label=f'小时级区间 ({coverage_vec_2[ic_show_2]:.2f})',
                zorder=3,
            )

        plt.xlabel('未来小时')
        plt.ylabel('室温')
        plt.title(f'Stage1-CQR：指定起点({selected_origin_index})的小时级温度区间')
        plt.grid(True, alpha=0.3)
        plt.legend(ncol=2)
        save_figure(fig4)
        saved_files.append(fig4)

        print(f'Stage2 小时级文件已读取：H={H2}, Nh={Nh}')

    print('重绘完成，保存文件如下：')
    for path in saved_files:
        print(f'  {path}')

    print('\n汇总指标：')
    for ic, cov in enumerate(coverage_vec):
        print(
            f'coverage={cov:.2f} | empirical={avg_coverage_test[ic]:.4f} | avg_width={avg_width_test[ic]:.4f}'
        )
    print(f'平均 MAE = {np.mean(mae_test):.4f}')

    return saved_files


def main():
    plot_stage1_cqr_results()


if __name__ == '__main__':
    main()
