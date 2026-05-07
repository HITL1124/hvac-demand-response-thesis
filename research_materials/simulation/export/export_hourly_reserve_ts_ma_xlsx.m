function out = export_hourly_reserve_ts_ma_xlsx(cfg)
% =========================================================================
% Export hourly reserve scan Ts/ma data to Excel.
%
% Default behavior:
%   1) Read reserve scan results from:
%        data/reserve/hourly_reserve_costcurve_all_beta.mat
%   2) Fall back to single-beta files:
%        hourly_reserve_costcurve_beta_XX.mat
%   3) Export only feasible reserve scan points
%   4) One beta per sheet, 24 hourly blocks per sheet
%
% Typical usage:
%   out = export_hourly_reserve_ts_ma_xlsx();
%
%   cfg = struct();
%   cfg.beta_list = [0.80 0.85 0.90 0.95];
%   cfg.hours = 1:24;
%   cfg.feasible_only = true;
%   cfg.outfile = project_data_file('exports', ...
%       'export_hourly_reserve_ts_ma.xlsx');
%   out = export_hourly_reserve_ts_ma_xlsx(cfg);
% =========================================================================

if nargin < 1
    cfg = struct();
end
cfg = local_fill_defaults(cfg);

outdir = fileparts(cfg.outfile);
if ~isempty(outdir) && exist(outdir, 'dir') ~= 7
    mkdir(outdir);
end
if exist(cfg.outfile, 'file') == 2
    delete(cfg.outfile);
end

reserveMap = local_collect_reserve_results(cfg);

beta_req = cfg.beta_list(:).';
beta_avail = reserveMap.beta_list(:).';
beta_use = beta_req(ismember(round(100 * beta_req), round(100 * beta_avail)));
if isempty(beta_use)
    error('No requested beta values were found in the reserve results.');
end

Nh = local_detect_Nh(reserveMap, beta_use(1));
hours_use = cfg.hours(:).';
if any(hours_use < 1 | hours_use > Nh | abs(hours_use - round(hours_use)) > 0)
    error('cfg.hours must be integer hour indices within [1, %d].', Nh);
end
hours_use = unique(hours_use, 'stable');

out = struct();
out.case_label = 'export_hourly_reserve_ts_ma_xlsx';
out.outfile = cfg.outfile;
out.beta_list = beta_use(:);
out.hours = hours_use(:);
out.source_file = reserveMap.source_used;
out.summary = struct( ...
    'beta', cell(numel(beta_use), numel(hours_use)), ...
    'hour', cell(numel(beta_use), numel(hours_use)), ...
    'n_total_points', cell(numel(beta_use), numel(hours_use)), ...
    'n_exported_points', cell(numel(beta_use), numel(hours_use)), ...
    'sheet_name', cell(numel(beta_use), numel(hours_use)));

for ib = 1:numel(beta_use)
    beta = beta_use(ib);
    out_i = local_get_reserve_out_by_beta(reserveMap, beta);
    sheetName = local_make_sheet_name(beta);
    block = local_build_sheet_block(out_i, beta, hours_use, cfg, sheetName);
    writecell(block.sheet_cell, cfg.outfile, 'Sheet', sheetName, 'Range', 'A1');

    for ih = 1:numel(hours_use)
        out.summary(ib, ih).beta = beta;
        out.summary(ib, ih).hour = hours_use(ih);
        out.summary(ib, ih).n_total_points = block.n_total_points(ih);
        out.summary(ib, ih).n_exported_points = block.n_exported_points(ih);
        out.summary(ib, ih).sheet_name = sheetName;
    end
end

fprintf('\n============================================================\n');
fprintf('Hourly reserve Ts/ma export finished.\n');
fprintf('Excel saved to: %s\n', cfg.outfile);
fprintf('beta_list      : ');
fprintf('%.2f ', beta_use);
fprintf('\n');
fprintf('hours          : ');
fprintf('%d ', hours_use);
fprintf('\n');
fprintf('============================================================\n');

end

% =========================================================================
% Defaults
% =========================================================================
function cfg = local_fill_defaults(cfg)

defaults.outfile = project_data_file('exports', '05_Fig10_Fig11_workpoint_risk', ...
    'export_hourly_reserve_ts_ma.xlsx');
