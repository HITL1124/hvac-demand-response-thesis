function figs = plot_ch3_hourly_reserve_costcurve_results_V2(in, plot_cfg)
% =========================================================================
% 第三章：逐小时备用成本曲线结果绘图（含图1~图15）
%
% 从总结果文件选定置信度画图：
% $$
% plot\_cfg = struct();
% plot\_cfg.beta_select = 0.95;
% plot\_cfg.beta\_compare_list = [0.80\ 0.85\ 0.90\ 0.95];
% figs = plot_ch3_hourly_reserve_costcurve_results_V2(project_data_file('reserve', 'hourly_reserve_costcurve_all_beta.mat'));
% $$
%
% 支持：
%   1) figs = plot_ch3_hourly_reserve_costcurve_results(out);
%   2) figs = plot_ch3_hourly_reserve_costcurve_results('single_beta_mat.mat');
%   3) figs = plot_ch3_hourly_reserve_costcurve_results(results_all, plot_cfg);
%   4) figs = plot_ch3_hourly_reserve_costcurve_results('hourly_reserve_costcurve_all_beta.mat', plot_cfg);
%
% 说明：
%   - 如果你像下面这样直接调用：
%       plot_ch3_hourly_reserve_costcurve_results_V2('...hourly_reserve_costcurve_all_beta.mat');
%     那么默认展示的 beta 由本文件顶部的 default_beta_select 决定。
% =========================================================================

if nargin < 1
    error('必须提供结果结构体或结果文件路径。');
end
if nargin < 2 || isempty(plot_cfg)
    plot_cfg = struct();
end

% ========================================================================
% 只改这一行，就能改变"直接调用时"的默认展示 beta
% ========================================================================
default_beta_select = 0.95;

S = local_load_any(in);
[out, results_all, plot_cfg] = local_select_out(S, plot_cfg, default_beta_select);
plot_cfg = local_fill_plot_defaults(plot_cfg, out, default_beta_select);

cfg = out.cfg;
baseline = out.baseline;
hours = out.hours;
Nh = out.mdl.Nh;
Nk = out.mdl.H15;
hvec = (1:Nh).';

if ~isempty(plot_cfg.outdir)
    cfg.outdir = plot_cfg.outdir;
end
if ~exist(cfg.outdir, 'dir')
    mkdir(cfg.outdir);
end

figs = {};

%% 图1：天然备用与最大可行备用
Rnat = out.R_nat_hour(:);
Rmax = nan(Nh,1);
for h = 1:Nh
    if isfield(hours(h), 'max_feasible_R')
        Rmax(h) = hours(h).max_feasible_R;
    end
end

f1 = figure('Color','w'); hold on; box on; grid on;
plot(hvec, Rnat, '-o', 'LineWidth', 1.8, 'MarkerSize', 5, 'DisplayName','天然备用 R_{nat}');
plot(hvec, Rmax, '-s', 'LineWidth', 1.8, 'MarkerSize', 5, 'DisplayName','最大可行备用');
xlabel('小时 h');
ylabel('备用 (kW)');
title(sprintf('逐小时天然备用与最大可行备用 (beta=%.2f)', out.beta_use));
legend('Location','best');
file1 = fullfile(cfg.outdir, sprintf('fig1_hourly_reserve_bounds_beta_%02d.png', round(100*out.beta_use)));

figs{end+1} = file1;

%% 图2：不同置信度下的最大可行备用
cmp_outs = local_collect_compare_outs(out, results_all, plot_cfg);
clr_beta = lines(max(4, numel(cmp_outs)));

f2 = figure('Color','w'); hold on; box on; grid on;
plot(hvec, Rnat, '-k', 'LineWidth', 2.0, 'MarkerSize', 5, 'DisplayName','天然备用 R_{nat}');
for ibeta = 1:numel(cmp_outs)
    outb = cmp_outs{ibeta};
    Rmax_b = local_get_max_feasible_reserve_series(outb);
    plot(hvec, Rmax_b, '-o', ...
        'Color', clr_beta(ibeta,:), ...
        'LineWidth', 1.7, ...
        'MarkerSize', 4, ...
        'DisplayName', sprintf('最大可行备用 (\\beta=%.2f)', outb.beta_use));
