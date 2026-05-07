function cred = run_ch3_hourly_credible_feasibility_screen_V2(in, regStatFile, cfg)
% =========================================================================
% 第三章：逐小时可信可行判定（V2：显式使用 hourly covariance）
% -------------------------------------------------------------------------
% 【说明】
%   1) 本文件在"已验证可运行的单 beta 版本"基础上，做最小增量修改；
%   2) 不改动原有 RegD 读取、字段统一化、hourly covariance 传播主干；
%   3) 新增：支持四个置信度批量运行；
%   4) 新增：每个置信度输出一张阶梯图（天然备用 / 最大热可行备用 / 最大可信备用）；
%   5) 新增：所有置信度下最大可信备用的阶梯对比图；
%   6) 单 beta 模式原有逻辑保持不变。
%
% 输入：
%   in          : 逐小时备用结果（结构体或 MAT 文件路径）
%   regStatFile : RegD 统计 MAT 文件（来自 plot_regd_15min_historical_variance_v8.m）
%   cfg         : 可选配置结构体
%
% 常用调用：
%   % 单个置信度
%   cfg = struct(); cfg.beta_select = 0.95;
%   cred = run_ch3_hourly_credible_feasibility_screen_V2( ...
%       project_data_file('reserve', 'hourly_reserve_costcurve_all_beta.mat'), ...
%       project_data_file('regd', 'regd_15min_moments_and_hourly_cov_dynamic.mat'), cfg);
%
%   % 四个置信度批量运行
%   cfg = struct();
%   cfg.run_all_beta = true;
%   cfg.beta_list = [0.80 0.85 0.90 0.95];
%   cred = run_ch3_hourly_credible_feasibility_screen_V2( ...
%       project_data_file('reserve', 'hourly_reserve_costcurve_all_beta.mat'), ...
%       project_data_file('regd', 'regd_15min_moments_and_hourly_cov_dynamic.mat'), cfg);
% =========================================================================

%% 0) 默认输入
if nargin < 1 || isempty(in)
    in = project_data_file('reserve', 'hourly_reserve_costcurve_all_beta.mat');
end
if nargin < 2 || isempty(regStatFile)
    regStatFile = project_data_file('regd', 'regd_15min_moments_and_hourly_cov_dynamic.mat');
end
if nargin < 3
    cfg = struct();
end
cfg = local_fill_defaults(cfg, in, regStatFile);

%% 1) 批量 beta 包装器（最小增量，不破坏单 beta 主干）
if cfg.run_all_beta
    beta_list = cfg.beta_list(:).';
    nBeta = numel(beta_list);
    results_all = cell(nBeta,1);

    if cfg.verbose
        fprintf('\n============================================================\n');
        fprintf('开始批量逐小时可信可行判定，共 %d 个置信度\n', nBeta);
        fprintf('beta_list = '); fprintf('%.2f ', beta_list); fprintf('\n');
        fprintf('============================================================\n');
    end

    % 批量运行时，为避免每个子调用再触发对比图，先关闭单次对比图标志
    for ib = 1:nBeta
        cfg_i = cfg;
        cfg_i.run_all_beta = false;
        cfg_i.beta_select = beta_list(ib);
        cfg_i.beta_screen = beta_list(ib);
        cfg_i.make_compare_plot = false;
        cfg_i.make_plot = false;   % 子调用不单独画图，避免批量模式下重复生成相同单 beta 图

        if cfg.verbose
            fprintf('\n>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n');
            fprintf('批量运行 beta = %.2f (%d/%d)\n', beta_list(ib), ib, nBeta);
            fprintf('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n');
        end

        results_all{ib} = local_run_single_beta(in, regStatFile, cfg_i);
    end

    % 汇总输出
    cred = struct();
    cred.case_label = 'batch_all_beta';
    cred.beta_list = beta_list(:);
    cred.results_all = results_all;
    cred.cfg = cfg;

    % 保存批量 MAT
    cred.saved_mat = '';
    if cfg.save_mat
        outfile = fullfile(cfg.outdir, 'hourly_credible_feasibility_v2_all_beta.mat');
        save(outfile, 'cred', '-v7.3');
        cred.saved_mat = outfile;
    end

    % 绘图：
    % 1) 每个 beta 各一张天然/热可行/可信备用阶梯图
    % 2) 四个 beta 的最大可信备用对比阶梯图
    cred.saved_figures = {};
    cred.saved_typical_hour_fig = '';
    if cfg.make_plot
        figs = local_make_all_beta_step_plots(results_all, beta_list, cfg);
        cred.saved_figures = figs;
        cred.saved_typical_hour_fig = local_make_typical_hour_max_credible_vs_beta_plot(results_all, beta_list, cfg);
    end

    if cfg.verbose
        fprintf('\n============================================================\n');
        fprintf('批量可信可行判定完成。\n');
        if ~isempty(cred.saved_mat)
            fprintf('批量 MAT 已保存到: %s\n', cred.saved_mat);
        end
        for i = 1:numel(cred.saved_figures)
            fprintf('图已保存到      : %s\n', cred.saved_figures{i});
        end
        fprintf('============================================================\n');
    end
    return;
