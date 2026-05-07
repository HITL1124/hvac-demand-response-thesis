function figs = plot_typical_hour_reserve_preview_V1(in, plot_cfg)
% =========================================================================
% 典型小时备用水平预览图（V1）
% -------------------------------------------------------------------------
% 功能：
%   在给定置信度（默认 beta=0.90）和典型小时（默认 h=12）下，
%   预览"不同备用水平 vs 基线"的两类图：
%     1) 全天控制量对比（2x1）：Ts / ma
%     2) 全天室温轨迹对比（含风险舒适区间）
%
% 设计目的：
%   这不是论文终稿图，而是给用户"挑选要展示哪些备用水平"用的预览图。
%
% 输入：
%   in       : 结果结构体或 MAT 文件路径，通常为
%              project_data_file('reserve', 'hourly_reserve_costcurve_all_beta.mat')
%   plot_cfg : 可选配置结构体，常用字段如下
%       .beta_select      = 0.90;   % 选择的置信度
%       .typical_hour     = 12;     % 典型小时
%       .n_show           = 6;      % 默认挑选的备用水平条数
%       .reserve_values   = [];     % 手动指定若干 R 值（kW），按最近可行点匹配
%       .reserve_indices  = [];     % 手动指定若干可行点索引（指向 Hr 内部索引）
%       .plot_in_celsius  = true;   % 是否转为 ℃
%       .show_risk_band   = true;   % 第二张图是否画风险舒适区间
%       .mark_hour_window = true;   % 是否标出典型小时对应窗口
%       .save_fig         = false;  % 是否保存图片
%       .outdir           = '';     % 图片输出目录，空则沿用结果 outdir 或当前目录
%
% 调用示例：
%   plot_cfg = struct();
%   plot_cfg.beta_select = 0.90;
%   plot_cfg.typical_hour = 12;
%   plot_cfg.n_show = 6;
%   figs = plot_typical_hour_reserve_preview_V1( ...
%       project_data_file('reserve', 'hourly_reserve_costcurve_all_beta.mat'), plot_cfg);
%
%   % 手动指定要看的备用水平（按 kW）
%   plot_cfg = struct();
%   plot_cfg.beta_select = 0.90;
%   plot_cfg.typical_hour = 12;
%   plot_cfg.reserve_values = [70 90 110];
%   figs = plot_typical_hour_reserve_preview_V1( ...
%       project_data_file('reserve', 'hourly_reserve_costcurve_all_beta.mat'), plot_cfg);
% =========================================================================

if nargin < 1 || isempty(in)
    in = project_data_file('reserve','hourly_reserve_costcurve_all_beta.mat');
end
if nargin < 2 || isempty(plot_cfg)
    plot_cfg = struct();
end

S = local_load_any(in);
[out, plot_cfg] = local_select_out(S, plot_cfg);
plot_cfg = local_fill_plot_defaults(plot_cfg, out);

baseline = out.baseline;
hours    = out.hours;
Nh       = double(out.mdl.Nh);
Nk       = double(out.mdl.H15);
ns       = double(out.mdl.ns);
hvec     = (1:Nh).';
t15h     = (0:Nk-1).' / ns;

h_fix = plot_cfg.typical_hour;
assert(h_fix >= 1 && h_fix <= Nh, 'typical_hour 超出范围，应在 [1,%d] 内。', Nh);
Hr = hours(h_fix);
assert(isfield(Hr,'R_grid') && ~isempty(Hr.R_grid), 'hour=%d 缺少 R_grid。', h_fix);
assert(isfield(Hr,'is_feasible') && ~isempty(Hr.is_feasible), 'hour=%d 缺少 is_feasible。', h_fix);
assert(isfield(Hr,'solutions') && ~isempty(Hr.solutions), 'hour=%d 缺少 solutions。', h_fix);

if isempty(plot_cfg.outdir)
    if isfield(out,'cfg') && isfield(out.cfg,'outdir') && ~isempty(out.cfg.outdir)
        outdir = out.cfg.outdir;
    else
        outdir = pwd;
    end
