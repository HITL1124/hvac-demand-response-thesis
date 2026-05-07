function out = run_ch3_hourly_reserve_costcurve_main_V2(cfg)
% =========================================================================
% 第三章：逐小时备用成本曲线（支持单一/批量置信度）
% -------------------------------------------------------------------------
% 设计原则：
%   1) 先求全日名义基线；
%   2) 基于基线风机功率，计算每小时天然对称备用 R_nat(h)；
%   3) 对每个小时 h，扫描绝对备用水平 R >= R_nat(h)；
%   4) 对给定 R，先由风机功率区间 [Pfan_min+R, Pfan_max-R] 反解
%      目标小时风量可行区间 [maL(R), maU(R)]；
%   5) 在"全日 24h 联合优化"中，将目标小时 ma(h) 约束在该区间内，
%      内层优化求"最小代价工作点"；
%   6) 目标函数默认与基线一致：全日能耗成本 + 温度偏离代价 + 松弛惩罚；
%      可选加入相对基线偏移惩罚（默认系数为 0）；
%   7) 输出逐小时备用成本曲线。
%
% 新增说明：
%   - 支持 cfg.run_all_beta = true 时批量运行多个置信度；
%   - 支持 cfg.beta_list 指定批量运行列表；
%   - 每个置信度下都会导出风险收缩后的舒适区间：
%         out.theta_risk_lb, out.theta_risk_ub
%         out.hours(h).theta_risk_lb, out.hours(h).theta_risk_ub
%
% 调用示例：
%   % 单个置信度
%   cfg = struct();
%   cfg.beta_target = 0.95;
%   cfg.run_all_beta = false;
%   out = run_ch3_hourly_reserve_costcurve_main(cfg);
%
%   % 批量置信度
%   cfg = struct();
%   cfg.run_all_beta = true;
%   cfg.beta_list = [0.80 0.85 0.90 0.95];
%   results_all = run_ch3_hourly_reserve_costcurve_main(cfg);
% =========================================================================

%% 0) 默认参数
if nargin < 1
    cfg = struct();
end
cfg = local_fill_defaults(cfg);

if ~exist(cfg.outdir, 'dir')
    mkdir(cfg.outdir);
end

% ---------- 置信度运行列表 ----------
if cfg.run_all_beta
    beta_run_list = cfg.beta_list(:).';
else
    beta_run_list = cfg.beta_target;
end

results_all = struct([]);