end

%% 2) 单个 beta 主流程（保持原有逻辑）
cred = local_run_single_beta(in, regStatFile, cfg);

end

%% =========================================================================
% 单 beta 主求解器（尽量保持原有可行代码逻辑不变）
% =========================================================================
function cred = local_run_single_beta(in, regStatFile, cfg)

%% 1) 读取逐小时备用结果
[out, srcInfo] = local_load_reserve_results(in, cfg); %#ok<NASGU>
mdl = out.mdl;
par = out.par;
baseline = out.baseline;
hours = out.hours;

assert(isfield(mdl, 'Nh') && isfield(mdl, 'ns'), '结果结构缺少 mdl.Nh / mdl.ns。');
Nh = double(mdl.Nh);
ns = double(mdl.ns);
Nk = double(mdl.H15);
assert(Nh * ns == Nk, 'H15 != Nh * ns，当前不支持。');
assert(numel(hours) == Nh, 'hours 数量与 Nh 不一致。');
assert(ns == 4, '当前版本默认每小时 4 个 15min 子步；实际 ns = %d。', ns);

%% 2) 读取 RegD 统计文件
assert(exist(regStatFile, 'file') == 2, '未找到 RegD 统计文件：%s', regStatFile);
Sreg = load(regStatFile);
Sreg = local_normalize_reg_stat_struct(Sreg);
[regStats, statMode] = local_build_signal_stats(Sreg, Nh, ns); %#ok<ASGLU>

%% 3) z_beta
if isempty(cfg.z_beta)
    cfg.z_beta = local_norminv(cfg.beta_screen);
end

%% 4) 预分配输出
cred = struct();
cred.cfg = cfg;
cred.meta = struct();
cred.meta.case_label = 'hourly_credible_feasibility_screen_v2_hourly_cov';
cred.meta.assumptions = struct( ...
    'mu0', 0, ...
    'Sigma0', 0, ...
    'xi_mean', 0, ...
    'Sigma_xi', 0, ...
    'signal_stat_mode', statMode);
cred.meta.reserve_result_source = cfg.reserve_result_file;
cred.meta.reg_stat_file = regStatFile;
cred.meta.beta_use_reserve = out.beta_use;
cred.meta.beta_screen = cfg.beta_screen;
cred.meta.z_beta = cfg.z_beta;

cred.summary = struct();
cred.summary.R_nat_hour  = nan(Nh,1);
cred.summary.R_max_hour  = nan(Nh,1);
cred.summary.R_cred_hour = nan(Nh,1);
cred.summary.idx_max_credible = nan(Nh,1);
cred.summary.n_credible = nan(Nh,1);
cred.summary.pass_ratio = nan(Nh,1);

emptyHour = struct( ...
    'hour', [], ...
    'R_grid_cred', [], ...
    'workpoint_source', {{}}, ...
    'idx_map_existing', [], ...
    'Ts_work', [], ...
    'ma_work', [], ...
    'Pfan_work', [], ...
    'fan_slope_kw_per_ma', [], ...
    'kappa_ma_per_kw', [], ...
    'Tref_work_15', [], ...
    'theta_risk_lb_15', [], ...
    'theta_risk_ub_15', [], ...
    'mu_s_15', [], ...
    'Sigma_s_15', [], ...
    'mu_m_15', [], ...
    'Sigma_m_15', [], ...
    'Htheta', [], ...
    'mu_theta_15', [], ...
    'Sigma_theta_15', [], ...
    'sigma_theta_15', [], ...
    'risk_upper_15', [], ...
    'risk_lower_15', [], ...
    'margin_to_upper_15', [], ...
    'margin_to_lower_15', [], ...
    'margin_min', [], ...
    'is_credible', [], ...
    'fail_step', [], ...
    'fail_side', {{}}, ...
    'idx_max_credible', NaN, ...
    'R_credible', NaN);
cred.hours = repmat(emptyHour, Nh, 1);

%% 5) 预提取状态空间模型中对 ma 的通道
A = double(local_get_required_field(mdl, 'A'));
B = double(local_get_required_field(mdl, 'B'));
C = double(local_get_required_field(mdl, 'C'));
D = double(local_get_required_field(mdl, 'D'));
assert(size(B,2) >= 2 && size(D,2) >= 2, '模型输入列数不足，当前默认第2列对应 ma。');
Bma = B(:,2);
Dma = D(:,2);
Htheta = local_build_theta_map(A, Bma, C, Dma, ns);

