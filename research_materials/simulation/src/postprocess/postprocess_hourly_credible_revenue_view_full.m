function out_market = postprocess_hourly_credible_revenue_view_full(inReserve, inCred, cfg)
% =========================================================================
% 完整绘图版：可信备用域截断 + 容量收益后处理
% -------------------------------------------------------------------------
% 目标：
%   在尽量保留 plot_ch3_hourly_reserve_costcurve_results_V2.m 绘图风格的前提下，
%   只做两类变化：
%     1) 横轴从热可行域改为可信备用域 [0, R_cred(h)]；
%     2) 纵轴从 DeltaJ 改为 DeltaJ_net = DeltaJ - lambdaR(h)*R。
%
% 说明：
%   - 不改动内层优化；
%   - 不保存图片，只直接 figure() 绘图；
%   - 保留 MAT 输出，便于后续调试；
%   - 会补上 [0, min(R_nat, R_cred)] 的天然备用零成本段。
%
% 常用调用：
%   out_market = postprocess_hourly_credible_revenue_view_full();
%
%   cfg = struct();
%   cfg.beta_select = 0.95;
%   cfg.makePlots = true;
%   cfg.hours_to_plot = [12 13];
%   out_market = postprocess_hourly_credible_revenue_view_full( ...
%       project_data_file('reserve', 'hourly_reserve_costcurve_all_beta.mat'), ...
%       project_data_file('reserve', 'hourly_credible_feasibility_v2_all_beta.mat'), cfg);
% =========================================================================

%% 0) 默认输入
if nargin < 1 || isempty(inReserve)
    inReserve = project_data_file('reserve','hourly_reserve_costcurve_all_beta.mat');
end
if nargin < 2 || isempty(inCred)
    inCred = project_data_file('reserve','hourly_credible_feasibility_v2_all_beta.mat');
end
if nargin < 3
    cfg = struct();
end
cfg = local_fill_defaults(cfg);

if ~exist(cfg.outdir, 'dir')
    mkdir(cfg.outdir);
end

%% 1) 读取 reserve / cred，并选定 beta
[out_ref, results_all_reserve, beta_use] = local_load_reserve_any(inReserve, cfg.beta_select);
[cred_ref, results_all_cred, beta_screen] = local_load_cred_any(inCred, cfg.beta_select);

out_market = local_build_market_struct(out_ref, cred_ref, cfg, beta_use, beta_screen);
out_market.reserve_source = inReserve;
out_market.credible_source = inCred;

%% 2) 为 beta_compare_list 生成 compare 版本（若存在批量结果）
out_market.compare_markets = {};
if ~isempty(results_all_reserve) && ~isempty(results_all_cred)
    beta_cmp = cfg.beta_compare_list(:).';
    beta_all_res = local_get_beta_list_from_reserve_results(results_all_reserve);
    beta_all_cred = local_get_beta_list_from_cred_results(results_all_cred);

    for i = 1:numel(beta_cmp)
        [~, idxr] = min(abs(beta_all_res - beta_cmp(i)));
        [~, idxc] = min(abs(beta_all_cred - beta_cmp(i)));

        out_i  = local_extract_out_from_reserve_entry(results_all_reserve, idxr);
        cred_i = local_extract_cred_from_cred_entry(results_all_cred, idxc);
        beta_i = local_get_beta_from_out(out_i);
        beta_sc_i = local_get_beta_from_cred(cred_i);

        out_market.compare_markets{end+1} = local_build_market_struct(out_i, cred_i, cfg, beta_i, beta_sc_i); %#ok<AGROW>
    end
end

%% 3) 保存 MAT
outfile = fullfile(cfg.outdir, sprintf('hourly_reserve_credible_revenue_full_beta_%02d.mat', round(100*beta_use)));
save(outfile, 'out_market', '-v7.3');
out_market.saved_mat = outfile;

%% 4) 绘图（不保存图片）
if cfg.makePlots
    local_make_all_plots(out_market, cfg);
end

fprintf('\n============================================================\n');
fprintf('完整绘图版后处理完成\n');
fprintf('beta_use / beta_screen = %.4f / %.4f\n', beta_use, beta_screen);
fprintf('MAT 已保存到: %s\n', out_market.saved_mat);
fprintf('图片未保存，仅直接绘图。\n');
fprintf('============================================================\n');

end

% =========================================================================
% 构造单个 beta 的 market 结构
% =========================================================================
function out_market = local_build_market_struct(out, credOne, cfg, beta_use, beta_screen)

Nh = double(out.mdl.Nh);
assert(numel(cfg.lambdaR_hour) == Nh, 'lambdaR_hour 长度应为 Nh=%d。', Nh);

