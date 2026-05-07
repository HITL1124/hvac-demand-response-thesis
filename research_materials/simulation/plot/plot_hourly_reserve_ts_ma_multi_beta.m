function figs = plot_hourly_reserve_ts_ma_multi_beta(cfg)
% =========================================================================
% 按置信度分别绘制逐小时的备用水平-控制量关系图
%
% 默认行为：
%   1) 优先读取批量可信性结果：
%        data/reserve/hourly_credible_feasibility_v2_all_beta.mat
%   2) 优先读取批量备用扫描结果：
%        data/reserve/hourly_reserve_costcurve_all_beta.mat
%   3) 默认采用可信域口径：
%        R  = R_grid_cred(is_credible)
%        Ts = Ts_work(is_credible)
%        ma = ma_work(is_credible)
%   4) 每个 beta 单独输出 1 张 4x6 子图总览图
%   5) 每个小时子图采用双 Y 轴：
%        左轴 Ts（℃），右轴 ma
%
% 常用调用：
%   figs = plot_hourly_reserve_ts_ma_multi_beta();
%
%   cfg = struct();
%   cfg.beta_list = [0.80 0.85 0.90 0.95];
%   cfg.hours = 1:24;
%   cfg.domain_mode = 'credible';
%   cfg.show_rcred_marker = true;
%   cfg.show_rmax_ref = true;
%   cfg.outdir = project_data_file('figures');
%   figs = plot_hourly_reserve_ts_ma_multi_beta(cfg);
% =========================================================================

if nargin < 1
    cfg = struct();
end
cfg = local_fill_defaults(cfg);

if ~exist(cfg.outdir, 'dir')
    mkdir(cfg.outdir);
end

credMap = local_collect_credible_results(cfg);
reserveMap = local_collect_reserve_results(cfg);

beta_req = cfg.beta_list(:).';
beta_cred = credMap.beta_list(:).';
beta_res = reserveMap.beta_list(:).';
beta_use = beta_req(ismember(round(100 * beta_req), round(100 * intersect(beta_cred, beta_res))));
if isempty(beta_use)
    error('请求的置信度在可信结果与备用结果中没有共同可用项。');
end

Nh = local_detect_Nh(reserveMap, credMap, beta_use(1));
hours_use = cfg.hours(:).';
if any(hours_use < 1 | hours_use > Nh | abs(hours_use - round(hours_use)) > 0)
    error('cfg.hours 必须是 [1, %d] 范围内的整数小时序号。', Nh);
end
hours_use = unique(hours_use, 'stable');

figs = struct();
figs.figure_handles = cell(numel(beta_use), 1);
figs.saved_files = cell(numel(beta_use), 1);
figs.beta_list = beta_use(:);
figs.hours = hours_use(:);
figs.domain_mode = cfg.domain_mode;
figs.credible_source = credMap.source_used;
figs.reserve_source = reserveMap.source_used;

for ib = 1:numel(beta_use)
    beta = beta_use(ib);
    cred_i = local_get_cred_by_beta(credMap, beta);
    out_i = local_get_reserve_out_by_beta(reserveMap, beta);

    fig_i = figure('Color', 'w', 'Name', sprintf('beta=%.2f 备用-控制量关系', beta));
    tiledlayout(4, 6, 'TileSpacing', 'compact', 'Padding', 'compact');

    for ih = 1:numel(hours_use)
        h = hours_use(ih);
        ax = nexttile;
        hold(ax, 'on');
        box(ax, 'on');
        grid(ax, 'on');

        [Rplot, TsPlot, maPlot, Rcred, Rmax] = local_get_hour_plot_data(out_i, cred_i, h, cfg);
        local_plot_one_hour(ax, h, Rplot, TsPlot, maPlot, Rcred, Rmax, cfg);

        if mod(ih - 1, 6) == 0
            yyaxis(ax, 'left');
            ylabel(ax, 'Ts (℃)');
            yyaxis(ax, 'right');
            ylabel(ax, 'ma');
        end
        if ih > max(0, numel(hours_use) - 6)
            xlabel(ax, '备用水平 R (kW)');
        end
    end

    sgtitle(sprintf('置信度 \\beta = %.2f 下逐小时备用水平与控制量关系（%s域）', ...
        beta, local_domain_mode_cn(cfg.domain_mode)));

    file_i = fullfile(cfg.outdir, ...
        sprintf('fig_hourly_ts_ma_vs_reserve_beta_%02d_%s.png', ...
        round(100 * beta), lower(cfg.domain_mode)));
    % saveas(fig_i, file_i);

    figs.figure_handles{ib} = fig_i;
    figs.saved_files{ib} = file_i;
