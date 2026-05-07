function figs = plot_postprocess_hourly_credible_revenue_view_full(in, cfg)
% =========================================================================
% 第三章：可信备用域 + 容量收益后处理结果绘图（完整绘图版）
% -------------------------------------------------------------------------
% 功能：
%   1) 读取 run_postprocess_hourly_credible_revenue_view_full.m 的输出 out_market；
%   2) 在可信备用域 [0, R_cred(h)] 上绘制净成本视图；
%   3) 尽量沿用 plot_ch3_hourly_reserve_costcurve_results_V2.m 的图形组织方式；
%   4) 默认仅直接 figure() 绘图，不保存图片。
%
% 常用调用：
%   figs = plot_postprocess_hourly_credible_revenue_view_full();
%
%   figs = plot_postprocess_hourly_credible_revenue_view_full( ...
%       project_data_file('postprocess_market', 'hourly_reserve_credible_revenue_full_beta_95.mat'));
%
%   figs = plot_postprocess_hourly_credible_revenue_view_full(out_market);
%
%   cfg = struct();
%   cfg.typical_hour = 13;
%   cfg.hours_to_plot = [12 13];
%   cfg.temp_hours_4panel = [12 13 14 15];
%   cfg.ctrl_compare_hours = [12 13];
%   figs = plot_postprocess_hourly_credible_revenue_view_full(out_market, cfg);
% =========================================================================

if nargin < 1 || isempty(in)
    in = project_data_file('postprocess_market', ...
        'hourly_reserve_credible_revenue_full_beta_95.mat');
end
if nargin < 2 || isempty(cfg)
    cfg = struct();
end

out_market = local_load_market_any(in);
cfg = local_fill_plot_defaults(cfg, out_market);

baseline = out_market.base.baseline;
Nh = double(out_market.base.mdl.Nh);
hvec = (1:Nh).';
Nk = local_get_Nk(baseline, out_market);

figs = struct();

%% 图1：天然备用 / 最大热可行备用 / 最大可信备用
Rnat  = out_market.R_nat_hour(:);
Rcred = out_market.R_cred_hour(:);
Rmax  = nan(Nh,1);
for h = 1:Nh
    Hr0 = out_market.base.hours(h);
    if isfield(Hr0,'max_feasible_R') && ~isempty(Hr0.max_feasible_R)
        Rmax(h) = Hr0.max_feasible_R;
    end
end

figs.bounds = figure('Color','w'); hold on; box on; grid on;
stairs(hvec, Rnat,  '-o', 'LineWidth', 1.8, 'MarkerSize', 4, 'DisplayName','天然备用 R_{nat}');
stairs(hvec, Rmax,  '-s', 'LineWidth', 1.8, 'MarkerSize', 4, 'DisplayName','最大热可行备用');
stairs(hvec, Rcred, '-d', 'LineWidth', 1.8, 'MarkerSize', 4, 'DisplayName','最大可信备用 R_{cred}');
xlabel('小时 h');
ylabel('备用 (kW)');
title(sprintf('逐小时备用边界对比 (beta=%.2f)', out_market.beta_use));
legend('Location','best');

%% 图2：容量价格与最优净成本点
lambdaR = out_market.lambdaR_hour(:);
Rstar = nan(Nh,1);
JnetStar = nan(Nh,1);
for h = 1:Nh
    Hr = out_market.hours(h);
    if ~isfield(Hr,'R_grid_cred') || isempty(Hr.R_grid_cred)
        continue;
    end
    if ~isfield(Hr,'delta_net_cred') || isempty(Hr.delta_net_cred)
        continue;
    end
    [JnetStar(h), idx] = min(Hr.delta_net_cred(:));
    Rstar(h) = Hr.R_grid_cred(idx);
end

figs.market = figure('Color','w');
tiledlayout(2,1,'TileSpacing','compact','Padding','compact');

nexttile; hold on; box on; grid on;
stairs(hvec, lambdaR, '-o', 'LineWidth', 1.6, 'MarkerSize', 4);
xlabel('小时 h');
ylabel('\lambda_R (元/kW)');
title('逐小时备用容量价格');

