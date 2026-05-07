function out_export = export_hourly_max_feasible_and_credible_reserve_xlsx(cfg)
% =========================================================================
% 导出不同置信度下的：
%   1) 逐小时最大可行备用
%   2) 逐小时最大可信备用
% 保存为 Excel 文件，便于横向比较不同 beta。
%
% 默认优先读取已保存的 MAT：
%   data/reserve/hourly_reserve_costcurve_all_beta.mat
%   data/reserve/hourly_credible_feasibility_v2_all_beta.mat
%
% 若批量 MAT 不存在，则尝试逐个读取：
%   hourly_reserve_costcurve_beta_XX.mat
%   hourly_credible_feasibility_v2_beta_XX.mat
%
% 可选：当文件缺失时允许自动补跑（默认 false，避免重复计算）
%
% 常用调用：
%   out_export = export_hourly_max_feasible_and_credible_reserve_xlsx();
%
%   cfg = struct();
%   cfg.beta_list = [0.80 0.85 0.90 0.95];
%   out_export = export_hourly_max_feasible_and_credible_reserve_xlsx(cfg);
% =========================================================================

if nargin < 1
    cfg = struct();
end
cfg = local_fill_defaults(cfg);

if ~exist(cfg.outdir, 'dir')
    mkdir(cfg.outdir);
end

% 1) 读取 reserve / credible 结果
reserveMap = local_collect_reserve_results(cfg);
credMap    = local_collect_credible_results(cfg);

beta_req = cfg.beta_list(:).';
beta_res = reserveMap.beta_list(:).';
beta_crd = credMap.beta_list(:).';

beta_use = beta_req(ismember(round(100*beta_req), round(100*intersect(beta_res, beta_crd))));
if isempty(beta_use)
    error('未找到同时存在于 reserve 与 credible 结果中的 beta。');
end

Nh = local_detect_Nh(reserveMap, credMap, beta_use(1));
hvec = (1:Nh).';
nb = numel(beta_use);

Rnat_mat  = nan(Nh, nb);
Rmax_mat  = nan(Nh, nb);
Rcred_mat = nan(Nh, nb);
ratio_mat = nan(Nh, nb);

for ib = 1:nb
    beta = beta_use(ib);
    out_i  = local_get_reserve_out_by_beta(reserveMap, beta);
    cred_i = local_get_cred_by_beta(credMap, beta);

    Rnat  = local_get_Rnat_hour(out_i, Nh);
    Rmax  = local_get_Rmax_hour(out_i, cred_i, Nh);
    Rcred = local_get_Rcred_hour(cred_i, Nh);

    Rnat_mat(:,ib)  = Rnat(:);
    Rmax_mat(:,ib)  = Rmax(:);
    Rcred_mat(:,ib) = Rcred(:);

    tmp = nan(Nh,1);
    idx = isfinite(Rmax) & abs(Rmax) > cfg.zero_tol;
    tmp(idx) = Rcred(idx) ./ Rmax(idx);
    ratio_mat(:,ib) = tmp;
end

% 2) 写 Excel
xlsxFile = fullfile(cfg.outdir, cfg.xlsx_name);
if exist(xlsxFile, 'file') == 2
    delete(xlsxFile);
end

local_write_sheet_wide(xlsxFile, '最大可行备用_宽表', hvec, beta_use, Rmax_mat, '最大可行备用_kW');
local_write_sheet_wide(xlsxFile, '最大可信备用_宽表', hvec, beta_use, Rcred_mat, '最大可信备用_kW');
local_write_sheet_wide(xlsxFile, '天然备用_宽表',     hvec, beta_use, Rnat_mat,  '天然备用_kW');
local_write_summary_sheet(xlsxFile, '汇总对照_宽表', hvec, beta_use, Rnat_mat, Rmax_mat, Rcred_mat, ratio_mat);
local_write_long_sheet(xlsxFile, '长表_逐小时逐置信度', hvec, beta_use, Rnat_mat, Rmax_mat, Rcred_mat, ratio_mat);