end

fprintf('\n============================================================\n');
fprintf('逐小时 R-Ts/ma 双Y轴绘图完成。\n');
fprintf('domain_mode     : %s\n', cfg.domain_mode);
fprintf('beta_list       : ');
fprintf('%.2f ', beta_use);
fprintf('\n');
fprintf('hours           : ');
fprintf('%d ', hours_use);
fprintf('\n');
for ib = 1:numel(beta_use)
    fprintf('beta=%.2f 图文件 : %s\n', beta_use(ib), figs.saved_files{ib});
end
fprintf('============================================================\n');

end

% =========================================================================
% 默认参数
% =========================================================================
function cfg = local_fill_defaults(cfg)

defaults.outdir = project_data_file('figures');
defaults.reserve_dir = project_data_file('reserve');
defaults.credible_all_beta_file = fullfile(defaults.reserve_dir, ...
    'hourly_credible_feasibility_v2_all_beta.mat');
defaults.reserve_all_beta_file = fullfile(defaults.reserve_dir, ...
    'hourly_reserve_costcurve_all_beta.mat');
defaults.beta_list = [0.80 0.85 0.90 0.95];
defaults.hours = 1:24;
defaults.domain_mode = 'credible';
defaults.show_rcred_marker = true;
defaults.show_rmax_ref = true;
defaults.reserve_tol = 1e-10;
defaults.ts_color = [0.00 0.45 0.74];
defaults.ma_color = [0.85 0.33 0.10];
defaults.rmax_color = [0.45 0.45 0.45];

fns = fieldnames(defaults);
for i = 1:numel(fns)
    fn = fns{i};
    if ~isfield(cfg, fn) || isempty(cfg.(fn))
        cfg.(fn) = defaults.(fn);
    end
end

end

% =========================================================================
% 绘制单个小时子图
% =========================================================================
function local_plot_one_hour(ax, h, Rplot, TsPlot, maPlot, Rcred, Rmax, cfg)

title(ax, sprintf('h=%02d', h));

yyaxis(ax, 'left');
set(ax, 'YColor', cfg.ts_color);

if cfg.show_rmax_ref && isfinite(Rmax)
    xline(ax, Rmax, ':', 'Color', cfg.rmax_color, ...
        'LineWidth', 0.9, 'HandleVisibility', 'off');
end

if ~isempty(Rplot) && ~isempty(TsPlot)
    plot(ax, Rplot, TsPlot, '-o', ...
        'Color', cfg.ts_color, ...
        'LineWidth', 1.2, ...
        'MarkerSize', 3.5, ...
        'HandleVisibility', 'off');

    if cfg.show_rcred_marker && isfinite(Rcred)
        idxMark = local_find_marker_index(Rplot, Rcred, cfg.reserve_tol);
        plot(ax, Rplot(idxMark), TsPlot(idxMark), 'o', ...
            'Color', cfg.ts_color, ...
            'MarkerFaceColor', cfg.ts_color, ...
            'MarkerSize', 5, ...
            'HandleVisibility', 'off');
    end
end

yyaxis(ax, 'right');
set(ax, 'YColor', cfg.ma_color);

if ~isempty(Rplot) && ~isempty(maPlot)
    plot(ax, Rplot, maPlot, '-s', ...
        'Color', cfg.ma_color, ...
        'LineWidth', 1.2, ...
        'MarkerSize', 3.5, ...
        'HandleVisibility', 'off');

    if cfg.show_rcred_marker && isfinite(Rcred)
        idxMark = local_find_marker_index(Rplot, Rcred, cfg.reserve_tol);
        plot(ax, Rplot(idxMark), maPlot(idxMark), 's', ...
            'Color', cfg.ma_color, ...
            'MarkerFaceColor', cfg.ma_color, ...
            'MarkerSize', 4.5, ...
            'HandleVisibility', 'off');
    end
end

if isempty(Rplot)
    text(ax, 0.5, 0.5, local_empty_text(cfg.domain_mode), ...
        'Units', 'normalized', ...
        'HorizontalAlignment', 'center', ...
        'Color', [0.45 0.45 0.45], ...
        'FontSize', 9);