else
    outdir = plot_cfg.outdir;
end
if plot_cfg.save_fig && ~exist(outdir,'dir')
    mkdir(outdir);
end

% -------- 选取备用水平 --------
[idx_show, info_sel] = local_pick_preview_indices(Hr, plot_cfg);
assert(~isempty(idx_show), 'hour=%d 未选出可绘制的备用水平。', h_fix);

% -------- 终端打印：该小时所有可行备用水平 & 本次选中水平 --------
local_print_hour_reserve_summary(Hr, h_fix, idx_show);

% -------- 风险舒适区间 --------
[risk_lb, risk_ub] = local_get_reference_risk_band(out, baseline, Nk);

if plot_cfg.plot_in_celsius
    baseline_T15 = baseline.T15(:) - 273.15;
    risk_lb_plot = risk_lb(:) - 273.15;
    risk_ub_plot = risk_ub(:) - 273.15;
    baseline_Ts_hour = baseline.Ts_hour(:) - 273.15;
else
    baseline_T15 = baseline.T15(:);
    risk_lb_plot = risk_lb(:);
    risk_ub_plot = risk_ub(:);
    baseline_Ts_hour = baseline.Ts_hour(:);
end
baseline_ma_hour = baseline.ma_hour(:);

% 统一颜色
cmap = lines(max(numel(idx_show), 6));

figs = struct();
figs.meta = struct();
figs.meta.beta_use = out.beta_use;
figs.meta.typical_hour = h_fix;
figs.meta.selected_indices = idx_show(:);
figs.meta.selected_R = Hr.R_grid(idx_show(:));
figs.meta.selection_info = info_sel;

%% ======================================================================
% 图1：不同备用水平与基线方案的控制量对比（2x1）
% =======================================================================
figs.control = figure('Color','w');
tl1 = tiledlayout(2,1,'TileSpacing','compact','Padding','compact'); %#ok<NASGU>

% ----- Ts -----
ax1 = nexttile;
hold(ax1,'on'); box(ax1,'on'); grid(ax1,'on');
plot(ax1, hvec, baseline_Ts_hour, '-k', 'LineWidth', 2.0, 'DisplayName', '基线');
for k = 1:numel(idx_show)
    iR = idx_show(k);
    if ~Hr.is_feasible(iR) || isempty(Hr.solutions{iR})
        continue;
    end
    solk = Hr.solutions{iR};
    if plot_cfg.plot_in_celsius
        Ts_plot = solk.Ts_hour(:) - 273.15;
    else
        Ts_plot = solk.Ts_hour(:);
    end
    plot(ax1, hvec, Ts_plot, '-', 'Color', cmap(k,:), 'LineWidth', 1.7, ...
        'DisplayName', sprintf('R = %.2f kW', Hr.R_grid(iR)));
end
xline(ax1, h_fix, ':', 'Color', [0.55 0.10 0.10], 'LineWidth', 1.2, 'HandleVisibility','off');
xlabel(ax1, '小时 h');
if plot_cfg.plot_in_celsius
    ylabel(ax1, 'T_s (℃)');
else
    ylabel(ax1, 'T_s (K)');
end
title(ax1, sprintf('\beta = %.2f, 固定 h = %02d 时，不同备用水平下的全天 T_s 对比', out.beta_use, h_fix));
legend(ax1,'Location','best');

% ----- ma -----
ax2 = nexttile;
hold(ax2,'on'); box(ax2,'on'); grid(ax2,'on');
plot(ax2, hvec, baseline_ma_hour, '-k', 'LineWidth', 2.0, 'DisplayName', '基线');
for k = 1:numel(idx_show)
    iR = idx_show(k);
    if ~Hr.is_feasible(iR) || isempty(Hr.solutions{iR})
        continue;
    end
    solk = Hr.solutions{iR};
    plot(ax2, hvec, solk.ma_hour(:), '-', 'Color', cmap(k,:), 'LineWidth', 1.7, ...
        'DisplayName', sprintf('R = %.2f kW', Hr.R_grid(iR)));