out_market = struct();
out_market.case_label = 'credible_revenue_postprocessed_full';
out_market.beta_use = beta_use;
out_market.beta_screen = beta_screen;
out_market.cfg = cfg;
out_market.base = out;
out_market.cred = credOne;
out_market.lambdaR_hour = cfg.lambdaR_hour(:);
out_market.R_nat_hour = out.R_nat_hour(:);
out_market.R_cred_hour = credOne.summary.R_cred_hour(:);
out_market.hours = repmat(struct(), Nh, 1);

for h = 1:Nh
    Hr = out.hours(h);

    Rnat = out_market.R_nat_hour(h);
    Rcred = out_market.R_cred_hour(h);
    lam = out_market.lambdaR_hour(h);

    % ----- 原始热可行扫描点 -----
    if isfield(Hr,'R_grid') && ~isempty(Hr.R_grid)
        R_all = Hr.R_grid(:);
    else
        R_all = [];
    end

    if isfield(Hr,'is_feasible') && ~isempty(Hr.is_feasible)
        feas = logical(Hr.is_feasible(:));
    else
        feas = true(size(R_all));
    end

    J_all   = local_get_num_field(Hr, 'delta_total',  R_all);
    JE_all  = local_get_num_field(Hr, 'delta_energy', R_all);
    JT_all  = local_get_num_field(Hr, 'delta_temp',   R_all);
    MA_all  = local_get_num_field(Hr, 'ma_hour',      R_all);
    PF_all  = local_get_num_field(Hr, 'Pfan_hour',    R_all);
    TS_all  = local_get_num_field(Hr, 'Ts_hour_C',    R_all);

    % ----- 天然备用零成本段 -----
    R0 = min(max(Rcred, 0), max(Rnat, 0));
    if R0 > cfg.reserve_tol
        R_nat_seg = linspace(0, R0, cfg.nNatSeg).';
    elseif Rcred >= 0
        R_nat_seg = 0;
    else
        R_nat_seg = [];
    end

    J_nat_seg  = zeros(size(R_nat_seg));
    JE_nat_seg = zeros(size(R_nat_seg));
    JT_nat_seg = zeros(size(R_nat_seg));
    MA_nat_seg = out.baseline.ma_hour(h)      * ones(size(R_nat_seg));
    PF_nat_seg = out.baseline.Pfan_hour(h)    * ones(size(R_nat_seg));
    TS_nat_seg = (out.baseline.Ts_hour(h)-273.15) * ones(size(R_nat_seg));
    SOL_nat_seg = repmat({out.baseline}, numel(R_nat_seg), 1);

    % ----- 原始扫描中，可信域内且高于天然备用段的部分 -----
    keep = [];
    if ~isempty(R_all)
        keep = feas & isfinite(R_all) & (R_all <= Rcred + cfg.reserve_tol) & (R_all > R0 + cfg.reserve_tol);
    end

    if ~isempty(keep)
        R_keep   = R_all(keep);
        J_keep   = J_all(keep);
        JE_keep  = JE_all(keep);
        JT_keep  = JT_all(keep);
        MA_keep  = MA_all(keep);
        PF_keep  = PF_all(keep);
        TS_keep  = TS_all(keep);
        if isfield(Hr,'solutions') && ~isempty(Hr.solutions)
            SOL_keep = Hr.solutions(keep);
        else
            SOL_keep = repmat({[]}, nnz(keep), 1);
        end
    else
        R_keep   = [];
        J_keep   = [];
        JE_keep  = [];
        JT_keep  = [];
        MA_keep  = [];
        PF_keep  = [];
        TS_keep  = [];
        SOL_keep = {};
    end

    % ----- 拼接完整可信域 -----
    R_plot   = [R_nat_seg; R_keep];
    J_plot   = [J_nat_seg; J_keep];
    JE_plot  = [JE_nat_seg; JE_keep];
    JT_plot  = [JT_nat_seg; JT_keep];
    MA_plot  = [MA_nat_seg; MA_keep];
    PF_plot  = [PF_nat_seg; PF_keep];
    TS_plot  = [TS_nat_seg; TS_keep];
    SOL_plot = [SOL_nat_seg; SOL_keep];

    if ~isempty(R_plot)
        [R_plot, ia] = unique(R_plot, 'stable');
        J_plot   = J_plot(ia);
        JE_plot  = JE_plot(ia);
        JT_plot  = JT_plot(ia);
        MA_plot  = MA_plot(ia);
        PF_plot  = PF_plot(ia);
        TS_plot  = TS_plot(ia);
        SOL_plot = SOL_plot(ia);

        [R_plot, order] = sort(R_plot);
        J_plot   = J_plot(order);
        JE_plot  = JE_plot(order);
        JT_plot  = JT_plot(order);
        MA_plot  = MA_plot(order);
        PF_plot  = PF_plot(order);
        TS_plot  = TS_plot(order);
        SOL_plot = SOL_plot(order);
    end

    Rev_plot = lam * R_plot;
    Jnet_plot = J_plot - Rev_plot;

    lambdaR_be = nan(size(R_plot));
    nz = abs(R_plot) > cfg.reserve_tol;
    lambdaR_be(nz) = J_plot(nz) ./ R_plot(nz);

    out_market.hours(h).hour = h;
    out_market.hours(h).R_grid_cred = R_plot;
    out_market.hours(h).delta_total_cred = J_plot;
    out_market.hours(h).delta_energy_cred = JE_plot;
    out_market.hours(h).delta_temp_cred = JT_plot;
    out_market.hours(h).revenue_cap_cred = Rev_plot;
    out_market.hours(h).delta_net_cred = Jnet_plot;
    out_market.hours(h).lambdaR_break_even_cred = lambdaR_be;
    out_market.hours(h).ma_hour_cred = MA_plot;
    out_market.hours(h).Pfan_hour_cred = PF_plot;
    out_market.hours(h).Ts_hour_C_cred = TS_plot;
    out_market.hours(h).solutions_cred = SOL_plot;

    out_market.hours(h).theta_risk_lb = local_pick_theta_band(out, h, 'lb');
    out_market.hours(h).theta_risk_ub = local_pick_theta_band(out, h, 'ub');
