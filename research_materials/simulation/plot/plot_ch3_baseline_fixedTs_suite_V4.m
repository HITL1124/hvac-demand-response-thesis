function figs = plot_ch3_baseline_fixedTs_suite_V4(inCoop, inFix, plot_cfg)
% =========================================================================
% 第三章：固定 Ts 基线对比绘图（V4）
% -------------------------------------------------------------------------
% 功能：
%   1) 读取 run_ch3_hourly_reserve_costcurve_main_V2.m 求出的水风协同基线；
%   2) 读取 run_ch3_baseline_fixedTs_suite_V4.m 求出的固定 Ts 单次/多次基线；
%   3) 绘制：
%        图1：功率基线对比（总功率 / 机组功率 / 风机功率）
%        图2：控制量对比（Ts / ma）
%        图3：天然备用对比
%        图4：室温轨迹对比 + 风险舒适区间
% =========================================================================

if nargin < 2
    error('必须同时提供协同基线结果和固定 Ts 基线结果。');
end
if nargin < 3 || isempty(plot_cfg)
    plot_cfg = struct();
end

plot_cfg = local_fill_plot_defaults(plot_cfg);
coop = local_load_coop_case(inCoop, plot_cfg);
fixout = local_load_fix_any(inFix);
assert(isfield(fixout,'fixed_cases') && ~isempty(fixout.fixed_cases), '固定 Ts 结果中未找到 fixed_cases。');

cases = cell(numel(fixout.fixed_cases)+1,1);
labels = cell(numel(fixout.fixed_cases)+1,1);
cases{1} = coop;
labels{1} = '水风协同';
for i = 1:numel(fixout.fixed_cases)
    cases{i+1} = fixout.fixed_cases(i);
    labels{i+1} = sprintf('固定Ts=%.1f℃', fixout.fixed_cases(i).Ts_fixed_C);
end

Nh = coop.mdl.Nh;
h = (1:Nh).';
Nk = local_get_Nk_from_cases(cases);
t15h = (0:Nk-1).' / local_get_ns_from_cases(cases);
figs = struct();

%% 图1：功率基线对比
figs.power = figure('Color','w');
tiledlayout(3,1,'TileSpacing','compact','Padding','compact');

nexttile; hold on; box on; grid on;
for i = 1:numel(cases)
    plot(h, local_get_hour_series(cases{i}, 'Pbase_hour', 'Ptot'), 'LineWidth', 1.6, 'DisplayName', labels{i});
end
xlabel('小时 h'); ylabel('总功率 (kW)');
title(local_build_power_title(fixout));
legend('Location','best');

nexttile; hold on; box on; grid on;
for i = 1:numel(cases)
    plot(h, local_get_hour_series(cases{i}, 'Php_hour', 'Php'), 'LineWidth', 1.6, 'DisplayName', labels{i});
end
xlabel('小时 h'); ylabel('机组功率 (kW)');
title('基线机组功率对比');
legend('Location','best');

nexttile; hold on; box on; grid on;
for i = 1:numel(cases)
    plot(h, local_get_hour_series(cases{i}, 'Pfan_hour', 'Pfan'), 'LineWidth', 1.6, 'DisplayName', labels{i});
end
xlabel('小时 h'); ylabel('风机功率 (kW)');
title('基线风机功率对比');
legend('Location','best');

%% 图2：控制量对比
figs.control = figure('Color','w');
tiledlayout(2,1,'TileSpacing','compact','Padding','compact');

nexttile; hold on; box on; grid on;
for i = 1:numel(cases)
    Ts_hour = cases{i}.Ts_hour(:);
    if plot_cfg.plot_in_celsius
        Ts_hour = Ts_hour - 273.15;
    end
    stairs(h, Ts_hour, 'LineWidth', 1.7, 'DisplayName', labels{i});
end
xlabel('小时 h');
if plot_cfg.plot_in_celsius
    ylabel('Ts (℃)');
else
    ylabel('Ts (K)');
end
title(local_build_control_title_Ts(fixout));
legend('Location','best');

nexttile; hold on; box on; grid on;
for i = 1:numel(cases)
    stairs(h, cases{i}.ma_hour(:), 'LineWidth', 1.7, 'DisplayName', labels{i});
end
xlabel('小时 h'); ylabel('m_a');
title('基线风量对比');
legend('Location','best');

%% 图3：天然备用对比
figs.reserve = figure('Color','w');
hold on; box on; grid on;
for i = 1:numel(cases)
    par_i = local_get_case_par(cases{i}, coop, fixout);
    Rnat_i = local_compute_rnat(local_get_hour_series(cases{i}, 'Pfan_hour', 'Pfan'), par_i);
    plot(h, Rnat_i, 'LineWidth', 1.7, 'DisplayName', labels{i});
