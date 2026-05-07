function out = run_ch3_baseline_fixedTs_suite_V4(cfg)
% =========================================================================
% 第三章：固定 Ts 基线统一入口（V4）
% -------------------------------------------------------------------------
% 功能：
%   1) 只做固定常数 Ts 下的基线求解，不做备用扫描；
%   2) 支持固定 Ts 的单次 / 多次仿真；
%   3) 不再重复求解水风协同基线；
%   4) 水风协同基线默认由 run_ch3_hourly_reserve_costcurve_main_V2.m 提供；
%   5) 绘图时再由单独绘图程序读取协同基线与本程序结果进行对比。
%
% 说明：
%   - 协同基线不再由本程序内部求解；
%   - 本程序内部的建模、目标函数、风险收缩舒适带与功率模型，
%     仍直接参考 run_ch3_hourly_reserve_costcurve_main_V2 /
%     run_ch3_hourly_reserve_costcurve_main_fixTsConst_V2 的基线部分；
%   - 输出结构专门服务于"固定 Ts vs 水风协同"基线对比。
%
% 常用调用：
%   cfg = struct();
%   cfg.mode = 'single';
%   cfg.Ts_fixed_C = 42;
%   out = run_ch3_baseline_fixedTs_suite_V4(cfg);
%
%   cfg = struct();
%   cfg.mode = 'multi';
%   cfg.Ts_fixed_list_C = [35 42 45];
%   out = run_ch3_baseline_fixedTs_suite_V4(cfg);
% =========================================================================

if nargin < 1
    cfg = struct();
end
cfg = local_fill_defaults(cfg);

if ~exist(cfg.outdir, 'dir')
    mkdir(cfg.outdir);
end

fprintf('\n============================================================\n');
fprintf('固定 Ts 基线统一求解入口 V4\n');
fprintf('mode                      = %s\n', cfg.mode);
fprintf('beta_target               = %.4f\n', cfg.beta_target);
if strcmpi(cfg.mode,'single')
    fprintf('Ts_fixed_C                = %.2f ℃\n', cfg.Ts_fixed_C);
else
    fprintf('Ts_fixed_list_C           = ');
    fprintf('%.2f ', cfg.Ts_fixed_list_C);
    fprintf('℃\n');
end
fprintf('仅求固定 Ts 基线；协同基线请由 run_ch3_hourly_reserve_costcurve_main_V2 提供。\n');
fprintf('============================================================\n');


[mdl, par, cfg] = local_build_model_from_stage2(cfg);

out = struct();
out.case_label = 'baseline_fixedTs_suite_v4';
out.cfg = cfg;
out.mode = lower(cfg.mode);
out.beta_target = cfg.beta_target;
out.beta_use = mdl.beta_use;
out.fixed_cases = struct([]);
out.Ts_fixed_list_C = [];
out.saved_mat = '';

%% 1) 固定 Ts 单次 / 多次
Ts_list_C = local_resolve_Ts_list(cfg);
nCase = numel(Ts_list_C);
out.fixed_cases = struct([]);
out.Ts_fixed_list_C = Ts_list_C(:);

for i = 1:nCase
    TsC = Ts_list_C(i);
    fprintf('\n[%d/%d] 求解固定 Ts 基线：Ts = %.2f ℃（只做 baseline）...\n', i, nCase, TsC);

    Ts_fixed_hour = local_resolve_fixed_Ts(cfg, mdl, TsC);

    init = struct();
    init.Ts_hour = Ts_fixed_hour(:);
    init.ma_hour = min(max(mdl.ma_hour_ref, par.ma_min), par.ma_max);
    init.sL = zeros(mdl.H15,1);
    init.sU = zeros(mdl.H15,1);

    solver_mode = struct();
    solver_mode.fix_Ts = true;
    solver_mode.fixed_Ts_hour = Ts_fixed_hour(:);
    solver_mode.has_target_hour = false;
    solver_mode.targetHour = [];
    solver_mode.maL = [];
    solver_mode.maU = [];
    solver_mode.baseline_ref = [];

    sol = local_solve_one_problem(mdl, par, init, cfg, solver_mode);
    sol.label = sprintf('baseline_fixTs_%gC', TsC);

    case_i = local_pack_case(sol, mdl, par, cfg, sprintf('固定Ts=%.1f℃', TsC), TsC);
    if i == 1
        out.fixed_cases = case_i;
    else
        out.fixed_cases(i,1) = case_i;
    end