%% 6) 逐小时扫描
if cfg.verbose
    fprintf('\n============================================================\n');
    fprintf('开始逐小时可信可行判定（V2：hourly covariance）\n');
    fprintf('beta_screen        = %.4f\n', cfg.beta_screen);
    fprintf('z_beta             = %.6f\n', cfg.z_beta);
    fprintf('scan from          = 0\n');
    fprintf('signal_stat_mode   = %s\n', statMode);
    fprintf('RegD stat file     = %s\n', regStatFile);
    fprintf('============================================================\n');
end

for h = 1:Nh
    Hr = hours(h);
    idx15 = local_hour_to_15min_idx(h, ns);

    Rnat = double(local_get_required_field(Hr, 'R_nat'));
    if isfield(Hr, 'max_feasible_R') && ~isempty(Hr.max_feasible_R) && isfinite(Hr.max_feasible_R)
        Rmax = double(Hr.max_feasible_R);
    else
        Rmax = Rnat;
    end

    RgridCred = local_build_credible_grid(Hr, Rnat, Rmax, cfg);
    nR = numel(RgridCred);

    mu_s_h = regStats.mu_s_hourly(:, h);
    Sigma_s_h = regStats.Sigma_s_hourly(:,:,h);

    cred.hours(h).hour = h;
    cred.hours(h).R_grid_cred = RgridCred(:);
    cred.hours(h).Ts_work = nan(nR,1);
    cred.hours(h).ma_work = nan(nR,1);
    cred.hours(h).Pfan_work = nan(nR,1);
    cred.hours(h).fan_slope_kw_per_ma = nan(nR,1);
    cred.hours(h).kappa_ma_per_kw = nan(nR,1);
    cred.hours(h).Tref_work_15 = nan(ns, nR);
    cred.hours(h).theta_risk_lb_15 = repmat(local_pick_theta_lb(Hr, out, idx15), 1, nR);
    cred.hours(h).theta_risk_ub_15 = repmat(local_pick_theta_ub(Hr, out, idx15), 1, nR);
    cred.hours(h).mu_s_15 = repmat(mu_s_h, 1, nR);
    cred.hours(h).Sigma_s_15 = repmat({Sigma_s_h}, 1, nR);
    cred.hours(h).mu_m_15 = nan(ns, nR);
    cred.hours(h).Sigma_m_15 = repmat({nan(ns)}, 1, nR);
    cred.hours(h).Htheta = repmat({Htheta}, 1, nR);
    cred.hours(h).mu_theta_15 = nan(ns, nR);
    cred.hours(h).Sigma_theta_15 = repmat({nan(ns)}, 1, nR);
    cred.hours(h).sigma_theta_15 = nan(ns, nR);
    cred.hours(h).risk_upper_15 = nan(ns, nR);
    cred.hours(h).risk_lower_15 = nan(ns, nR);
    cred.hours(h).margin_to_upper_15 = nan(ns, nR);
    cred.hours(h).margin_to_lower_15 = nan(ns, nR);
    cred.hours(h).margin_min = nan(1, nR);
    cred.hours(h).is_credible = false(1, nR);
    cred.hours(h).fail_step = zeros(1, nR);
    cred.hours(h).fail_side = repmat({'none'}, 1, nR);
    cred.hours(h).idx_map_existing = nan(1, nR);
    cred.hours(h).workpoint_source = repmat({''}, 1, nR);

    cred.summary.R_nat_hour(h) = Rnat;
    cred.summary.R_max_hour(h) = Rmax;

    if cfg.verbose
        fprintf('\n------------------------------------------------------------\n');
        fprintf('Hour %02d / %02d\n', h, Nh);
        fprintf('R_nat(h) = %.6f kW,  R_max(h) = %.6f kW\n', Rnat, Rmax);
    end

    for i = 1:nR
        r = RgridCred(i);
        [wp, wpInfo] = local_pick_workpoint_for_r(out, h, r, cfg); %#ok<NASGU>

        cred.hours(h).Ts_work(i) = wp.Ts;
        cred.hours(h).ma_work(i) = wp.ma;
        cred.hours(h).Pfan_work(i) = wp.Pfan;
        cred.hours(h).Tref_work_15(:,i) = wp.Tref15(:);
        cred.hours(h).idx_map_existing(i) = wp.existing_idx;
        cred.hours(h).workpoint_source{i} = wp.source;

        slope = local_fan_slope_kw_per_ma(wp.ma, par);
        cred.hours(h).fan_slope_kw_per_ma(i) = slope;

        if ~isfinite(slope) || abs(slope) <= cfg.slope_tol
            cred.hours(h).kappa_ma_per_kw(i) = NaN;
            cred.hours(h).is_credible(i) = false;
            cred.hours(h).fail_step(i) = 1;
            cred.hours(h).fail_side{i} = 'slope';
            continue;
        end

        kappa = 1 / slope;
        cred.hours(h).kappa_ma_per_kw(i) = kappa;

        mu_m_h = (kappa * r) * mu_s_h;
        Sigma_m_h = (kappa * r)^2 * Sigma_s_h;
        Sigma_m_h = 0.5 * (Sigma_m_h + Sigma_m_h.');

        cred.hours(h).mu_m_15(:,i) = mu_m_h;
        cred.hours(h).Sigma_m_15{i} = Sigma_m_h;

        mu_theta_h = Htheta * mu_m_h;
        Sigma_theta_h = Htheta * Sigma_m_h * Htheta.';
        Sigma_theta_h = 0.5 * (Sigma_theta_h + Sigma_theta_h.');
        sigma_theta_h = sqrt(max(real(diag(Sigma_theta_h)), 0));

        cred.hours(h).mu_theta_15(:,i) = mu_theta_h;
        cred.hours(h).Sigma_theta_15{i} = Sigma_theta_h;
        cred.hours(h).sigma_theta_15(:,i) = sigma_theta_h;

        theta_ref = wp.Tref15(:);
        risk_upper = theta_ref + mu_theta_h + cfg.z_beta * sigma_theta_h;
        risk_lower = theta_ref + mu_theta_h - cfg.z_beta * sigma_theta_h;

        cred.hours(h).risk_upper_15(:,i) = risk_upper;
        cred.hours(h).risk_lower_15(:,i) = risk_lower;
        cred.hours(h).margin_to_upper_15(:,i) = cred.hours(h).theta_risk_ub_15(:,i) - risk_upper;
        cred.hours(h).margin_to_lower_15(:,i) = risk_lower - cred.hours(h).theta_risk_lb_15(:,i);

        muUpper = cred.hours(h).margin_to_upper_15(:,i);
        muLower = cred.hours(h).margin_to_lower_15(:,i);
        cred.hours(h).margin_min(i) = min([muUpper(:); muLower(:)]);

        failUpper = find(muUpper < -cfg.margin_tol, 1, 'first');
        failLower = find(muLower < -cfg.margin_tol, 1, 'first');

        if isempty(failUpper) && isempty(failLower)
            cred.hours(h).is_credible(i) = true;
            cred.hours(h).fail_step(i) = 0;
            cred.hours(h).fail_side{i} = 'none';
        else
            cred.hours(h).is_credible(i) = false;
            if isempty(failUpper)
                cred.hours(h).fail_step(i) = failLower;
                cred.hours(h).fail_side{i} = 'lower';
            elseif isempty(failLower)
                cred.hours(h).fail_step(i) = failUpper;
                cred.hours(h).fail_side{i} = 'upper';
            else
                if failUpper <= failLower
                    cred.hours(h).fail_step(i) = failUpper;
                    cred.hours(h).fail_side{i} = 'upper';
                else
                    cred.hours(h).fail_step(i) = failLower;
                    cred.hours(h).fail_side{i} = 'lower';
                end
            end
        end
    end

    idxCred = find(cred.hours(h).is_credible, 1, 'last');
    if isempty(idxCred)
        cred.hours(h).idx_max_credible = NaN;
        cred.hours(h).R_credible = NaN;
        cred.summary.idx_max_credible(h) = NaN;
        cred.summary.R_cred_hour(h) = NaN;
    else
        cred.hours(h).idx_max_credible = idxCred;
        cred.hours(h).R_credible = cred.hours(h).R_grid_cred(idxCred);
        cred.summary.idx_max_credible(h) = idxCred;
        cred.summary.R_cred_hour(h) = cred.hours(h).R_credible;
    end

    cred.summary.n_credible(h) = sum(cred.hours(h).is_credible);
    if nR > 0
        cred.summary.pass_ratio(h) = mean(cred.hours(h).is_credible);
    end

    if cfg.verbose
        if isnan(cred.summary.R_cred_hour(h))
            fprintf('R_cred(h) = NaN\n');
        else
            fprintf('R_cred(h) = %.6f kW\n', cred.summary.R_cred_hour(h));
        end
    end
end

%% 7) 保存结果与单 beta 图
cred.saved_mat = '';
cred.saved_fig = '';
if cfg.save_mat
    outfile = fullfile(cfg.outdir, sprintf('hourly_credible_feasibility_v2_beta_%02d.mat', round(100 * cfg.beta_screen)));
    save(outfile, 'cred', '-v7.3');
    cred.saved_mat = outfile;
end

if cfg.make_plot
    filefig = local_make_single_beta_step_plot(cred, cfg);
    cred.saved_fig = filefig;
end

if cfg.verbose
    fprintf('\n============================================================\n');
    fprintf('可信可行判定完成（V2）。\n');
    if ~isempty(cred.saved_mat)
        fprintf('MAT 已保存到: %s\n', cred.saved_mat);
    end
    if ~isempty(cred.saved_fig)
        fprintf('图  已保存到: %s\n', cred.saved_fig);
    end
    fprintf('============================================================\n');
end

end

%% =========================================================================
% 单 beta 阶梯图
% =========================================================================
function filefig = local_make_single_beta_step_plot(cred, cfg)
Nh = numel(cred.summary.R_nat_hour);
hvec = (1:Nh).';

f = figure('Color', 'w'); hold on; box on; grid on;
stairs(hvec, cred.summary.R_nat_hour(:), '-o', 'LineWidth', 1.6, 'MarkerSize', 4, 'DisplayName', '天然备用 R_{nat}');
stairs(hvec, cred.summary.R_max_hour(:), '-s', 'LineWidth', 1.6, 'MarkerSize', 4, 'DisplayName', '最大热可行备用');
stairs(hvec, cred.summary.R_cred_hour(:), '-^', 'LineWidth', 1.8, 'MarkerSize', 5, 'DisplayName', '最大可信备用 R_{cred}');
xlabel('小时 h');
ylabel('备用 (kW)');
title(sprintf('逐小时天然备用 / 最大热可行备用 / 最大可信备用（阶梯图, beta=%.2f）', cred.meta.beta_screen));
legend('Location', 'best');
filefig = fullfile(cfg.outdir, sprintf('fig_hourly_credible_feasibility_v2_beta_%02d.png', round(100 * cred.meta.beta_screen)));
saveas(f, filefig);
% close(f);
end

%% =========================================================================
% 全 beta 绘图
% =========================================================================
function figs = local_make_all_beta_step_plots(results_all, beta_list, cfg)
figs = {};
nBeta = numel(results_all);
Nh = numel(results_all{1}.summary.R_nat_hour);
hvec = (1:Nh).';

% 1) 每个 beta 各一张三条阶梯图
for ib = 1:nBeta
    cred_i = results_all{ib};
    filei = local_make_single_beta_step_plot(cred_i, cfg);
    figs{end+1} = filei;