for ib = 1:numel(beta_run_list)

    cfg.beta_target = beta_run_list(ib);

    % 批量运行时，建议先不自动绘图
    if cfg.run_all_beta
        cfg.makePlots = false;
    end

    %% 1) 读取模型与参数
    [mdl, par, cfg] = local_build_model_from_stage2(cfg);

    fprintf('\n============================================================\n');
    if cfg.run_all_beta
        fprintf('批量运行 beta = %.4f (%d/%d)\n', cfg.beta_target, ib, numel(beta_run_list));
    else
        fprintf('逐小时备用成本曲线求解开始\n');
    end
    fprintf('============================================================\n');
    fprintf('beta_target                = %.4f\n', cfg.beta_target);
    fprintf('beta_use                   = %.4f\n', mdl.beta_use);
    fprintf('nScan                      = %d\n', cfg.nScan);
    fprintf('reserve_ub_mode            = %s\n', cfg.reserve_ub_mode);
    fprintf('目标函数                   = Energy + Temp + Slack + optional Dev\n');
    fprintf('rho_dev_Ts / rho_dev_ma    = %.3e / %.3e\n', cfg.rho_dev_Ts, cfg.rho_dev_ma);
    fprintf('Pfan_min / Pfan_max        = %.6f / %.6f kW\n', par.Pfan_min, par.Pfan_max);
    fprintf('============================================================\n');

    %% 2) 求全日基线
    init = struct();
    init.Ts_hour = min(max(mdl.Ts_hour_ref, par.Ts_min), par.Ts_max);
    init.ma_hour = min(max(mdl.ma_hour_ref, par.ma_min), par.ma_max);
    init.sL = zeros(mdl.H15,1);
    init.sU = zeros(mdl.H15,1);

    solver_mode = struct();
    solver_mode.has_target_hour = false;
    solver_mode.targetHour = [];
    solver_mode.maL = [];
    solver_mode.maU = [];
    solver_mode.baseline_ref = [];

    fprintf('\n[步骤 1/3] 求全日名义基线 ...\n');
    baseline = local_solve_one_problem(mdl, par, init, cfg, solver_mode);
    baseline.label = 'baseline';

    R_nat_hour = min(baseline.Pfan_hour - par.Pfan_min, par.Pfan_max - baseline.Pfan_hour);
    R_nat_hour = max(R_nat_hour, 0);
    R_upper_global = 0.5 * (par.Pfan_max - par.Pfan_min);

    fprintf('\n[基线摘要]\n');
    fprintf('obj_value                  = %.6f\n', baseline.obj_value);
    fprintf('cost_energy                = %.6f\n', baseline.cost_energy);
    fprintf('temp_penalty               = %.6f\n', baseline.temp_penalty);
    fprintf('max_slack                  = %.3e\n', baseline.max_slack);
    fprintf('前6小时天然备用 R_nat      : '); fprintf('%.4f ', R_nat_hour(1:min(6,numel(R_nat_hour)))); fprintf(' kW\n');

    %% 3) 逐小时扫描
    Nh = mdl.Nh;
    hours_result = cell(Nh, 1);

    fprintf('\n[步骤 2/3] 开始逐小时扫描 ...\n');
    for h = 1:Nh
        fprintf('\n------------------------------------------------------------\n');
        fprintf('Hour %02d / %02d\n', h, Nh);
        fprintf('Pfan_base(h)               = %.6f kW\n', baseline.Pfan_hour(h));
        fprintf('R_nat(h)                   = %.6f kW\n', R_nat_hour(h));

        r_grid = local_build_hour_grid(cfg, par, h, R_nat_hour(h), R_upper_global);

        Hr = struct();
        Hr.hour = h;
        Hr.Pfan_base = baseline.Pfan_hour(h);
        Hr.R_nat = R_nat_hour(h);
        Hr.R_upper_global = R_upper_global;
        Hr.R_grid = r_grid(:);
        nR = numel(r_grid);

        Hr.is_feasible = false(nR,1);
        Hr.exitflag = nan(nR,1);
        Hr.maL = nan(nR,1);
        Hr.maU = nan(nR,1);

        Hr.obj_total = nan(nR,1);
        Hr.delta_total = nan(nR,1);
        Hr.cost_energy = nan(nR,1);
        Hr.delta_energy = nan(nR,1);
        Hr.temp_penalty = nan(nR,1);
        Hr.delta_temp = nan(nR,1);
        Hr.slack_penalty = nan(nR,1);
        Hr.dev_penalty = nan(nR,1);
        Hr.max_slack = nan(nR,1);

        Hr.Pfan_hour = nan(nR,1);
        Hr.ma_hour = nan(nR,1);
        Hr.Ts_hour_C = nan(nR,1);
        Hr.solutions = cell(nR,1);

        % ===== 导出当前置信度下风险收缩舒适区间 =====
        Hr.theta_risk_lb = mdl.Tlow_rob_15(:);
        Hr.theta_risk_ub = mdl.Tup_rob_15(:);
        Hr.theta_pred    = mdl.Tpred15(:);
        Hr.beta_use      = mdl.beta_use;

        prev_init = struct();
        prev_init.Ts_hour = baseline.Ts_hour(:);
        prev_init.ma_hour = baseline.ma_hour(:);
        prev_init.sL      = zeros(mdl.H15,1);
        prev_init.sU      = zeros(mdl.H15,1);

        for i = 1:nR
            R = r_grid(i);

            % 若 R 不高于天然备用，则直接沿用基线，增量成本为 0
            if R <= R_nat_hour(h) + cfg.reserve_tol
                Hr.is_feasible(i)    = true;
                Hr.exitflag(i)       = 99;  % 99 表示直接沿用基线
                Hr.maL(i)            = baseline.ma_hour(h);
                Hr.maU(i)            = baseline.ma_hour(h);
                Hr.obj_total(i)      = baseline.obj_value;
                Hr.delta_total(i)    = 0;
                Hr.cost_energy(i)    = baseline.cost_energy;
                Hr.delta_energy(i)   = 0;
                Hr.temp_penalty(i)   = baseline.temp_penalty;
                Hr.delta_temp(i)     = 0;
                Hr.slack_penalty(i)  = baseline.slack_penalty;
                Hr.dev_penalty(i)    = 0;
                Hr.max_slack(i)      = baseline.max_slack;
                Hr.Pfan_hour(i)      = baseline.Pfan_hour(h);
                Hr.ma_hour(i)        = baseline.ma_hour(h);
                Hr.Ts_hour_C(i)      = baseline.Ts_hour(h) - 273.15;
                Hr.solutions{i}      = baseline;
                continue;
            end

            [maL, maU, okInv] = local_get_ma_interval_for_reserve(R, par);
            Hr.maL(i) = maL;
            Hr.maU(i) = maU;

            if ~okInv || isnan(maL) || isnan(maU) || maL > maU
                fprintf('  R = %.6f -> 无法反解风量区间，记为 infeasible\n', R);
                if cfg.stop_at_first_infeasible
                    break;
                else
                    continue;
                end
            end

            fprintf('  R = %.6f, ma interval = [%.6f, %.6f]\n', R, maL, maU);

            solver_mode = struct();
            solver_mode.has_target_hour = true;
            solver_mode.targetHour = h;
            solver_mode.maL = maL;
            solver_mode.maU = maU;
            solver_mode.baseline_ref = baseline;

            try
                sol_i = local_solve_one_problem(mdl, par, prev_init, cfg, solver_mode);

                feasible_i = (sol_i.max_slack <= cfg.feas_slack_tol);

                Hr.is_feasible(i)    = feasible_i;
                Hr.exitflag(i)       = sol_i.exitflag;
                Hr.obj_total(i)      = sol_i.obj_value;
                Hr.delta_total(i)    = sol_i.obj_value - baseline.obj_value;
                Hr.cost_energy(i)    = sol_i.cost_energy;
                Hr.delta_energy(i)   = sol_i.cost_energy - baseline.cost_energy;
                Hr.temp_penalty(i)   = sol_i.temp_penalty;
                Hr.delta_temp(i)     = sol_i.temp_penalty - baseline.temp_penalty;
                Hr.slack_penalty(i)  = sol_i.slack_penalty;
                Hr.dev_penalty(i)    = sol_i.dev_penalty;
                Hr.max_slack(i)      = sol_i.max_slack;

                Hr.Pfan_hour(i)      = sol_i.Pfan_hour(h);
                Hr.ma_hour(i)        = sol_i.ma_hour(h);
                Hr.Ts_hour_C(i)      = sol_i.Ts_hour(h) - 273.15;
                Hr.solutions{i}      = sol_i;

                if feasible_i
                    prev_init.Ts_hour = sol_i.Ts_hour(:);
                    prev_init.ma_hour = sol_i.ma_hour(:);
                    prev_init.sL      = sol_i.sL(:);
                    prev_init.sU      = sol_i.sU(:);
                else
                    if cfg.stop_at_first_infeasible
                        break;
                    end
                end

            catch ME
                fprintf('  solver failure: %s\n', ME.message);
                if cfg.stop_at_first_infeasible
                    break;
                end
            end
        end

        feas_idx = find(Hr.is_feasible);
        if isempty(feas_idx)
            Hr.max_feasible_R = NaN;
            Hr.idx_max_feasible = NaN;
        else
            Hr.idx_max_feasible = feas_idx(end);
            Hr.max_feasible_R = Hr.R_grid(Hr.idx_max_feasible);
        end

        Hr.marginal_cost = local_compute_marginal_cost(Hr.R_grid, Hr.delta_total, Hr.is_feasible);

        if isnan(Hr.max_feasible_R)
            fprintf('  max feasible reserve      = NaN\n');
        else
            fprintf('  max feasible reserve      = %.6f kW\n', Hr.max_feasible_R);
        end

        hours_result{h} = Hr;
    end

    %% 4) 输出当前 beta 的整体结果
    out_i = struct();
    out_i.cfg = cfg;
    out_i.par = par;
    out_i.mdl = mdl;
    out_i.baseline = baseline;
    out_i.R_nat_hour = R_nat_hour;
    out_i.hours = vertcat(hours_result{:});

    % ===== 全局导出当前 beta 下的风险收缩舒适区间 =====
    out_i.beta_use = mdl.beta_use;
    out_i.theta_risk_lb = mdl.Tlow_rob_15(:);
    out_i.theta_risk_ub = mdl.Tup_rob_15(:);
    out_i.theta_pred    = mdl.Tpred15(:);

    outfile = fullfile(cfg.outdir, sprintf('hourly_reserve_costcurve_beta_%02d.mat', round(100*mdl.beta_use)));
    save(outfile, 'out_i', '-v7.3');
    out_i.saved_mat = outfile;

    figs = {};
    out_i.saved_figures = figs;
    if cfg.makePlots
        figs = plot_ch3_hourly_reserve_costcurve_results(out_i);
        out_i.saved_figures = figs;
    end

    fprintf('\n[步骤 3/3] 完成\n');
    fprintf('结果已保存到: %s\n', outfile);
    if ~isempty(out_i.saved_figures)
        for i = 1:numel(out_i.saved_figures)
            fprintf('图已保存到  : %s\n', out_i.saved_figures{i});
        end
    else
        fprintf('本次未自动绘图；如需绘图，请单独运行 plot_ch3_hourly_reserve_costcurve_results。\n');
    end

    results_all(ib).beta_target = cfg.beta_target;
    results_all(ib).beta_use    = out_i.beta_use;
    results_all(ib).out         = out_i;