end

%% 3) 保存
if cfg.save_mat
    outfile = fullfile(cfg.outdir, local_build_outfile_name(cfg, Ts_list_C));
    save(outfile, 'out', '-v7.3');
    out.saved_mat = outfile;
    fprintf('\n结果已保存到: %s\n', outfile);
end

%% 4) 可选提示
if cfg.makePlots
    fprintf('提示：请使用 plot_ch3_baseline_fixedTs_suite_V4.m 并同时传入协同基线结果与本程序输出进行对比绘图。\n');
end

end

% =========================================================================
% 默认参数
% =========================================================================
function cfg = local_fill_defaults(cfg)

% 运行模式
if ~isfield(cfg,'mode') || isempty(cfg.mode), cfg.mode = 'multi'; end
if ~isfield(cfg,'Ts_fixed_C') || isempty(cfg.Ts_fixed_C), cfg.Ts_fixed_C = 42; end
if ~isfield(cfg,'Ts_fixed_list_C') || isempty(cfg.Ts_fixed_list_C), cfg.Ts_fixed_list_C = [42 45]; end

if ~isfield(cfg,'save_mat') || isempty(cfg.save_mat), cfg.save_mat = true; end
if ~isfield(cfg,'makePlots') || isempty(cfg.makePlots), cfg.makePlots = false; end
if ~isfield(cfg,'outdir') || isempty(cfg.outdir), cfg.outdir = project_data_file('baseline'); end
if ~isfield(cfg,'plot_in_celsius') || isempty(cfg.plot_in_celsius), cfg.plot_in_celsius = true; end

% 文件
if ~isfield(cfg,'stage2ModelFile') || isempty(cfg.stage2ModelFile)
    cfg.stage2ModelFile = project_data_file('stage1','stage1_hour_model_for_stage2.mat');
end
if ~isfield(cfg,'stage2CqrFile') || isempty(cfg.stage2CqrFile)
    cfg.stage2CqrFile = project_data_file('stage1','stage1_cqr_for_stage2.mat');
end

% 风险
if ~isfield(cfg,'beta_target') || isempty(cfg.beta_target), cfg.beta_target = 0.95; end

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

% 优化器
if ~isfield(cfg,'showIterSummary') || isempty(cfg.showIterSummary), cfg.showIterSummary = false; end
if ~isfield(cfg,'summaryIterGap') || isempty(cfg.summaryIterGap), cfg.summaryIterGap = 20; end
if ~isfield(cfg,'MaxFunctionEvaluations') || isempty(cfg.MaxFunctionEvaluations), cfg.MaxFunctionEvaluations = 3e5; end
if ~isfield(cfg,'MaxIterations') || isempty(cfg.MaxIterations), cfg.MaxIterations = 300; end
if ~isfield(cfg,'ConstraintTolerance') || isempty(cfg.ConstraintTolerance), cfg.ConstraintTolerance = 1e-6; end
if ~isfield(cfg,'OptimalityTolerance') || isempty(cfg.OptimalityTolerance), cfg.OptimalityTolerance = 1e-6; end
if ~isfield(cfg,'StepTolerance') || isempty(cfg.StepTolerance), cfg.StepTolerance = 1e-8; end

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
% Ts 列表
% =========================================================================
function Ts_list_C = local_resolve_Ts_list(cfg)
switch lower(cfg.mode)
    case 'single'
        Ts_list_C = cfg.Ts_fixed_C;
    case 'multi'
        Ts_list_C = cfg.Ts_fixed_list_C(:).';
    otherwise
        error('cfg.mode 只能取 ''single'' 或 ''multi''。');
end
Ts_list_C = unique(Ts_list_C, 'stable');
assert(~isempty(Ts_list_C), '固定 Ts 列表为空。');
end

% =========================================================================
% 固定 Ts 小时轨迹（常数）
% =========================================================================
function Ts_fixed_hour = local_resolve_fixed_Ts(cfg, mdl, TsC)
Nh = mdl.Nh;
Ts_fixed_hour = (273.15 + TsC) * ones(Nh,1);
Ts_fixed_hour = min(max(Ts_fixed_hour, 273.15 + cfg.Ts_min_C), 273.15 + cfg.Ts_max_C);
end