end

end

% =========================================================================
% 绘图总入口
% =========================================================================
function local_make_all_plots(out_market, cfg)

out = out_market.base;
baseline = out.baseline;
Nh = out.mdl.Nh;
Nk = out.mdl.H15;
hvec = (1:Nh).';
cmp_markets = out_market.compare_markets;

%% 图1：天然 / 最大可信 / 最大热可行备用
figure(); hold on; box on; grid on;
Rmax = nan(Nh,1);
for h = 1:Nh
    if isfield(out.hours(h),'max_feasible_R')
        Rmax(h) = out.hours(h).max_feasible_R;
    end
end
plot(hvec, out_market.R_nat_hour(:), '-o', 'LineWidth', 1.8, 'MarkerSize', 5, 'DisplayName','天然备用');
plot(hvec, Rmax, '-s', 'LineWidth', 1.8, 'MarkerSize', 5, 'DisplayName','最大热可行备用');
plot(hvec, out_market.R_cred_hour(:), '-d', 'LineWidth', 1.8, 'MarkerSize', 5, 'DisplayName','最大可信备用');
xlabel('小时 h'); ylabel('备用 (kW)');
title(sprintf('天然 / 最大热可行 / 最大可信备用 (beta=%.2f)', out_market.beta_use));
legend('Location','best');

%% 图2：典型小时方案与基线的全天控制量对比（Figure 5 类）
[sol_typ, R_typ] = local_pick_typical_solution_market(out_market, cfg.typical_hour, cfg.typical_solution_mode);
if ~isempty(sol_typ)
    figure();
    tiledlayout(2,1,'TileSpacing','compact','Padding','compact');

    nexttile; hold on; box on; grid on;
    plot(hvec, baseline.Ts_hour(:)-273.15, '-ko', 'LineWidth', 1.5, 'MarkerSize', 4, 'DisplayName','基线');
    plot(hvec, sol_typ.Ts_hour(:)-273.15, '-s', 'LineWidth', 1.5, 'MarkerSize', 4, 'DisplayName','可信域典型方案');
    xline(cfg.typical_hour, ':r', 'LineWidth', 1.0);
    xlabel('小时 h'); ylabel('T_s (°C)');
    title(sprintf('典型小时 h=%02d 与基线的全天 T_s 对比（R=%.4f kW）', cfg.typical_hour, R_typ));
    legend('Location','best');

    nexttile; hold on; box on; grid on;
    plot(hvec, baseline.ma_hour(:), '-ko', 'LineWidth', 1.5, 'MarkerSize', 4, 'DisplayName','基线');
    plot(hvec, sol_typ.ma_hour(:), '-s', 'LineWidth', 1.5, 'MarkerSize', 4, 'DisplayName','可信域典型方案');
    xline(cfg.typical_hour, ':r', 'LineWidth', 1.0);
    xlabel('小时 h'); ylabel('m_a');
    title(sprintf('典型小时 h=%02d 与基线的全天 m_a 对比（R=%.4f kW）', cfg.typical_hour, R_typ));
    legend('Location','best');
end