% 3) 返回信息
out_export = struct();
out_export.file = xlsxFile;
out_export.beta_list = beta_use(:);
out_export.hour = hvec;
out_export.R_nat_hour = Rnat_mat;
out_export.R_max_hour = Rmax_mat;
out_export.R_cred_hour = Rcred_mat;
out_export.ratio_cred_over_max = ratio_mat;
out_export.reserve_source = reserveMap.source_used;
out_export.credible_source = credMap.source_used;

fprintf('\n============================================================\n');
fprintf('最大可行备用/最大可信备用导出完成。\n');
fprintf('Excel 已保存到: %s\n', xlsxFile);
fprintf('beta_list       : '); fprintf('%.2f ', beta_use); fprintf('\n');
fprintf('============================================================\n');

end

% =========================================================================
% 默认参数
% =========================================================================
function cfg = local_fill_defaults(cfg)

if ~isfield(cfg, 'outdir') || isempty(cfg.outdir)
    cfg.outdir = project_data_file('exports', '04_Fig9_Fig14_reserve_summary');
end
if ~isfield(cfg, 'reserve_dir') || isempty(cfg.reserve_dir)
    cfg.reserve_dir = project_data_file('reserve');
end
if ~isfield(cfg, 'reserve_all_beta_file') || isempty(cfg.reserve_all_beta_file)
    cfg.reserve_all_beta_file = fullfile(cfg.reserve_dir, 'hourly_reserve_costcurve_all_beta.mat');
end
if ~isfield(cfg, 'credible_all_beta_file') || isempty(cfg.credible_all_beta_file)
    cfg.credible_all_beta_file = fullfile(cfg.reserve_dir, 'hourly_credible_feasibility_v2_all_beta.mat');
end
if ~isfield(cfg, 'beta_list') || isempty(cfg.beta_list)
    cfg.beta_list = [0.80 0.85 0.90 0.95];
end
if ~isfield(cfg, 'allow_rerun_if_missing') || isempty(cfg.allow_rerun_if_missing)
    cfg.allow_rerun_if_missing = false;
end
if ~isfield(cfg, 'zero_tol') || isempty(cfg.zero_tol)
    cfg.zero_tol = 1e-12;
end
if ~isfield(cfg, 'xlsx_name') || isempty(cfg.xlsx_name)
    cfg.xlsx_name = 'export_hourly_max_feasible_and_credible_reserve_all_beta.xlsx';
end

end

% =========================================================================
% 收集 reserve 结果
% =========================================================================
function reserveMap = local_collect_reserve_results(cfg)

reserveMap = struct();
reserveMap.items = struct('beta', {}, 'out', {});
reserveMap.beta_list = [];
reserveMap.source_used = '';

% 优先读取批量 MAT
if exist(cfg.reserve_all_beta_file, 'file') == 2
    S = load(cfg.reserve_all_beta_file);
    if isfield(S, 'results_all') && ~isempty(S.results_all)
        items = struct('beta', {}, 'out', {});
        for i = 1:numel(S.results_all)
            beta_i = local_get_beta_from_reserve_entry(S.results_all(i));
            out_i  = local_get_out_from_reserve_entry(S.results_all(i));
            items(end+1).beta = beta_i; %#ok<AGROW>
            items(end).out = out_i;
        end
        reserveMap.items = items;
        reserveMap.beta_list = [items.beta];
        reserveMap.source_used = cfg.reserve_all_beta_file;
        return;
    end
end

% 再尝试逐个 beta 的单文件
items = struct('beta', {}, 'out', {});
for ib = 1:numel(cfg.beta_list)
    beta = cfg.beta_list(ib);
    onefile = fullfile(cfg.reserve_dir, sprintf('hourly_reserve_costcurve_beta_%02d.mat', round(100*beta)));
    if exist(onefile, 'file') == 2
        S = load(onefile);
        if isfield(S, 'out_i')
            out_i = S.out_i;
        elseif isfield(S, 'out')
            out_i = S.out;
        else
            continue;
        end
        items(end+1).beta = local_get_beta_from_out(out_i); %#ok<AGROW>
        items(end).out = out_i;
    end
end

if isempty(items) && cfg.allow_rerun_if_missing
    cfg_run = struct();
    cfg_run.run_all_beta = true;
    cfg_run.beta_list = cfg.beta_list;
    cfg_run.makePlots = false;
    run_ch3_hourly_reserve_costcurve_main_V2(cfg_run);
    reserveMap = local_collect_reserve_results(local_merge_cfg(cfg, struct('allow_rerun_if_missing', false)));
    return;