end

% 2) 所有 beta 的最大可信备用对比阶梯图
f = figure('Color', 'w'); hold on; box on; grid on;
mk = {'-o','-s','-^','-d','-v','-p','-h'};
for ib = 1:nBeta
    cred_i = results_all{ib};
    style = mk{1 + mod(ib-1, numel(mk))};
    stairs(hvec, cred_i.summary.R_cred_hour(:), style, 'LineWidth', 1.8, 'MarkerSize', 4, ...
        'DisplayName', sprintf('beta = %.2f', beta_list(ib)));
end
xlabel('小时 h');
ylabel('最大可信备用 (kW)');
title('不同置信度下逐小时最大可信备用（阶梯图）');
legend('Location', 'best');
filecmp = fullfile(cfg.outdir, 'fig_hourly_credible_feasibility_v2_compare_all_beta.png');
saveas(f, filecmp);
% close(f);
figs{end+1} = filecmp;
end

%% =========================================================================
% 默认参数
% =========================================================================
function cfg = local_fill_defaults(cfg, in, regStatFile)
if ~isfield(cfg, 'beta_select') || isempty(cfg.beta_select)
    cfg.beta_select = [];
end
if ~isfield(cfg, 'beta_screen') || isempty(cfg.beta_screen)
    if ~isempty(cfg.beta_select)
        cfg.beta_screen = cfg.beta_select;
    else
        cfg.beta_screen = 0.95;
    end