end
xline(ax2, h_fix, ':', 'Color', [0.55 0.10 0.10], 'LineWidth', 1.2, 'HandleVisibility','off');
xlabel(ax2, '小时 h');
ylabel(ax2, 'm_a');
title(ax2, sprintf('\beta = %.2f, 固定 h = %02d 时，不同备用水平下的全天 m_a 对比', out.beta_use, h_fix));
legend(ax2,'Location','best');

%% ======================================================================
% 图2：不同备用水平与基线方案的室温轨迹对比
% =======================================================================
figs.temperature = figure('Color','w');
hold on; box on; grid on;

if plot_cfg.show_risk_band
    xpatch = [t15h; flipud(t15h)];
    ypatch = [risk_lb_plot(:); flipud(risk_ub_plot(:))];
    patch(xpatch, ypatch, [0.88 0.92 0.98], 'EdgeColor','none', 'FaceAlpha',0.35, ...
        'DisplayName', sprintf('风险舒适区间 (%.2f)', out.beta_use));
    plot(t15h, risk_lb_plot, '--', 'Color', [0.45 0.55 0.75], 'LineWidth', 1.0, 'HandleVisibility','off');
    plot(t15h, risk_ub_plot, '--', 'Color', [0.45 0.55 0.75], 'LineWidth', 1.0, 'HandleVisibility','off');
end

plot(t15h, baseline_T15, '-k', 'LineWidth', 2.0, 'DisplayName', '基线');

for k = 1:numel(idx_show)
    iR = idx_show(k);
    if ~Hr.is_feasible(iR) || isempty(Hr.solutions{iR})
        continue;
    end
    solk = Hr.solutions{iR};
    T15k = local_get_temp15(solk);
    if plot_cfg.plot_in_celsius
        T15k = T15k - 273.15;
    end
    plot(t15h, T15k(:), '-', 'Color', cmap(k,:), 'LineWidth', 1.6, ...
        'DisplayName', sprintf('R = %.2f kW', Hr.R_grid(iR)));
end