% =========================================================================
% 结果打包
% =========================================================================
function case_out = local_pack_case(sol, mdl, par, cfg, label, Ts_fixed_C)

case_out = struct();
case_out.cfg = cfg;
case_out.mdl = mdl;
case_out.par = par;

case_out.beta_target = cfg.beta_target;
case_out.beta_use = mdl.beta_use;

case_out.case_label = label;
case_out.Ts_fixed_C = Ts_fixed_C;

case_out.Ts_hour = sol.Ts_hour(:);
case_out.ma_hour = sol.ma_hour(:);
case_out.Ts_15min = sol.Ts_15min(:);
case_out.ma_15min = sol.ma_15min(:);

case_out.x = sol.x;
case_out.T15 = sol.T15(:);
case_out.To15 = mdl.To15(:);

case_out.Tpred15 = mdl.Tpred15(:);
case_out.Tlow15 = mdl.Tlow15(:);
case_out.Tup15 = mdl.Tup15(:);
case_out.Tlow_rob_15 = mdl.Tlow_rob_15(:);
case_out.Tup_rob_15 = mdl.Tup_rob_15(:);

case_out.COP = sol.COP(:);
case_out.Q = sol.Q(:);
case_out.Pfan = sol.Pfan(:);
case_out.Php = sol.Php(:);
case_out.Ptot = sol.Ptot(:);

case_out.Pbase_hour = sol.Pbase_hour(:);
case_out.Pfan_hour = sol.Pfan_hour(:);
case_out.Php_hour = sol.Php_hour(:);
case_out.To_hour = mean(reshape(case_out.To15, mdl.ns, mdl.Nh), 1).';

case_out.sL = sol.sL(:);
case_out.sU = sol.sU(:);
case_out.max_slack = sol.max_slack;
case_out.sum_slack = sol.sum_slack;

case_out.obj_value = sol.obj_value;
case_out.cost_energy = sol.cost_energy;
case_out.temp_penalty = sol.temp_penalty;
case_out.dev_penalty = sol.dev_penalty;
case_out.slack_penalty = sol.slack_penalty;
case_out.exitflag = sol.exitflag;
case_out.output = sol.output;
case_out.solver_debug = sol.solver_debug;
end

% =========================================================================
% 从 stage2 构建模型（直接沿用 reserve 主程序的基线构造逻辑）
% =========================================================================
function [mdl, par, cfg] = local_build_model_from_stage2(cfg)

assert(exist(cfg.stage2ModelFile,'file')==2, '未找到模型文件：%s', cfg.stage2ModelFile);
assert(exist(cfg.stage2CqrFile,'file')==2, '未找到 CQR 文件：%s', cfg.stage2CqrFile);

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
mdl.Nh = double(local_get_required_field(Scqr,'Nh'));
mdl.ns = double(local_get_required_field(Scqr,'ns'));
mdl.coverage_vec = double(local_get_required_field(Scqr,'coverage_vec')); mdl.coverage_vec = mdl.coverage_vec(:);

assert(mdl.H15 == mdl.Nh * mdl.ns, 'H != Nh*ns');

[mdl.Tpred15, mdl.Tlow15, mdl.Tup15, beta_use, ~] = local_get_cqr_15min_bands(Scqr, cfg.beta_target, mdl.H15, mdl.coverage_vec);
mdl.beta_use = beta_use;

if isfield(Smdl,'Tmin'), mdl.Tmin = double(Smdl.Tmin); else, mdl.Tmin = cfg.default_Tmin; end
if isfield(Smdl,'Tmax'), mdl.Tmax = double(Smdl.Tmax); else, mdl.Tmax = cfg.default_Tmax; end

if isfield(Scqr,'U_future_15min')
    U_future = double(Scqr.U_future_15min);
    assert(size(U_future,1)==mdl.H15 && size(U_future,2)>=5, 'U_future_15min 尺寸异常');
    mdl.Ts_ref15 = U_future(:,1);
    mdl.ma_ref15 = U_future(:,2);
    mdl.To15 = U_future(:,3);
    mdl.Isol15 = U_future(:,4);
    mdl.Qint15 = U_future(:,5);