end

%% 5) 单一/批量两种输出模式
if cfg.run_all_beta
    allfile = fullfile(cfg.outdir, 'hourly_reserve_costcurve_all_beta.mat');
    save(allfile, 'results_all', '-v7.3');
    fprintf('\n所有置信度结果已统一保存到: %s\n', allfile);
    out = results_all;
else
    out = results_all(1).out;
end

end

% =========================================================================
% 默认参数
% =========================================================================
function cfg = local_fill_defaults(cfg)

% 文件
if ~isfield(cfg,'stage2ModelFile') || isempty(cfg.stage2ModelFile)
    cfg.stage2ModelFile = project_data_file('stage1','stage1_hour_model_for_stage2.mat');
end
if ~isfield(cfg,'stage2CqrFile') || isempty(cfg.stage2CqrFile)
    cfg.stage2CqrFile = project_data_file('stage1','stage1_cqr_for_stage2.mat');
end
if ~isfield(cfg,'outdir') || isempty(cfg.outdir)
    cfg.outdir = project_data_file('reserve');
end

% 风险
if ~isfield(cfg,'beta_target') || isempty(cfg.beta_target)
    cfg.beta_target = 0.80;
end
if ~isfield(cfg,'run_all_beta') || isempty(cfg.run_all_beta)
    cfg.run_all_beta = true;
end
if ~isfield(cfg,'beta_list') || isempty(cfg.beta_list)
    cfg.beta_list = [0.80 0.85 0.90 0.95];
end

% 扫描
if ~isfield(cfg,'nScan') || isempty(cfg.nScan)
    cfg.nScan = 40;
end
if ~isfield(cfg,'reserve_ub_mode') || isempty(cfg.reserve_ub_mode)
    cfg.reserve_ub_mode = 'physical_half_range';
end
if ~isfield(cfg,'reserve_ub_kw') || isempty(cfg.reserve_ub_kw)
    cfg.reserve_ub_kw = [];
end
if ~isfield(cfg,'reserve_tol') || isempty(cfg.reserve_tol)
    cfg.reserve_tol = 1e-6;
end
if ~isfield(cfg,'stop_at_first_infeasible') || isempty(cfg.stop_at_first_infeasible)
    cfg.stop_at_first_infeasible = true;
end
if ~isfield(cfg,'feas_slack_tol') || isempty(cfg.feas_slack_tol)
    cfg.feas_slack_tol = 1e-4;
end
if ~isfield(cfg,'hours_to_plot') || isempty(cfg.hours_to_plot)
    cfg.hours_to_plot = [8 12 18];
end
if ~isfield(cfg,'makePlots') || isempty(cfg.makePlots)
    cfg.makePlots = true;
end