end
xlabel('小时 h');
ylabel('备用 (kW)');
title('不同置信度下的逐小时最大可行备用');
legend('Location','best');
file2 = fullfile(cfg.outdir, 'fig2_hourly_max_feasible_reserve_compare_multi_beta.png');

figs{end+1} = file2;

%% 图3：基线功率分解
Php_hour = local_get_hour_series(baseline, 'Php_hour', 'Php');
Pfan_hour = local_get_hour_series(baseline, 'Pfan_hour', 'Pfan');
Ptot_hour = local_get_hour_series(baseline, 'Pbase_hour', 'Ptot');

f3 = figure('Color','w');
tiledlayout(2,1,'TileSpacing','compact','Padding','compact');

nexttile; hold on; box on; grid on;
bar(hvec, [Php_hour(:), Pfan_hour(:)], 'stacked');
plot(hvec, Ptot_hour(:), '-ko', 'LineWidth', 1.4, 'MarkerSize', 4, 'DisplayName','总功率');
xlabel('小时 h');
ylabel('功率 (kW)');
title('基线功率分解');
legend({'机组/热泵功率','风机功率','总功率'}, 'Location','best');

nexttile; hold on; box on; grid on;
plot(hvec, Php_hour(:), '-o', 'LineWidth', 1.5, 'MarkerSize', 4, 'DisplayName','机组/热泵');
plot(hvec, Pfan_hour(:), '-s', 'LineWidth', 1.5, 'MarkerSize', 4, 'DisplayName','风机');
plot(hvec, Ptot_hour(:), '-^', 'LineWidth', 1.5, 'MarkerSize', 4, 'DisplayName','总功率');
xlabel('小时 h');
ylabel('功率 (kW)');
title('基线功率分量时序');
legend('Location','best');

file3 = fullfile(cfg.outdir, sprintf('fig3_baseline_power_breakdown_beta_%02d.png', round(100*out.beta_use)));

figs{end+1} = file3;

%% 图4：基线控制量
Ts_hour_C = baseline.Ts_hour(:) - 273.15;
ma_hour = baseline.ma_hour(:);

f4 = figure('Color','w');
tiledlayout(2,1,'TileSpacing','compact','Padding','compact');

nexttile; hold on; box on; grid on;
plot(hvec, Ts_hour_C, '-o', 'LineWidth', 1.6, 'MarkerSize', 4);
xlabel('小时 h');
ylabel('T_s (°C)');
title('基线控制量：送风/供水温度');

nexttile; hold on; box on; grid on;
plot(hvec, ma_hour, '-o', 'LineWidth', 1.6, 'MarkerSize', 4);
xlabel('小时 h');
ylabel('m_a');
title('基线控制量：送风质量流量');

file4 = fullfile(cfg.outdir, sprintf('fig4_baseline_controls_beta_%02d.png', round(100*out.beta_use)));

figs{end+1} = file4;

%% 图5：24小时成本曲线总览（4x6）
f5 = figure('Color','w');
tiledlayout(4,6,'TileSpacing','compact','Padding','compact');
for h = 1:Nh
    nexttile; hold on; box on; grid on;
    Hr = hours(h);
    if ~isempty(Hr.R_grid)
        plot(Hr.R_grid(Hr.is_feasible), Hr.delta_total(Hr.is_feasible), '-o', ...
            'LineWidth', 1.2, 'MarkerSize', 4);
        xline(Hr.R_nat, ':k', 'LineWidth', 0.8);
        if ~isnan(Hr.max_feasible_R)
            xline(Hr.max_feasible_R, '--r', 'LineWidth', 0.8);
        end
    end
    title(sprintf('h=%02d', h));
    xlabel('R');
    ylabel('\DeltaJ');
end
file5 = fullfile(cfg.outdir, sprintf('fig5_hourly_cost_curves_overview_beta_%02d.png', round(100*out.beta_use)));

figs{end+1} = file5;