else
    mdl.Ts_ref15 = double(local_get_required_field(Scqr,'Ts_future_15min')); mdl.Ts_ref15 = mdl.Ts_ref15(:);
    mdl.ma_ref15 = double(local_get_required_field(Scqr,'ma_future_15min')); mdl.ma_ref15 = mdl.ma_ref15(:);
    mdl.To15 = double(local_get_required_field(Scqr,'To_future_15min')); mdl.To15 = mdl.To15(:);
    mdl.Isol15 = double(local_get_required_field(Scqr,'Isol_future_15min')); mdl.Isol15 = mdl.Isol15(:);
    mdl.Qint15 = double(local_get_required_field(Scqr,'Qint_future_15min')); mdl.Qint15 = mdl.Qint15(:);
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
mdl.dplus15  = mdl.Tup15 - mdl.Tpred15;
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

[pmin_kw, pmax_kw] = local_cubic_range_on_interval( ...
    par.fan_a, par.fan_b, par.fan_c, par.fan_d, ...
    par.ma_min, par.ma_max, par.fan_multiplier);
par.Pfan_min = pmin_kw;
par.Pfan_max = pmax_kw;

end

% =========================================================================
% 求解一个问题
% =========================================================================
function res = local_solve_one_problem(mdl, par, init, cfg, solver_mode)

[z0, lb, ub, nTs, nMa] = local_build_bounds_and_init(mdl, par, init, solver_mode);
[Aineq, bineq] = local_build_ramp_constraints(nTs, nMa, mdl.Nh, mdl.H15, par);

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
problem.nonlcon = @(z)local_nonlcon(z, mdl, par, solver_mode);
problem.x0 = z0;
problem.lb = lb;
problem.ub = ub;
problem.Aineq = Aineq;
problem.bineq = bineq;
problem.solver = 'fmincon';
problem.options = opts;

[zopt, fval, exitflag, output] = fmincon(problem);

sol = local_unpack_and_simulate(zopt, mdl, par, solver_mode);
sol.obj_value = fval;
sol.exitflag = exitflag;
sol.output = output;
sol.solver_debug = solver_debug;
sol.max_slack = max([sol.sL; sol.sU]);
sol.sum_slack = sum(sol.sL) + sum(sol.sU);
sol.Pfan_hour = mean(reshape(sol.Pfan, mdl.ns, mdl.Nh), 1).';
sol.Php_hour  = mean(reshape(sol.Php, mdl.ns, mdl.Nh), 1).';
sol.Pbase_hour = mean(reshape(sol.Ptot, mdl.ns, mdl.Nh), 1).';

res = sol;
end

% =========================================================================
% 初值和上下界
% =========================================================================
function [z0, lb, ub, nTs, nMa] = local_build_bounds_and_init(mdl, par, init, solver_mode)
Nh = mdl.Nh;
Nk = mdl.H15;

if isfield(solver_mode,'fix_Ts') && solver_mode.fix_Ts
    nTs = 0;
    nMa = Nh;

    ma0 = min(max(init.ma_hour(:), par.ma_min), par.ma_max);
    sL0 = max(init.sL(:), 0); if numel(sL0) ~= Nk, sL0 = zeros(Nk,1); end
    sU0 = max(init.sU(:), 0); if numel(sU0) ~= Nk, sU0 = zeros(Nk,1); end

    lb_ma = par.ma_min * ones(Nh,1);
    ub_ma = par.ma_max * ones(Nh,1);

    z0 = [ma0; sL0; sU0];
    lb = [lb_ma; zeros(Nk,1); zeros(Nk,1)];
    ub = [ub_ma; inf(Nk,1); inf(Nk,1)];
else
    nTs = Nh;
    nMa = Nh;

    Ts0 = min(max(init.Ts_hour(:), par.Ts_min), par.Ts_max);
    ma0 = min(max(init.ma_hour(:), par.ma_min), par.ma_max);
    sL0 = max(init.sL(:), 0); if numel(sL0) ~= Nk, sL0 = zeros(Nk,1); end
    sU0 = max(init.sU(:), 0); if numel(sU0) ~= Nk, sU0 = zeros(Nk,1); end

    lb_Ts = par.Ts_min * ones(Nh,1);
    ub_Ts = par.Ts_max * ones(Nh,1);
    lb_ma = par.ma_min * ones(Nh,1);
    ub_ma = par.ma_max * ones(Nh,1);

    z0 = [Ts0; ma0; sL0; sU0];
    lb = [lb_Ts; lb_ma; zeros(Nk,1); zeros(Nk,1)];
    ub = [ub_Ts; ub_ma; inf(Nk,1); inf(Nk,1)];
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
% 非线性约束（风险收缩舒适带）
% =========================================================================
function [c, ceq] = local_nonlcon(z, mdl, par, solver_mode)
sol = local_unpack_and_simulate(z, mdl, par, solver_mode);
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