defaults.outdir = project_data_file('exports', '05_Fig10_Fig11_workpoint_risk');
defaults.reserve_dir = project_data_file('reserve');
defaults.reserve_all_beta_file = fullfile(defaults.reserve_dir, ...
    'hourly_reserve_costcurve_all_beta.mat');
defaults.beta_list = [0.80 0.85 0.90 0.95];
defaults.hours = 1:24;
defaults.feasible_only = true;
defaults.allow_rerun_if_missing = false;
defaults.include_note_row_for_empty_hour = true;

fns = fieldnames(defaults);
for i = 1:numel(fns)
    fn = fns{i};
    if ~isfield(cfg, fn) || isempty(cfg.(fn))
        cfg.(fn) = defaults.(fn);
    end
end

end

% =========================================================================
% Collect reserve results
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

if isempty(items) && cfg.allow_rerun_if_missing
    cfg_run = struct();
    cfg_run.run_all_beta = true;
    cfg_run.beta_list = cfg.beta_list;
    cfg_run.makePlots = false;
    run_ch3_hourly_reserve_costcurve_main_V2(cfg_run);
    reserveMap = local_collect_reserve_results(local_merge_cfg(cfg, ...
        struct('allow_rerun_if_missing', false)));
    return;
end

if isempty(items)
    error(['No reserve results were found. Expected batch file: %s ' ...
           'or single-beta files hourly_reserve_costcurve_beta_XX.mat.'], ...
          cfg.reserve_all_beta_file);
end

reserveMap.items = items;
reserveMap.beta_list = [items.beta];
reserveMap.source_used = 'single_beta_files';

end

% =========================================================================
% Extract a single beta result
% =========================================================================
function out_i = local_get_reserve_out_by_beta(reserveMap, beta)

idx = find(round(100 * [reserveMap.items.beta]) == round(100 * beta), ...
    1, 'first');
if isempty(idx)
    error('Reserve results do not contain beta=%.2f.', beta);
end
out_i = reserveMap.items(idx).out;

end

function Nh = local_detect_Nh(reserveMap, beta)

out_i = local_get_reserve_out_by_beta(reserveMap, beta);
if isfield(out_i, 'hours') && ~isempty(out_i.hours)
    Nh = numel(out_i.hours);
    return;
end
error('Unable to detect the number of hours from reserve results.');

end

% =========================================================================
% Build one sheet
% =========================================================================
function block = local_build_sheet_block(out_i, beta, hours_use, cfg, sheetName)

rows = {};
rows{end + 1, 1} = sprintf('beta = %.2f', beta); %#ok<AGROW>
rows{end, 2} = 'source';
rows{end, 3} = local_describe_source(out_i);
rows{end + 1, 1} = sprintf('hours exported = %d', numel(hours_use)); %#ok<AGROW>
rows{end, 2} = 'feasible_only';
rows{end, 3} = logical(cfg.feasible_only);
rows{end + 1, 1} = ''; %#ok<AGROW>
rows{end, 2} = '';
rows{end, 3} = '';

n_total_points = zeros(numel(hours_use), 1);
n_exported_points = zeros(numel(hours_use), 1);

for ih = 1:numel(hours_use)
    h = hours_use(ih);
    Hr = out_i.hours(h);
    [R_use, Ts_use, ma_use, n_total, n_export] = local_extract_hour_rows(Hr, cfg);
    n_total_points(ih) = n_total;
    n_exported_points(ih) = n_export;

    rows{end + 1, 1} = sprintf('hour = %02d', h); %#ok<AGROW>
    rows{end, 2} = sprintf('beta = %.2f', beta);
    rows{end, 3} = sprintf('n_feasible_points = %d', n_export);
    rows{end, 4} = sprintf('n_total_points = %d', n_total);
    rows{end + 1, 1} = 'R_kW'; %#ok<AGROW>
    rows{end, 2} = 'Ts_C';
    rows{end, 3} = 'ma';

    if isempty(R_use)
        if cfg.include_note_row_for_empty_hour
            rows{end + 1, 1} = 'no_feasible_points'; %#ok<AGROW>
            rows{end, 2} = '';
            rows{end, 3} = '';
        end
    else
        for i = 1:numel(R_use)
            rows{end + 1, 1} = R_use(i); %#ok<AGROW>
            rows{end, 2} = Ts_use(i);
            rows{end, 3} = ma_use(i);
        end
    end

    if ih < numel(hours_use)
        rows{end + 1, 1} = ''; %#ok<AGROW>
        rows{end, 2} = '';
        rows{end, 3} = '';
        rows{end + 1, 1} = ''; %#ok<AGROW>
        rows{end, 2} = '';
        rows{end, 3} = '';
    end