%% 图3：指定小时详细图（Figure 7/8 类）
for ii = 1:numel(cfg.hours_to_plot)
    h = cfg.hours_to_plot(ii);
    if h < 1 || h > Nh
        continue;
    end
    Hr = out_market.hours(h);
    if isempty(Hr.R_grid_cred)
        continue;
    end

    figure();
    tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

    nexttile; hold on; box on; grid on;
    plot(Hr.R_grid_cred, Hr.delta_net_cred, '-o', 'LineWidth', 1.6);
    xline(out_market.R_nat_hour(h), ':k', 'LineWidth', 1.0);
    xline(out_market.R_cred_hour(h), '--r', 'LineWidth', 1.0);
    xlabel('R (kW)'); ylabel('\Delta J_{net}');
    title(sprintf('h=%02d: 可信域净增量成本曲线', h));

    nexttile; hold on; box on; grid on;
    plot(Hr.R_grid_cred, Hr.delta_total_cred,  '-s', 'LineWidth', 1.4, 'DisplayName','\Delta J');
    plot(Hr.R_grid_cred, Hr.revenue_cap_cred, '-^', 'LineWidth', 1.4, 'DisplayName','备用容量收益');
    plot(Hr.R_grid_cred, Hr.delta_net_cred,   '-o', 'LineWidth', 1.4, 'DisplayName','\Delta J_{net}');
    xlabel('R (kW)'); ylabel('金额');
    title('成本-收益分解');
    legend('Location','best');

    nexttile; hold on; box on; grid on;
    plot(Hr.R_grid_cred, Hr.ma_hour_cred, '-o', 'LineWidth', 1.5, 'DisplayName','ma(h)');
    yline(baseline.ma_hour(h), ':k', 'LineWidth', 1.0, 'DisplayName','baseline');
    xlabel('R (kW)'); ylabel('m_a');
    title('目标小时风量工作点');
    legend('Location','best');

    nexttile; hold on; box on; grid on;
    plot(Hr.R_grid_cred, Hr.Pfan_hour_cred, '-o', 'LineWidth', 1.5, 'DisplayName','P_{fan}(h)');
    yline(baseline.Pfan_hour(h), ':k', 'LineWidth', 1.0, 'DisplayName','baseline');
    xlabel('R (kW)'); ylabel('P_{fan} (kW)');
    title('目标小时风机功率工作点');
    legend('Location','best');
end

%% 图4：当前置信度下，四个小时的室温轨迹图（Figure 9 类）
figure();
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
for ii = 1:numel(cfg.temp_hours_4panel)
    h = cfg.temp_hours_4panel(ii);
    if h < 1 || h > Nh, continue; end
    Hr = out_market.hours(h);

    nexttile; hold on; box on; grid on;

    if ~isempty(Hr.theta_risk_lb) && ~isempty(Hr.theta_risk_ub)
        fill([1:Nk, fliplr(1:Nk)], ...
             [Hr.theta_risk_lb(:).', fliplr(Hr.theta_risk_ub(:).')], ...
             [0.85 0.90 1.00], 'FaceAlpha', 0.35, 'EdgeColor', 'none', ...
             'DisplayName','风险收缩舒适区间');
    end

    if isfield(baseline,'T15') && ~isempty(baseline.T15)
        plot(1:Nk, baseline.T15(:), '-k', 'LineWidth', 1.6, 'DisplayName','基线');
    end

    rep_idx = local_pick_even_indices(Hr.R_grid_cred, cfg.n_temp_curves);
    cmap = lines(max(2,numel(rep_idx)));
    for jj = 1:numel(rep_idx)
        idx = rep_idx(jj);
        solj = Hr.solutions_cred{idx};
        if isempty(solj) || ~isfield(solj,'T15') || isempty(solj.T15)
            continue;
        end
        plot(1:Nk, solj.T15(:), '-', 'LineWidth', 1.3, 'Color', cmap(jj,:), ...
            'DisplayName', sprintf('R=%.2f', Hr.R_grid_cred(idx)));
    end

    idx15 = (4*(h-1)+1):(4*h);
    xline(idx15(1)-0.5, ':r', 'LineWidth', 0.8);
    xline(idx15(end)+0.5, ':r', 'LineWidth', 0.8);
    xlabel('15min 子步 k'); ylabel('\theta (K)');
    title(sprintf('h=%02d: 室温轨迹与风险区间', h));
    legend('Location','best');
end