end

if isempty(items)
    error('未找到 reserve 结果文件。请先生成：%s 或各 beta 单文件。', cfg.reserve_all_beta_file);
end

reserveMap.items = items;
reserveMap.beta_list = [items.beta];
reserveMap.source_used = 'single_beta_files';

end

% =========================================================================
% 收集 credible 结果
% =========================================================================
function credMap = local_collect_credible_results(cfg)

credMap = struct();
credMap.items = struct('beta', {}, 'cred', {});
credMap.beta_list = [];
credMap.source_used = '';

% 优先读取批量 MAT
if exist(cfg.credible_all_beta_file, 'file') == 2
    S = load(cfg.credible_all_beta_file);
    if isfield(S, 'cred') && isfield(S.cred, 'results_all') && ~isempty(S.cred.results_all)
        items = struct('beta', {}, 'cred', {});
        allres = S.cred.results_all;
        if iscell(allres)
            for i = 1:numel(allres)
                cred_i = allres{i};
                beta_i = local_get_beta_from_cred(cred_i);
                items(end+1).beta = beta_i; %#ok<AGROW>
                items(end).cred = cred_i;
            end
        else
            for i = 1:numel(allres)
                cred_i = allres(i);
                beta_i = local_get_beta_from_cred(cred_i);
                items(end+1).beta = beta_i; %#ok<AGROW>
                items(end).cred = cred_i;
            end
        end
        credMap.items = items;
        credMap.beta_list = [items.beta];
        credMap.source_used = cfg.credible_all_beta_file;
        return;
    end
end

% 再尝试逐个 beta 的单文件
items = struct('beta', {}, 'cred', {});
for ib = 1:numel(cfg.beta_list)
    beta = cfg.beta_list(ib);
    onefile = fullfile(cfg.reserve_dir, sprintf('hourly_credible_feasibility_v2_beta_%02d.mat', round(100*beta)));
    if exist(onefile, 'file') == 2
        S = load(onefile);
        if isfield(S, 'cred')
            cred_i = S.cred;
        else
            continue;
        end
        items(end+1).beta = local_get_beta_from_cred(cred_i); %#ok<AGROW>
        items(end).cred = cred_i;
    end
end

if isempty(items) && cfg.allow_rerun_if_missing
    cfg_run = struct();
    cfg_run.run_all_beta = true;
    cfg_run.beta_list = cfg.beta_list;
    cfg_run.make_plot = false;
    cfg_run.save_mat = true;
    run_ch3_hourly_credible_feasibility_screen_V2(cfg.reserve_all_beta_file, [], cfg_run);
    credMap = local_collect_credible_results(local_merge_cfg(cfg, struct('allow_rerun_if_missing', false)));
    return;
end

if isempty(items)
    error('未找到 credible 结果文件。请先生成：%s 或各 beta 单文件。', cfg.credible_all_beta_file);
end

credMap.items = items;
credMap.beta_list = [items.beta];
credMap.source_used = 'single_beta_files';

end

% =========================================================================
% 获取单个 beta 的 reserve / cred
% =========================================================================
function out_i = local_get_reserve_out_by_beta(reserveMap, beta)
idx = find(round(100*[reserveMap.items.beta]) == round(100*beta), 1, 'first');
if isempty(idx)
    error('reserve 结果中未找到 beta=%.2f。', beta);
end
out_i = reserveMap.items(idx).out;
end

function cred_i = local_get_cred_by_beta(credMap, beta)
idx = find(round(100*[credMap.items.beta]) == round(100*beta), 1, 'first');
if isempty(idx)
    error('credible 结果中未找到 beta=%.2f。', beta);
end
cred_i = credMap.items(idx).cred;
end

% =========================================================================
% 提取逐小时数据
% =========================================================================
function Nh = local_detect_Nh(reserveMap, credMap, beta)
out_i  = local_get_reserve_out_by_beta(reserveMap, beta);
cred_i = local_get_cred_by_beta(credMap, beta);

if isfield(out_i, 'hours') && ~isempty(out_i.hours)
    Nh = numel(out_i.hours);