nexttile; yyaxis left; hold on; box on; grid on;
stairs(hvec, Rstar, '-s', 'LineWidth', 1.6, 'MarkerSize', 4, 'DisplayName','净成本最优备用');
ylabel('R^* (kW)');
yyaxis right;
stairs(hvec, JnetStar, '-d', 'LineWidth', 1.6, 'MarkerSize', 4, 'DisplayName','最小净成本');
ylabel('min \Delta J_{net}');
xlabel('小时 h');
title('逐小时市场视角下的最优净成本点');

%% 图3：24小时净成本曲线总览（4x6）
figs.net_curve_overview = figure('Color','w');
tiledlayout(4,6,'TileSpacing','compact','Padding','compact');
for h = 1:Nh
    nexttile; hold on; box on; grid on;
    Hr = out_market.hours(h);
    if ~isempty(Hr.R_grid_cred)
        plot(Hr.R_grid_cred, Hr.delta_net_cred, '-o', 'LineWidth', 1.2, 'MarkerSize', 3);
        xline(out_market.R_nat_hour(h), ':k', 'LineWidth', 0.8);
        if isfinite(out_market.R_cred_hour(h))
            xline(out_market.R_cred_hour(h), '--r', 'LineWidth', 0.8);
        end
        yline(0, ':', 'Color', [0.45 0.45 0.45], 'LineWidth', 0.8);
    end
    title(sprintf('h=%02d', h));
    xlabel('R');
    ylabel('\DeltaJ_{net}');
end

%% 图4：24小时盈亏平衡备用价格总览（4x6）
figs.break_even_overview = figure('Color','w');
tiledlayout(4,6,'TileSpacing','compact','Padding','compact');
for h = 1:Nh
    nexttile; hold on; box on; grid on;
    Hr = out_market.hours(h);
    if ~isempty(Hr.R_grid_cred)
        plot(Hr.R_grid_cred, Hr.lambdaR_break_even_cred, '-o', 'LineWidth', 1.2, 'MarkerSize', 3);
        yline(out_market.lambdaR_hour(h), '--r', 'LineWidth', 1.0, 'DisplayName','当前\lambda_R');
    end
    title(sprintf('h=%02d', h));
    xlabel('R');
    ylabel('\lambda_R^{BE}');
end

%% 图5：典型小时方案与基线的全天控制量对比
[sol_typ, R_typ] = local_pick_typical_solution_market(out_market, cfg.typical_hour, cfg.typical_solution_mode);
if ~isempty(sol_typ)
    figs.typical_control = figure('Color','w');
    tiledlayout(2,1,'TileSpacing','compact','Padding','compact');

    nexttile; hold on; box on; grid on;
    plot(hvec, baseline.Ts_hour(:)-273.15, '-ko', 'LineWidth', 1.6, 'MarkerSize', 4, 'DisplayName','基线');
    plot(hvec, sol_typ.Ts_hour(:)-273.15, '-s',  'LineWidth', 1.6, 'MarkerSize', 4, 'DisplayName','典型小时方案');
    xline(cfg.typical_hour, ':r', 'LineWidth', 1.0, 'DisplayName','典型小时');
    xlabel('小时 h'); ylabel('T_s (°C)');
    title(sprintf('典型小时 h=%02d 与基线的全天 T_s 对比 (R=%.4f kW)', cfg.typical_hour, R_typ));
    legend('Location','best');

    nexttile; hold on; box on; grid on;
    plot(hvec, baseline.ma_hour(:), '-ko', 'LineWidth', 1.6, 'MarkerSize', 4, 'DisplayName','基线');
    plot(hvec, sol_typ.ma_hour(:), '-s',  'LineWidth', 1.6, 'MarkerSize', 4, 'DisplayName','典型小时方案');
    xline(cfg.typical_hour, ':r', 'LineWidth', 1.0, 'DisplayName','典型小时');
    xlabel('小时 h'); ylabel('m_a');
    title(sprintf('典型小时 h=%02d 与基线的全天 m_a 对比', cfg.typical_hour));
    legend('Location','best');
end