%% 图5：固定某两个小时，不同备用水平下的全天控制量对比（Figure 10 类）
for jj = 1:numel(cfg.ctrl_compare_hours)
    h_fix = cfg.ctrl_compare_hours(jj);
    if h_fix < 1 || h_fix > Nh, continue; end
    Hr = out_market.hours(h_fix);
    if isempty(Hr.R_grid_cred), continue; end

    idx_show = local_pick_even_indices(Hr.R_grid_cred, cfg.n_ctrl_curves);
    cmap = lines(max(2,numel(idx_show)));

    if jj == 1
        f_ctrl = figure();
        tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
    end

    nexttile; hold on; box on; grid on;
    plot(hvec, baseline.Ts_hour(:)-273.15, '-ko', 'LineWidth', 1.5, 'MarkerSize', 4, 'DisplayName','基线');
    for kk = 1:numel(idx_show)
        idx = idx_show(kk);
        solk = Hr.solutions_cred{idx};
        if isempty(solk), continue; end
        plot(hvec, solk.Ts_hour(:)-273.15, '-', 'Color', cmap(kk,:), 'LineWidth', 1.3, ...
            'DisplayName', sprintf('R=%.2f', Hr.R_grid_cred(idx)));
    end
    xline(h_fix, ':r', 'LineWidth', 1.0);
    xlabel('小时 h'); ylabel('T_s (°C)');
    title(sprintf('固定 h=%02d 时，不同备用水平下的全天 T_s 对比', h_fix));
    legend('Location','best');

    nexttile; hold on; box on; grid on;
    plot(hvec, baseline.ma_hour(:), '-ko', 'LineWidth', 1.5, 'MarkerSize', 4, 'DisplayName','基线');
    for kk = 1:numel(idx_show)
        idx = idx_show(kk);
        solk = Hr.solutions_cred{idx};
        if isempty(solk), continue; end
        plot(hvec, solk.ma_hour(:), '-', 'Color', cmap(kk,:), 'LineWidth', 1.3, ...
            'DisplayName', sprintf('R=%.2f', Hr.R_grid_cred(idx)));
    end
    xline(h_fix, ':r', 'LineWidth', 1.0);
    xlabel('小时 h'); ylabel('m_a');
    title(sprintf('固定 h=%02d 时，不同备用水平下的全天 m_a 对比', h_fix));
    legend('Location','best');
end

%% 图6：不同 beta 下，固定小时、固定备用附近的温度与控制对比（Figure 11 类）
if ~isempty(cmp_markets)
    h_fix = cfg.typical_hour;
    R_fix = local_pick_reference_R(out_market, h_fix, cfg.typical_solution_mode);
    if isfinite(R_fix)
        figure();
        tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

        nexttile([1 2]); hold on; box on; grid on;
        plot(1:Nk, baseline.T15(:), '-k', 'LineWidth', 1.5, 'DisplayName', sprintf('基线 (beta=%.2f)', out_market.beta_use));

        cmap = lines(max(2,numel(cmp_markets)));
        for kk = 1:numel(cmp_markets)
            mk = cmp_markets{kk};
            [solk, Rk] = local_pick_solution_near_R(mk, h_fix, R_fix);
            if isempty(solk) || ~isfield(solk,'T15') || isempty(solk.T15)
                continue;
            end
            plot(1:Nk, solk.T15(:), '-', 'LineWidth', 1.4, 'Color', cmap(kk,:), ...
                'DisplayName', sprintf('beta=%.2f, R≈%.2f', mk.beta_use, Rk));
        end
        xlabel('15min 子步 k'); ylabel('\theta (K)');
        title(sprintf('固定 h=%02d、R≈%.2f kW 下，不同置信度的室温轨迹', h_fix, R_fix));
        legend('Location','best');

        nexttile; hold on; box on; grid on;
        for kk = 1:numel(cmp_markets)
            mk = cmp_markets{kk};
            [solk, Rk] = local_pick_solution_near_R(mk, h_fix, R_fix); %#ok<ASGLU>
            if isempty(solk), continue; end
            plot(hvec, solk.Ts_hour(:)-273.15, '-', 'LineWidth', 1.4, 'Color', cmap(kk,:), ...
                'DisplayName', sprintf('beta=%.2f', mk.beta_use));
        end
        xlabel('小时 h'); ylabel('T_s (°C)');
        title(sprintf('固定 h=%02d、R≈%.2f 下的全天 T_s 对比', h_fix, R_fix));
        legend('Location','best');

        nexttile; hold on; box on; grid on;
        for kk = 1:numel(cmp_markets)
            mk = cmp_markets{kk};
            [solk, Rk] = local_pick_solution_near_R(mk, h_fix, R_fix); %#ok<ASGLU>
            if isempty(solk), continue; end
            plot(hvec, solk.ma_hour(:), '-', 'LineWidth', 1.4, 'Color', cmap(kk,:), ...
                'DisplayName', sprintf('beta=%.2f', mk.beta_use));
        end
        xlabel('小时 h'); ylabel('m_a');
        title(sprintf('固定 h=%02d、R≈%.2f 下的全天 m_a 对比', h_fix, R_fix));
        legend('Location','best');
    end
end