%% 图6：典型小时方案与基线的全天控制量对比
[sol_typ, idx_typ, R_typ] = local_pick_typical_solution(out, plot_cfg.typical_hour, plot_cfg.typical_solution_mode);
if ~isempty(sol_typ)
    f6 = figure('Color','w');
    tiledlayout(2,1,'TileSpacing','compact','Padding','compact');

    nexttile; hold on; box on; grid on;
    plot(hvec, baseline.Ts_hour(:) - 273.15, '-ko', 'LineWidth', 1.5, 'MarkerSize', 4, 'DisplayName','基线');
    plot(hvec, sol_typ.Ts_hour(:) - 273.15, '-s', 'LineWidth', 1.5, 'MarkerSize', 4, 'DisplayName','典型小时方案');
    xline(plot_cfg.typical_hour, ':r', 'LineWidth', 1.0, 'DisplayName','典型小时');
    xlabel('小时 h');
    ylabel('T_s (°C)');
    title(sprintf('典型小时 h=%02d 与基线的全天控制量对比：T_s（R=%.4f kW）', plot_cfg.typical_hour, R_typ));
    legend('Location','best');

    nexttile; hold on; box on; grid on;
    plot(hvec, baseline.ma_hour(:), '-ko', 'LineWidth', 1.5, 'MarkerSize', 4, 'DisplayName','基线');
    plot(hvec, sol_typ.ma_hour(:), '-s', 'LineWidth', 1.5, 'MarkerSize', 4, 'DisplayName','典型小时方案');
    xline(plot_cfg.typical_hour, ':r', 'LineWidth', 1.0, 'DisplayName','典型小时');
    xlabel('小时 h');
    ylabel('m_a');
    title(sprintf('典型小时 h=%02d 与基线的全天控制量对比：m_a（第 %d 个可行点）', plot_cfg.typical_hour, idx_typ));
    legend('Location','best');

    file6 = fullfile(cfg.outdir, sprintf('fig6_typical_hour_%02d_control_vs_baseline_beta_%02d.png', plot_cfg.typical_hour, round(100*out.beta_use)));

    figs{end+1} = file6;
end

%% 图7~9：指定小时详细图
for hh = 1:numel(cfg.hours_to_plot)
    h = cfg.hours_to_plot(hh);
    if h < 1 || h > Nh
        continue;
    end
    Hr = hours(h);
    if isempty(Hr.R_grid)
        continue;
    end

    f = figure('Color','w');
    tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

    nexttile; hold on; box on; grid on;
    plot(Hr.R_grid(Hr.is_feasible), Hr.delta_total(Hr.is_feasible), '-o', 'LineWidth', 1.6);
    xline(Hr.R_nat, ':k', 'LineWidth', 1.0);
    if ~isnan(Hr.max_feasible_R)
        xline(Hr.max_feasible_R, '--r', 'LineWidth', 1.0);
    end
    xlabel('R (kW)'); ylabel('\DeltaJ');
    title(sprintf('h=%02d: 备用成本曲线', h));

    nexttile; hold on; box on; grid on;
    plot(Hr.R_grid(Hr.is_feasible), Hr.delta_energy(Hr.is_feasible), '-s', 'LineWidth', 1.5, 'DisplayName','\Delta Energy');
    plot(Hr.R_grid(Hr.is_feasible), Hr.delta_temp(Hr.is_feasible), '-^', 'LineWidth', 1.5, 'DisplayName','\Delta Temp');
    xlabel('R (kW)'); ylabel('增量');
    legend('Location','best');
    title('成本构成');

    nexttile; hold on; box on; grid on;
    plot(Hr.R_grid(Hr.is_feasible), Hr.ma_hour(Hr.is_feasible), '-o', 'LineWidth', 1.5, 'DisplayName','ma(h)');
    yline(baseline.ma_hour(h), ':k', 'LineWidth', 1.0, 'DisplayName','baseline ma(h)');
    xlabel('R (kW)'); ylabel('ma');
    legend('Location','best');
    title('目标小时风量工作点');

    nexttile; hold on; box on; grid on;
    plot(Hr.R_grid(Hr.is_feasible), Hr.Pfan_hour(Hr.is_feasible), '-o', 'LineWidth', 1.5, 'DisplayName','Pfan(h)');
    yline(baseline.Pfan_hour(h), ':k', 'LineWidth', 1.0, 'DisplayName','baseline Pfan(h)');
    xlabel('R (kW)'); ylabel('Pfan (kW)');
    legend('Location','best');
    title('目标小时风机功率工作点');

    fileh = fullfile(cfg.outdir, sprintf('fig7to9_hour_%02d_detail_beta_%02d.png', h, round(100*out.beta_use)));

    figs{end+1} = fileh;
end

%% 图10：当前置信度下，12/13/14/15点的室温图（四子图）
f10 = figure('Color','w');
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