% 热参数
if ~isfield(cfg,'epsilon') || isempty(cfg.epsilon), cfg.epsilon = 0.9; end
if ~isfield(cfg,'cp_a') || isempty(cfg.cp_a), cfg.cp_a = 1.005; end
if ~isfield(cfg,'Qmax') || isempty(cfg.Qmax), cfg.Qmax = 650; end
if ~isfield(cfg,'COP_lb') || isempty(cfg.COP_lb), cfg.COP_lb = 1.2; end
if ~isfield(cfg,'cop_dT_mode') || isempty(cfg.cop_dT_mode), cfg.cop_dT_mode = 'Ts_minus_To'; end

% 控制边界
if ~isfield(cfg,'Ts_min_C') || isempty(cfg.Ts_min_C), cfg.Ts_min_C = 35; end
if ~isfield(cfg,'Ts_max_C') || isempty(cfg.Ts_max_C), cfg.Ts_max_C = 50; end
if ~isfield(cfg,'ma_min') || isempty(cfg.ma_min), cfg.ma_min = 6; end
if ~isfield(cfg,'ma_max') || isempty(cfg.ma_max), cfg.ma_max = 24; end
if ~isfield(cfg,'dTs_max') || isempty(cfg.dTs_max), cfg.dTs_max = 10; end
if ~isfield(cfg,'dma_max') || isempty(cfg.dma_max), cfg.dma_max = 10; end

% 风机参数
if ~isfield(cfg,'fan_a') || isempty(cfg.fan_a), cfg.fan_a = 10.133064171; end
if ~isfield(cfg,'fan_b') || isempty(cfg.fan_b), cfg.fan_b = 10.087791979; end
if ~isfield(cfg,'fan_c') || isempty(cfg.fan_c), cfg.fan_c = -59.56637575; end
if ~isfield(cfg,'fan_d') || isempty(cfg.fan_d), cfg.fan_d = 208.2979381; end
if ~isfield(cfg,'fan_multiplier') || isempty(cfg.fan_multiplier), cfg.fan_multiplier = 1; end

% 舒适带
if ~isfield(cfg,'default_Tmin') || isempty(cfg.default_Tmin), cfg.default_Tmin = 293.15; end
if ~isfield(cfg,'default_Tmax') || isempty(cfg.default_Tmax), cfg.default_Tmax = 297.15; end

% 目标函数
if ~isfield(cfg,'rho_slack') || isempty(cfg.rho_slack), cfg.rho_slack = 1e4; end
if ~isfield(cfg,'rho_temp') || isempty(cfg.rho_temp), cfg.rho_temp = 2; end
if ~isfield(cfg,'temp_penalty_mode') || isempty(cfg.temp_penalty_mode), cfg.temp_penalty_mode = 'band_center'; end
if ~isfield(cfg,'Tref_fixed_C') || isempty(cfg.Tref_fixed_C), cfg.Tref_fixed_C = 22; end
if ~isfield(cfg,'rho_dev_Ts') || isempty(cfg.rho_dev_Ts), cfg.rho_dev_Ts = 0; end
if ~isfield(cfg,'rho_dev_ma') || isempty(cfg.rho_dev_ma), cfg.rho_dev_ma = 0; end
if ~isfield(cfg,'slack_tol') || isempty(cfg.slack_tol), cfg.slack_tol = 1e-5; end

% 调试和求解器
if ~isfield(cfg,'showIterSummary') || isempty(cfg.showIterSummary), cfg.showIterSummary = true; end
if ~isfield(cfg,'summaryIterGap') || isempty(cfg.summaryIterGap), cfg.summaryIterGap = 20; end
if ~isfield(cfg,'MaxFunctionEvaluations') || isempty(cfg.MaxFunctionEvaluations), cfg.MaxFunctionEvaluations = 3e5; end
if ~isfield(cfg,'MaxIterations') || isempty(cfg.MaxIterations), cfg.MaxIterations = 300; end
if ~isfield(cfg,'ConstraintTolerance') || isempty(cfg.ConstraintTolerance), cfg.ConstraintTolerance = 1e-6; end
if ~isfield(cfg,'OptimalityTolerance') || isempty(cfg.OptimalityTolerance), cfg.OptimalityTolerance = 1e-6; end
if ~isfield(cfg,'StepTolerance') || isempty(cfg.StepTolerance), cfg.StepTolerance = 1e-8; end
if ~isfield(cfg,'plot_in_celsius') || isempty(cfg.plot_in_celsius), cfg.plot_in_celsius = true; end

% 电价
if ~isfield(cfg,'lambdaE_hour') || isempty(cfg.lambdaE_hour)
    cfg.lambdaE_hour = [0.21148 0.20273 0.18913 0.18232 ...
                        0.18330 0.20079 0.21536 0.22800 ...
                        0.23577 0.26492 0.30768 0.33003 ...
                        0.33781 0.35141 0.34752 0.35433 ...
                        0.35821 0.34461 0.31351 0.28339 ...
                        0.26687 0.25715 0.22800 0.20953]';
end

end

% =========================================================================
% 从 stage2 构建模型（基本沿用基线程序）
% =========================================================================
function [mdl, par, cfg] = local_build_model_from_stage2(cfg)

assert(exist(cfg.stage2ModelFile,'file')==2, '未找到模型文件：%s', cfg.stage2ModelFile);
assert(exist(cfg.stage2CqrFile,'file')==2, '未找到CQR文件：%s', cfg.stage2CqrFile);

Smdl = load(cfg.stage2ModelFile);
Scqr = load(cfg.stage2CqrFile);

mdl = struct();
mdl.A = double(local_get_required_field(Smdl,'A'));
mdl.B = double(local_get_required_field(Smdl,'B'));
mdl.C = double(local_get_required_field(Smdl,'C'));
mdl.D = double(local_get_required_field(Smdl,'D'));
mdl.u_mean = double(local_get_required_field(Smdl,'u_mean')); mdl.u_mean = mdl.u_mean(:);
mdl.t_mean = double(local_get_required_field(Smdl,'t_mean'));