%% 图7：不同 beta 下固定小时固定备用的全天功率分解（Figure 12 类）
if ~isempty(cmp_markets)
    h_fix = cfg.typical_hour;
    R_fix = local_pick_reference_R(out_market, h_fix, cfg.typical_solution_mode);
    if isfinite(R_fix)
        figure();
        tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
        for kk = 1:min(4,numel(cmp_markets))
            mk = cmp_markets{kk};
            [solk, Rk] = local_pick_solution_near_R(mk, h_fix, R_fix);
            if isempty(solk), continue; end
            nexttile; hold on; box on; grid on;
            Php_hour = local_get_hour_series(solk, 'Php_hour', 'Php');
            Pfan_hour = local_get_hour_series(solk, 'Pfan_hour', 'Pfan');
            Ptot_hour = local_get_hour_series(solk, 'Pbase_hour', 'Ptot');
            bar(hvec, [Php_hour(:), Pfan_hour(:)], 'stacked', 'LineWidth', 0.8);
            plot(hvec, Ptot_hour(:), '-ko', 'LineWidth', 1.4, 'MarkerSize', 4);
            xlabel('小时 h'); ylabel('功率 (kW)');
            title(sprintf('beta=%.2f, h=%02d, R≈%.2f', mk.beta_use, h_fix, Rk));
            legend({'机组/热泵功率','风机功率','总功率'}, 'Location','best');
        end
    end
end

%% 图8：不同 beta 分别绘制净增量成本曲面（Figure 13 类）
for kk = 1:numel(cmp_markets)
    mk = cmp_markets{kk};
    [time_all, R_all, Z_all] = local_collect_surface_scatter(mk, 'delta_net_cred');
    if isempty(R_all), continue; end
    [TimeGrid, RGrid] = meshgrid(unique(time_all), unique(R_all));
    ZGrid = griddata(time_all, R_all, Z_all, TimeGrid, RGrid, 'linear');

    figure();
    surf(TimeGrid, RGrid, ZGrid, 'EdgeColor', 'none');
    hold on; box on; grid on;
    xlabel('时间 h'); ylabel('备用水平 R (kW)'); zlabel('\Delta J_{net}');
    title(sprintf('不同置信度下的净成本曲面（beta=%.2f）', mk.beta_use));
    colorbar; view(45,30);
end

%% 图9：不同 beta 下的净增量成本曲面叠加图（Figure 14 类）
if ~isempty(cmp_markets)
    figure(); hold on; box on; grid on;
    cmap = lines(max(4,numel(cmp_markets)));
    lgd_h = [];
    lgd_n = {};
    for kk = 1:numel(cmp_markets)
        mk = cmp_markets{kk};
        [time_all, R_all, Z_all] = local_collect_surface_scatter(mk, 'delta_net_cred');
        if isempty(R_all), continue; end
        [TimeGrid, RGrid] = meshgrid(unique(time_all), unique(R_all));
        ZGrid = griddata(time_all, R_all, Z_all, TimeGrid, RGrid, 'cubic');
        hs = surf(TimeGrid, RGrid, ZGrid, 'EdgeColor', 'none', 'FaceAlpha', 0.30, 'FaceColor', cmap(kk,:));
        lgd_h(end+1) = hs; %#ok<AGROW>
        lgd_n{end+1} = sprintf('beta=%.2f', mk.beta_use); %#ok<AGROW>
    end
    xlabel('时间 h'); ylabel('备用水平 R (kW)'); zlabel('\Delta J_{net}');
    title('不同置信度下的净增量成本曲面叠加图');
    view(45,30);
    if ~isempty(lgd_h)
        legend(lgd_h, lgd_n, 'Location','best');
    end
end

%% 图10：容量收益曲面（选定 beta）
[time_all, R_all, Z_all] = local_collect_surface_scatter(out_market, 'revenue_cap_cred');
if ~isempty(R_all)
    [TimeGrid, RGrid] = meshgrid(unique(time_all), unique(R_all));
    ZGrid = griddata(time_all, R_all, Z_all, TimeGrid, RGrid, 'linear');
    figure();
    surf(TimeGrid, RGrid, ZGrid, 'EdgeColor', 'none');
    hold on; box on; grid on;
    xlabel('时间 h'); ylabel('备用水平 R (kW)'); zlabel('Revenue');
    title(sprintf('容量收益曲面（beta=%.2f）', out_market.beta_use));
    colorbar; view(45,30);
end

%% 图11：Break-even 价格曲面（选定 beta）
[time_all, R_all, Z_all] = local_collect_surface_scatter(out_market, 'lambdaR_break_even_cred');
if ~isempty(R_all)
    [TimeGrid, RGrid] = meshgrid(unique(time_all), unique(R_all));
    ZGrid = griddata(time_all, R_all, Z_all, TimeGrid, RGrid, 'linear');
    figure();
    surf(TimeGrid, RGrid, ZGrid, 'EdgeColor', 'none');
    hold on; box on; grid on;
    xlabel('时间 h'); ylabel('备用水平 R (kW)'); zlabel('\lambda_R^{BE}');
    title(sprintf('Break-even 容量价格曲面（beta=%.2f）', out_market.beta_use));
    colorbar; view(45,30);
end