for ii = 1:numel(plot_cfg.temp_hours_4panel)
    h = plot_cfg.temp_hours_4panel(ii);
    if h < 1 || h > Nh, continue; end
    Hr = hours(h);

    nexttile; hold on; box on; grid on;

    if isfield(Hr,'theta_risk_lb') && isfield(Hr,'theta_risk_ub')
        fill([1:Nk, fliplr(1:Nk)], ...
             [Hr.theta_risk_lb(:).', fliplr(Hr.theta_risk_ub(:).')], ...
             [0.85 0.90 1.00], ...
             'FaceAlpha', 0.35, 'EdgeColor', 'none', ...
             'DisplayName', sprintf('风险收缩舒适区间 (%.2f)', out.beta_use));
    end

    plot(1:Nk, baseline.T15(:), '-k', 'LineWidth', 1.8, 'DisplayName', '基线');

    idx_show = local_pick_reserve_indices(Hr, plot_cfg.n_temp_curves);
    for jj = 1:numel(idx_show)
        iR = idx_show(jj);
        if Hr.is_feasible(iR)
            plot(1:Nk, Hr.solutions{iR}.T15(:), '--', 'LineWidth', 1.2, ...
                'DisplayName', sprintf('R=%.2f kW', Hr.R_grid(iR)));
        end
    end

    xlabel('时间步');
    ylabel('室温 (K)');
    title(sprintf('小时 %02d 室温', h));
    legend('Location','best');
end

file10 = fullfile(cfg.outdir, sprintf('fig10_temp_4panel_beta_%02d.png', round(100*out.beta_use)));

figs{end+1} = file10;


%% ========================================================================
% 图11：固定某两个小时时，不同备用水平下的控制方案与基线对比（2×2）
% ========================================================================

ctrl_hours = plot_cfg.ctrl_compare_hours;
if numel(ctrl_hours) < 2
    ctrl_hours = [12 13];
end
ctrl_hours = ctrl_hours(1:2);

f11 = figure('Color','w');
tl11 = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

for jj = 1:2
    h_fix = ctrl_hours(jj);
    if h_fix < 1 || h_fix > Nh
        continue;
    end

    Hr = hours(h_fix);
    if isempty(Hr.R_grid)
        continue;
    end

    idx_show = local_pick_reserve_indices(Hr, plot_cfg.n_ctrl_curves);
    if isempty(idx_show)
        continue;
    end

    % -------- 上排：Ts --------
    ax_ts = nexttile(tl11, jj);
    hold(ax_ts,'on'); box(ax_ts,'on'); grid(ax_ts,'on');

    plot(ax_ts, hvec, baseline.Ts_hour(:)-273.15, ...
        '-k', 'LineWidth', 2.0, 'DisplayName', '基线');

    for kk = 1:numel(idx_show)
        iR = idx_show(kk);
        if ~Hr.is_feasible(iR) || isempty(Hr.solutions{iR})
            continue;
        end
        solk = Hr.solutions{iR};
        plot(ax_ts, hvec, solk.Ts_hour(:)-273.15, ...
            '-', 'LineWidth', 1.6, ...
            'DisplayName', sprintf('R=%.2f kW', Hr.R_grid(iR)));
    end

    xlabel(ax_ts,'小时 h');
    ylabel(ax_ts,'T_s (°C)');
    title(ax_ts, sprintf('图11-%d：固定 h=%02d 时，不同备用水平下的全天 T_s 对比', jj, h_fix));
    legend(ax_ts,'Location','best');

    % -------- 下排：ma --------
    ax_ma = nexttile(tl11, jj+2);
    hold(ax_ma,'on'); box(ax_ma,'on'); grid(ax_ma,'on');

    plot(ax_ma, hvec, baseline.ma_hour(:), ...
        '-k', 'LineWidth', 2.0, 'DisplayName', '基线');

    for kk = 1:numel(idx_show)
        iR = idx_show(kk);
        if ~Hr.is_feasible(iR) || isempty(Hr.solutions{iR})
            continue;
        end
        solk = Hr.solutions{iR};
        plot(ax_ma, hvec, solk.ma_hour(:), ...
            '-', 'LineWidth', 1.6, ...
            'DisplayName', sprintf('R=%.2f kW', Hr.R_grid(iR)));
    end

    xlabel(ax_ma,'小时 h');
    ylabel(ax_ma,'m_a');
    title(ax_ma, sprintf('图11-%d：固定 h=%02d 时，不同备用水平下的全天 m_a 对比', jj+2, h_fix));
    legend(ax_ma,'Location','best');