if isfield(Smdl,'x0_hour')
    mdl.x0 = [-0.3065 -0.5];
else
    mdl.x0 = [];
end

mdl.useRemoveMean = true;
if isfield(Smdl,'useRemoveMean')
    mdl.useRemoveMean = logical(Smdl.useRemoveMean);
end

mdl.H15 = double(local_get_required_field(Scqr,'H'));
mdl.Nh  = double(local_get_required_field(Scqr,'Nh'));
mdl.ns  = double(local_get_required_field(Scqr,'ns'));
mdl.coverage_vec = double(local_get_required_field(Scqr,'coverage_vec')); mdl.coverage_vec = mdl.coverage_vec(:);

assert(mdl.H15 == mdl.Nh*mdl.ns, 'H != Nh*ns');

[mdl.Tpred15, mdl.Tlow15, mdl.Tup15, beta_use, ~] = local_get_cqr_15min_bands(Scqr, cfg.beta_target, mdl.H15, mdl.coverage_vec);
mdl.beta_use = beta_use;

if isfield(Smdl,'Tmin'), mdl.Tmin = double(Smdl.Tmin); else, mdl.Tmin = cfg.default_Tmin; end
if isfield(Smdl,'Tmax'), mdl.Tmax = double(Smdl.Tmax); else, mdl.Tmax = cfg.default_Tmax; end

if isfield(Scqr,'U_future_15min')
    U_future = double(Scqr.U_future_15min);
    assert(size(U_future,1)==mdl.H15 && size(U_future,2)>=5, 'U_future_15min 尺寸异常');
    mdl.Ts_ref15 = U_future(:,1);
    mdl.ma_ref15 = U_future(:,2);
    mdl.To15     = U_future(:,3);
    mdl.Isol15   = U_future(:,4);
    mdl.Qint15   = U_future(:,5);
else
    mdl.Ts_ref15 = double(local_get_required_field(Scqr,'Ts_future_15min')); mdl.Ts_ref15 = mdl.Ts_ref15(:);
    mdl.ma_ref15 = double(local_get_required_field(Scqr,'ma_future_15min')); mdl.ma_ref15 = mdl.ma_ref15(:);
    mdl.To15     = double(local_get_required_field(Scqr,'To_future_15min')); mdl.To15 = mdl.To15(:);
    mdl.Isol15   = double(local_get_required_field(Scqr,'Isol_future_15min')); mdl.Isol15 = mdl.Isol15(:);
    mdl.Qint15   = double(local_get_required_field(Scqr,'Qint_future_15min')); mdl.Qint15 = mdl.Qint15(:);
end

if isfield(Scqr,'Ts_future_hour')
    mdl.Ts_hour_ref = double(Scqr.Ts_future_hour(:));
else
    mdl.Ts_hour_ref = mean(reshape(mdl.Ts_ref15, mdl.ns, mdl.Nh), 1).';
end
if isfield(Scqr,'ma_future_hour')
    mdl.ma_hour_ref = double(Scqr.ma_future_hour(:));
else
    mdl.ma_hour_ref = mean(reshape(mdl.ma_ref15, mdl.ns, mdl.Nh), 1).';
end

mdl.lambdaE_hour = cfg.lambdaE_hour(:);
assert(numel(mdl.lambdaE_hour)==mdl.Nh, 'lambdaE_hour 长度异常');

mdl.dminus15 = mdl.Tpred15 - mdl.Tlow15;
mdl.dplus15  = mdl.Tup15   - mdl.Tpred15;
mdl.Tlow_rob_15 = mdl.Tmin + mdl.dminus15;
mdl.Tup_rob_15  = mdl.Tmax - mdl.dplus15;

if isempty(mdl.x0)
    u0 = [mdl.Ts_ref15(1); mdl.ma_ref15(1); mdl.To15(1); mdl.Isol15(1); mdl.Qint15(1)];
    mdl.x0 = pinv(mdl.C) * (mdl.Tpred15(1) - mdl.t_mean - mdl.D*(u0 - mdl.u_mean));
    mdl.x0 = mdl.x0(:);
end

par = struct();
par.epsilon = cfg.epsilon;
par.cp_a = cfg.cp_a;
par.Qmax = cfg.Qmax;
par.COP_lb = cfg.COP_lb;
par.cop_dT_mode = cfg.cop_dT_mode;

par.Ts_min = 273.15 + cfg.Ts_min_C;
par.Ts_max = 273.15 + cfg.Ts_max_C;
par.ma_min = cfg.ma_min;
par.ma_max = cfg.ma_max;

par.dTs_max = cfg.dTs_max;
par.dma_max = cfg.dma_max;

par.fan_a = cfg.fan_a;
par.fan_b = cfg.fan_b;
par.fan_c = cfg.fan_c;
par.fan_d = cfg.fan_d;
par.fan_multiplier = cfg.fan_multiplier;

par.rho_slack = cfg.rho_slack;
par.slack_tol = cfg.slack_tol;
par.rho_temp = cfg.rho_temp;
par.temp_penalty_mode = cfg.temp_penalty_mode;
par.Tref_fixed_K = cfg.Tref_fixed_C + 273.15;
par.rho_dev_Ts = cfg.rho_dev_Ts;
par.rho_dev_ma = cfg.rho_dev_ma;

[pmin_kw, pmax_kw, ~, ~] = local_cubic_range_on_interval( ...
    par.fan_a, par.fan_b, par.fan_c, par.fan_d, ...
    par.ma_min, par.ma_max, par.fan_multiplier);