end

end

function idxMark = local_find_marker_index(Rplot, Rcred, tol)

idxMark = find(abs(Rplot - Rcred) <= tol, 1, 'last');
if isempty(idxMark)
    [~, idxMark] = min(abs(Rplot - Rcred));
end

end

% =========================================================================
% 收集备用扫描结果
% =========================================================================
function reserveMap = local_collect_reserve_results(cfg)

reserveMap = struct();
reserveMap.items = struct('beta', {}, 'out', {});
reserveMap.beta_list = [];
reserveMap.source_used = '';

if exist(cfg.reserve_all_beta_file, 'file') == 2
    S = load(cfg.reserve_all_beta_file);
    if isfield(S, 'results_all') && ~isempty(S.results_all)
        items = struct('beta', {}, 'out', {});
        allres = S.results_all;
        for i = 1:numel(allres)
            if iscell(allres)
                entry = allres{i};
            else
                entry = allres(i);
            end
            beta_i = local_get_beta_from_reserve_entry(entry);
            out_i = local_get_out_from_reserve_entry(entry);
            if ~isempty(out_i)
                items(end + 1).beta = beta_i; %#ok<AGROW>
                items(end).out = out_i;
            end
        end
        if ~isempty(items)
            reserveMap.items = items;
            reserveMap.beta_list = [items.beta];
            reserveMap.source_used = cfg.reserve_all_beta_file;
            return;
        end
    end
end

items = struct('beta', {}, 'out', {});
for ib = 1:numel(cfg.beta_list)
    beta = cfg.beta_list(ib);
    onefile = fullfile(cfg.reserve_dir, ...
        sprintf('hourly_reserve_costcurve_beta_%02d.mat', round(100 * beta)));
    if exist(onefile, 'file') ~= 2
        continue;
    end

    S = load(onefile);
    if isfield(S, 'out_i')
        out_i = S.out_i;
    elseif isfield(S, 'out')
        out_i = S.out;
    else
        continue;
    end

    items(end + 1).beta = local_get_beta_from_out(out_i); %#ok<AGROW>
    items(end).out = out_i;
end

if isempty(items)
    error('未找到备用扫描结果，请检查 %s 或 hourly_reserve_costcurve_beta_XX.mat。', ...
        cfg.reserve_all_beta_file);
end

reserveMap.items = items;
reserveMap.beta_list = [items.beta];
reserveMap.source_used = 'single_beta_files';

end

% =========================================================================
% 收集可信性结果
% =========================================================================
function credMap = local_collect_credible_results(cfg)

credMap = struct();
credMap.items = struct('beta', {}, 'cred', {});
credMap.beta_list = [];
credMap.source_used = '';

if exist(cfg.credible_all_beta_file, 'file') == 2
    S = load(cfg.credible_all_beta_file);
    if isfield(S, 'cred') && isfield(S.cred, 'results_all') && ~isempty(S.cred.results_all)
        items = struct('beta', {}, 'cred', {});
        allres = S.cred.results_all;
        for i = 1:numel(allres)
            if iscell(allres)
                cred_i = allres{i};
            else
                cred_i = allres(i);
            end
            beta_i = local_get_beta_from_cred(cred_i);
            items(end + 1).beta = beta_i; %#ok<AGROW>
            items(end).cred = cred_i;
        end
        credMap.items = items;
        credMap.beta_list = [items.beta];
        credMap.source_used = cfg.credible_all_beta_file;
        return;
    end
end

items = struct('beta', {}, 'cred', {});
for ib = 1:numel(cfg.beta_list)
    beta = cfg.beta_list(ib);
    onefile = fullfile(cfg.reserve_dir, ...
        sprintf('hourly_credible_feasibility_v2_beta_%02d.mat', round(100 * beta)));
    if exist(onefile, 'file') ~= 2
        continue;
    end

    S = load(onefile);
    if ~isfield(S, 'cred')
        continue;
    end

    items(end + 1).beta = local_get_beta_from_cred(S.cred); %#ok<AGROW>
    items(end).cred = S.cred;
end

if isempty(items)
    error('未找到可信性结果，请检查 %s 或 hourly_credible_feasibility_v2_beta_XX.mat。', ...
        cfg.credible_all_beta_file);
end

credMap.items = items;
credMap.beta_list = [items.beta];
credMap.source_used = 'single_beta_files';

end