end

figs{end+1} = f11;

%% ========================================================================
% 图12
% ========================================================================

h_fix = plot_cfg.typical_hour;

Hr_ref = hours(h_fix);
idx_ref = local_pick_typical_idx(Hr_ref, plot_cfg.typical_solution_mode);
assert(~isnan(idx_ref), '图12：未找到典型小时可行解。');

R_fix = Hr_ref.R_grid(idx_ref);
cmp_outs = local_collect_compare_outs(out, results_all, plot_cfg);

cmp_colors = lines(max(4, numel(cmp_outs)));
line_styles = {'-','--',':','-.'};
markers = {'o','s','d','^'};

f12 = figure('Color','w');
tl12 = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

%% -------- 第一行：温度图（跨两列）--------
ax1 = nexttile(tl12,[1 2]);
hold(ax1,'on'); box(ax1,'on'); grid(ax1,'on');

legend_handles = [];
legend_names = {};

hb = plot(ax1, 1:Nk, baseline.T15(:), '-k', 'LineWidth', 2.0);
legend_handles(end+1) = hb;
legend_names{end+1} = '基线';

for k = 1:numel(cmp_outs)
    outk = cmp_outs{k};
    Hrk = outk.hours(h_fix);

    idxk = local_pick_idx_nearest_R(Hrk, R_fix);
    if isnan(idxk)
        continue;
    end

    solk = Hrk.solutions{idxk};
    Rk = Hrk.R_grid(idxk);
    ck = cmp_colors(k,:);
    ls = line_styles{1 + mod(k-1, numel(line_styles))};
    mk = markers{1 + mod(k-1, numel(markers))};

    if isfield(Hrk,'theta_risk_lb') && isfield(Hrk,'theta_risk_ub')
        hp = fill(ax1, [1:Nk, fliplr(1:Nk)], ...
            [Hrk.theta_risk_lb(:).', fliplr(Hrk.theta_risk_ub(:).')], ...
            ck, 'FaceAlpha', 0.10, 'EdgeColor', 'none');
        legend_handles(end+1) = hp;
        legend_names{end+1} = sprintf('舒适区间 \\beta=%.2f', outk.beta_use);
    end

    ht = plot(ax1, 1:Nk, solk.T15(:), ...
        'Color', ck, ...
        'LineStyle', ls, ...
        'Marker', mk, ...
        'MarkerIndices', round(linspace(1,Nk,8)), ...
        'LineWidth', 1.8, ...
        'MarkerSize', 4);
    legend_handles(end+1) = ht;
    legend_names{end+1} = sprintf('方案 \\beta=%.2f, R=%.2f kW', outk.beta_use, Rk);
end

xlabel(ax1,'时间步');
ylabel(ax1,'室温 (K)');
title(ax1, sprintf('图12-1：固定小时 h=%02d、固定备用约 R=%.2f kW 下，不同置信度的风险舒适区间与室温轨迹', ...
    h_fix, R_fix));
legend(ax1, legend_handles, legend_names, 'Location','best');

%% -------- 第二行左：Ts --------
ax2 = nexttile(tl12,3);
hold(ax2,'on'); box(ax2,'on'); grid(ax2,'on');

plot(ax2, hvec, baseline.Ts_hour(:)-273.15, ...
    '-k', 'LineWidth', 2.0, 'DisplayName', '基线');

for k = 1:numel(cmp_outs)
    outk = cmp_outs{k};
    Hrk = outk.hours(h_fix);
    idxk = local_pick_idx_nearest_R(Hrk, R_fix);
    if isnan(idxk)
        continue;
    end
    solk = Hrk.solutions{idxk};

    plot(ax2, hvec, solk.Ts_hour(:)-273.15, ...
        'Color', cmp_colors(k,:), ...
        'LineStyle', line_styles{1 + mod(k-1, numel(line_styles))}, ...
        'Marker', markers{1 + mod(k-1, numel(markers))}, ...
        'MarkerIndices', 1:2:Nh, ...
        'LineWidth', 1.8, ...
        'MarkerSize', 4, ...
        'DisplayName', sprintf('\\beta=%.2f, R=%.2f kW', outk.beta_use, Hrk.R_grid(idxk)));