end
if ~isfield(cfg, 'z_beta')
    cfg.z_beta = [];
end
if ~isfield(cfg, 'nScan_zero_to_nat') || isempty(cfg.nScan_zero_to_nat)
    cfg.nScan_zero_to_nat = 5;
end
if ~isfield(cfg, 'reserve_tol') || isempty(cfg.reserve_tol)
    cfg.reserve_tol = 1e-8;
end
if ~isfield(cfg, 'margin_tol') || isempty(cfg.margin_tol)
    cfg.margin_tol = 1e-10;
end
if ~isfield(cfg, 'slope_tol') || isempty(cfg.slope_tol)
    cfg.slope_tol = 1e-10;
end
if ~isfield(cfg, 'use_nearest_existing_solution') || isempty(cfg.use_nearest_existing_solution)
    cfg.use_nearest_existing_solution = true;
end
if ~isfield(cfg, 'make_plot') || isempty(cfg.make_plot)
    cfg.make_plot = true;
end
if ~isfield(cfg, 'save_mat') || isempty(cfg.save_mat)
    cfg.save_mat = true;
end
if ~isfield(cfg, 'verbose') || isempty(cfg.verbose)
    cfg.verbose = true;
end
if ~isfield(cfg, 'run_all_beta') || isempty(cfg.run_all_beta)
    cfg.run_all_beta = true;
end
if ~isfield(cfg, 'beta_list') || isempty(cfg.beta_list)
    cfg.beta_list = [0.80 0.85 0.90 0.95];
end
if ~isfield(cfg, 'make_compare_plot') || isempty(cfg.make_compare_plot)
    cfg.make_compare_plot = true;
end
if ~isfield(cfg, 'typical_hour') || isempty(cfg.typical_hour)
    cfg.typical_hour = 12;
end

if ischar(in) || isstring(in)
    cfg.reserve_result_file = char(in);
    reserveDir = fileparts(cfg.reserve_result_file);