%% 图6~8：指定小时详细图
figs.hour_detail = gobjects(0);
for kk = 1:numel(cfg.hours_to_plot)
    h = cfg.hours_to_plot(kk);
    if h < 1 || h > Nh
        continue;
    end
    Hr = out_market.hours(h);
    if isempty(Hr.R_grid_cred)
        continue;
    end

    fh = figure('Color','w');
    tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

    nexttile; hold on; box on; grid on;
    plot(Hr.R_grid_cred, Hr.delta_net_cred, '-o', 'LineWidth', 1.6, 'MarkerSize', 4, 'DisplayName','净成本');
    plot(Hr.R_grid_cred, Hr.delta_total_cred, '--s', 'LineWidth', 1.4, 'MarkerSize', 4, 'DisplayName','总增量成本');
    yline(0, ':', 'Color', [0.45 0.45 0.45], 'LineWidth', 0.9, 'DisplayName','零净成本');
    xline(out_market.R_nat_hour(h), ':k', 'LineWidth', 0.9, 'DisplayName','R_{nat}');
    xline(out_market.R_cred_hour(h), '--r', 'LineWidth', 0.9, 'DisplayName','R_{cred}');
    xlabel('R (kW)'); ylabel('值');
    title(sprintf('h=%02d：净成本曲线', h));
    legend('Location','best');

    nexttile; hold on; box on; grid on;
    plot(Hr.R_grid_cred, Hr.delta_energy_cred, '-o', 'LineWidth', 1.5, 'MarkerSize', 4, 'DisplayName','\Delta Energy');
    plot(Hr.R_grid_cred, Hr.delta_temp_cred,   '-s', 'LineWidth', 1.5, 'MarkerSize', 4, 'DisplayName','\Delta Temp');
    plot(Hr.R_grid_cred, Hr.revenue_cap_cred,  '-^', 'LineWidth', 1.5, 'MarkerSize', 4, 'DisplayName','容量收益');
    xlabel('R (kW)'); ylabel('值');
    title('成本/收益构成');
    legend('Location','best');

    nexttile; hold on; box on; grid on;
    basePfan_hour = local_get_hour_series(baseline, 'Pfan_hour', 'Pfan');
    plot(Hr.R_grid_cred, Hr.ma_hour_cred,   '-o', 'LineWidth', 1.5, 'MarkerSize', 4, 'DisplayName','m_a(h)');
    plot(Hr.R_grid_cred, Hr.Pfan_hour_cred, '-s', 'LineWidth', 1.5, 'MarkerSize', 4, 'DisplayName','P_{fan}(h)');
    yline(baseline.ma_hour(h), ':k', 'LineWidth', 0.9, 'DisplayName','baseline m_a');
    yline(basePfan_hour(h), ':', 'Color', [0.25 0.45 0.75], ...
        'LineWidth', 0.9, 'DisplayName','baseline P_{fan}');
    xlabel('R (kW)'); ylabel('值');
    title('目标小时风侧工作点');
    legend('Location','best');

    nexttile; hold on; box on; grid on;
    plot(Hr.R_grid_cred, Hr.Ts_hour_C_cred,           '-o', 'LineWidth', 1.5, 'MarkerSize', 4, 'DisplayName','T_s(h)');
    plot(Hr.R_grid_cred, Hr.lambdaR_break_even_cred,  '-s', 'LineWidth', 1.5, 'MarkerSize', 4, 'DisplayName','\lambda_R^{BE}');
    yline(baseline.Ts_hour(h)-273.15, ':k', 'LineWidth', 0.9, 'DisplayName','baseline T_s');
    yline(out_market.lambdaR_hour(h), '--r', 'LineWidth', 0.9, 'DisplayName','当前\lambda_R');
    xlabel('R (kW)'); ylabel('值');
    title('目标小时水侧与盈亏平衡价格');
    legend('Location','best');

    figs.hour_detail(end+1,1) = fh; %#ok<AGROW>
end