end

block = struct();
block.sheet_name = sheetName;
block.sheet_cell = local_rectangularize_cell(rows);
block.n_total_points = n_total_points;
block.n_exported_points = n_exported_points;

end

function [R_use, Ts_use, ma_use, n_total, n_export] = local_extract_hour_rows(Hr, cfg)

R_all = local_force_column(local_try_get(Hr, 'R_grid', []));
Ts_all = local_force_column(local_try_get(Hr, 'Ts_hour_C', []));
ma_all = local_force_column(local_try_get(Hr, 'ma_hour', []));
is_feasible = local_force_column(local_try_get(Hr, 'is_feasible', []));

n_total = max([numel(R_all), numel(Ts_all), numel(ma_all), numel(is_feasible)]);
if n_total == 0
    R_use = [];
    Ts_use = [];
    ma_use = [];
    n_export = 0;
    return;
end

R_all = local_pad_numeric(R_all, n_total, NaN);
Ts_all = local_pad_numeric(Ts_all, n_total, NaN);
ma_all = local_pad_numeric(ma_all, n_total, NaN);

if isempty(is_feasible)
    is_feasible = true(n_total, 1);
else
    is_feasible = local_pad_logical(is_feasible, n_total, false);
end

valid_mask = isfinite(R_all) & isfinite(Ts_all) & isfinite(ma_all);
if cfg.feasible_only
    keep = is_feasible & valid_mask;
else
    keep = valid_mask;
end

R_use = R_all(keep);
Ts_use = Ts_all(keep);
ma_use = ma_all(keep);
n_export = sum(keep);

end

% =========================================================================
% Helpers for result parsing
% =========================================================================
function beta = local_get_beta_from_reserve_entry(entry)

if isfield(entry, 'beta_use') && ~isempty(entry.beta_use)
    beta = double(entry.beta_use);
    return;
end
if isfield(entry, 'beta_target') && ~isempty(entry.beta_target)
    beta = double(entry.beta_target);
    return;
end
if isfield(entry, 'out') && isstruct(entry.out)
    beta = local_get_beta_from_out(entry.out);
    return;
end
error('Unable to identify beta from a reserve batch entry.');

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
    return;
end
if isfield(out_i, 'mdl') && isstruct(out_i.mdl) ...
        && isfield(out_i.mdl, 'beta_use') && ~isempty(out_i.mdl.beta_use)
    beta = double(out_i.mdl.beta_use);
    return;
end
if isfield(out_i, 'cfg') && isstruct(out_i.cfg) ...
        && isfield(out_i.cfg, 'beta_target') && ~isempty(out_i.cfg.beta_target)
    beta = double(out_i.cfg.beta_target);
    return;
end
error('Unable to identify beta from reserve output.');

end

function txt = local_describe_source(out_i)

beta = local_get_beta_from_out(out_i);
txt = sprintf('reserve scan result, beta=%.2f', beta);

end

function sheetName = local_make_sheet_name(beta)

sheetName = sprintf('beta_%.2f', beta);

end

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

function C = local_rectangularize_cell(rows)

if isempty(rows)
    C = cell(0, 0);
    return;
end

nRows = size(rows, 1);
nCols = 0;
for i = 1:nRows
    nCols = max(nCols, size(rows(i, :), 2));
end

C = repmat({''}, nRows, nCols);
for i = 1:nRows
    row_i = rows(i, :);
    for j = 1:size(row_i, 2)
        C{i, j} = row_i{j};
    end
end

end

function cfg = local_merge_cfg(cfg, patchCfg)

fns = fieldnames(patchCfg);
for i = 1:numel(fns)
    cfg.(fns{i}) = patchCfg.(fns{i});
end

end