elseif isfield(cred_i, 'summary') && isfield(cred_i.summary, 'R_cred_hour')
    Nh = numel(cred_i.summary.R_cred_hour);
else
    error('无法识别小时数 Nh。');
end
end

function Rnat = local_get_Rnat_hour(out_i, Nh)
Rnat = nan(Nh,1);
if isfield(out_i, 'R_nat_hour') && ~isempty(out_i.R_nat_hour)
    Rnat = out_i.R_nat_hour(:);
elseif isfield(out_i, 'hours') && ~isempty(out_i.hours)
    for h = 1:min(Nh, numel(out_i.hours))
        if isfield(out_i.hours(h), 'R_nat')
            Rnat(h) = out_i.hours(h).R_nat;
        end
    end
end
end

function Rmax = local_get_Rmax_hour(out_i, cred_i, Nh)
Rmax = nan(Nh,1);

% 优先使用 reserve 结果中的 max_feasible_R
if isfield(out_i, 'hours') && ~isempty(out_i.hours)
    for h = 1:min(Nh, numel(out_i.hours))
        if isfield(out_i.hours(h), 'max_feasible_R') && ~isempty(out_i.hours(h).max_feasible_R)
            Rmax(h) = out_i.hours(h).max_feasible_R;
        end
    end
end

% 若 reserve 中有缺失，再尝试 credible.summary.R_max_hour 补齐
if any(~isfinite(Rmax)) && isfield(cred_i, 'summary') && isfield(cred_i.summary, 'R_max_hour')
    Rmax2 = cred_i.summary.R_max_hour(:);
    n = min(numel(Rmax2), Nh);
    idxFill = ~isfinite(Rmax(1:n)) & isfinite(Rmax2(1:n));
    Rmax(idxFill) = Rmax2(idxFill);
end
end

function Rcred = local_get_Rcred_hour(cred_i, Nh)
if isfield(cred_i, 'summary') && isfield(cred_i.summary, 'R_cred_hour') && ~isempty(cred_i.summary.R_cred_hour)
    Rcred = cred_i.summary.R_cred_hour(:);
    if numel(Rcred) ~= Nh
        Rcred = Rcred(1:min(end,Nh));
        Rcred(end+1:Nh,1) = NaN;
    end
else
    Rcred = nan(Nh,1);
end
end

% =========================================================================
% 写宽表
% =========================================================================
function local_write_sheet_wide(xlsxFile, sheetName, hvec, beta_list, M, valueLabel)

nb = numel(beta_list);
header = cell(1, nb + 1);
header{1} = '小时';
for ib = 1:nb
    header{ib+1} = sprintf('beta=%.2f', beta_list(ib));
end

C = cell(numel(hvec) + 1, nb + 1);
C(1,:) = header;
for i = 1:numel(hvec)
    C{i+1,1} = sprintf('第%02d小时', hvec(i));
    for ib = 1:nb
        C{i+1,ib+1} = M(i,ib);
    end
end

meta = {
    '统计量', valueLabel;
    '行方向', '第01小时 ~ 第24小时';
    '列方向', '不同置信度 beta';
    '说明',   '单元格数值单位均为 kW';
    };

writecell(meta, xlsxFile, 'Sheet', sheetName, 'Range', 'A1');
writecell(C, xlsxFile, 'Sheet', sheetName, 'Range', 'A6');

end

% =========================================================================
% 写汇总宽表
% =========================================================================
function local_write_summary_sheet(xlsxFile, sheetName, hvec, beta_list, Rnat_mat, Rmax_mat, Rcred_mat, ratio_mat)

nb = numel(beta_list);
header = {'小时'};
for ib = 1:nb
    b = beta_list(ib);
    header{end+1} = sprintf('beta=%.2f_天然备用_kW', b); %#ok<AGROW>
    header{end+1} = sprintf('beta=%.2f_最大可行备用_kW', b); %#ok<AGROW>
    header{end+1} = sprintf('beta=%.2f_最大可信备用_kW', b); %#ok<AGROW>
    header{end+1} = sprintf('beta=%.2f_可信可行比', b); %#ok<AGROW>
end