%% 图9：四个典型小时的室温图（四子图）
figs.temp_4panel = figure('Color','w');
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
for ii = 1:numel(cfg.temp_hours_4panel)
    h = cfg.temp_hours_4panel(ii);
    if h < 1 || h > Nh
        continue;
    end
    Hr = out_market.hours(h);
    nexttile; hold on; box on; grid on;

    local_plot_risk_band(Hr, Nk);
    plot(1:Nk, baseline.T15(:), '-k', 'LineWidth', 1.8, 'DisplayName','基线');

    idx_show = local_pick_indices(Hr.R_grid_cred, cfg.n_temp_curves);
    for jj = 1:numel(idx_show)
        idx = idx_show(jj);
        if idx < 1 || idx > numel(Hr.solutions_cred)
            continue;
        end
        solj = Hr.solutions_cred{idx};
        if isempty(solj) || ~isfield(solj,'T15') || isempty(solj.T15)
            continue;
        end
        plot(1:Nk, solj.T15(:), '--', 'LineWidth', 1.2, ...
            'DisplayName', sprintf('R=%.2f kW', Hr.R_grid_cred(idx)));
    end

    xlabel('时间步'); ylabel('室温 (K)');
    title(sprintf('小时 %02d 室温轨迹', h));
    legend('Location','best');
end

%% 图10：固定两个小时时，不同可信备用水平下的全天控制方案对比（2×2）
ctrl_hours = cfg.ctrl_compare_hours(:).';
if numel(ctrl_hours) < 2
    ctrl_hours = [12 13];
end
ctrl_hours = ctrl_hours(1:2);

figs.ctrl_compare = figure('Color','w');
tl = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
for jj = 1:2
    h_fix = ctrl_hours(jj);
    if h_fix < 1 || h_fix > Nh
        continue;
    end
    Hr = out_market.hours(h_fix);
    if isempty(Hr.R_grid_cred)
        continue;
    end
    idx_show = local_pick_indices(Hr.R_grid_cred, cfg.n_ctrl_curves);

    ax1 = nexttile(tl, jj); hold(ax1,'on'); box(ax1,'on'); grid(ax1,'on');
    plot(ax1, hvec, baseline.Ts_hour(:)-273.15, '-k', 'LineWidth', 2.0, 'DisplayName','基线');
    for kk = 1:numel(idx_show)
        idx = idx_show(kk);
        solk = Hr.solutions_cred{idx};
        if isempty(solk), continue; end
        plot(ax1, hvec, solk.Ts_hour(:)-273.15, '-', 'LineWidth', 1.5, ...
            'DisplayName', sprintf('R=%.2f kW', Hr.R_grid_cred(idx)));
    end
    xlabel(ax1,'小时 h'); ylabel(ax1,'T_s (°C)');
    title(ax1, sprintf('固定 h=%02d 时，不同可信备用水平下的全天 T_s', h_fix));
    legend(ax1,'Location','best');

    ax2 = nexttile(tl, jj+2); hold(ax2,'on'); box(ax2,'on'); grid(ax2,'on');
    plot(ax2, hvec, baseline.ma_hour(:), '-k', 'LineWidth', 2.0, 'DisplayName','基线');
    for kk = 1:numel(idx_show)
        idx = idx_show(kk);
        solk = Hr.solutions_cred{idx};
        if isempty(solk), continue; end
        plot(ax2, hvec, solk.ma_hour(:), '-', 'LineWidth', 1.5, ...
            'DisplayName', sprintf('R=%.2f kW', Hr.R_grid_cred(idx)));
    end
    xlabel(ax2,'小时 h'); ylabel(ax2,'m_a');
    title(ax2, sprintf('固定 h=%02d 时，不同可信备用水平下的全天 m_a', h_fix));
    legend(ax2,'Location','best');
end