par.Pfan_min = pmin_kw;
par.Pfan_max = pmax_kw;

end

% =========================================================================
% 构造单小时扫描网格
% =========================================================================
function r_grid = local_build_hour_grid(cfg, par, h, Rnat, RupperGlobal)

switch lower(cfg.reserve_ub_mode)
    case 'user_specified'
        assert(~isempty(cfg.reserve_ub_kw), 'reserve_ub_mode=user_specified 时必须给 reserve_ub_kw');
        r_ub = cfg.reserve_ub_kw;
    otherwise
        r_ub = RupperGlobal;
end

r_lb = max(Rnat, 0);

if r_ub < r_lb
    r_grid = r_lb;
    return;
end

r_grid = linspace(r_lb, r_ub, cfg.nScan).';
r_grid = unique([r_lb; r_grid(:)]);
r_grid = sort(r_grid(:));

end

% =========================================================================
% 求解一个问题
% =========================================================================
function res = local_solve_one_problem(mdl, par, init, cfg, solver_mode)

[z0, lb, ub] = local_build_bounds_and_init(mdl, par, init, solver_mode);
[Aineq, bineq] = local_build_ramp_constraints(mdl.Nh, mdl.H15, par);

solver_debug = struct();
solver_debug.z0 = z0;
solver_debug.lb = lb;
solver_debug.ub = ub;

if cfg.showIterSummary
    outfun = @(x,optimValues,state)local_outfun_summary(x,optimValues,state,mdl,par,cfg,solver_mode);
else
    outfun = [];
end

opts = optimoptions('fmincon', ...
    'Display', 'off', ...
    'Algorithm', 'sqp', ...
    'MaxFunctionEvaluations', cfg.MaxFunctionEvaluations, ...
    'MaxIterations', cfg.MaxIterations, ...
    'ConstraintTolerance', cfg.ConstraintTolerance, ...
    'OptimalityTolerance', cfg.OptimalityTolerance, ...
    'StepTolerance', cfg.StepTolerance, ...
    'OutputFcn', outfun);

problem = struct();
problem.objective = @(z)local_objective(z, mdl, par, solver_mode);
problem.nonlcon   = @(z)local_nonlcon(z, mdl, par);
problem.x0        = z0;
problem.lb        = lb;
problem.ub        = ub;
problem.Aineq     = Aineq;
problem.bineq     = bineq;
problem.solver    = 'fmincon';
problem.options   = opts;

[zopt, fval, exitflag, output] = fmincon(problem);

sol = local_unpack_and_simulate(zopt, mdl, par, solver_mode);
sol.obj_value = fval;
sol.exitflag = exitflag;
sol.output = output;
sol.solver_debug = solver_debug;
sol.max_slack = max([sol.sL; sol.sU]);
sol.sum_slack = sum(sol.sL) + sum(sol.sU);
sol.Pfan_hour = mean(reshape(sol.Pfan, mdl.ns, mdl.Nh), 1).';
sol.Php_hour  = mean(reshape(sol.Php,  mdl.ns, mdl.Nh), 1).';
sol.Pbase_hour = mean(reshape(sol.Ptot, mdl.ns, mdl.Nh), 1).';

res = sol;

end

% =========================================================================
% 初值和上下界
% =========================================================================
function [z0, lb, ub] = local_build_bounds_and_init(mdl, par, init, solver_mode)
Nh = mdl.Nh;
Nk = mdl.H15;

Ts0 = min(max(init.Ts_hour(:), par.Ts_min), par.Ts_max);
ma0 = min(max(init.ma_hour(:), par.ma_min), par.ma_max);
sL0 = max(init.sL(:), 0);
sU0 = max(init.sU(:), 0);
if numel(sL0) ~= Nk, sL0 = zeros(Nk,1); end
if numel(sU0) ~= Nk, sU0 = zeros(Nk,1); end

lb_Ts = par.Ts_min * ones(Nh,1);
ub_Ts = par.Ts_max * ones(Nh,1);
lb_ma = par.ma_min * ones(Nh,1);
ub_ma = par.ma_max * ones(Nh,1);

if solver_mode.has_target_hour
    h = solver_mode.targetHour;
    lb_ma(h) = max(lb_ma(h), solver_mode.maL);
    ub_ma(h) = min(ub_ma(h), solver_mode.maU);
end

z0 = [Ts0; ma0; sL0; sU0];
lb = [lb_Ts; lb_ma; zeros(Nk,1); zeros(Nk,1)];
ub = [ub_Ts; ub_ma; inf(Nk,1); inf(Nk,1)];
end

% =========================================================================
% 迭代摘要
% =========================================================================
function stop = local_outfun_summary(x, optimValues, state, mdl, par, cfg, solver_mode)
stop = false;
if strcmp(state,'iter')
    if optimValues.iteration == 1 || mod(optimValues.iteration, cfg.summaryIterGap) == 0
        sol = local_unpack_and_simulate(x, mdl, par, solver_mode);
        fprintf('[iter] %d, f=%.6f, E=%.6f, T=%.6f, Dev=%.6f, Slack=%.6f\n', ...
            optimValues.iteration, optimValues.fval, sol.cost_energy, sol.temp_penalty, ...
            sol.dev_penalty, sol.slack_penalty);
    end
end
end

% =========================================================================
% 目标函数
% =========================================================================
function f = local_objective(z, mdl, par, solver_mode)
sol = local_unpack_and_simulate(z, mdl, par, solver_mode);
f = sol.cost_energy + sol.temp_penalty + sol.dev_penalty + sol.slack_penalty;
end