end
xlabel('小时 h'); ylabel('天然备用 (kW)');
title(local_build_reserve_title(fixout));
legend('Location','best');

%% 图4：室温轨迹对比 + 风险舒适区间
figs.temperature = figure('Color','w');
hold on; box on; grid on;
[risk_lb, risk_ub] = local_get_reference_risk_band(coop, fixout);
if plot_cfg.plot_in_celsius
    risk_lb = risk_lb - 273.15;
    risk_ub = risk_ub - 273.15;
end
xpatch = [t15h; flipud(t15h)];
ypatch = [risk_lb(:); flipud(risk_ub(:))];
patch(xpatch, ypatch, [0.88 0.92 0.98], 'EdgeColor','none', 'FaceAlpha',0.35, ...
    'DisplayName','风险舒适区间');
plot(t15h, risk_lb, '--', 'Color', [0.45 0.55 0.75], 'LineWidth', 1.0, 'HandleVisibility','off');
plot(t15h, risk_ub, '--', 'Color', [0.45 0.55 0.75], 'LineWidth', 1.0, 'HandleVisibility','off');
for i = 1:numel(cases)
    T15 = local_get_temp15(cases{i});
    if plot_cfg.plot_in_celsius
        T15 = T15 - 273.15;
    end
    plot(t15h, T15(:), 'LineWidth', 1.6, 'DisplayName', labels{i});
end
xlabel('时间 (h)');
if plot_cfg.plot_in_celsius
    ylabel('室温 (℃)');
else
    ylabel('室温 (K)');
end
xlim([t15h(1), t15h(end)]);
xticks(0:2:24);
title(local_build_temperature_title(fixout));
legend('Location','best');

%% 可选保存
if plot_cfg.save_fig
    if ~exist(plot_cfg.outdir, 'dir')
        mkdir(plot_cfg.outdir);
    end
    powerFile = fullfile(plot_cfg.outdir, local_build_power_name(fixout, coop));
    controlFile = fullfile(plot_cfg.outdir, local_build_control_name(fixout, coop));
    reserveFile = fullfile(plot_cfg.outdir, local_build_reserve_name(fixout, coop));
    tempFile = fullfile(plot_cfg.outdir, local_build_temperature_name(fixout, coop));
    % exportgraphics(figs.power, powerFile, 'Resolution', 200);
    % exportgraphics(figs.control, controlFile, 'Resolution', 200);
    % exportgraphics(figs.reserve, reserveFile, 'Resolution', 200);
    % exportgraphics(figs.temperature, tempFile, 'Resolution', 200);
    figs.power_file = powerFile;
    figs.control_file = controlFile;
    figs.reserve_file = reserveFile;
    figs.temperature_file = tempFile;
end

end

function plot_cfg = local_fill_plot_defaults(plot_cfg)
if ~isfield(plot_cfg,'beta_select') || isempty(plot_cfg.beta_select), plot_cfg.beta_select = 0.95; end
if ~isfield(plot_cfg,'plot_in_celsius') || isempty(plot_cfg.plot_in_celsius), plot_cfg.plot_in_celsius = true; end
if ~isfield(plot_cfg,'save_fig') || isempty(plot_cfg.save_fig), plot_cfg.save_fig = false; end
if ~isfield(plot_cfg,'outdir') || isempty(plot_cfg.outdir), plot_cfg.outdir = project_data_file('figures'); end
end

function coop = local_load_coop_case(inCoop, plot_cfg)
S = local_load_any(inCoop);
if isfield(S,'baseline') && isfield(S,'mdl')
    coop = local_pack_coop_case(S); return;
end
if isfield(S,'out_i') && isstruct(S.out_i)
    coop = local_pack_coop_case(S.out_i); return;
end
if isfield(S,'out') && isstruct(S.out) && isfield(S.out,'baseline')
    coop = local_pack_coop_case(S.out); return;
end
if isfield(S,'results_all')
    coop = local_select_from_results_all(S.results_all, plot_cfg.beta_select);
    coop = local_pack_coop_case(coop); return;
end
fns = fieldnames(S);
if numel(fns) == 1 && isstruct(S.(fns{1}))
    X = S.(fns{1});
    if isfield(X,'baseline')
        coop = local_pack_coop_case(X); return;
    elseif isfield(X,'results_all')
        coop = local_select_from_results_all(X.results_all, plot_cfg.beta_select);
        coop = local_pack_coop_case(coop); return;
    end
end
error('无法从协同结果输入中识别 run_ch3_hourly_reserve_costcurve_main_V2 的基线输出。');
end