%% 图11：不同置信度对比（若存在 compare_markets）
if isfield(out_market,'compare_markets') && ~isempty(out_market.compare_markets)
    cmp = out_market.compare_markets;
    nCmp = numel(cmp);
    colors = lines(max(4,nCmp));

    figs.beta_compare = figure('Color','w');
    tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

    nexttile; hold on; box on; grid on;
    for i = 1:nCmp
        mk = cmp{i};
        stairs(hvec, mk.R_cred_hour(:), 'LineWidth', 1.7, 'Color', colors(i,:), ...
            'DisplayName', sprintf('\beta=%.2f', mk.beta_use));
    end
    xlabel('小时 h'); ylabel('R_{cred} (kW)');
    title('不同置信度下最大可信备用');
    legend('Location','best');

    nexttile; hold on; box on; grid on;
    for i = 1:nCmp
        mk = cmp{i};
        [tAll, RAll, ZAll] = local_collect_surface_scatter(mk, 'delta_net_cred');
        if isempty(tAll), continue; end
        plot3(tAll, RAll, ZAll, '.', 'MarkerSize', 10, 'Color', colors(i,:), ...
            'DisplayName', sprintf('\beta=%.2f', mk.beta_use));
    end
    xlabel('小时 h'); ylabel('R (kW)'); zlabel('\Delta J_{net}');
    title('不同置信度下净成本散点视图');
    view(40,25); grid on;
    legend('Location','best');

    nexttile([1 2]); hold on; box on; grid on;
    h_fix = cfg.typical_hour;
    R_fix = local_pick_reference_R(out_market, h_fix, cfg.typical_solution_mode);
    plot(1:Nk, baseline.T15(:), '-k', 'LineWidth', 2.0, 'DisplayName','基线');
    for i = 1:nCmp
        mk = cmp{i};
        [soli, Ri] = local_pick_solution_near_R(mk, h_fix, R_fix);
        if isempty(soli) || ~isfield(soli,'T15')
            continue;
        end
        plot(1:Nk, soli.T15(:), 'LineWidth', 1.6, 'Color', colors(i,:), ...
            'DisplayName', sprintf('\beta=%.2f, R=%.2f kW', mk.beta_use, Ri));
    end
    xlabel('时间步'); ylabel('室温 (K)');
    title(sprintf('固定小时 h=%02d、固定参考备用下的不同置信度室温轨迹', h_fix));
    legend('Location','best');
end

end

% =========================================================================
% 默认参数
% =========================================================================
function cfg = local_fill_plot_defaults(cfg, out_market)
if ~isfield(cfg,'typical_hour') || isempty(cfg.typical_hour)
    cfg.typical_hour = 13;
end
if ~isfield(cfg,'hours_to_plot') || isempty(cfg.hours_to_plot)
    cfg.hours_to_plot = [14 15];
end
if ~isfield(cfg,'temp_hours_4panel') || isempty(cfg.temp_hours_4panel)
    cfg.temp_hours_4panel = [12 13 14 15];
end
if ~isfield(cfg,'n_temp_curves') || isempty(cfg.n_temp_curves)
    cfg.n_temp_curves = 6;
end
if ~isfield(cfg,'ctrl_compare_hours') || isempty(cfg.ctrl_compare_hours)
    cfg.ctrl_compare_hours = [12 13];
end
if ~isfield(cfg,'n_ctrl_curves') || isempty(cfg.n_ctrl_curves)
    cfg.n_ctrl_curves = 5;
end
if ~isfield(cfg,'typical_solution_mode') || isempty(cfg.typical_solution_mode)
    cfg.typical_solution_mode = 'max_credible';
end
if ~isfield(cfg,'beta_compare_list') || isempty(cfg.beta_compare_list)
    if isfield(out_market,'compare_markets') && ~isempty(out_market.compare_markets)
        b = nan(numel(out_market.compare_markets),1);
        for i = 1:numel(out_market.compare_markets)
            b(i) = out_market.compare_markets{i}.beta_use;
        end
        cfg.beta_compare_list = b(:).';
    else
        cfg.beta_compare_list = out_market.beta_use;
    end
end
end

% =========================================================================
% 读取 out_market
% =========================================================================
function out_market = local_load_market_any(in)
if ischar(in) || isstring(in)
    S = load(in);
else
    S = in;
end

if isfield(S,'out_market')
    out_market = S.out_market;
elseif isfield(S,'hours') && isfield(S,'base') && isfield(S,'cred')
    out_market = S;
else
    error('无法识别输入，请提供 out_market 结构体或其 MAT 文件。');
end
end