% =========================================================================
% 结果访问
% =========================================================================
function out_i = local_get_reserve_out_by_beta(reserveMap, beta)

idx = find(round(100 * [reserveMap.items.beta]) == round(100 * beta), 1, 'first');
if isempty(idx)
    error('备用扫描结果中未找到 beta=%.2f。', beta);
end
out_i = reserveMap.items(idx).out;

end

function cred_i = local_get_cred_by_beta(credMap, beta)

idx = find(round(100 * [credMap.items.beta]) == round(100 * beta), 1, 'first');
if isempty(idx)
    error('可信性结果中未找到 beta=%.2f。', beta);
end
cred_i = credMap.items(idx).cred;

end

function Nh = local_detect_Nh(reserveMap, credMap, beta)

out_i = local_get_reserve_out_by_beta(reserveMap, beta);
cred_i = local_get_cred_by_beta(credMap, beta);

if isfield(out_i, 'hours') && ~isempty(out_i.hours)
    Nh = numel(out_i.hours);
elseif isfield(cred_i, 'summary') && isfield(cred_i.summary, 'R_cred_hour')
    Nh = numel(cred_i.summary.R_cred_hour);
else
    error('无法识别小时数量 Nh。');
end

end

% =========================================================================
% 提取单个小时的绘图数据
% =========================================================================
function [Rplot, TsPlot, maPlot, Rcred, Rmax] = local_get_hour_plot_data(out_i, cred_i, h, cfg)

Rplot = [];
TsPlot = [];
maPlot = [];
Rcred = local_get_rcred(cred_i, h);
Rmax = local_get_rmax(out_i, cred_i, h);

if strcmpi(cfg.domain_mode, 'credible')
    Hr = cred_i.hours(h);
    R_all = local_force_column(local_try_get(Hr, 'R_grid_cred', []));
    Ts_all = local_force_column(local_try_get(Hr, 'Ts_work', []));
    ma_all = local_force_column(local_try_get(Hr, 'ma_work', []));
    mask = local_force_column(local_try_get(Hr, 'is_credible', []));

    n = max([numel(R_all), numel(Ts_all), numel(ma_all), numel(mask)]);
    if n == 0
        return;
    end

    R_all = local_pad_numeric(R_all, n, NaN);
    Ts_all = local_pad_numeric(Ts_all, n, NaN);
    ma_all = local_pad_numeric(ma_all, n, NaN);
    if isempty(mask)
        mask = true(n, 1);
    else
        mask = local_pad_logical(mask, n, false);
    end

    keep = mask & isfinite(R_all) & isfinite(Ts_all) & isfinite(ma_all);
    Rplot = R_all(keep);
    TsPlot = Ts_all(keep);
    maPlot = ma_all(keep);
    return;
end

if strcmpi(cfg.domain_mode, 'feasible')
    Hr = out_i.hours(h);
    R_all = local_force_column(local_try_get(Hr, 'R_grid', []));
    Ts_all = local_force_column(local_try_get(Hr, 'Ts_hour_C', []));
    ma_all = local_force_column(local_try_get(Hr, 'ma_hour', []));
    mask = local_force_column(local_try_get(Hr, 'is_feasible', []));

    n = max([numel(R_all), numel(Ts_all), numel(ma_all), numel(mask)]);
    if n == 0
        return;
    end

    R_all = local_pad_numeric(R_all, n, NaN);
    Ts_all = local_pad_numeric(Ts_all, n, NaN);
    ma_all = local_pad_numeric(ma_all, n, NaN);
    if isempty(mask)
        mask = true(n, 1);
    else
        mask = local_pad_logical(mask, n, false);
    end

    keep = mask & isfinite(R_all) & isfinite(Ts_all) & isfinite(ma_all);
    Rplot = R_all(keep);
    TsPlot = Ts_all(keep);
    maPlot = ma_all(keep);
    return;
end

error('不支持的 domain_mode：%s', cfg.domain_mode);

end

function Rcred = local_get_rcred(cred_i, h)

Rcred = NaN;
if isfield(cred_i, 'hours') && numel(cred_i.hours) >= h ...
        && isfield(cred_i.hours(h), 'R_credible') && ~isempty(cred_i.hours(h).R_credible)
    Rcred = cred_i.hours(h).R_credible;
    return;