else
    cfg.reserve_result_file = '[struct input]';
    reserveDir = pwd;
end
if isempty(reserveDir)
    reserveDir = pwd;
end
if ~isfield(cfg, 'outdir') || isempty(cfg.outdir)
    cfg.outdir = reserveDir;
end
if ~exist(cfg.outdir, 'dir')
    mkdir(cfg.outdir);
end

if nargin >= 3
    cfg.reg_stat_file = regStatFile;
end
end

%% =========================================================================
% 读取逐小时备用结果
% =========================================================================
function [out, srcInfo] = local_load_reserve_results(in, cfg)
srcInfo = struct();
if isstruct(in)
    if isfield(in, 'out')
        out = in.out;
    elseif isfield(in, 'out_i')
        out = in.out_i;
    elseif isfield(in, 'results_all')
        out = local_select_out_from_results_all(in.results_all, cfg.beta_select);
    else
        out = in;
    end
    return;
end
assert(exist(in, 'file') == 2, '未找到结果文件：%s', in);
S = load(in);
if isfield(S, 'out')
    out = S.out;
elseif isfield(S, 'out_i')
    out = S.out_i;
elseif isfield(S, 'results_all')
    out = local_select_out_from_results_all(S.results_all, cfg.beta_select);
else
    error('无法从 %s 中识别 out / out_i / results_all。', in);
end
end

function out = local_select_out_from_results_all(results_all, beta_select)
assert(~isempty(results_all), 'results_all 为空。');
if isempty(beta_select)
    beta_all = nan(numel(results_all),1);
    for i = 1:numel(results_all)
        if isfield(results_all(i), 'beta_use') && ~isempty(results_all(i).beta_use)
            beta_all(i) = results_all(i).beta_use;
        elseif isfield(results_all(i), 'out') && isfield(results_all(i).out, 'beta_use')
            beta_all(i) = results_all(i).out.beta_use;
        end
    end
    [~, idx] = max(beta_all);
else
    beta_all = nan(numel(results_all),1);
    for i = 1:numel(results_all)
        if isfield(results_all(i), 'beta_use') && ~isempty(results_all(i).beta_use)
            beta_all(i) = results_all(i).beta_use;
        elseif isfield(results_all(i), 'out') && isfield(results_all(i).out, 'beta_use')
            beta_all(i) = results_all(i).out.beta_use;
        end
    end
    [~, idx] = min(abs(beta_all - beta_select));
end
assert(isfield(results_all(idx), 'out'), 'results_all(%d) 缺少 out 字段。', idx);
out = results_all(idx).out;
end

%% =========================================================================
% 构造每小时可信扫描网格：从 0 扫到 R_max
% =========================================================================
function RgridCred = local_build_credible_grid(Hr, Rnat, Rmax, cfg)
if ~isfinite(Rmax) || Rmax < 0
    RgridCred = 0;
    return;
end
if Rnat <= cfg.reserve_tol
    Rlow = 0;
else
    nLow = max(2, round(cfg.nScan_zero_to_nat));
    nLow = 20;
    Rlow = linspace(0, Rnat, nLow).';
end
Rhigh = [];
if isfield(Hr, 'R_grid') && ~isempty(Hr.R_grid)
    x = double(Hr.R_grid(:));
    x = x(isfinite(x));
    x = x(x > Rnat + cfg.reserve_tol & x <= Rmax + cfg.reserve_tol);
    Rhigh = x(:);
end
RgridCred = unique([Rlow(:); Rhigh(:)]);
RgridCred = sort(RgridCred(:));
if isempty(RgridCred)
    RgridCred = 0;
end
if abs(RgridCred(end) - Rmax) > cfg.reserve_tol
    RgridCred = unique([RgridCred(:); Rmax]);
end
end

%% =========================================================================
% 对指定 r 选工作点：r <= Rnat 用基线；其余复用已有重构工作点
% =========================================================================
function [wp, info] = local_pick_workpoint_for_r(out, h, r, cfg)
baseline = out.baseline;
Hr = out.hours(h);
ns = double(out.mdl.ns);
idx15 = local_hour_to_15min_idx(h, ns);
wp = struct();
info = struct();
if r <= Hr.R_nat + cfg.reserve_tol
    wp.source = 'baseline';
    wp.existing_idx = 0;
    wp.Ts = baseline.Ts_hour(h);
    wp.ma = baseline.ma_hour(h);
    wp.Pfan = baseline.Pfan_hour(h);
    wp.Tref15 = baseline.T15(idx15);
    return;
end
assert(isfield(Hr, 'R_grid') && ~isempty(Hr.R_grid), 'Hour %d 缺少已有 R_grid。', h);
assert(isfield(Hr, 'is_feasible') && ~isempty(Hr.is_feasible), 'Hour %d 缺少 is_feasible。', h);
feasIdx = find(Hr.is_feasible(:) & isfinite(Hr.R_grid(:)) & (Hr.R_grid(:) > Hr.R_nat + cfg.reserve_tol));
assert(~isempty(feasIdx), 'Hour %d 在 R > R_nat 段没有可复用重构工作点。', h);
Rfeas = Hr.R_grid(feasIdx);
if cfg.use_nearest_existing_solution
    [~, k] = min(abs(Rfeas - r));
    idxUse = feasIdx(k);