% =========================================================================
% 温度约束
% =========================================================================
function [c, ceq] = local_nonlcon(z, mdl, par)
sol = local_unpack_and_simulate(z, mdl, par, struct('has_target_hour',false));
c1 = sol.T15 - (mdl.Tup_rob_15 + sol.sU);
c2 = (mdl.Tlow_rob_15 - sol.sL) - sol.T15;
c = [c1(:); c2(:)];
ceq = [];
end

% =========================================================================
% 展开变量并完成仿真
% =========================================================================
function sol = local_unpack_and_simulate(z, mdl, par, solver_mode)

Nh = mdl.Nh;
Nk = mdl.H15;
ns = mdl.ns;
nx = size(mdl.A,1);

id1 = 1:Nh;
id2 = Nh + (1:Nh);
id3 = 2*Nh + (1:Nk);
id4 = 2*Nh + Nk + (1:Nk);

Ts_hour = z(id1);
ma_hour = z(id2);
sL = z(id3);
sU = z(id4);

Ts_15min = repelem(Ts_hour, ns);
ma_15min = repelem(ma_hour, ns);

x = zeros(nx, Nk+1);
T15 = zeros(Nk,1);
COP = zeros(Nk,1);
Q = zeros(Nk,1);
Pfan = zeros(Nk,1);
Php = zeros(Nk,1);
Ptot = zeros(Nk,1);

x(:,1) = mdl.x0(:);

for k = 1:Nk
    u = [Ts_15min(k); ma_15min(k); mdl.To15(k); mdl.Isol15(k); mdl.Qint15(k)];
    if mdl.useRemoveMean
        uz = u - mdl.u_mean(:);
    else
        uz = u;
    end

    yk = mdl.C * x(:,k) + mdl.D * uz;
    T15(k) = yk + mdl.t_mean;

    [Q(k), COP(k), Php(k), Pfan(k), Ptot(k)] = local_compute_power(Ts_15min(k), ma_15min(k), T15(k), mdl.To15(k), par);

    x(:,k+1) = mdl.A * x(:,k) + mdl.B * uz;
end

Pbase_hour = mean(reshape(Ptot, ns, Nh), 1).';
cost_energy = sum(mdl.lambdaE_hour(:) .* Pbase_hour(:));
slack_penalty = par.rho_slack * (sum(sL) + sum(sU));

switch lower(par.temp_penalty_mode)
    case 'fixed_ref'
        Tref_15 = par.Tref_fixed_K * ones(Nk,1);
    otherwise
        Tref_15 = 0.5 * (mdl.Tlow_rob_15 + mdl.Tup_rob_15);
end
temp_penalty = par.rho_temp * sum((T15 - Tref_15).^2);

dev_penalty = 0;
if isfield(solver_mode,'has_target_hour') && solver_mode.has_target_hour ...
        && isfield(solver_mode,'baseline_ref') && ~isempty(solver_mode.baseline_ref)
    baseRef = solver_mode.baseline_ref;
    dev_penalty = dev_penalty + par.rho_dev_Ts * sum((Ts_hour(:) - baseRef.Ts_hour(:)).^2);
    dev_penalty = dev_penalty + par.rho_dev_ma * sum((ma_hour(:) - baseRef.ma_hour(:)).^2);
end

sol = struct();
sol.Ts_hour = Ts_hour;
sol.ma_hour = ma_hour;
sol.Ts_15min = Ts_15min;
sol.ma_15min = ma_15min;
sol.sL = sL;
sol.sU = sU;
sol.x = x;
sol.T15 = T15;
sol.COP = COP;
sol.Q = Q;
sol.Pfan = Pfan;
sol.Php = Php;
sol.Ptot = Ptot;
sol.Pbase_hour = Pbase_hour;
sol.cost_energy = cost_energy;
sol.temp_penalty = temp_penalty;
sol.dev_penalty = dev_penalty;
sol.slack_penalty = slack_penalty;
sol.Tref_15 = Tref_15;
end

% =========================================================================
% 功率模型
% =========================================================================
function [Qk, COPk, Php_k, Pfan_k, Ptot_k] = local_compute_power(TsK, ma, TrK, ToK, par)

TsC = TsK - 273.15;
TrC = TrK - 273.15;
ToC = ToK - 273.15;

deltaT_heat = max(TsC - TrC, 0);
Qk = par.epsilon * par.cp_a * ma * deltaT_heat;
Qk = min(max(Qk, 0), par.Qmax);

switch lower(par.cop_dT_mode)
    case 'ts_minus_tr'
        dT = max(TsC - TrC, 0);
    otherwise
        dT = max(TsC - ToC, 0);
end
COP_raw = 5.148 - 0.075 * dT;
COPk = max(par.COP_lb, COP_raw);

Php_k = Qk / COPk;

Pfan_single_W = par.fan_a*ma^3 + par.fan_b*ma^2 + par.fan_c*ma + par.fan_d;
Pfan_single_kW = Pfan_single_W / 1000;
Pfan_k = par.fan_multiplier * Pfan_single_kW;

Ptot_k = Php_k + Pfan_k;
end

% =========================================================================
% 相邻小时变化约束
% =========================================================================
function [Aineq, bineq] = local_build_ramp_constraints(Nh, Nk, par)

nVar = 2*Nh + 2*Nk;
Aineq = [];
bineq = [];

for h = 2:Nh
    row = zeros(1,nVar); row(h)=1; row(h-1)=-1;
    Aineq = [Aineq; row]; bineq = [bineq; par.dTs_max];

    row = zeros(1,nVar); row(h)=-1; row(h-1)=1;
    Aineq = [Aineq; row]; bineq = [bineq; par.dTs_max];
end