C = cell(numel(hvec)+1, numel(header));
C(1,:) = header;
for i = 1:numel(hvec)
    C{i+1,1} = sprintf('第%02d小时', hvec(i));
    col = 2;
    for ib = 1:nb
        C{i+1,col}   = Rnat_mat(i,ib);  col = col + 1;
        C{i+1,col}   = Rmax_mat(i,ib);  col = col + 1;
        C{i+1,col}   = Rcred_mat(i,ib); col = col + 1;
        C{i+1,col}   = ratio_mat(i,ib); col = col + 1;
    end
end

meta = {
    '说明1', '同一小时横向比较不同置信度最方便';
    '说明2', '可信可行比 = 最大可信备用 / 最大可行备用';
    '说明3', '备用单位均为 kW';
    '说明4', '若最大可行备用为 0 或 NaN，则可信可行比记为 NaN';
    };

writecell(meta, xlsxFile, 'Sheet', sheetName, 'Range', 'A1');
writecell(C, xlsxFile, 'Sheet', sheetName, 'Range', 'A7');

end

% =========================================================================
% 写长表
% =========================================================================
function local_write_long_sheet(xlsxFile, sheetName, hvec, beta_list, Rnat_mat, Rmax_mat, Rcred_mat, ratio_mat)

rows = cell(numel(hvec)*numel(beta_list) + 1, 6);
rows(1,:) = {'小时', '置信度beta', '天然备用_kW', '最大可行备用_kW', '最大可信备用_kW', '可信可行比'};

rr = 1;
for ib = 1:numel(beta_list)
    for i = 1:numel(hvec)
        rr = rr + 1;
        rows{rr,1} = sprintf('第%02d小时', hvec(i));
        rows{rr,2} = beta_list(ib);
        rows{rr,3} = Rnat_mat(i,ib);
        rows{rr,4} = Rmax_mat(i,ib);
        rows{rr,5} = Rcred_mat(i,ib);
        rows{rr,6} = ratio_mat(i,ib);
    end
end

writecell(rows, xlsxFile, 'Sheet', sheetName, 'Range', 'A1');

end

% =========================================================================
% beta / 结构提取
% =========================================================================
function beta = local_get_beta_from_reserve_entry(entry)
if isfield(entry, 'beta_use') && ~isempty(entry.beta_use)
    beta = double(entry.beta_use);
elseif isfield(entry, 'beta_target') && ~isempty(entry.beta_target)
    beta = double(entry.beta_target);
elseif isfield(entry, 'out')
    beta = local_get_beta_from_out(entry.out);
else
    error('无法从 reserve entry 中识别 beta。');
end
end

function out_i = local_get_out_from_reserve_entry(entry)
if isfield(entry, 'out')
    out_i = entry.out;
elseif isfield(entry, 'out_i')
    out_i = entry.out_i;
else
    out_i = entry;
end
end

function beta = local_get_beta_from_out(out_i)
if isfield(out_i, 'beta_use') && ~isempty(out_i.beta_use)
    beta = double(out_i.beta_use);
elseif isfield(out_i, 'mdl') && isfield(out_i.mdl, 'beta_use') && ~isempty(out_i.mdl.beta_use)
    beta = double(out_i.mdl.beta_use);
elseif isfield(out_i, 'cfg') && isfield(out_i.cfg, 'beta_target') && ~isempty(out_i.cfg.beta_target)
    beta = double(out_i.cfg.beta_target);
else
    error('无法从 reserve out 结构中识别 beta。');
end
end

function beta = local_get_beta_from_cred(cred_i)
if isfield(cred_i, 'meta') && isfield(cred_i.meta, 'beta_screen') && ~isempty(cred_i.meta.beta_screen)
    beta = double(cred_i.meta.beta_screen);
elseif isfield(cred_i, 'cfg') && isfield(cred_i.cfg, 'beta_screen') && ~isempty(cred_i.cfg.beta_screen)
    beta = double(cred_i.cfg.beta_screen);
elseif isfield(cred_i, 'beta_use') && ~isempty(cred_i.beta_use)
    beta = double(cred_i.beta_use);
else
    error('无法从 credible 结构中识别 beta。');
end
end

% =========================================================================
% 小工具
% =========================================================================
function cfg = local_merge_cfg(cfg, patch)
fn = fieldnames(patch);
for i = 1:numel(fn)
    cfg.(fn{i}) = patch.(fn{i});
end
end