end
if isfield(cred_i, 'summary') && isfield(cred_i.summary, 'R_cred_hour') ...
        && numel(cred_i.summary.R_cred_hour) >= h
    Rcred = cred_i.summary.R_cred_hour(h);
end

end

function Rmax = local_get_rmax(out_i, cred_i, h)

Rmax = NaN;
if isfield(out_i, 'hours') && numel(out_i.hours) >= h ...
        && isfield(out_i.hours(h), 'max_feasible_R') && ~isempty(out_i.hours(h).max_feasible_R)
    Rmax = out_i.hours(h).max_feasible_R;
end
if ~isfinite(Rmax) && isfield(cred_i, 'summary') && isfield(cred_i.summary, 'R_max_hour') ...
        && numel(cred_i.summary.R_max_hour) >= h
    Rmax = cred_i.summary.R_max_hour(h);
end

end

% =========================================================================
% beta 与结构解析
% =========================================================================
function beta = local_get_beta_from_reserve_entry(entry)

if isfield(entry, 'beta_use') && ~isempty(entry.beta_use)
    beta = double(entry.beta_use);
elseif isfield(entry, 'beta_target') && ~isempty(entry.beta_target)
    beta = double(entry.beta_target);
elseif isfield(entry, 'out') && isstruct(entry.out)
    beta = local_get_beta_from_out(entry.out);
else
    error('无法从备用扫描批量结果中识别 beta。');
end

end

function out_i = local_get_out_from_reserve_entry(entry)

if isfield(entry, 'out') && isstruct(entry.out)
    out_i = entry.out;
elseif isfield(entry, 'out_i') && isstruct(entry.out_i)
    out_i = entry.out_i;
else
    out_i = [];
end

end

function beta = local_get_beta_from_out(out_i)

if isfield(out_i, 'beta_use') && ~isempty(out_i.beta_use)
    beta = double(out_i.beta_use);
elseif isfield(out_i, 'mdl') && isstruct(out_i.mdl) ...
        && isfield(out_i.mdl, 'beta_use') && ~isempty(out_i.mdl.beta_use)
    beta = double(out_i.mdl.beta_use);
elseif isfield(out_i, 'cfg') && isstruct(out_i.cfg) ...
        && isfield(out_i.cfg, 'beta_target') && ~isempty(out_i.cfg.beta_target)
    beta = double(out_i.cfg.beta_target);
else
    error('无法从备用扫描结果中识别 beta。');
end

end

function beta = local_get_beta_from_cred(cred_i)

if isfield(cred_i, 'meta') && isstruct(cred_i.meta) ...
        && isfield(cred_i.meta, 'beta_screen') && ~isempty(cred_i.meta.beta_screen)
    beta = double(cred_i.meta.beta_screen);
elseif isfield(cred_i, 'cfg') && isstruct(cred_i.cfg) ...
        && isfield(cred_i.cfg, 'beta_screen') && ~isempty(cred_i.cfg.beta_screen)
    beta = double(cred_i.cfg.beta_screen);
elseif isfield(cred_i, 'beta_use') && ~isempty(cred_i.beta_use)
    beta = double(cred_i.beta_use);
else
    error('无法从可信性结果中识别 beta。');
end

end

% =========================================================================
% 通用辅助函数
% =========================================================================
function v = local_try_get(S, field, defaultValue)

if isstruct(S) && isfield(S, field) && ~isempty(S.(field))
    v = S.(field);
else
    v = defaultValue;
end

end

function x = local_force_column(x)

if isempty(x)
    return;
end
x = x(:);

end

function x = local_pad_numeric(x, n, fillValue)

if isempty(x)
    x = repmat(fillValue, n, 1);
    return;
end
if numel(x) < n
    x(end + 1:n, 1) = fillValue;
elseif numel(x) > n
    x = x(1:n);
end

end

function x = local_pad_logical(x, n, fillValue)

x = logical(x(:));
if numel(x) < n
    x(end + 1:n, 1) = fillValue;
elseif numel(x) > n
    x = x(1:n);
end

end

function txt = local_empty_text(domain_mode)

switch lower(domain_mode)
    case 'credible'
        txt = '无可信点';
    case 'feasible'
        txt = '无可行点';
    otherwise
        txt = '无数据点';
end

end

function txt = local_domain_mode_cn(domain_mode)

switch lower(domain_mode)
    case 'credible'
        txt = '可信';
    case 'feasible'
        txt = '可行';
    otherwise
        txt = domain_mode;
end

end