end

xlabel(ax2,'小时 h');
ylabel(ax2,'T_s (°C)');
title(ax2, sprintf('图12-2a：固定 h=%02d、R≈%.2f kW 下的全天 T_s 对比', h_fix, R_fix));
legend(ax2,'Location','best');

%% -------- 第二行右：ma --------
ax3 = nexttile(tl12,4);
hold(ax3,'on'); box(ax3,'on'); grid(ax3,'on');

plot(ax3, hvec, baseline.ma_hour(:), ...
    '-k', 'LineWidth', 2.0, 'DisplayName', '基线');

for k = 1:numel(cmp_outs)
    outk = cmp_outs{k};
    Hrk = outk.hours(h_fix);
    idxk = local_pick_idx_nearest_R(Hrk, R_fix);
    if isnan(idxk)
        continue;
    end
    solk = Hrk.solutions{idxk};

    plot(ax3, hvec, solk.ma_hour(:), ...
        'Color', cmp_colors(k,:), ...
        'LineStyle', line_styles{1 + mod(k-1, numel(line_styles))}, ...
        'Marker', markers{1 + mod(k-1, numel(markers))}, ...
        'MarkerIndices', 1:2:Nh, ...
        'LineWidth', 1.8, ...
        'MarkerSize', 4, ...
        'DisplayName', sprintf('\\beta=%.2f, R=%.2f kW', outk.beta_use, Hrk.R_grid(idxk)));
end

xlabel(ax3,'小时 h');
ylabel(ax3,'m_a');
title(ax3, sprintf('图12-2b：固定 h=%02d、R≈%.2f kW 下的全天 m_a 对比', h_fix, R_fix));
legend(ax3,'Location','best');

figs{end+1} = f12;

%% ========================================================================
% 图13：替换原图12整段
% ========================================================================

f13 = figure('Color','w');
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

for k = 1:min(4,numel(cmp_outs))
    outk = cmp_outs{k};
    Hrk = outk.hours(h_fix);
    idxk = local_pick_idx_nearest_R(Hrk, R_fix);
    if isnan(idxk)
        continue;
    end
    solk = Hrk.solutions{idxk};
    Rk = Hrk.R_grid(idxk);

    nexttile; hold on; box on; grid on;
    bar(hvec, [solk.Php_hour(:), solk.Pfan_hour(:)], 'stacked', 'LineWidth', 0.8);
    plot(hvec, solk.Pbase_hour(:), '-ko', 'LineWidth', 1.4, 'MarkerSize', 4);
    xlabel('小时 h');
    ylabel('功率 (kW)');
    title(sprintf('固定小时 h=%02d 下，\\beta=%.2f，R=%.2f kW 的全天功率分解', ...
        h_fix, outk.beta_use, Rk));
    legend({'机组/热泵功率','风机功率','总功率'}, 'Location','best');
end

figs{end+1} = f13;

%% ========================================================================
% 图14：不同置信度下分别绘制"备用水平-时间-成本曲面图"
% ========================================================================

cmp_outs = local_collect_compare_outs(out, results_all, plot_cfg);

for k = 1:numel(cmp_outs)
    outk = cmp_outs{k};
    Nhk = outk.mdl.Nh;

    Rgrid_all = [];
    time_all  = [];
    cost_all  = [];

    for h = 1:Nhk
        Hr = outk.hours(h);
        if isempty(Hr.R_grid)
            continue;
        end
        feasible_idx = find(Hr.is_feasible);
        if isempty(feasible_idx)
            continue;
        end

        Rgrid_all = [Rgrid_all; Hr.R_grid(feasible_idx)];
        cost_all  = [cost_all; Hr.delta_total(feasible_idx)];
        time_all  = [time_all; h*ones(numel(feasible_idx),1)];
    end

    if isempty(Rgrid_all)
        continue;
    end

    [TimeGrid, RGrid] = meshgrid(unique(time_all), unique(Rgrid_all));
    CostGrid = griddata(time_all, Rgrid_all, cost_all, TimeGrid, RGrid, 'linear');

    f14k = figure('Color','w');
    surf(TimeGrid, RGrid, CostGrid, 'EdgeColor', 'none');
    hold on; box on; grid on;
    xlabel('时间 h');
    ylabel('备用水平 R (kW)');
    zlabel('增量成本 \Delta J');
    title(sprintf('图14-%d：备用水平-时间-成本曲面图（置信度 %.2f）', k, outk.beta_use));
    colorbar;
    view(45,30);

    figs{end+1} = f14k;
