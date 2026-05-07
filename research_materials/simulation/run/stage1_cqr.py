# stage1_cqr_v73.py
# ============================================================
# 在原版 stage1_cqr.py 基础上增加 MATLAB v7.3 大文件读取兼容：
# 1) 输入 .mat 若为 v7/v7.2，则仍走 scipy.io.loadmat
# 2) 输入 .mat 若为 v7.3，则自动切换到 mat73.loadmat
# 3) 运行前若未安装依赖，请先执行：pip install mat73 h5py
# ============================================================

import os
import sys
import argparse
import csv
from pathlib import Path
import numpy as np
from scipy.io import loadmat, savemat

from sklearn.ensemble import HistGradientBoostingRegressor
from sklearn.metrics import mean_absolute_error, mean_squared_error
from concurrent.futures import ProcessPoolExecutor, as_completed

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))
from project_paths import FIGURES, STAGE1, SUPPLEMENT_STAGE1_TEST_DAYS

STAGE1.mkdir(parents=True, exist_ok=True)
FIGURES.mkdir(parents=True, exist_ok=True)

# ============================================================
# 0) MATLAB .mat 文件兼容读取
#    - v7 / v7.2: scipy.io.loadmat
#    - v7.3    : mat73.loadmat（需 pip install mat73 h5py）
# ============================================================
def loadmat_auto(path):
    try:
        return loadmat(path, squeeze_me=True, struct_as_record=False)
    except NotImplementedError:
        try:
            import mat73
        except ImportError as exc:
            raise ImportError(
                "检测到 MATLAB v7.3 文件，但当前 Python 环境未安装 mat73。\n"
                "请先执行：pip install mat73 h5py"
            ) from exc

        print(f"Detected MATLAB v7.3 file, switching to mat73 loader: {path}")
        return mat73.loadmat(path)


def ensure_1d_numeric(arr, name="array"):
    arr = np.asarray(arr, dtype=float)
    arr = np.squeeze(arr)
    return arr.reshape(-1)


def ensure_2d_features(arr, name="Xk"):
    arr = np.asarray(arr, dtype=float)
    arr = np.squeeze(arr)

    if arr.ndim == 0:
        return arr.reshape(1, 1)
    if arr.ndim == 1:
        return arr.reshape(-1, 1)
    if arr.ndim == 2:
        return arr

    # 兼容 MATLAB v7.3 / mat73 读出的额外单例维或嵌套维度
    non_singleton = [d for d in arr.shape if d > 1]
    if len(non_singleton) == 0:
        return arr.reshape(1, 1)
    if len(non_singleton) == 1:
        return arr.reshape(non_singleton[0], 1)

    # 约定第一个非单例维对应样本数，其余维展平为特征维
    n_samples = non_singleton[0]
    n_features = int(np.prod(non_singleton[1:]))
    return arr.reshape(n_samples, n_features)


def ensure_horizon_container(obj, H, name="X_all"):
    if isinstance(obj, list):
        if len(obj) != H:
            raise ValueError(f"{name} 长度为 {len(obj)}，与 H={H} 不一致。")
        return obj

    if isinstance(obj, np.ndarray):
        obj = np.squeeze(obj)
        if obj.dtype == object:
            flat = list(obj.reshape(-1))
            if len(flat) != H:
                raise ValueError(f"{name} 元素个数为 {len(flat)}，与 H={H} 不一致。")
            return flat

        # 极少数情况下 mat73 可能把 cell 读成更高维的数值数组
        if obj.shape[0] == H:
            return [obj[k] for k in range(H)]

    raise TypeError(f"无法识别 {name} 的数据结构，type={type(obj)}")


import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager


# ============================================================
# 1) 中文字体与绘图保存
# ============================================================
def setup_plot_style():
    candidate_fonts = [
        "Microsoft YaHei",
        "SimHei",
        "Noto Sans CJK SC",
        "Source Han Sans SC",
        "WenQuanYi Zen Hei",
        "Arial Unicode MS",
        "DejaVu Sans",
    ]
    available_fonts = {f.name for f in font_manager.fontManager.ttflist}
    chosen_font = None
    for font_name in candidate_fonts:
        if font_name in available_fonts:
            chosen_font = font_name
            break

    if chosen_font is not None:
        plt.rcParams["font.sans-serif"] = [chosen_font]
        print(f"Using font: {chosen_font}")
    else:
        print("Warning: No preferred font found. Chinese may not display correctly.")

    plt.rcParams["axes.unicode_minus"] = False
    plt.rcParams["figure.dpi"] = 120
    plt.rcParams["savefig.dpi"] = 200


def save_figure(fig_name):
    plt.tight_layout()
    plt.savefig(fig_name, dpi=200, bbox_inches="tight")
    plt.close()


def parse_args():
    parser = argparse.ArgumentParser(
        description="Train Stage1 CQR and optionally export representative test-day Stage2 MAT files."
    )
    parser.add_argument(
        "--multiday",
        action="store_true",
        help="Export representative test-day stage1_cqr_for_stage2.mat files under the sibling supplement directory.",
    )
    parser.add_argument(
        "--multiday-count",
        type=int,
        default=5,
        help="Requested representative test-day count. Actual count may be lower if not enough test midnight origins exist.",
    )
    parser.add_argument(
        "--select-only",
        action="store_true",
        help="Only select and record representative test days; do not train CQR models.",
    )
    return parser.parse_args()