if plot_cfg.mark_hour_window
    x1 = h_fix - 1;
    x2 = h_fix;
    yl = ylim;
    patch([x1 x2 x2 x1], [yl(1) yl(1) yl(2) yl(2)], [0.95 0.85 0.85], ...
        'FaceAlpha', 0.10, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    xline(x1, ':', 'Color', [0.55 0.10 0.10], 'LineWidth', 1.0, 'HandleVisibility','off');
    xline(x2, ':', 'Color', [0.55 0.10 0.10], 'LineWidth', 1.0, 'HandleVisibility','off');
    ylim(yl);
end

xlabel('时间 (h)');
if plot_cfg.plot_in_celsius
    ylabel('室温 (℃)');
else
    ylabel('室温 (K)');
end
xlim([t15h(1), max(24, t15h(end))]);
xticks(0:2:24);
title(sprintf('\beta = %.2f, 固定 h = %02d 时，不同备用水平下的全天室温轨迹对比', out.beta_use, h_fix));
legend('Location','best');

%% 保存（可选）
if plot_cfg.save_fig
    ctrl_file = fullfile(outdir, sprintf('fig_preview_hour_%02d_controls_beta_%02d.png', h_fix, round(100*out.beta_use)));
    temp_file = fullfile(outdir, sprintf('fig_preview_hour_%02d_temperature_beta_%02d.png', h_fix, round(100*out.beta_use)));
    exportgraphics(figs.control, ctrl_file, 'Resolution', 200);
    exportgraphics(figs.temperature, temp_file, 'Resolution', 200);
    figs.control_file = ctrl_file;
    figs.temperature_file = temp_file;
else
    figs.control_file = '';
    figs.temperature_file = '';
end

end

% =========================================================================
% 读取输入
% =========================================================================
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

% =========================================================================
% 选择指定 beta 对应结果
% =========================================================================
function [out, plot_cfg] = local_select_out(S, plot_cfg)
if isfield(S,'out') && isstruct(S.out)
    out = S.out;
    return;
end
if isfield(S,'out_i') && isstruct(S.out_i)
    out = S.out_i;
    return;
end
if isfield(S,'results_all')
    results_all = S.results_all;
    if iscell(results_all)
        items = results_all;
    else
        items = num2cell(results_all);
    end

    if ~isfield(plot_cfg,'beta_select') || isempty(plot_cfg.beta_select)
        plot_cfg.beta_select = local_try_get_beta(items{1});
    end

    beta_all = nan(numel(items),1);
    for i = 1:numel(items)
        beta_all(i) = local_try_get_beta(items{i});
    end
    [~, idx] = min(abs(beta_all - plot_cfg.beta_select));
    out = items{idx};
    if isfield(out,'out_i'), out = out.out_i; end
    if isfield(out,'out') && isstruct(out.out), out = out.out; end
    return;
end
if isfield(S,'beta_use') && isfield(S,'hours')
    out = S;
    return;
end

fns = fieldnames(S);
if numel(fns) == 1 && isstruct(S.(fns{1}))
    X = S.(fns{1});
    if isfield(X,'results_all')
        [out, plot_cfg] = local_select_out(X, plot_cfg);
        return;
    end
    if isfield(X,'hours') && isfield(X,'beta_use')
        out = X;
        return;
    end
end

error('无法识别输入数据结构。');
end

function beta = local_try_get_beta(x)
beta = NaN;
if isfield(x,'beta_use')
    beta = x.beta_use;
elseif isfield(x,'out_i') && isfield(x.out_i,'beta_use')
    beta = x.out_i.beta_use;
elseif isfield(x,'out') && isfield(x.out,'beta_use')
    beta = x.out.beta_use;
end
end

% =========================================================================
% 默认参数
% =========================================================================
function plot_cfg = local_fill_plot_defaults(plot_cfg, out)
if ~isfield(plot_cfg,'beta_select') || isempty(plot_cfg.beta_select)
    plot_cfg.beta_select = out.beta_use;
end
if ~isfield(plot_cfg,'typical_hour') || isempty(plot_cfg.typical_hour)
    plot_cfg.typical_hour = 14;
end
if ~isfield(plot_cfg,'n_show') || isempty(plot_cfg.n_show)
    plot_cfg.n_show = 6;
end
if ~isfield(plot_cfg,'reserve_values')
    plot_cfg.reserve_values = [];
end
if ~isfield(plot_cfg,'reserve_indices')
    plot_cfg.reserve_indices = [];
end
if ~isfield(plot_cfg,'plot_in_celsius') || isempty(plot_cfg.plot_in_celsius)
    plot_cfg.plot_in_celsius = true;
end
if ~isfield(plot_cfg,'show_risk_band') || isempty(plot_cfg.show_risk_band)
    plot_cfg.show_risk_band = true;
end
if ~isfield(plot_cfg,'mark_hour_window') || isempty(plot_cfg.mark_hour_window)
    plot_cfg.mark_hour_window = true;
end
if ~isfield(plot_cfg,'save_fig') || isempty(plot_cfg.save_fig)
    plot_cfg.save_fig = false;
end
if ~isfield(plot_cfg,'outdir')
    plot_cfg.outdir = project_data_file('figures');
end
if ~isfield(plot_cfg,'reserve_tol') || isempty(plot_cfg.reserve_tol)
    plot_cfg.reserve_tol = 1e-8;
end
end

% =========================================================================
% 选择要展示的备用水平
% =========================================================================
function [idx_show, info_sel] = local_pick_preview_indices(Hr, plot_cfg)
info_sel = struct();

feas_idx = find(Hr.is_feasible(:));
if isempty(feas_idx)
    idx_show = [];
    return;
end

% 默认优先排除"天然备用直接沿用基线"的重复点
if isfield(Hr,'R_nat') && ~isempty(Hr.R_nat)
    idx_pos = feas_idx(Hr.R_grid(feas_idx) > Hr.R_nat + plot_cfg.reserve_tol);
else
    idx_pos = feas_idx;
end
if isempty(idx_pos)
    idx_pos = feas_idx;
end

% 1) 用户显式给内部索引
if ~isempty(plot_cfg.reserve_indices)
    idx_raw = unique(plot_cfg.reserve_indices(:));
    idx_raw = idx_raw(isfinite(idx_raw));
    idx_raw = idx_raw(idx_raw >= 1 & idx_raw <= numel(Hr.R_grid));
    idx_raw = idx_raw(Hr.is_feasible(idx_raw));
    idx_show = idx_raw(:).';
    info_sel.mode = 'manual_indices';
    return;