%% 图12：24 小时净增量成本总览（4x6）
figure();
tiledlayout(4,6,'TileSpacing','compact','Padding','compact');
for h = 1:Nh
    nexttile; hold on; box on; grid on;
    Hr = out_market.hours(h);
    if ~isempty(Hr.R_grid_cred)
        plot(Hr.R_grid_cred, Hr.delta_net_cred, '-o', 'LineWidth', 1.1, 'MarkerSize', 3);
    end
    xline(out_market.R_nat_hour(h), ':k', 'LineWidth', 0.8);
    if isfinite(out_market.R_cred_hour(h))
        xline(out_market.R_cred_hour(h), '--r', 'LineWidth', 0.8);
    end
    title(sprintf('h=%02d', h));
    xlabel('R'); ylabel('\Delta J_{net}');
end

end

% =========================================================================
% 默认参数
% =========================================================================
function cfg = local_fill_defaults(cfg)
if ~isfield(cfg,'beta_select') || isempty(cfg.beta_select)
    cfg.beta_select = 0.95;
end
if ~isfield(cfg,'beta_compare_list') || isempty(cfg.beta_compare_list)
    cfg.beta_compare_list = [0.80 0.85 0.90 0.95];
end
if ~isfield(cfg,'lambdaR_hour') || isempty(cfg.lambdaR_hour)
    cfg.lambdaR_hour = [0.0557, 0.0706, 0.0822, 0.0265, ...
                        0.0590, 0.0861, 0.0920, 0.0784, ...
                        0.1026, 0.1629, 0.2241, 0.1143, ...
                        0.3602, 0.1279, 0.1143, 0.0294, ...
                        0.0340, 0.0525, 0.1182, 0.3475, ...
                        0.1143, 0.2494, 0.0754, 0.1337]';
end
if ~isfield(cfg,'outdir') || isempty(cfg.outdir)
    cfg.outdir = project_data_file('postprocess_market');
end
if ~isfield(cfg,'reserve_tol') || isempty(cfg.reserve_tol)
    cfg.reserve_tol = 1e-8;
end
if ~isfield(cfg,'nNatSeg') || isempty(cfg.nNatSeg)
    cfg.nNatSeg = 20;
end
if ~isfield(cfg,'makePlots') || isempty(cfg.makePlots)
    cfg.makePlots = true;
end
if ~isfield(cfg,'typical_hour') || isempty(cfg.typical_hour)
    cfg.typical_hour = 13;
end
if ~isfield(cfg,'hours_to_plot') || isempty(cfg.hours_to_plot)
    cfg.hours_to_plot = [12 13];
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
end

% =========================================================================
% reserve / cred 读取
% =========================================================================
function [out, results_all, beta_use] = local_load_reserve_any(inReserve, beta_select)
results_all = [];
if ischar(inReserve) || isstring(inReserve)
    S = load(inReserve);
else
    S = inReserve;
end
if isfield(S,'results_all')
    results_all = S.results_all;
elseif isfield(S,'out')
    out = S.out; beta_use = local_get_beta_from_out(out); return;
elseif isfield(S,'out_i')
    out = S.out_i; beta_use = local_get_beta_from_out(out); return;
elseif isfield(S,'hours')
    out = S; beta_use = local_get_beta_from_out(out); return;
else
    error('无法识别 reserve 输入。');
end
beta_all = local_get_beta_list_from_reserve_results(results_all);
[~, idx] = min(abs(beta_all - beta_select));
out = local_extract_out_from_reserve_entry(results_all, idx);
beta_use = local_get_beta_from_out(out);
end

function [credOne, results_all, beta_screen] = local_load_cred_any(inCred, beta_select)
results_all = [];
if ischar(inCred) || isstring(inCred)
    S = load(inCred);
else
    S = inCred;
end
if isfield(S,'cred')
    S = S.cred;
end
if isfield(S,'results_all')
    results_all = S.results_all;
elseif isfield(S,'summary')
    credOne = S; beta_screen = local_get_beta_from_cred(credOne); return;
else
    error('无法识别 cred 输入。');
end
beta_all = local_get_beta_list_from_cred_results(results_all);
[~, idx] = min(abs(beta_all - beta_select));
credOne = local_extract_cred_from_cred_entry(results_all, idx);
beta_screen = local_get_beta_from_cred(credOne);
end

function beta_all = local_get_beta_list_from_reserve_results(results_all)
beta_all = nan(numel(results_all),1);
for i = 1:numel(results_all)
    outi = local_extract_out_from_reserve_entry(results_all, i);
    beta_all(i) = local_get_beta_from_out(outi);
end
end

function out = local_extract_out_from_reserve_entry(results_all, idx)
if isfield(results_all(idx),'out')
    out = results_all(idx).out;
else
    out = results_all(idx);
end
end