function out_one = local_select_from_results_all(results_all, beta_select)
if iscell(results_all), items = results_all; else, items = num2cell(results_all); end
n = numel(items); beta = nan(n,1);
for i = 1:n
    xi = items{i};
    if isfield(xi,'beta_use')
        beta(i) = xi.beta_use;
    elseif isfield(xi,'out_i') && isfield(xi.out_i,'beta_use')
        beta(i) = xi.out_i.beta_use;
    elseif isfield(xi,'out') && isfield(xi.out,'beta_use')
        beta(i) = xi.out.beta_use;
    end
end
[~,idx] = min(abs(beta - beta_select));
out_one = items{idx};
if isfield(out_one,'out_i'), out_one = out_one.out_i; end
if isfield(out_one,'out') && isfield(out_one.out,'baseline'), out_one = out_one.out; end
end

function coop = local_pack_coop_case(out)
coop = struct();
coop.case_label = '水风协同';
coop.beta_use = local_try_get(out,'beta_use',nan);
coop.mdl = out.mdl;
coop.par = local_try_get(out,'par',[]);
coop.baseline = out.baseline;
coop.Ts_hour = out.baseline.Ts_hour(:);
coop.ma_hour = out.baseline.ma_hour(:);
coop.T15 = local_get_field_any(out.baseline, {'T15','theta15','Tr15'}, []);
coop.Pbase_hour = local_get_hour_series(out.baseline, 'Pbase_hour', 'Ptot');
coop.Php_hour = local_get_hour_series(out.baseline, 'Php_hour', 'Php');
coop.Pfan_hour = local_get_hour_series(out.baseline, 'Pfan_hour', 'Pfan');
coop.theta_risk_lb = local_get_field_any(out, {'theta_risk_lb','Tlow_rob_15'}, local_get_field_any(out.baseline, {'Tlow_rob_15'}, []));
coop.theta_risk_ub = local_get_field_any(out, {'theta_risk_ub','Tup_rob_15'}, local_get_field_any(out.baseline, {'Tup_rob_15'}, []));
end

function out = local_load_fix_any(inFix)
S = local_load_any(inFix);
if isfield(S,'out') && isstruct(S.out)
    out = S.out;
elseif isfield(S,'fixed_cases')
    out = S;
else
    fns = fieldnames(S);
    if numel(fns)==1 && isstruct(S.(fns{1}))
        out = S.(fns{1});
    else
        error('无法识别固定 Ts 结果输入。');
    end
end
end

function S = local_load_any(in)
if ischar(in) || isstring(in)
    S = load(in);
elseif isstruct(in)
    S = in;
else
    error('输入必须是结构体或 MAT 文件路径。');
end
end

function y = local_get_hour_series(S, fieldHour, field15)
if isfield(S, fieldHour) && ~isempty(S.(fieldHour))
    y = S.(fieldHour)(:); return;
end
if isfield(S,'mdl') && isfield(S.mdl,'ns') && isfield(S.mdl,'Nh') && isfield(S, field15)
    ns = S.mdl.ns; Nh = S.mdl.Nh; y15 = S.(field15)(:);
    y = mean(reshape(y15, ns, Nh), 1).'; return;
end
error('无法从结果结构中提取字段 %s / %s。', fieldHour, field15);
end

function T15 = local_get_temp15(S)
T15 = local_get_field_any(S, {'T15','theta15','Tr15'}, []);
if isempty(T15) && isfield(S,'baseline')
    T15 = local_get_field_any(S.baseline, {'T15','theta15','Tr15'}, []);
end
if isempty(T15)
    error('无法从结果结构中提取 15min 室温轨迹。');
end
T15 = T15(:);
end

function [lb, ub] = local_get_reference_risk_band(coop, fixout)
lb = local_get_field_any(coop, {'theta_risk_lb','Tlow_rob_15'}, []);
ub = local_get_field_any(coop, {'theta_risk_ub','Tup_rob_15'}, []);
if isempty(lb) || isempty(ub)
    lb = local_get_field_any(fixout.fixed_cases(1), {'Tlow_rob_15','theta_risk_lb'}, []);
    ub = local_get_field_any(fixout.fixed_cases(1), {'Tup_rob_15','theta_risk_ub'}, []);
end
if isempty(lb) || isempty(ub)
    error('无法读取风险舒适区间。');
end
lb = lb(:); ub = ub(:);
end

function v = local_get_field_any(S, names, v0)
v = v0;
for i = 1:numel(names)
    if isfield(S, names{i}) && ~isempty(S.(names{i}))
        v = S.(names{i});
        return;
    end
end
end

function par_i = local_get_case_par(S, coop, fixout)
if isfield(S, 'par') && ~isempty(S.par)
    par_i = S.par;
elseif isfield(coop, 'par') && ~isempty(coop.par)
    par_i = coop.par;
else
    par_i = fixout.fixed_cases(1).par;