off = Nh;
for h = 2:Nh
    row = zeros(1,nVar); row(off+h)=1; row(off+h-1)=-1;
    Aineq = [Aineq; row]; bineq = [bineq; par.dma_max];

    row = zeros(1,nVar); row(off+h)=-1; row(off+h-1)=1;
    Aineq = [Aineq; row]; bineq = [bineq; par.dma_max];
end

end

% =========================================================================
% 由固定对称备用 R 反解目标小时风量区间
% =========================================================================
function [maL, maU, ok] = local_get_ma_interval_for_reserve(R, par)

P_low  = par.Pfan_min + R;
P_high = par.Pfan_max - R;

if P_low > P_high
    maL = NaN; maU = NaN; ok = false;
    return;
end

[maL, ok1] = local_inverse_fan_power_kw(P_low,  par, 'smallest');
[maU, ok2] = local_inverse_fan_power_kw(P_high, par, 'largest');

ok = ok1 && ok2 && (maL <= maU + 1e-10);
if ~ok
    maL = NaN; maU = NaN;
end

end

function [ma, ok] = local_inverse_fan_power_kw(Pkw, par, modePick)
targetW = Pkw * 1000 / par.fan_multiplier;
coef = [par.fan_a, par.fan_b, par.fan_c, par.fan_d - targetW];
rt = roots(coef);
rt = real(rt(abs(imag(rt)) < 1e-8));
rt = rt(rt >= par.ma_min - 1e-8 & rt <= par.ma_max + 1e-8);
rt = sort(rt(:));
if isempty(rt)
    ma = NaN; ok = false; return;
end
switch lower(modePick)
    case 'largest'
        ma = rt(end);
    otherwise
        ma = rt(1);
end
ma = min(max(ma, par.ma_min), par.ma_max);
ok = true;
end

% =========================================================================
% CQR 边界读取
% =========================================================================
function [Tpred15, Tlow15, Tup15, beta_use, ib] = local_get_cqr_15min_bands(Scqr, beta_target, Nk, coverage_vec)
[~, ib] = min(abs(coverage_vec - beta_target));
beta_use = coverage_vec(ib);
Tpred15 = local_pick_prediction_vector(Scqr, Nk);
Tlow15  = local_pick_bound_vector(Scqr, {'T_low_15min','Tlow_15min'}, ib, Nk, 'lower');
Tup15   = local_pick_bound_vector(Scqr, {'T_up_15min','Tup_15min'}, ib, Nk, 'upper');
end

function Tpred15 = local_pick_prediction_vector(Scqr, Nk)
Tpred15 = [];
cand = {'T_pred_15min','Tpred_15min'};
for i = 1:numel(cand)
    if isfield(Scqr, cand{i})
        x = double(Scqr.(cand{i})); x = x(:);
        if numel(x) == Nk
            Tpred15 = x; return;
        end
    end
end
if isfield(Scqr,'example_yhat_med')
    x = double(Scqr.example_yhat_med); x = x(:);
    if numel(x) == Nk
        Tpred15 = x; return;
    end
end
error('未找到 15min 预测中值向量。');
end

function bnd = local_pick_bound_vector(Scqr, field_list, ib, Nk, which_side)
bnd = [];
for i = 1:numel(field_list)
    if isfield(Scqr, field_list{i})
        x = double(Scqr.(field_list{i}));
        if isvector(x)
            x = x(:);
            if numel(x) == Nk
                bnd = x; return;
            end
        else
            if size(x,1) == Nk && ib <= size(x,2)
                bnd = x(:,ib); return;
            elseif size(x,2) == Nk && ib <= size(x,1)
                bnd = x(ib,:).'; return;
            end
        end
    end
end

if strcmpi(which_side,'lower') && isfield(Scqr,'example_L')
    x = double(Scqr.example_L);
elseif strcmpi(which_side,'upper') && isfield(Scqr,'example_U')
    x = double(Scqr.example_U);
else
    error('未找到 %s bound 对应字段。', which_side);
end

if size(x,1) == Nk && ib <= size(x,2)
    bnd = x(:,ib);
elseif size(x,2) == Nk && ib <= size(x,1)
    bnd = x(ib,:).';
else
    error('%s bound 维度与 Nk 不匹配。', which_side);
end
end

% =========================================================================
% 边际成本
% =========================================================================
function mc = local_compute_marginal_cost(r, dc, feas)
mc = nan(size(r));
idx = find(feas);
if numel(idx) < 2
    return;
end
for j = 2:numel(idx)
    i1 = idx(j-1);
    i2 = idx(j);
    dr = r(i2) - r(i1);
    if dr > 0
        mc(i2) = (dc(i2) - dc(i1)) / dr;
    end
end
mc(idx(1)) = mc(idx(2));
end

% =========================================================================
% 三次函数在区间上的理论最小/最大值
% =========================================================================
function [pmin_kw, pmax_kw, x_at_min, x_at_max] = local_cubic_range_on_interval(a,b,c,d,xl,xu,multiplier)

cand = [xl; xu];
rt = roots([3*a, 2*b, c]);
rt = real(rt(abs(imag(rt))<1e-10));
rt = rt(rt>=xl & rt<=xu);
cand = [cand; rt(:)];

valsW = a*cand.^3 + b*cand.^2 + c*cand + d;
valsKW = multiplier * valsW / 1000;

[pmin_kw, idx1] = min(valsKW);
[pmax_kw, idx2] = max(valsKW);

x_at_min = cand(idx1);
x_at_max = cand(idx2);
end

% =========================================================================
% 结构体字段读取
% =========================================================================
function v = local_get_required_field(S, fn)
assert(isfield(S, fn), '缺少字段：%s', fn);
v = S.(fn);
end