function beta_all = local_get_beta_list_from_cred_results(results_all)
beta_all = nan(numel(results_all),1);
for i = 1:numel(results_all)
    ci = local_extract_cred_from_cred_entry(results_all, i);
    beta_all(i) = local_get_beta_from_cred(ci);
end
end

function credOne = local_extract_cred_from_cred_entry(results_all, idx)
if iscell(results_all)
    credOne = results_all{idx};
else
    credOne = results_all(idx);
end
end

function beta_use = local_get_beta_from_out(out)
if isfield(out,'beta_use') && ~isempty(out.beta_use)
    beta_use = out.beta_use;
elseif isfield(out,'mdl') && isfield(out.mdl,'beta_use')
    beta_use = out.mdl.beta_use;
else
    beta_use = NaN;
end
end

function beta_screen = local_get_beta_from_cred(credOne)
beta_screen = NaN;
if isfield(credOne,'meta')
    if isfield(credOne.meta,'beta_screen') && ~isempty(credOne.meta.beta_screen)
        beta_screen = credOne.meta.beta_screen;
    elseif isfield(credOne.meta,'beta_use_reserve') && ~isempty(credOne.meta.beta_use_reserve)
        beta_screen = credOne.meta.beta_use_reserve;
    end
end
if isnan(beta_screen) && isfield(credOne,'cfg') && isfield(credOne.cfg,'beta_screen')
    beta_screen = credOne.cfg.beta_screen;
end
end

% =========================================================================
% helper
% =========================================================================
function y = local_get_num_field(Hr, fname, R_all)
if isfield(Hr,fname) && ~isempty(Hr.(fname))
    y = Hr.(fname)(:);
else
    y = nan(size(R_all));
end
end

function theta = local_pick_theta_band(out, h, side)
Hr = out.hours(h);
if strcmpi(side,'lb')
    if isfield(Hr,'theta_risk_lb') && ~isempty(Hr.theta_risk_lb)
        theta = Hr.theta_risk_lb(:); return;
    elseif isfield(out,'theta_risk_lb') && ~isempty(out.theta_risk_lb)
        theta = out.theta_risk_lb(:); return;
    end
else
    if isfield(Hr,'theta_risk_ub') && ~isempty(Hr.theta_risk_ub)
        theta = Hr.theta_risk_ub(:); return;
    elseif isfield(out,'theta_risk_ub') && ~isempty(out.theta_risk_ub)
        theta = out.theta_risk_ub(:); return;
    end
end
theta = [];
end

function idx = local_pick_even_indices(R, n_show)
idx = [];
if isempty(R), return; end
if numel(R) <= n_show
    idx = (1:numel(R)).';
    return;
end
pick = round(linspace(1, numel(R), n_show));
idx = unique(pick(:));
end

function [sol_typ, R_typ] = local_pick_typical_solution_market(out_market, h, modeSel)
sol_typ = [];
R_typ = NaN;
if h < 1 || h > numel(out_market.hours), return; end
Hr = out_market.hours(h);
if isempty(Hr.R_grid_cred) || isempty(Hr.solutions_cred), return; end
switch lower(modeSel)
    case 'max_credible'
        idx = numel(Hr.R_grid_cred);
    case 'middle_credible'
        idx = ceil(numel(Hr.R_grid_cred)/2);
    case 'first_above_nat'
        idx2 = find(Hr.R_grid_cred > out_market.R_nat_hour(h) + 1e-8, 1, 'first');
        if isempty(idx2)
            idx = numel(Hr.R_grid_cred);
        else
            idx = idx2;
        end
    otherwise
        idx = numel(Hr.R_grid_cred);
end
sol_typ = Hr.solutions_cred{idx};
R_typ = Hr.R_grid_cred(idx);
end

function R_fix = local_pick_reference_R(out_market, h, modeSel)
R_fix = NaN;
[~, R_fix] = local_pick_typical_solution_market(out_market, h, modeSel);
end

function [solk, Rk] = local_pick_solution_near_R(mk, h, Rtar)
solk = [];
Rk = NaN;
if h < 1 || h > numel(mk.hours), return; end
Hr = mk.hours(h);
if isempty(Hr.R_grid_cred), return; end
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
    if ~isfield(Hr,'R_grid_cred') || isempty(Hr.R_grid_cred), continue; end
    if ~isfield(Hr,fieldname) || isempty(Hr.(fieldname)), continue; end
    R_all = [R_all; Hr.R_grid_cred(:)]; %#ok<AGROW>
    Z_all = [Z_all; Hr.(fieldname)(:)]; %#ok<AGROW>
    time_all = [time_all; h*ones(numel(Hr.R_grid_cred),1)]; %#ok<AGROW>
end

mask = isfinite(R_all) & isfinite(Z_all) & isfinite(time_all);
R_all = R_all(mask);
Z_all = Z_all(mask);
time_all = time_all(mask);
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