def resolve_origin_position(origin_idx, target_origin_index):
    matches = np.where(origin_idx == target_origin_index)[0]
    if len(matches) == 0:
        raise ValueError(f"target_origin_index={target_origin_index} is not in origin_idx.")
    return int(matches[0])


def select_representative_test_midnights(origin_idx, idx_origin_te, T, U, H, L_hist, steps_per_day, n_days):
    origin_to_pos = {int(origin): int(i) for i, origin in enumerate(origin_idx)}
    test_origins = set(int(x) for x in np.asarray(idx_origin_te).reshape(-1))
    max_day = int(np.floor((len(T) - H - 1) / steps_per_day) + 1)
    candidates = []

    for day_index in range(1, max_day + 1):
        origin = int((day_index - 1) * steps_per_day + 1)
        if origin < L_hist or origin + H > len(T):
            continue
        if origin not in origin_to_pos or origin not in test_origins:
            continue

        U_future = U[origin:origin + H, :]
        candidates.append({
            "label": f"day_{day_index:03d}",
            "day_index": int(day_index),
            "origin_index": int(origin),
            "origin_pos": origin_to_pos[origin],
            "origin_hour": 0.0,
            "is_test_midnight_origin": 1,
            "mean_outdoor_temp": float(np.mean(U_future[:, 2])),
            "max_outdoor_temp": float(np.max(U_future[:, 2])),
            "sum_irradiance": float(np.sum(U_future[:, 3])),
            "mean_internal_gain": float(np.mean(U_future[:, 4])),
            "selection_reason": "candidate",
        })

    if not candidates:
        return []

    selected = []
    used = set()

    def add_candidate(idx, reason):
        if idx is None:
            return
        idx = int(idx)
        if idx in used:
            return
        candidates[idx]["selection_reason"] = reason
        selected.append(candidates[idx])
        used.add(idx)

    temp_mean = np.array([c["mean_outdoor_temp"] for c in candidates], dtype=float)
    solar_sum = np.array([c["sum_irradiance"] for c in candidates], dtype=float)

    add_candidate(np.argmin(np.abs(temp_mean - np.median(temp_mean))), "median_outdoor_temperature")
    add_candidate(np.argmax(temp_mean), "highest_mean_outdoor_temperature")
    add_candidate(np.argmin(temp_mean), "lowest_mean_outdoor_temperature")
    add_candidate(np.argmax(solar_sum), "highest_total_irradiance")
    add_candidate(np.argmin(solar_sum), "lowest_total_irradiance")

    if len(selected) < min(n_days, len(candidates)):
        fill_idx = np.linspace(0, len(candidates) - 1, min(n_days, len(candidates)))
        for idx in np.round(fill_idx).astype(int):
            add_candidate(idx, "evenly_spaced_test_midnight")
            if len(selected) >= n_days:
                break

    selected = selected[:max(0, int(n_days))]
    selected.sort(key=lambda x: x["origin_index"])
    return selected


def build_stage2_payload(pred, U, H, Ts_stage1, coverage_vec, input_names,
                         avg_coverage_test, avg_width_test, metrics, Delta):
    ns = 4
    nC = len(coverage_vec)
    Nh = H // ns
    t0 = int(pred["origin_index"])

    U_future_15min = U[t0:t0 + H, :].copy()
    Ts_future_15min = U_future_15min[:, 0].copy()
    ma_future_15min = U_future_15min[:, 1].copy()
    To_future_15min = U_future_15min[:, 2].copy()
    Isol_future_15min = U_future_15min[:, 3].copy()
    Qint_future_15min = U_future_15min[:, 4].copy()

    T_true_15min = pred["y_true_future"].copy()
    T_pred_15min = pred["yhat_med"].copy()
    T_low_15min = pred["L"].copy()
    T_up_15min = pred["U"].copy()

    T_true_hour = T_true_15min.reshape(Nh, ns).mean(axis=1)
    T_pred_hour = T_pred_15min.reshape(Nh, ns).mean(axis=1)
    T_low_hour = T_low_15min.reshape(Nh, ns, nC).mean(axis=1)
    T_up_hour = T_up_15min.reshape(Nh, ns, nC).mean(axis=1)

    delta_minus_hour = T_pred_hour[:, None] - T_low_hour
    delta_plus_hour = T_up_hour - T_pred_hour[:, None]

    Ts_future_hour = Ts_future_15min.reshape(Nh, ns).mean(axis=1)
    ma_future_hour = ma_future_15min.reshape(Nh, ns).mean(axis=1)
    To_future_hour = To_future_15min.reshape(Nh, ns).mean(axis=1)
    Isol_future_hour = Isol_future_15min.reshape(Nh, ns).mean(axis=1)
    Qint_future_hour = Qint_future_15min.reshape(Nh, ns).mean(axis=1)

    Uc_future_hour = np.column_stack([Ts_future_hour, ma_future_hour])
    D_future_hour = np.column_stack([To_future_hour, Isol_future_hour, Qint_future_hour])

    return {
        "selected_origin_index": t0,
        "stage2_case_label": pred["label"],
        "stage2_day_index": int(pred["day_index"]),
        "stage2_origin_hour": float(pred["origin_hour"]),
        "stage2_selection_reason": pred["selection_reason"],
        "is_test_midnight_origin": int(pred["is_test_midnight_origin"]),
        "H": H,
        "Nh": Nh,
        "ns": ns,
        "Ts_stage1": Ts_stage1,
        "coverage_vec": coverage_vec,
        "input_names": np.array(input_names, dtype=object),
        "ctrl_input_idx": np.array([1, 2]),
        "dist_input_idx": np.array([3, 4, 5]),
        "T_true_15min": T_true_15min,
        "T_pred_15min": T_pred_15min,
        "T_low_15min": T_low_15min,
        "T_up_15min": T_up_15min,
        "T_true_hour": T_true_hour,
        "T_pred_hour": T_pred_hour,
        "T_low_hour": T_low_hour,
        "T_up_hour": T_up_hour,
        "delta_minus_hour": delta_minus_hour,
        "delta_plus_hour": delta_plus_hour,
        "U_future_15min": U_future_15min,
        "Ts_future_15min": Ts_future_15min,
        "ma_future_15min": ma_future_15min,
        "To_future_15min": To_future_15min,
        "Isol_future_15min": Isol_future_15min,
        "Qint_future_15min": Qint_future_15min,
        "Ts_future_hour": Ts_future_hour,
        "ma_future_hour": ma_future_hour,
        "To_future_hour": To_future_hour,
        "Isol_future_hour": Isol_future_hour,
        "Qint_future_hour": Qint_future_hour,
        "Uc_future_hour": Uc_future_hour,
        "D_future_hour": D_future_hour,
        "avg_coverage_test": avg_coverage_test,
        "avg_width_test": avg_width_test,
        "mae_train": metrics["mae_train"],
        "rmse_train": metrics["rmse_train"],
        "mae_cal": metrics["mae_cal"],
        "rmse_cal": metrics["rmse_cal"],
        "mae_test": metrics["mae_test"],
        "rmse_test": metrics["rmse_test"],
        "avg_mae_train": np.mean(metrics["mae_train"]),
        "avg_rmse_train": np.mean(metrics["rmse_train"]),
        "avg_mae_cal": np.mean(metrics["mae_cal"]),
        "avg_rmse_cal": np.mean(metrics["rmse_cal"]),
        "avg_mae_test": np.mean(metrics["mae_test"]),
        "avg_rmse_test": np.mean(metrics["rmse_test"]),
        "Delta_conformal": Delta,
        "manual_stage2_origin_used": int(pred["manual_stage2_origin_used"]),
    }