end

%% ========================================================================
% 图15：不同置信度下的空间曲面叠加图
% ========================================================================

f15 = figure('Color','w');
hold on; box on; grid on;

surf_colors = lines(max(4, numel(cmp_outs)));
legend_handles = [];
legend_names = {};

for k = 1:numel(cmp_outs)
    outk = cmp_outs{k};
    Nhk = outk.mdl.Nh;

    Rgrid_all = [];
    time_all  = [];
    cost_all  = [];

    for h = 1:Nhk
        Hr = outk.hours(h);
        if isempty(Hr.R_grid)
            continue;
        end
        feasible_idx = find(Hr.is_feasible);
        if isempty(feasible_idx)
            continue;
        end

        Rgrid_all = [Rgrid_all; Hr.R_grid(feasible_idx)];
        cost_all  = [cost_all; Hr.delta_total(feasible_idx)];
        time_all  = [time_all; h*ones(numel(feasible_idx),1)];
    end

    if isempty(Rgrid_all)
        continue;
    end

    [TimeGrid, RGrid] = meshgrid(unique(time_all), unique(Rgrid_all));
    CostGrid = griddata(time_all, Rgrid_all, cost_all, TimeGrid, RGrid, 'linear');

    hs = surf(TimeGrid, RGrid, CostGrid, ...
        'EdgeColor', 'none', ...
        'FaceAlpha', 0.30, ...
        'FaceColor', surf_colors(k,:));

    legend_handles(end+1) = hs;
    legend_names{end+1} = sprintf('\\beta=%.2f', outk.beta_use);
end

xlabel('时间 h');
ylabel('备用水平 R (kW)');
zlabel('增量成本 \Delta J');
title('图15：不同置信度下的备用水平-时间-成本曲面叠加图');
view(45,30);
legend(legend_handles, legend_names, 'Location','best');

figs{end+1} = f15;

end


function y = local_get_max_feasible_reserve_series(outi)
Nh = outi.mdl.Nh;
y = nan(Nh,1);
for h = 1:Nh
    if h <= numel(outi.hours) && isfield(outi.hours(h), 'max_feasible_R')
        y(h) = outi.hours(h).max_feasible_R;
    end
end
end


function idx = local_pick_idx_nearest_R(Hr, Rtar)
idx = NaN;
feas_idx = find(Hr.is_feasible);
if isempty(feas_idx)
    return;
end
[~, ii] = min(abs(Hr.R_grid(feas_idx) - Rtar));
idx = feas_idx(ii);
end


function S = local_load_any(in)
if isstruct(in)
    S = in;
    return;
end
if ischar(in) || isstring(in)
    matFile = char(in);
    assert(exist(matFile,'file')==2, '未找到结果文件：%s', matFile);
    S = load(matFile);
    return;
end
error('输入必须是结构体或 .mat 文件路径。');
end


function [out, results_all, plot_cfg] = local_select_out(S, plot_cfg, default_beta_select)
results_all = [];

if isfield(S,'out')
    out = S.out;
    return;
end

if isfield(S,'out_i')
    out = S.out_i;
    return;
end

if isfield(S,'results_all')
    results_all = S.results_all;

    if ~isfield(plot_cfg,'beta_select') || isempty(plot_cfg.beta_select)
        plot_cfg.beta_select = 0.85;
    end

    beta_all = [S.results_all.beta_use];
    [~, idx] = min(abs(beta_all - plot_cfg.beta_select));
    out = S.results_all(idx).out;
    return;
end

if isfield(S,'beta_use') && isfield(S,'hours')
    out = S;
    return;
end

error('无法识别输入数据结构。');
end


function plot_cfg = local_fill_plot_defaults(plot_cfg, out, default_beta_select) %#ok<INUSD>
if ~isfield(plot_cfg,'outdir'); plot_cfg.outdir = project_data_file('figures'); end
if ~isfield(plot_cfg,'beta_select') || isempty(plot_cfg.beta_select)
    plot_cfg.beta_select = 0.85;
end
if ~isfield(plot_cfg,'beta_compare_list') || isempty(plot_cfg.beta_compare_list)
    plot_cfg.beta_compare_list = [0.80 0.85 0.90 0.95];