end

% 2) 用户显式给 R 值（按最近可行点匹配）
if ~isempty(plot_cfg.reserve_values)
    idx_tmp = nan(numel(plot_cfg.reserve_values),1);
    for i = 1:numel(plot_cfg.reserve_values)
        Rtar = plot_cfg.reserve_values(i);
        [~, ii] = min(abs(Hr.R_grid(idx_pos) - Rtar));
        idx_tmp(i) = idx_pos(ii);
    end
    idx_show = unique(idx_tmp(:)).';
    info_sel.mode = 'manual_R_values';
    return;
end

% 3) 默认均匀挑选若干个代表性备用水平
n_show = max(1, round(plot_cfg.n_show));
if numel(idx_pos) <= n_show
    idx_show = idx_pos(:).';
else
    pick = round(linspace(1, numel(idx_pos), n_show));
    idx_show = unique(idx_pos(pick));
end
info_sel.mode = 'auto_evenly_spaced_feasible';
end

% =========================================================================
% 打印该小时全部可行备用水平及选中项
% =========================================================================
function local_print_hour_reserve_summary(Hr, h_fix, idx_show)
feas_idx = find(Hr.is_feasible(:));
Rfeas = Hr.R_grid(feas_idx);

fprintf('\n============================================================\n');
fprintf('典型小时预览：hour = %02d\n', h_fix);
if isfield(Hr,'R_nat') && ~isempty(Hr.R_nat)
    fprintf('R_nat(h) = %.6f kW\n', Hr.R_nat);
end
if isfield(Hr,'max_feasible_R') && ~isempty(Hr.max_feasible_R)
    fprintf('R_max(h) = %.6f kW\n', Hr.max_feasible_R);
end
fprintf('该小时全部可行点个数 = %d\n', numel(feas_idx));

fprintf('\n[全部可行备用水平]\n');
for i = 1:numel(feas_idx)
    ii = feas_idx(i);
    fprintf('  idx = %-4d   R = %.6f kW\n', ii, Hr.R_grid(ii));
end

fprintf('\n[本次选中用于绘图的备用水平]\n');
for i = 1:numel(idx_show)
    ii = idx_show(i);
    fprintf('  idx = %-4d   R = %.6f kW\n', ii, Hr.R_grid(ii));
end
fprintf('============================================================\n');
end

% =========================================================================
% 提取风险舒适区间
% =========================================================================
function [lb, ub] = local_get_reference_risk_band(out, baseline, Nk)
lb = local_get_field_any(out, {'theta_risk_lb','Tlow_rob_15'}, []);
ub = local_get_field_any(out, {'theta_risk_ub','Tup_rob_15'}, []);
if isempty(lb)
    lb = local_get_field_any(baseline, {'theta_risk_lb','Tlow_rob_15'}, []);
end
if isempty(ub)
    ub = local_get_field_any(baseline, {'theta_risk_ub','Tup_rob_15'}, []);
end
if isempty(lb) || isempty(ub)
    error('无法读取风险舒适区间。');
end
lb = lb(:); ub = ub(:);
assert(numel(lb) == Nk && numel(ub) == Nk, '风险舒适区间长度与 Nk 不一致。');
end

% =========================================================================
% 提取 15min 室温轨迹
% =========================================================================
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

% =========================================================================
% 通用读字段
% =========================================================================
function v = local_get_field_any(S, names, v0)
v = v0;
for i = 1:numel(names)
    if isfield(S, names{i}) && ~isempty(S.(names{i}))
        v = S.(names{i});
        return;
    end
end
end