def write_stage2_case_manifest(cases, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "label", "day_index", "origin_index", "origin_pos", "origin_hour",
        "is_test_midnight_origin", "selection_reason", "mean_outdoor_temp",
        "max_outdoor_temp", "sum_irradiance", "mean_internal_gain", "mat_file",
    ]
    with path.open("w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for case in cases:
            row = {name: case.get(name, "") for name in fieldnames}
            writer.writerow(row)


# ============================================================
# 2) conformal 分位点函数
# ============================================================
def conformal_quantile(scores, coverage):
    scores = np.sort(np.asarray(scores).reshape(-1))
    n = len(scores)
    j = int(np.ceil((n + 1) * coverage)) - 1
    j = max(0, min(j, n - 1))
    return scores[j]


# ============================================================
# 3) 单个 horizon 的训练与评估
# ============================================================
def run_one_horizon(
    k,
    Xk,
    Yk,
    nTr,
    nCal,
    coverage_vec,
    quantile_lo,
    quantile_hi,
    tree_params,
    target_origin_positions,
):
    Xk = ensure_2d_features(Xk, name=f"X_all[{k}]")
    Yk = ensure_1d_numeric(Yk, name=f"Y_all[{k}]")

    if Xk.shape[0] != Yk.shape[0]:
        raise ValueError(
            f"horizon k={k}: Xk 样本数 {Xk.shape[0]} 与 Yk 长度 {Yk.shape[0]} 不一致。"
        )

    Xtr = Xk[:nTr, :]
    Ytr = Yk[:nTr]

    Xcal = Xk[nTr:nTr + nCal, :]
    Ycal = Yk[nTr:nTr + nCal]

    Xte = Xk[nTr + nCal:, :]
    Yte = Yk[nTr + nCal:]

    model_lo = HistGradientBoostingRegressor(
        loss="quantile",
        quantile=quantile_lo,
        **tree_params,
    )
    model_lo.fit(Xtr, Ytr)

    model_hi = HistGradientBoostingRegressor(
        loss="quantile",
        quantile=quantile_hi,
        **tree_params,
    )
    model_hi.fit(Xtr, Ytr)

    model_med = HistGradientBoostingRegressor(
        loss="absolute_error",
        **tree_params,
    )
    model_med.fit(Xtr, Ytr)

    # -----------------------------
    # median model 点预测：train / cal / test
    # -----------------------------
    ymed_tr = model_med.predict(Xtr)
    ymed_cal = model_med.predict(Xcal)
    ymed_te = model_med.predict(Xte)

    mae_tr = mean_absolute_error(Ytr, ymed_tr)
    rmse_tr = np.sqrt(mean_squared_error(Ytr, ymed_tr))

    mae_cal = mean_absolute_error(Ycal, ymed_cal)
    rmse_cal = np.sqrt(mean_squared_error(Ycal, ymed_cal))

    mae_te = mean_absolute_error(Yte, ymed_te)
    rmse_te = np.sqrt(mean_squared_error(Yte, ymed_te))

    # calibration
    qlo_cal = model_lo.predict(Xcal)
    qhi_cal = model_hi.predict(Xcal)
    scores_cal = np.maximum(qlo_cal - Ycal, Ycal - qhi_cal)

    Delta_k = np.full(len(coverage_vec), np.nan)
    for ic, cov in enumerate(coverage_vec):
        Delta_k[ic] = conformal_quantile(scores_cal, cov)

    # test 区间指标
    qlo_te = model_lo.predict(Xte)
    qhi_te = model_hi.predict(Xte)

    coverage_k = np.full(len(coverage_vec), np.nan)
    width_k = np.full(len(coverage_vec), np.nan)

    for ic in range(len(coverage_vec)):
        L_te = qlo_te - Delta_k[ic]
        U_te = qhi_te + Delta_k[ic]
        coverage_k[ic] = np.mean((Yte >= L_te) & (Yte <= U_te))
        width_k[ic] = np.mean(U_te - L_te)

    # 指定起点的单点预测
    target_origin_positions = np.asarray(target_origin_positions, dtype=int).reshape(-1)
    if np.any(target_origin_positions < 0) or np.any(target_origin_positions >= Xk.shape[0]):
        raise IndexError(f"target_origin_positions out of range for horizon k={k}.")

    x_target = Xk[target_origin_positions, :]
    qlo_target = model_lo.predict(x_target)
    qhi_target = model_hi.predict(x_target)
    ymed_target = model_med.predict(x_target)

    L_target = np.full((len(target_origin_positions), len(coverage_vec)), np.nan)
    U_target = np.full((len(target_origin_positions), len(coverage_vec)), np.nan)
    for ic in range(len(coverage_vec)):
        L_target[:, ic] = qlo_target - Delta_k[ic]
        U_target[:, ic] = qhi_target + Delta_k[ic]

    return {
        "k": k,
        "Delta_k": Delta_k,
        "coverage_k": coverage_k,
        "width_k": width_k,

        # 保留原字段，避免影响原主程序兼容性
        "mae_k": mae_te,

        # 新增点预测指标
        "mae_tr_k": mae_tr,
        "rmse_tr_k": rmse_tr,
        "mae_cal_k": mae_cal,
        "rmse_cal_k": rmse_cal,
        "mae_te_k": mae_te,
        "rmse_te_k": rmse_te,

        "yhat_med_target": ymed_target[0],
        "L_target": L_target[0, :],
        "U_target": U_target[0, :],
        "yhat_med_targets": ymed_target,
        "L_targets": L_target,
        "U_targets": U_target,
    }


# ============================================================
# 4) 主程序
# ============================================================
def main():
    args = parse_args()
    setup_plot_style()

    # ------------------------------------------------------------
    # Stage2 导出起点设置：手动指定"某天 0:00"
    # dayIndex 从 1 开始计
    # ------------------------------------------------------------
    use_manual_stage2_midnight_origin = True
    stage2_day_index = 2

    # ------------------------------------------------------------
    # 读取 MATLAB 导出的数据
    # ------------------------------------------------------------
    mat = loadmat_auto(str(STAGE1 / "stage1_cqr_tree_data.mat"))

    H = int(mat["H"])
    L_hist = int(mat["L_hist"])
    coverage_vec = np.atleast_1d(mat["coverage_vec"]).astype(float)
    Ts_stage1 = float(mat["Ts_stage1"])

    T = np.atleast_1d(mat["T"]).astype(float).reshape(-1)
    U = np.atleast_2d(mat["U"]).astype(float)

    if U.shape[1] != 5:
        raise ValueError(
            f"当前重构版要求 U 为 5 列 [Ts, ma, To, Isol, Qint]，实际为 {U.shape[1]} 列。"
        )

    input_names = ["Ts", "ma", "To", "Isol", "Qint"]

    origin_idx = np.atleast_1d(mat["origin_idx"]).astype(int).reshape(-1)
    idx_origin_tr = np.atleast_1d(mat["idx_origin_tr"]).astype(int).reshape(-1)
    idx_origin_cal = np.atleast_1d(mat["idx_origin_cal"]).astype(int).reshape(-1)
    idx_origin_te = np.atleast_1d(mat["idx_origin_te"]).astype(int).reshape(-1)

    X_all = ensure_horizon_container(mat["X_all"], H, name="X_all")
    Y_all = ensure_horizon_container(mat["Y_all"], H, name="Y_all")

    nTr = len(idx_origin_tr)
    nCal = len(idx_origin_cal)
    nTe = len(idx_origin_te)

    steps_per_day = int(round(24 * 3600 / Ts_stage1))

    # ------------------------------------------------------------
    # 手动指定 Stage2 起点
    # ------------------------------------------------------------
    if use_manual_stage2_midnight_origin:
        target_origin_index = (stage2_day_index - 1) * steps_per_day + 1
        print(
            f"Stage2 手动指定起点：第 {stage2_day_index} 天 0:00 -> target_origin_index = {target_origin_index}"
        )

        if target_origin_index < L_hist:
            raise ValueError(
                f"target_origin_index={target_origin_index} < L_hist={L_hist}，"
                "无法构造历史窗口，请把 stage2_day_index 设大一些。"
            )
        if target_origin_index + H > len(T):
            raise ValueError(
                f"target_origin_index + H = {target_origin_index + H} > len(T) = {len(T)}，"
                "所选起点越界。"
            )

        matches = np.where(origin_idx == target_origin_index)[0]
        if len(matches) == 0:
            raise ValueError(f"target_origin_index={target_origin_index} 不在合法 origin_idx 中。")

        target_origin_pos = int(matches[0])
    else:
        target_origin_index = int(idx_origin_te[0])
        print(f"Stage2 默认起点：test集第一个样本 -> target_origin_index = {target_origin_index}")

        matches = np.where(origin_idx == target_origin_index)[0]
        target_origin_pos = int(matches[0])

    # ------------------------------------------------------------
    # tuned tree 参数
    # ------------------------------------------------------------
    primary_case = {
        "label": f"day_{int(stage2_day_index):03d}_primary",
        "day_index": int(stage2_day_index),
        "origin_index": int(target_origin_index),
        "origin_pos": int(target_origin_pos),
        "origin_hour": 0.0,
        "is_test_midnight_origin": int(target_origin_index in set(int(x) for x in idx_origin_te)),
        "selection_reason": "manual_primary_stage2_origin" if use_manual_stage2_midnight_origin else "first_test_origin",
        "mean_outdoor_temp": float(np.mean(U[target_origin_index:target_origin_index + H, 2])),
        "max_outdoor_temp": float(np.max(U[target_origin_index:target_origin_index + H, 2])),
        "sum_irradiance": float(np.sum(U[target_origin_index:target_origin_index + H, 3])),
        "mean_internal_gain": float(np.mean(U[target_origin_index:target_origin_index + H, 4])),
        "manual_stage2_origin_used": int(use_manual_stage2_midnight_origin),
    }

    selected_test_cases = []
    if args.multiday or args.select_only:
        selected_test_cases = select_representative_test_midnights(
            origin_idx, idx_origin_te, T, U, H, L_hist, steps_per_day, args.multiday_count
        )
        for case in selected_test_cases:
            case["manual_stage2_origin_used"] = 0
            case["mat_file"] = str(SUPPLEMENT_STAGE1_TEST_DAYS / case["label"] / "stage1_cqr_for_stage2.mat")

        manifest_path = SUPPLEMENT_STAGE1_TEST_DAYS / "selected_test_days.csv"
        write_stage2_case_manifest(selected_test_cases, manifest_path)
        print(f"Selected {len(selected_test_cases)} test midnight day(s); manifest: {manifest_path}")
        if len(selected_test_cases) < args.multiday_count:
            print(
                f"Requested {args.multiday_count} day(s), but only {len(selected_test_cases)} complete test midnight origin(s) exist."
            )
        if args.select_only:
            return

    stage2_cases = [primary_case]
    if args.multiday:
        seen_origins = {primary_case["origin_index"]}
        for case in selected_test_cases:
            if case["origin_index"] in seen_origins:
                continue
            stage2_cases.append(case)
            seen_origins.add(case["origin_index"])
    target_origin_positions = np.array([case["origin_pos"] for case in stage2_cases], dtype=int)

    quantile_lo = 0.15
    quantile_hi = 0.85

    tree_params = dict(
        max_iter=300,
        learning_rate=0.05,
        max_depth=3,
        min_samples_leaf=60,
        l2_regularization=1e-3,
        random_state=42,
    )

    nC = len(coverage_vec)
    Delta = np.full((H, nC), np.nan)
    coverage_test = np.full((H, nC), np.nan)
    width_test = np.full((H, nC), np.nan)

    # 保留原有
    mae_test = np.full(H, np.nan)

    # 新增
    mae_train = np.full(H, np.nan)
    rmse_train = np.full(H, np.nan)
    mae_cal = np.full(H, np.nan)
    rmse_cal = np.full(H, np.nan)
    rmse_test = np.full(H, np.nan)

    example_preds = []
    for case in stage2_cases:
        origin = int(case["origin_index"])
        example_preds.append({
            **case,
            "H": H,
            "coverage_vec": coverage_vec.copy(),
            "y_true_future": T[origin:origin + H].copy(),
            "L": np.full((H, nC), np.nan),
            "U": np.full((H, nC), np.nan),
            "yhat_med": np.full(H, np.nan),
        })
    example_pred = example_preds[0]

    X_list = [ensure_2d_features(X_all[k], name=f"X_all[{k}]") for k in range(H)]
    Y_list = [ensure_1d_numeric(Y_all[k], name=f"Y_all[{k}]") for k in range(H)]

    for k in range(H):
        if X_list[k].shape[0] != Y_list[k].shape[0]:
            raise ValueError(
                f"预检查失败：horizon k={k}, X_list[k].shape={X_list[k].shape}, Y_list[k].shape={Y_list[k].shape}"
            )

    n_workers = max(1, os.cpu_count() - 1)
    print(f"Using {n_workers} workers for parallel horizon training...")

    with ProcessPoolExecutor(max_workers=n_workers) as executor:
        futures = []
        for k in range(H):
            futures.append(
                executor.submit(
                    run_one_horizon,
                    k,
                    X_list[k],
                    Y_list[k],
                    nTr,
                    nCal,
                    coverage_vec,
                    quantile_lo,
                    quantile_hi,
                    tree_params,
                    target_origin_positions,
                )
            )

        finished = 0
        for fut in as_completed(futures):
            res = fut.result()
            k = res["k"]

            Delta[k, :] = res["Delta_k"]
            coverage_test[k, :] = res["coverage_k"]
            width_test[k, :] = res["width_k"]

            # 保留原逻辑：mae_test 仍来自 test MAE
            mae_test[k] = res["mae_k"]

            # 新增
            mae_train[k] = res["mae_tr_k"]
            rmse_train[k] = res["rmse_tr_k"]
            mae_cal[k] = res["mae_cal_k"]
            rmse_cal[k] = res["rmse_cal_k"]
            rmse_test[k] = res["rmse_te_k"]

            for j, pred in enumerate(example_preds):
                pred["yhat_med"][k] = res["yhat_med_targets"][j]
                pred["L"][k, :] = res["L_targets"][j, :]
                pred["U"][k, :] = res["U_targets"][j, :]

            finished += 1
            if finished % 8 == 0 or finished == 1 or finished == H:
                print(f"Finished {finished}/{H} horizons")

    avg_coverage_test = np.mean(coverage_test, axis=0)
    avg_width_test = np.mean(width_test, axis=0)

    print("\n===== Overall test results (parallel, same logic) =====")
    for ic, cov in enumerate(coverage_vec):
        print(
            f"Target coverage={cov:.2f} | empirical coverage={avg_coverage_test[ic]:.4f} | avg width={avg_width_test[ic]:.4f}"
        )

    print("\n===== Point prediction metrics of median model =====")
    print("Across all horizons:")
    print(f"  Train | MAE  = {np.mean(mae_train):.4f} | RMSE = {np.mean(rmse_train):.4f}")
    print(f"  Cal   | MAE  = {np.mean(mae_cal):.4f} | RMSE = {np.mean(rmse_cal):.4f}")
    print(f"  Test  | MAE  = {np.mean(mae_test):.4f} | RMSE = {np.mean(rmse_test):.4f}")

    print("\n===== Per-horizon point prediction metrics =====")
    for k in range(H):
        print(
            f"horizon {k+1:02d} | "
            f"Train: MAE={mae_train[k]:.4f}, RMSE={rmse_train[k]:.4f} | "
            f"Cal: MAE={mae_cal[k]:.4f}, RMSE={rmse_cal[k]:.4f} | "
            f"Test: MAE={mae_test[k]:.4f}, RMSE={rmse_test[k]:.4f}"
        )

    out = {
        "H": H,
        "coverage_vec": coverage_vec,
        "Delta": Delta,
        "coverage_test": coverage_test,
        "width_test": width_test,
        "avg_coverage_test": avg_coverage_test,
        "avg_width_test": avg_width_test,
        "mae_test": mae_test,

        "mae_train": mae_train,
        "rmse_train": rmse_train,
        "mae_cal": mae_cal,
        "rmse_cal": rmse_cal,
        "rmse_test": rmse_test,

        "avg_mae_train": np.mean(mae_train),
        "avg_rmse_train": np.mean(rmse_train),
        "avg_mae_cal": np.mean(mae_cal),
        "avg_rmse_cal": np.mean(rmse_cal),
        "avg_mae_test": np.mean(mae_test),
        "avg_rmse_test": np.mean(rmse_test),

        "example_origin_index": example_pred["origin_index"],
        "example_y_true_future": example_pred["y_true_future"],
        "example_yhat_med": example_pred["yhat_med"],
        "example_L": example_pred["L"],
        "example_U": example_pred["U"],
        "quantile_lo": quantile_lo,
        "quantile_hi": quantile_hi,
        "max_depth": tree_params["max_depth"],
        "min_samples_leaf": tree_params["min_samples_leaf"],
        "max_iter": tree_params["max_iter"],
        "learning_rate": tree_params["learning_rate"],
        "n_workers": n_workers,
        "manual_stage2_origin_used": int(use_manual_stage2_midnight_origin),
        "stage2_day_index": int(stage2_day_index),
        "target_origin_index": int(example_pred["origin_index"]),
        "stage2_case_labels": np.array([p["label"] for p in example_preds], dtype=object),
        "stage2_case_day_indices": np.array([p["day_index"] for p in example_preds], dtype=int),
        "stage2_case_origin_indices": np.array([p["origin_index"] for p in example_preds], dtype=int),
    }
    savemat(str(STAGE1 / "stage1_cqr_tree_tuned_parallel_results.mat"), out)
    print("Saved stage1_cqr_tree_tuned_parallel_results.mat")

    # with open("stage1_cqr_tree_tuned_parallel_summary.txt", "w", encoding="utf-8") as f:
    #     f.write("===== Overall test results (parallel, same logic) =====\n")
    #     for ic, cov in enumerate(coverage_vec):
    #         f.write(
    #             f"Target coverage={cov:.2f} | empirical coverage={avg_coverage_test[ic]:.4f} | avg width={avg_width_test[ic]:.4f}\n"
    #         )
    #     f.write("\n")
    #     f.write("===== Point prediction metrics of median model =====\n")
    #     f.write("Across all horizons:\n")
    #     f.write(f"  Train | MAE  = {np.mean(mae_train):.4f} | RMSE = {np.mean(rmse_train):.4f}\n")
    #     f.write(f"  Cal   | MAE  = {np.mean(mae_cal):.4f} | RMSE = {np.mean(rmse_cal):.4f}\n")
    #     f.write(f"  Test  | MAE  = {np.mean(mae_test):.4f} | RMSE = {np.mean(rmse_test):.4f}\n")
    #     f.write(f"quantile_lo = {quantile_lo}\n")
    #     f.write(f"quantile_hi = {quantile_hi}\n")
    #     f.write(f"max_depth = {tree_params['max_depth']}\n")
    #     f.write(f"min_samples_leaf = {tree_params['min_samples_leaf']}\n")
    #     f.write(f"max_iter = {tree_params['max_iter']}\n")
    #     f.write(f"learning_rate = {tree_params['learning_rate']}\n")
    #     f.write(f"n_workers = {n_workers}\n")
    #     f.write(f"manual_stage2_origin_used = {use_manual_stage2_midnight_origin}\n")
    #     f.write(f"stage2_day_index = {stage2_day_index}\n")
    #     f.write(f"target_origin_index = {example_pred['origin_index']}\n")

    print("Saved stage1_cqr_tree_tuned_parallel_summary.txt")

    colors = plt.cm.tab10.colors

    plt.figure(figsize=(10, 5))
    for ic, cov in enumerate(coverage_vec):
        plt.plot(np.arange(1, H + 1), coverage_test[:, ic], label=f"target={cov:.2f}", color=colors[ic])
        plt.axhline(cov, linestyle="--", color=colors[ic], alpha=0.7)
    plt.xlabel("预测步长 k（15min）")
    plt.ylabel("经验覆盖率")
    plt.title("Stage1-CQR-Tree-Tuned-Parallel：Test集各 horizon 的经验覆盖率")
    plt.grid(True, alpha=0.3)
    plt.legend()
    save_figure(str(FIGURES / "fig1_coverage_tuned_parallel.png"))

    plt.figure(figsize=(10, 5))
    for ic, cov in enumerate(coverage_vec):
        plt.plot(np.arange(1, H + 1), width_test[:, ic], label=f"coverage={cov:.2f}", color=colors[ic])
    plt.xlabel("预测步长 k（15min）")
    plt.ylabel("平均区间宽度（室温单位）")
    plt.title("Stage1-CQR-Tree-Tuned-Parallel：Test集各 horizon 的平均区间宽度")
    plt.grid(True, alpha=0.3)
    plt.legend()
    save_figure(str(FIGURES / "fig2_width_tuned_parallel.png"))

    plt.figure(figsize=(10, 5))
    tt = np.arange(1, H + 1) / 4.0
    plt.plot(tt, example_pred["y_true_future"], label="真实未来室温", color="black", linewidth=1.8)
    plt.plot(tt, example_pred["yhat_med"], "--", label="树模型点预测", linewidth=1.5)

    ic_show = int(np.argmin(np.abs(coverage_vec - 0.90)))
    plt.fill_between(
        tt,
        example_pred["L"][:, ic_show],
        example_pred["U"][:, ic_show],
        alpha=0.25,
        label=f"CQR区间 (coverage={coverage_vec[ic_show]:.2f})",
    )
    plt.xlabel("未来时间（h）")
    plt.ylabel("室温")
    plt.title(f"Stage1-CQR-Tree-Tuned-Parallel：指定起点({example_pred['origin_index']})的24h室温区间预测")
    plt.grid(True, alpha=0.3)
    plt.legend()
    save_figure(str(FIGURES / "fig3_example_tuned_parallel.png"))

    print("Saved figures:")
    print("  fig1_coverage_tuned_parallel.png")
    print("  fig2_width_tuned_parallel.png")
    print("  fig3_example_tuned_parallel.png")

    # ------------------------------------------------------------
    # 导出供 Stage2 使用的 CQR 结果（重构版：双控制输入）
    # ------------------------------------------------------------
    ns = 4
    nC = len(coverage_vec)
    Nh = H // ns

    t0 = int(example_pred["origin_index"])

    U_future_15min = U[t0:t0 + H, :].copy()
    Ts_future_15min = U_future_15min[:, 0].copy()
    ma_future_15min = U_future_15min[:, 1].copy()
    To_future_15min = U_future_15min[:, 2].copy()
    Isol_future_15min = U_future_15min[:, 3].copy()
    Qint_future_15min = U_future_15min[:, 4].copy()

    T_true_15min = example_pred["y_true_future"].copy()
    T_pred_15min = example_pred["yhat_med"].copy()
    T_low_15min = example_pred["L"].copy()
    T_up_15min = example_pred["U"].copy()

    T_true_hour = T_true_15min.reshape(Nh, ns).mean(axis=1)
    T_pred_hour = T_pred_15min.reshape(Nh, ns).mean(axis=1)
    T_low_hour = T_low_15min.reshape(Nh, ns, nC).mean(axis=1)
    T_up_hour = T_up_15min.reshape(Nh, ns, nC).mean(axis=1)

    delta_minus_hour = T_pred_hour[:, None] - T_low_hour
    delta_plus_hour = T_up_hour - T_pred_hour[:, None]

    Ts_future_hour = Ts_future_15min.reshape(Nh, ns).mean(axis=1)
    ma_future_hour = ma_future_15min.reshape(Nh, ns).mean(axis=1)
    To_future_hour = To_future_15min.reshape(Nh, ns).mean(axis=1)
    Isol_future_hour = Isol_future_15min.reshape(Nh, ns).mean(axis=1)
    Qint_future_hour = Qint_future_15min.reshape(Nh, ns).mean(axis=1)

    Uc_future_hour = np.column_stack([Ts_future_hour, ma_future_hour])
    D_future_hour = np.column_stack([To_future_hour, Isol_future_hour, Qint_future_hour])

    out_stage2 = {
        "selected_origin_index": t0,
        "H": H,
        "Nh": Nh,
        "ns": ns,
        "Ts_stage1": Ts_stage1,
        "coverage_vec": coverage_vec,
        "input_names": np.array(input_names, dtype=object),
        "ctrl_input_idx": np.array([1, 2]),
        "dist_input_idx": np.array([3, 4, 5]),
        # 15min 原始结果
        "T_true_15min": T_true_15min,
        "T_pred_15min": T_pred_15min,
        "T_low_15min": T_low_15min,
        "T_up_15min": T_up_15min,
        # 小时级结果
        "T_true_hour": T_true_hour,
        "T_pred_hour": T_pred_hour,
        "T_low_hour": T_low_hour,
        "T_up_hour": T_up_hour,
        "delta_minus_hour": delta_minus_hour,
        "delta_plus_hour": delta_plus_hour,
        # 未来24h输入与外扰
        "U_future_15min": U_future_15min,
        "Ts_future_15min": Ts_future_15min,
        "ma_future_15min": ma_future_15min,
        "To_future_15min": To_future_15min,
        "Isol_future_15min": Isol_future_15min,
        "Qint_future_15min": Qint_future_15min,
        # 小时平均输入与外扰
        "Ts_future_hour": Ts_future_hour,
        "ma_future_hour": ma_future_hour,
        "To_future_hour": To_future_hour,
        "Isol_future_hour": Isol_future_hour,
        "Qint_future_hour": Qint_future_hour,
        "Uc_future_hour": Uc_future_hour,
        "D_future_hour": D_future_hour,
        # 评估指标
        "avg_coverage_test": avg_coverage_test,
        "avg_width_test": avg_width_test,

        "mae_train": mae_train,
        "rmse_train": rmse_train,
        "mae_cal": mae_cal,
        "rmse_cal": rmse_cal,
        "mae_test": mae_test,
        "rmse_test": rmse_test,

        "avg_mae_train": np.mean(mae_train),
        "avg_rmse_train": np.mean(rmse_train),
        "avg_mae_cal": np.mean(mae_cal),
        "avg_rmse_cal": np.mean(rmse_cal),
        "avg_mae_test": np.mean(mae_test),
        "avg_rmse_test": np.mean(rmse_test),

        "Delta_conformal": Delta,
        "manual_stage2_origin_used": int(use_manual_stage2_midnight_origin),
        "stage2_day_index": int(stage2_day_index),
    }
    savemat(str(STAGE1 / "stage1_cqr_for_stage2.mat"), out_stage2)
    print("Saved stage1_cqr_for_stage2.mat")

    metrics = {
        "mae_train": mae_train,
        "rmse_train": rmse_train,
        "mae_cal": mae_cal,
        "rmse_cal": rmse_cal,
        "mae_test": mae_test,
        "rmse_test": rmse_test,
    }
    if args.multiday:
        saved_cases = []
        for pred in example_preds[1:]:
            case_dir = SUPPLEMENT_STAGE1_TEST_DAYS / pred["label"]
            case_dir.mkdir(parents=True, exist_ok=True)
            out_case = build_stage2_payload(
                pred, U, H, Ts_stage1, coverage_vec, input_names,
                avg_coverage_test, avg_width_test, metrics, Delta
            )
            case_file = case_dir / "stage1_cqr_for_stage2.mat"
            savemat(str(case_file), out_case)
            pred["mat_file"] = str(case_file)
            saved_cases.append(pred)
            print(f"Saved multiday Stage2 CQR MAT: {case_file}")

        manifest_rows = []
        for pred in saved_cases:
            manifest_rows.append({
                "label": pred["label"],
                "day_index": pred["day_index"],
                "origin_index": pred["origin_index"],
                "origin_pos": pred["origin_pos"],
                "origin_hour": pred["origin_hour"],
                "is_test_midnight_origin": pred["is_test_midnight_origin"],
                "selection_reason": pred["selection_reason"],
                "mean_outdoor_temp": pred["mean_outdoor_temp"],
                "max_outdoor_temp": pred["max_outdoor_temp"],
                "sum_irradiance": pred["sum_irradiance"],
                "mean_internal_gain": pred["mean_internal_gain"],
                "mat_file": pred["mat_file"],
            })
        write_stage2_case_manifest(manifest_rows, SUPPLEMENT_STAGE1_TEST_DAYS / "selected_test_days.csv")

    # with open("stage1_cqr_for_stage2_readme.txt", "w", encoding="utf-8") as f:
    #     f.write("stage1_cqr_for_stage2.mat 导出说明\n")
    #     f.write("================================\n")
    #     f.write("1) 该文件基于手动指定的某天0:00起点导出。\n")
    #     f.write("2) T_low_hour / T_up_hour 为未来24h的小时级温度区间。\n")
    #     f.write("3) delta_minus_hour / delta_plus_hour 为小时级上下安全裕度。\n")
    #     f.write("4) Stage2 只需要小时温度约束，不再使用 15min 子步温度约束。\n")
    #     f.write("5) 控制输入已重构为 [Ts, ma]，不再导出 Q_future_hour。\n")
    #     f.write(f"6) selected_origin_index = {t0}\n")
    #     f.write(f"7) stage2_day_index = {stage2_day_index}\n")

    print("Saved stage1_cqr_for_stage2_readme.txt")


if __name__ == "__main__":
    main()