end
if ~isfield(plot_cfg,'temp_hours_4panel') || isempty(plot_cfg.temp_hours_4panel)
    plot_cfg.temp_hours_4panel = [12 13 14 15];
end
if ~isfield(plot_cfg,'n_temp_curves') || isempty(plot_cfg.n_temp_curves)
    plot_cfg.n_temp_curves = 6;
end
if ~isfield(plot_cfg,'typical_hour') || isempty(plot_cfg.typical_hour)
    plot_cfg.typical_hour = 13;
end
if ~isfield(plot_cfg,'ctrl_compare_hours') || isempty(plot_cfg.ctrl_compare_hours)
    plot_cfg.ctrl_compare_hours = [12 13];
end
if ~isfield(plot_cfg,'n_ctrl_curves') || isempty(plot_cfg.n_ctrl_curves)
    plot_cfg.n_ctrl_curves = 5;
end
if ~isfield(plot_cfg,'typical_solution_mode') || isempty(plot_cfg.typical_solution_mode)
    plot_cfg.typical_solution_mode = 'max_feasible';
end
end


function y = local_get_hour_series(sol, fieldHour, field15)
if isfield(sol, fieldHour) && ~isempty(sol.(fieldHour))
    y = sol.(fieldHour)(:);
    return;
end
if isfield(sol, field15) && isfield(sol, 'Ts_hour')
    Nh = numel(sol.Ts_hour);
    ns = numel(sol.(field15)) / Nh;
    y = mean(reshape(sol.(field15), ns, Nh), 1).';
    return;
end
error('无法从结果中读取字段 %s 或 %s。', fieldHour, field15);
end


function [sol_typ, idx_typ, R_typ] = local_pick_typical_solution(out, h, modeSel)
sol_typ = [];
idx_typ = NaN;
R_typ = NaN;
if h < 1 || h > out.mdl.Nh
    return;
end
Hr = out.hours(h);
if isempty(Hr.solutions)
    return;
end
feas_idx = find(Hr.is_feasible);
if isempty(feas_idx)
    return;
end

switch lower(modeSel)
    case 'max_feasible'
        idx_typ = feas_idx(end);
    case 'middle_feasible'
        idx_typ = feas_idx(ceil(numel(feas_idx)/2));
    case 'first_above_nat'
        idx2 = feas_idx(Hr.R_grid(feas_idx) > Hr.R_nat + 1e-8);
        if isempty(idx2)
            idx_typ = feas_idx(end);
        else
            idx_typ = idx2(1);
        end
    otherwise
        idx_typ = feas_idx(end);
end

sol_typ = Hr.solutions{idx_typ};
R_typ = Hr.R_grid(idx_typ);
end


function idx_show = local_pick_reserve_indices(Hr, n_show)
feas_idx = find(Hr.is_feasible);
if isempty(feas_idx)
    idx_show = [];
    return;
end
if numel(feas_idx) <= n_show
    idx_show = feas_idx;
    return;
end
pick = round(linspace(1, numel(feas_idx), n_show));
idx_show = feas_idx(pick);
idx_show = unique(idx_show);
end


function idx_typ = local_pick_typical_idx(Hr, modeSel)
idx_typ = NaN;
feas_idx = find(Hr.is_feasible);
if isempty(feas_idx), return; end

switch lower(modeSel)
    case 'max_feasible'
        idx_typ = feas_idx(end);
    case 'middle_feasible'
        idx_typ = feas_idx(ceil(numel(feas_idx)/2));
    case 'first_above_nat'
        idx2 = feas_idx(Hr.R_grid(feas_idx) > Hr.R_nat + 1e-8);
        if isempty(idx2)
            idx_typ = feas_idx(end);
        else
            idx_typ = idx2(1);
        end
    otherwise
        idx_typ = feas_idx(end);
end
end


function cmp_outs = local_collect_compare_outs(out, results_all, plot_cfg)
cmp_outs = {};
if isempty(results_all)
    cmp_outs = {out};
    return;
end

beta_all = [results_all.beta_use];
for i = 1:numel(plot_cfg.beta_compare_list)
    [~, idx] = min(abs(beta_all - plot_cfg.beta_compare_list(i)));
    cmp_outs{end+1} = results_all(idx).out;
end
end