else
    [dmin, k] = min(abs(Rfeas - r));
    assert(dmin <= cfg.reserve_tol, 'r=%.6f 在 hour=%d 无对应精确工作点。', r, h);
    idxUse = feasIdx(k);
end
assert(isfield(Hr, 'solutions') && numel(Hr.solutions) >= idxUse && ~isempty(Hr.solutions{idxUse}), ...
    'Hour %d, idx=%d 缺少 solutions。', h, idxUse);
sol = Hr.solutions{idxUse};
wp.source = 'existing';
wp.existing_idx = idxUse;
wp.Ts = sol.Ts_hour(h);
wp.ma = sol.ma_hour(h);
wp.Pfan = sol.Pfan_hour(h);
wp.Tref15 = sol.T15(idx15);
end

%% =========================================================================
% 风机功率对风量的导数（kW / ma）
% =========================================================================
function slope = local_fan_slope_kw_per_ma(ma, par)
fan_a = double(local_get_required_field(par, 'fan_a'));
fan_b = double(local_get_required_field(par, 'fan_b'));
fan_c = double(local_get_required_field(par, 'fan_c'));
fan_multiplier = double(local_get_required_field(par, 'fan_multiplier'));
slope_single_W = 3 * fan_a * ma.^2 + 2 * fan_b * ma + fan_c;
slope = fan_multiplier * slope_single_W / 1000;
end

%% =========================================================================
% 统一不同 RegD MAT 保存风格
% =========================================================================
function Sreg2 = local_normalize_reg_stat_struct(Sreg)
Sreg2 = Sreg;
if isfield(Sreg2, 'S_regd') && isstruct(Sreg2.S_regd)
    fn = fieldnames(Sreg2.S_regd);
    for i = 1:numel(fn)
        name = fn{i};
        if ~isfield(Sreg2, name) || isempty(Sreg2.(name))
            Sreg2.(name) = Sreg2.S_regd.(name);
        end
    end
end
map = { ...
    'pooled_raw_mean15_save', 'pooled_raw_mean15'; ...
    'pooled_raw_var15_save',  'pooled_raw_var15';  ...
    'pooled_raw_std15_save',  'pooled_raw_std15';  ...
    'mu_s_hourly_save',       'mu_s_hourly';       ...
    'Sigma_s_hourly_save',    'Sigma_s_hourly';    ...
    'slot_index_save',        'slot_index';        ...
    'slot_start_sec_save',    'slot_start_sec';    ...
    'slot_label_save',        'slot_label';        ...
    'hour_index_save',        'hour_index';        ...
    'substep_index_save',     'substep_index';     ...
    'substep_label_save',     'substep_label';     ...
    'dt_seconds_save',        'dt_seconds';        ...
    'samples_per_15min_save', 'samples_per_15min'; ...
    'nDays_save',             'nDays';             ...
    'nValid_days_hourly_save','nValid_days_hourly'};
for i = 1:size(map,1)
    src = map{i,1}; dst = map{i,2};
    if ~isfield(Sreg2, dst) && isfield(Sreg2, src)
        Sreg2.(dst) = Sreg2.(src);
    end
end
end