if isfield(solver_mode,'fix_Ts') && solver_mode.fix_Ts
    id1 = 1:Nh;
    id2 = Nh + (1:Nk);
    id3 = Nh + Nk + (1:Nk);

    Ts_hour = solver_mode.fixed_Ts_hour(:);
    ma_hour = z(id1);
    sL = z(id2);
    sU = z(id3);
else
    id1 = 1:Nh;
    id2 = Nh + (1:Nh);
    id3 = 2*Nh + (1:Nk);
    id4 = 2*Nh + Nk + (1:Nk);

    Ts_hour = z(id1);
    ma_hour = z(id2);
    sL = z(id3);
    sU = z(id4);
end

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
    if ~(isfield(solver_mode,'fix_Ts') && solver_mode.fix_Ts)
        dev_penalty = dev_penalty + par.rho_dev_Ts * sum((Ts_hour(:) - baseRef.Ts_hour(:)).^2);
    end
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
function [Aineq, bineq] = local_build_ramp_constraints(nTs, nMa, Nh, Nk, par)

nVar = nTs + nMa + 2*Nk;
Aineq = [];
bineq = [];

% Ts ramp（仅协同场景）
for h = 2:Nh
    if nTs > 0
        row = zeros(1,nVar); row(h)=1; row(h-1)=-1;
        Aineq = [Aineq; row]; bineq = [bineq; par.dTs_max]; %#ok<AGROW>
        row = zeros(1,nVar); row(h)=-1; row(h-1)=1;
        Aineq = [Aineq; row]; bineq = [bineq; par.dTs_max]; %#ok<AGROW>
    end
end

% ma ramp
off = nTs;
for h = 2:Nh
    row = zeros(1,nVar); row(off+h)=1; row(off+h-1)=-1;
    Aineq = [Aineq; row]; bineq = [bineq; par.dma_max]; %#ok<AGROW>
    row = zeros(1,nVar); row(off+h)=-1; row(off+h-1)=1;
    Aineq = [Aineq; row]; bineq = [bineq; par.dma_max]; %#ok<AGROW>
end

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
    if numel(x)==Nk
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
            if numel(x)==Nk
                bnd = x; return;
            end
        else
            if size(x,1)==Nk && ib<=size(x,2)
                bnd = x(:,ib); return;
            elseif size(x,2)==Nk && ib<=size(x,1)
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

if size(x,1)==Nk && ib<=size(x,2)
    bnd = x(:,ib);
elseif size(x,2)==Nk && ib<=size(x,1)
    bnd = x(ib,:).';
else
    error('%s bound 维度与 Nk 不匹配。', which_side);
end
end

% =========================================================================
% 工具函数
% =========================================================================
function v = local_get_required_field(S, name)
if ~isfield(S, name)
    error('缺少字段：%s', name);
end
v = S.(name);
end

function [pmin_kw, pmax_kw] = local_cubic_range_on_interval(a,b,c,d,xL,xU,mult)
xx = [xL; xU];
rt = roots([3*a, 2*b, c]);
rt = real(rt(abs(imag(rt))<1e-10));
rt = rt(rt>=xL & rt<=xU);
xx = [xx; rt(:)];
yy = mult*(a*xx.^3 + b*xx.^2 + c*xx + d)/1000;
pmin_kw = min(yy);
pmax_kw = max(yy);
end

function name = local_build_outfile_name(cfg, Ts_list_C)
if strcmpi(cfg.mode,'single')
    name = sprintf('baseline_fixedTs_single_%gC_beta_%02d_v4.mat', Ts_list_C, round(100*cfg.beta_target));
else
    s = sprintf('%g_', Ts_list_C);
    s(end) = [];
    name = sprintf('baseline_fixedTs_multi_%s_beta_%02d_v4.mat', s, round(100*cfg.beta_target));
end
end