end
end

function Rnat = local_compute_rnat(Pfan_hour, par)
assert(isfield(par,'Pfan_min') && isfield(par,'Pfan_max'), 'par 中缺少 Pfan_min / Pfan_max。');
Rnat = min(Pfan_hour(:) - par.Pfan_min, par.Pfan_max - Pfan_hour(:));
Rnat = max(Rnat, 0);
end

function n = local_get_ns_from_cases(cases)
for i = 1:numel(cases)
    if isfield(cases{i},'mdl') && isfield(cases{i}.mdl,'ns') && ~isempty(cases{i}.mdl.ns)
        n = double(cases{i}.mdl.ns); return;
    end
end
n = 4;
end

function Nk = local_get_Nk_from_cases(cases)
for i = 1:numel(cases)
    T15 = local_get_field_any(cases{i}, {'T15','theta15','Tr15'}, []);
    if ~isempty(T15)
        Nk = numel(T15); return;
    end
    if isfield(cases{i},'mdl') && isfield(cases{i}.mdl,'H15')
        Nk = double(cases{i}.mdl.H15); return;
    end
end
Nk = 96;
end

function v = local_try_get(S, name, v0)
if isfield(S,name), v = S.(name); else, v = v0; end
end

function ttl = local_build_power_title(fixout)
if strcmpi(fixout.mode,'single')
    ttl = sprintf('基线总功率对比（固定Ts=%.1f℃ vs 水风协同）', fixout.fixed_cases(1).Ts_fixed_C);
else
    ttl = '基线总功率对比（不同固定Ts与水风协同）';
end
end

function ttl = local_build_control_title_Ts(fixout)
if strcmpi(fixout.mode,'single')
    ttl = sprintf('基线供水温度对比（固定Ts=%.1f℃ vs 水风协同）', fixout.fixed_cases(1).Ts_fixed_C);
else
    ttl = '基线供水温度对比（不同固定Ts与水风协同）';
end
end

function ttl = local_build_reserve_title(fixout)
if strcmpi(fixout.mode,'single')
    ttl = sprintf('天然备用对比（固定Ts=%.1f℃ vs 水风协同）', fixout.fixed_cases(1).Ts_fixed_C);
else
    ttl = '天然备用对比（不同固定Ts与水风协同）';
end
end

function ttl = local_build_temperature_title(fixout)
if strcmpi(fixout.mode,'single')
    ttl = sprintf('室温轨迹对比与风险舒适区间（固定Ts=%.1f℃ vs 水风协同）', fixout.fixed_cases(1).Ts_fixed_C);
else
    ttl = '室温轨迹对比与风险舒适区间（不同固定Ts与水风协同）';
end
end

function fname = local_build_power_name(fixout, coop)
beta = local_round_beta(local_try_get(coop,'beta_use',local_try_get(fixout,'beta_use',nan)));
if strcmpi(fixout.mode,'single')
    fname = sprintf('fig_power_baseline_fixedTs_single_vs_coop_beta_%02d_v4.png', beta);
else
    fname = sprintf('fig_power_baseline_fixedTs_multi_vs_coop_beta_%02d_v4.png', beta);
end
end

function fname = local_build_control_name(fixout, coop)
beta = local_round_beta(local_try_get(coop,'beta_use',local_try_get(fixout,'beta_use',nan)));
if strcmpi(fixout.mode,'single')
    fname = sprintf('fig_control_baseline_fixedTs_single_vs_coop_beta_%02d_v4.png', beta);
else
    fname = sprintf('fig_control_baseline_fixedTs_multi_vs_coop_beta_%02d_v4.png', beta);
end
end

function fname = local_build_reserve_name(fixout, coop)
beta = local_round_beta(local_try_get(coop,'beta_use',local_try_get(fixout,'beta_use',nan)));
if strcmpi(fixout.mode,'single')
    fname = sprintf('fig_reserve_baseline_fixedTs_single_vs_coop_beta_%02d_v4.png', beta);
else
    fname = sprintf('fig_reserve_baseline_fixedTs_multi_vs_coop_beta_%02d_v4.png', beta);
end
end

function fname = local_build_temperature_name(fixout, coop)
beta = local_round_beta(local_try_get(coop,'beta_use',local_try_get(fixout,'beta_use',nan)));
if strcmpi(fixout.mode,'single')
    fname = sprintf('fig_temperature_baseline_fixedTs_single_vs_coop_beta_%02d_v4.png', beta);
else
    fname = sprintf('fig_temperature_baseline_fixedTs_multi_vs_coop_beta_%02d_v4.png', beta);
end
end

function b = local_round_beta(beta)
if isempty(beta) || ~isfinite(beta), b = 0; else, b = round(100*beta); end
end