%% =========================================================================
% 构造该小时信号统计量
% =========================================================================
function [regStats, statMode] = local_build_signal_stats(Sreg, Nh, ns)
regStats = struct();
if isfield(Sreg, 'mu_s_hourly') && isfield(Sreg, 'Sigma_s_hourly')
    mu_s_hourly = double(Sreg.mu_s_hourly);
    Sigma_s_hourly = double(Sreg.Sigma_s_hourly);
    if isequal(size(mu_s_hourly), [Nh, ns])
        mu_s_hourly = mu_s_hourly.';
    end
    assert(isequal(size(mu_s_hourly), [ns, Nh]), 'mu_s_hourly 尺寸应为 4x24 或 24x4。');
    assert(ndims(Sigma_s_hourly) == 3, 'Sigma_s_hourly 应为三维数组。');
    sz = size(Sigma_s_hourly);
    if isequal(sz, [ns, ns, Nh])
        % do nothing
    elseif isequal(sz, [Nh, ns, ns])
        Sigma_s_hourly = permute(Sigma_s_hourly, [2 3 1]);
    else
        error('Sigma_s_hourly 尺寸应为 4x4x24 或 24x4x4。');
    end
    for h = 1:Nh
        Sigma_s_hourly(:,:,h) = 0.5 * (Sigma_s_hourly(:,:,h) + Sigma_s_hourly(:,:,h).');
    end
    regStats.mu_s_hourly = mu_s_hourly;
    regStats.Sigma_s_hourly = Sigma_s_hourly;
    statMode = 'hourly_cov';
    return;
end

assert(isfield(Sreg, 'pooled_raw_mean15') && isfield(Sreg, 'pooled_raw_var15'), ...
    'RegD 文件既没有 hourly covariance，也没有 pooled_raw_mean15 / pooled_raw_var15。');
mu_s_15 = double(Sreg.pooled_raw_mean15(:));
var_s_15 = double(Sreg.pooled_raw_var15(:));
assert(numel(mu_s_15) == Nh * ns, 'pooled_raw_mean15 长度应为 %d。', Nh*ns);
assert(numel(var_s_15) == Nh * ns, 'pooled_raw_var15 长度应为 %d。', Nh*ns);
var_s_15 = max(var_s_15, 0);
mu_s_hourly = reshape(mu_s_15, ns, Nh);
Sigma_s_hourly = nan(ns, ns, Nh);
for h = 1:Nh
    rows = (h-1)*ns + (1:ns);
    Sigma_s_hourly(:,:,h) = diag(var_s_15(rows));
end
warning(['当前 RegD 文件未检测到 mu_s_hourly / Sigma_s_hourly，', ...
         '将退化为 15min 独立近似，即 Sigma_s = diag(var_s)。']);
regStats.mu_s_hourly = mu_s_hourly;
regStats.Sigma_s_hourly = Sigma_s_hourly;
statMode = 'diag_15min';
end

%% =========================================================================
% 构造从 4 子步风量扰动向量到 4 子步温度偏差向量的提升映射 Htheta
% =========================================================================
function Htheta = local_build_theta_map(A, Bma, C, Dma, ns)
nx = size(A,1);
Htheta = zeros(ns, ns);
for col = 1:ns
    x = zeros(nx,1);
    for j = 1:ns
        u = double(j == col);
        Htheta(j,col) = C * x + Dma * u;
        x = A * x + Bma * u;
    end
end
end

%% =========================================================================
% 选风险边界
% =========================================================================
function theta_lb = local_pick_theta_lb(Hr, out, idx15)
if isfield(Hr, 'theta_risk_lb') && ~isempty(Hr.theta_risk_lb)
    theta_lb = double(Hr.theta_risk_lb(idx15));
elseif isfield(out, 'theta_risk_lb') && ~isempty(out.theta_risk_lb)
    theta_lb = double(out.theta_risk_lb(idx15));
else
    error('缺少 theta_risk_lb。');
end
theta_lb = theta_lb(:);
end
function theta_ub = local_pick_theta_ub(Hr, out, idx15)
if isfield(Hr, 'theta_risk_ub') && ~isempty(Hr.theta_risk_ub)
    theta_ub = double(Hr.theta_risk_ub(idx15));
elseif isfield(out, 'theta_risk_ub') && ~isempty(out.theta_risk_ub)
    theta_ub = double(out.theta_risk_ub(idx15));
else
    error('缺少 theta_risk_ub。');
end
theta_ub = theta_ub(:);
end

%% =========================================================================
% 小时 -> 15min 索引
% =========================================================================
function idx15 = local_hour_to_15min_idx(h, ns)
idx15 = (h-1) * ns + (1:ns);
idx15 = idx15(:);
end


%% =========================================================================
% 典型小时：不同置信度下最大可信备用
% =========================================================================
function filefig = local_make_typical_hour_max_credible_vs_beta_plot(results_all, beta_list, cfg)

nBeta = numel(results_all);
if isfield(cfg,'typical_hour') && ~isempty(cfg.typical_hour) && isfinite(cfg.typical_hour)
    h_typ = round(cfg.typical_hour);
else
    h_typ = 12;
end
R_typ = nan(nBeta,1);
for ib = 1:nBeta
    cred_i = results_all{ib};
    if h_typ >= 1 && h_typ <= numel(cred_i.summary.R_cred_hour)
        R_typ(ib) = cred_i.summary.R_cred_hour(h_typ);
    end
end

f = figure('Color', 'w'); hold on; box on; grid on;
plot(beta_list(:), R_typ(:), '-o', 'LineWidth', 1.8, 'MarkerSize', 6);
xlabel('置信度 beta');
ylabel(sprintf('典型小时 h=%02d 的最大可信备用 (kW)', h_typ));
title(sprintf('典型小时 h=%02d 不同置信度下的最大可信备用', h_typ));
xticks(beta_list(:).');
filefig = fullfile(cfg.outdir, sprintf('fig_typical_hour_%02d_max_credible_vs_beta.png', h_typ));
saveas(f, filefig);
% close(f);
end

%% =========================================================================
% 工具函数
% =========================================================================
function v = local_get_required_field(S, name)
assert(isfield(S, name), '缺少字段：%s', name);
v = S.(name);
end
function z = local_norminv(p)
p = min(max(p, 1e-12), 1 - 1e-12);
z = sqrt(2) * erfinv(2*p - 1);
end