% =========================================================================
% helper
% =========================================================================
function Nk = local_get_Nk(baseline, out_market)
if isfield(baseline,'T15') && ~isempty(baseline.T15)
    Nk = numel(baseline.T15);
    return;
end
for h = 1:numel(out_market.hours)
    Hr = out_market.hours(h);
    if isfield(Hr,'theta_risk_lb') && ~isempty(Hr.theta_risk_lb)
        Nk = numel(Hr.theta_risk_lb);
        return;
    end
end
error('无法确定小时内总步数 Nk。');
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

function [sol_typ, R_typ] = local_pick_typical_solution_market(out_market, h, modeSel)
sol_typ = [];
R_typ = NaN;
if h < 1 || h > numel(out_market.hours)
    return;
end
Hr = out_market.hours(h);
if isempty(Hr.R_grid_cred) || isempty(Hr.solutions_cred)
    return;
end
switch lower(modeSel)
    case 'max_credible'
        idx = numel(Hr.R_grid_cred);
    case 'middle_credible'
        idx = ceil(numel(Hr.R_grid_cred)/2);
    case 'first_above_nat'
        idx0 = find(Hr.R_grid_cred > out_market.R_nat_hour(h) + 1e-8, 1, 'first');
        if isempty(idx0)
            idx = numel(Hr.R_grid_cred);
        else
            idx = idx0;
        end
    otherwise
        idx = numel(Hr.R_grid_cred);
end
idx = max(1, min(idx, numel(Hr.solutions_cred)));
sol_typ = Hr.solutions_cred{idx};
R_typ = Hr.R_grid_cred(idx);
end

function idx = local_pick_indices(R, n_show)
idx = [];
if isempty(R)
    return;
end
if numel(R) <= n_show
    idx = (1:numel(R)).';
    return;
end
pick = round(linspace(1, numel(R), n_show));
idx = unique(pick(:));
if idx(end) ~= numel(R)
    idx(end+1,1) = numel(R);
end
end

function local_plot_risk_band(Hr, Nk)
if isfield(Hr,'theta_risk_lb') && isfield(Hr,'theta_risk_ub') && ...
        ~isempty(Hr.theta_risk_lb) && ~isempty(Hr.theta_risk_ub)
    fill([1:Nk, fliplr(1:Nk)], ...
         [Hr.theta_risk_lb(:).', fliplr(Hr.theta_risk_ub(:).')], ...
         [0.85 0.90 1.00], ...
         'FaceAlpha', 0.35, 'EdgeColor', 'none', ...
         'DisplayName', '风险收缩舒适区间');
end
end

function R_fix = local_pick_reference_R(out_market, h, modeSel)
[~, R_fix] = local_pick_typical_solution_market(out_market, h, modeSel);
end

function [solk, Rk] = local_pick_solution_near_R(mk, h, Rtar)
solk = [];
Rk = NaN;
if h < 1 || h > numel(mk.hours)
    return;
end
Hr = mk.hours(h);
if isempty(Hr.R_grid_cred)
    return;
end
[~, idx] = min(abs(Hr.R_grid_cred - Rtar));
solk = Hr.solutions_cred{idx};
Rk = Hr.R_grid_cred(idx);
end

function [time_all, R_all, Z_all] = local_collect_surface_scatter(mk, fieldname)
time_all = [];
R_all = [];
Z_all = [];
for h = 1:numel(mk.hours)
    Hr = mk.hours(h);
    if ~isfield(Hr,'R_grid_cred') || isempty(Hr.R_grid_cred)
        continue;
    end
    if ~isfield(Hr,fieldname) || isempty(Hr.(fieldname))
        continue;
    end
    time_all = [time_all; h*ones(numel(Hr.R_grid_cred),1)]; %#ok<AGROW>
    R_all    = [R_all; Hr.R_grid_cred(:)]; %#ok<AGROW>
    Z_all    = [Z_all; Hr.(fieldname)(:)]; %#ok<AGROW>
end
mask = isfinite(time_all) & isfinite(R_all) & isfinite(Z_all);
time_all = time_all(mask);
R_all    = R_all(mask);
Z_all    = Z_all(mask);
end
