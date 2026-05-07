function out = export_baseline_fixedTs_vs_coop_xlsx(inCoop, inFix, cfg)
% =========================================================================
% 导出：固定水侧 Ts 与水风协同运行的基线对比表（xlsx）
% -------------------------------------------------------------------------
% 功能：
%   1) 读取水风协同基线结果（来自 run_ch3_hourly_reserve_costcurve_main_V2）；
%   2) 读取固定水侧 Ts 基线结果（来自 run_ch3_baseline_fixedTs_suite_V4）；
%   3) 按置信度导出 4 个表单：0.80 / 0.85 / 0.90 / 0.95；
%   4) 同一置信度下，导出全部 fixed_cases；
%   5) 每个表单包含三部分：
%        A. 小时级对比：Ts、ma、COP、功率分解、天然备用；
%        B. 15min 室温轨迹；
%        C. 15min COP 轨迹；
%
% 默认调用：
%   out = export_baseline_fixedTs_vs_coop_xlsx();
% =========================================================================

%% 0) 默认输入
if nargin < 1 || isempty(inCoop)
    inCoop = project_data_file('reserve', 'hourly_reserve_costcurve_all_beta.mat');
end
if nargin < 2 || isempty(inFix)
    inFix = project_data_file('baseline');
end
if nargin < 3
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

out = struct();
out.case_label = 'export_baseline_fixedTs_vs_coop_xlsx';
out.outfile = cfg.outfile;
out.beta_list = cfg.beta_list(:);
out.sheets = cell(numel(cfg.beta_list),1);
out.fixed_case_summary = cell(numel(cfg.beta_list),1);

%% 1) 逐个 beta 导出
for ib = 1:numel(cfg.beta_list)
    beta_tar = cfg.beta_list(ib);

    coop = local_load_coop_case(inCoop, beta_tar, cfg.beta_tol);
    [fix_cases, fix_meta] = local_load_fixed_cases_all(inFix, beta_tar, cfg, coop);

    sheet_name = sprintf('置信度%.2f', beta_tar);
    out.sheets{ib} = sheet_name;
    out.fixed_case_summary{ib} = fix_meta;

    block = local_build_sheet_block_all(coop, fix_cases, fix_meta, beta_tar, cfg);
    writecell(block, cfg.outfile, 'Sheet', sheet_name, 'Range', 'A1');
end

fprintf('\n============================================================\n');
fprintf('固定Ts vs 水风协同 基线对比表已导出完成\n');
fprintf('输出文件: %s\n', out.outfile);
fprintf('表单    : ');
for i = 1:numel(out.sheets)
    fprintf('%s  ', out.sheets{i});
end
fprintf('\n============================================================\n');

end

% =========================================================================
% 默认参数
% =========================================================================
function cfg = local_fill_defaults(cfg)

defaults.beta_list = [0.80 0.85 0.90 0.95];
defaults.beta_tol = 1e-8;
defaults.outfile = project_data_file('exports', '03_Fig6_Fig7_baseline_control_power', 'export_baseline_fixedTs_vs_coop.xlsx');
defaults.absTempThresholdK = 100;
defaults.keep_duplicate_Ts = false;

fns = fieldnames(defaults);
for i = 1:numel(fns)
    fn = fns{i};
    if ~isfield(cfg, fn) || isempty(cfg.(fn))
        cfg.(fn) = defaults.(fn);
    end
end

end

% =========================================================================
% 构造单个表单内容（导出同一 beta 下所有 fixed Ts 案例）
% =========================================================================
function C = local_build_sheet_block_all(coop, fix_cases, fix_meta, beta_tar, cfg)

nFix = numel(fix_cases);
assert(nFix >= 1, '当前 beta=%.2f 未找到任何固定 Ts 案例。', beta_tar);

% ---------------- 小时级数据 ----------------
Nh = numel(coop.Ts_hour);
h = (1:Nh).';

coop_Ts_C   = local_abs_temp_to_celsius(coop.Ts_hour(:), cfg.absTempThresholdK);
coop_ma     = coop.ma_hour(:);
coop_COP_h  = coop.COP_hour(:);
coop_Ptot   = coop.Pbase_hour(:);
coop_Php    = coop.Php_hour(:);
coop_Pfan   = coop.Pfan_hour(:);
coop_Rnat   = local_compute_rnat(coop_Pfan, coop.par);

hour_headers = {'小时', ...
    '水风协同_Ts_℃', '水风协同_ma', '水风协同_COP', ...
    '水风协同_总功率_kW', '水风协同_机组功率_kW', '水风协同_风机功率_kW', ...
    '水风协同_天然备用_kW'};

hour_data = [h, coop_Ts_C, coop_ma, coop_COP_h, coop_Ptot, coop_Php, coop_Pfan, coop_Rnat];

for j = 1:nFix
    fj = fix_cases{j};
    tag = local_case_tag(fj, j);

    Ts_C  = local_abs_temp_to_celsius(fj.Ts_hour(:), cfg.absTempThresholdK);
    ma    = fj.ma_hour(:);
    COP_h = fj.COP_hour(:);
    Ptot  = fj.Pbase_hour(:);
    Php   = fj.Php_hour(:);
    Pfan  = fj.Pfan_hour(:);
    Rnat  = local_compute_rnat(Pfan, fj.par);

    hour_headers = [hour_headers, ...
        {sprintf('%s_Ts_℃', tag), sprintf('%s_ma', tag), sprintf('%s_COP', tag), ...
         sprintf('%s_总功率_kW', tag), sprintf('%s_机组功率_kW', tag), ...
         sprintf('%s_风机功率_kW', tag), sprintf('%s_天然备用_kW', tag)}]; %#ok<AGROW>

    hour_data = [hour_data, Ts_C, ma, COP_h, Ptot, Php, Pfan, Rnat]; %#ok<AGROW>
end

% ---------------- 15min 室温轨迹 ----------------
[coop_T15, t15h, k15, Nk] = local_build_common_15min_axis(coop, fix_cases, cfg, 'temp');

temp_headers = {'15min步', '时间_h', '水风协同_室温_℃'};
temp_data = [k15, t15h, coop_T15];

for j = 1:nFix
    fj = fix_cases{j};
    tag = local_case_tag(fj, j);
    T15 = local_abs_temp_to_celsius(fj.T15(:), cfg.absTempThresholdK);
    T15 = T15(1:Nk);
    temp_headers = [temp_headers, {sprintf('%s_室温_℃', tag)}]; %#ok<AGROW>
    temp_data = [temp_data, T15]; %#ok<AGROW>
end

% ---------------- 15min COP 轨迹 ----------------
[coop_COP15, ~, ~, Nk2] = local_build_common_15min_axis(coop, fix_cases, cfg, 'cop');
Nk_use = min(Nk, Nk2);
coop_COP15 = coop_COP15(1:Nk_use);
k15_cop = k15(1:Nk_use);
t15h_cop = t15h(1:Nk_use);

cop_headers = {'15min步', '时间_h', '水风协同_COP'};
cop_data = [k15_cop, t15h_cop, coop_COP15];

for j = 1:nFix
    fj = fix_cases{j};
    tag = local_case_tag(fj, j);
    cop15 = fj.COP15(:);
    cop15 = cop15(1:Nk_use);
    cop_headers = [cop_headers, {sprintf('%s_COP', tag)}]; %#ok<AGROW>
    cop_data = [cop_data, cop15]; %#ok<AGROW>
end

% ---------------- 元信息 ----------------
maxCols = max([numel(hour_headers), numel(temp_headers), numel(cop_headers)]);

meta_lines = cell(0, maxCols);
meta_lines(end+1,:) = local_pad_row({sprintf('置信度 beta = %.2f', beta_tar)}, maxCols); %#ok<AGROW>
meta_lines(end+1,:) = local_pad_row({sprintf('固定Ts案例数 = %d', nFix)}, maxCols); %#ok<AGROW>
for j = 1:nFix
    meta_lines(end+1,:) = local_pad_row({sprintf('固定案例 %d: %s', j, fix_meta(j).case_brief)}, maxCols); %#ok<AGROW>
end
meta_lines(end+1,:) = repmat({''}, 1, maxCols); %#ok<AGROW>
meta_lines(end+1,:) = local_pad_row({'一、小时级对比（Ts、ma、COP、功率分解、天然备用）'}, maxCols); %#ok<AGROW>
meta_lines(end+1,:) = local_pad_row(hour_headers, maxCols); %#ok<AGROW>

rows_hour = local_pad_cell_matrix(num2cell(hour_data), maxCols);
sep_row = repmat({''}, 1, maxCols);

temp_title_row = local_pad_row({'二、15min室温轨迹对比'}, maxCols);
temp_header_row = local_pad_row(temp_headers, maxCols);
rows_temp = local_pad_cell_matrix(num2cell(temp_data(:,1:(2+1+nFix))), maxCols);

cop_title_row = local_pad_row({'三、15min COP轨迹对比'}, maxCols);
cop_header_row = local_pad_row(cop_headers, maxCols);
rows_cop = local_pad_cell_matrix(num2cell(cop_data(:,1:(2+1+nFix))), maxCols);

C = [meta_lines; rows_hour; sep_row; temp_title_row; temp_header_row; rows_temp; ...
     sep_row; cop_title_row; cop_header_row; rows_cop];

end

% =========================================================================
% 读取协同基线（按 beta）
% =========================================================================
function coop = local_load_coop_case(inCoop, beta_select, beta_tol)

cands = local_collect_coop_candidates(inCoop);
assert(~isempty(cands), '未找到可用的水风协同结果。');

beta_all = nan(numel(cands),1);
for i = 1:numel(cands)
    beta_all(i) = local_try_get(cands{i}, 'beta_use', nan);
end

match = abs(beta_all - beta_select) <= max(beta_tol, 1e-6);
if ~any(match)
    [~, idx] = min(abs(beta_all - beta_select));
    match(idx) = true;
end

coop = local_pack_coop_case(cands{find(match,1,'first')});

end

function cands = local_collect_coop_candidates(inCoop)
raws = local_parse_any_input(inCoop);
cands = {};
for i = 1:numel(raws)
    subs = local_parse_coop_struct(raws{i});
    if ~isempty(subs)
        cands = [cands; subs(:)]; %#ok<AGROW>
    end
end
end

function outs = local_parse_coop_struct(S)
outs = {};
if ~isstruct(S), return; end

if numel(S) > 1
    for ii = 1:numel(S)
        outs = [outs; local_parse_coop_struct(S(ii))]; %#ok<AGROW>
    end
    return;
end

if isfield(S,'baseline') && isfield(S,'mdl')
    outs = {S};
    return;
end

if isfield(S,'out_i') && isstruct(S.out_i)
    outs = [outs; local_parse_coop_struct(S.out_i)]; %#ok<AGROW>
end
if isfield(S,'out') && isstruct(S.out)
    outs = [outs; local_parse_coop_struct(S.out)]; %#ok<AGROW>
end
if isfield(S,'results_all')
    R = S.results_all;
    if iscell(R)
        for i = 1:numel(R)
            outs = [outs; local_parse_coop_struct(R{i})]; %#ok<AGROW>
        end
    elseif isstruct(R)
        for i = 1:numel(R)
            outs = [outs; local_parse_coop_struct(R(i))]; %#ok<AGROW>
        end
    end
end

fns = fieldnames(S);
if numel(fns) == 1
    x = S.(fns{1});
    if isstruct(x)
        outs = [outs; local_parse_coop_struct(x)]; %#ok<AGROW>
    end
end

end

function coop = local_pack_coop_case(out)
coop = struct();
coop.case_label = '水风协同';
coop.beta_use = local_try_get(out, 'beta_use', nan);
coop.mdl = local_try_get(out, 'mdl', struct());
coop.par = local_extract_par_from_case(out, []);
base = local_get_required_field(out, 'baseline');

coop.Ts_hour = local_get_required_series(base, {'Ts_hour'});
coop.ma_hour = local_get_required_series(base, {'ma_hour'});
coop.T15 = local_get_required_series(base, {'T15','theta15','Tr15'});
coop.COP15 = local_get_required_series(base, {'COP_15min','COP15','COP'});
coop.Pbase_hour = local_get_required_hour_series(base, {'Pbase_hour','Ptot_hour','Ptot'}, coop.mdl, []);
coop.Php_hour = local_get_required_hour_series(base, {'Php_hour','Php'}, coop.mdl, []);
coop.Pfan_hour = local_get_required_hour_series(base, {'Pfan_hour','Pfan'}, coop.mdl, []);
coop.COP_hour = local_get_required_hour_series(base, {'COP_hour'}, coop.mdl, coop.COP15);
coop.ns = local_get_ns_from_case_like(out, coop.T15);
end

% =========================================================================
% 读取固定 Ts 结果（按 beta，读取所有 fixed_case）
% =========================================================================
function [fix_cases, meta] = local_load_fixed_cases_all(inFix, beta_select, cfg, coop)

cands = local_collect_fixed_outs(inFix);
assert(~isempty(cands), '未找到可用的固定 Ts 结果。');

beta_all = nan(numel(cands),1);
for i = 1:numel(cands)
    beta_all(i) = local_try_get(cands{i}, 'beta_use', local_try_get(cands{i}, 'beta_target', nan));
end

match = abs(beta_all - beta_select) <= max(cfg.beta_tol, 1e-6);
if ~any(match)
    [~, idx_beta] = min(abs(beta_all - beta_select));
    match(idx_beta) = true;
end

cands_beta = cands(match);
fix_cases = {};
meta = struct([]);
count = 0;

for i = 1:numel(cands_beta)
    out_fix = cands_beta{i};
    assert(isfield(out_fix,'fixed_cases') && ~isempty(out_fix.fixed_cases), ...
        '匹配到的固定 Ts 结果中未找到 fixed_cases。');

    srcBrief = local_try_get(out_fix, 'saved_mat', '结构体/未记录文件路径');
    if ischar(srcBrief) || isstring(srcBrief)
        [~,nm,ext] = fileparts(char(srcBrief));
        srcBrief = [nm, ext];
    else
        srcBrief = '结构体输入';
    end

    for j = 1:numel(out_fix.fixed_cases)
        count = count + 1;
        packed = local_pack_fixed_case(out_fix.fixed_cases(j), out_fix, coop, count);
        fix_cases{count,1} = packed; %#ok<AGROW>

        meta(count,1).beta_use = local_try_get(out_fix, 'beta_use', local_try_get(out_fix, 'beta_target', nan)); %#ok<AGROW>
        meta(count,1).source_brief = srcBrief; %#ok<AGROW>
        meta(count,1).source_index = i; %#ok<AGROW>
        meta(count,1).case_index = j; %#ok<AGROW>
        meta(count,1).Ts_fixed_C = packed.Ts_fixed_C; %#ok<AGROW>
        if isfinite(packed.Ts_fixed_C)
            meta(count,1).case_brief = sprintf('%s | 第%d个fixed_case | Ts=%.1f℃', ...
                srcBrief, j, packed.Ts_fixed_C); %#ok<AGROW>
        else
            meta(count,1).case_brief = sprintf('%s | 第%d个fixed_case', srcBrief, j); %#ok<AGROW>
        end
    end
end

assert(~isempty(fix_cases), 'beta=%.2f 下未收集到任何 fixed_case。', beta_select);

% 排序：优先按 Ts_fixed_C 升序
Ts_all = nan(numel(fix_cases),1);
for i = 1:numel(fix_cases)
    Ts_all(i) = fix_cases{i}.Ts_fixed_C;
end
[~, order] = sortrows([isnan(Ts_all), Ts_all, (1:numel(Ts_all)).']);
fix_cases = fix_cases(order);
meta = meta(order);
Ts_all = Ts_all(order);

% 去重：同一 beta 下相同 Ts 只保留第一个
if ~cfg.keep_duplicate_Ts
    keep = true(numel(fix_cases),1);
    seen = [];
    for i = 1:numel(fix_cases)
        tsi = Ts_all(i);
        if ~isfinite(tsi)
            continue;
        end
        if any(abs(seen - tsi) <= 1e-8)
            keep(i) = false;
        else
            seen(end+1,1) = tsi; %#ok<AGROW>
        end
    end
    fix_cases = fix_cases(keep);
    meta = meta(keep);
end

end

function outs = local_collect_fixed_outs(inFix)
raws = local_parse_any_input(inFix);
outs = {};
for i = 1:numel(raws)
    subs = local_parse_fix_struct(raws{i});
    if ~isempty(subs)
        outs = [outs; subs(:)]; %#ok<AGROW>
    end
end
end

function outs = local_parse_fix_struct(S)
outs = {};
if ~isstruct(S), return; end

if numel(S) > 1
    for ii = 1:numel(S)
        outs = [outs; local_parse_fix_struct(S(ii))]; %#ok<AGROW>
    end
    return;
end

if isfield(S,'fixed_cases') && ~isempty(S.fixed_cases)
    outs = {S};
    return;
end

if isfield(S,'out') && isstruct(S.out)
    outs = [outs; local_parse_fix_struct(S.out)]; %#ok<AGROW>
end
if isfield(S,'results_all')
    R = S.results_all;
    if iscell(R)
        for i = 1:numel(R)
            outs = [outs; local_parse_fix_struct(R{i})]; %#ok<AGROW>
        end
    elseif isstruct(R)
        for i = 1:numel(R)
            outs = [outs; local_parse_fix_struct(R(i))]; %#ok<AGROW>
        end
    end
end

fns = fieldnames(S);
if numel(fns) == 1
    x = S.(fns{1});
    if isstruct(x)
        outs = [outs; local_parse_fix_struct(x)]; %#ok<AGROW>
    end
end

end

function fj = local_pack_fixed_case(raw_case, parent_out, coop, idx)

fj = struct();
fj.case_label = local_try_get(raw_case, 'case_label', sprintf('固定Ts_case_%d', idx));
fj.beta_use = local_try_get(parent_out, 'beta_use', local_try_get(parent_out, 'beta_target', nan));
fj.Ts_fixed_C = local_try_get(raw_case, 'Ts_fixed_C', nan);
fj.par = local_extract_par_from_case(raw_case, coop.par);

fj.Ts_hour = local_get_required_series(raw_case, {'Ts_hour'});
fj.ma_hour = local_get_required_series(raw_case, {'ma_hour'});
fj.T15 = local_get_required_series(raw_case, {'T15','theta15','Tr15'});
fj.COP15 = local_get_required_series(raw_case, {'COP_15min','COP15','COP'});
fj.Pbase_hour = local_get_required_hour_series(raw_case, {'Pbase_hour','Ptot_hour','Ptot'}, [], []);
fj.Php_hour = local_get_required_hour_series(raw_case, {'Php_hour','Php'}, [], []);
fj.Pfan_hour = local_get_required_hour_series(raw_case, {'Pfan_hour','Pfan'}, [], []);
fj.COP_hour = local_get_required_hour_series(raw_case, {'COP_hour'}, [], fj.COP15);
fj.ns = local_get_ns_from_case_like(raw_case, fj.T15);

end

% =========================================================================
% 通用加载与辅助
% =========================================================================
function raws = local_parse_any_input(in)
raws = {};
if ischar(in) || isstring(in)
    p = char(in);
    if exist(p, 'dir') == 7
        L = dir(fullfile(p, '*.mat'));
        for i = 1:numel(L)
            raws{end+1,1} = load(fullfile(L(i).folder, L(i).name)); %#ok<AGROW>
            % 为了保留来源路径，额外附加 saved_mat 到顶层结构并不可靠，这里在后续元信息中从 out.saved_mat 读
        end
    else
        raws = {load(p)};
    end
elseif isstruct(in)
    raws = {in};
elseif iscell(in)
    for i = 1:numel(in)
        sub = local_parse_any_input(in{i});
        raws = [raws; sub(:)]; %#ok<AGROW>
    end
else
    error('输入必须是路径、文件夹、cell 或结构体。');
end
end

function par = local_extract_par_from_case(S, parFallback)
par = [];
if isstruct(S) && isfield(S,'par') && ~isempty(S.par)
    par = S.par;
elseif isstruct(S) && isfield(S,'baseline') && isstruct(S.baseline) && isfield(S.baseline,'par') && ~isempty(S.baseline.par)
    par = S.baseline.par;
elseif nargin >= 2
    par = parFallback;
end
assert(~isempty(par), '无法提取 par。');
assert(isfield(par,'Pfan_min') && isfield(par,'Pfan_max'), 'par 中缺少 Pfan_min / Pfan_max。');
end

function v = local_get_required_field(S, name)
assert(isstruct(S) && isfield(S,name) && ~isempty(S.(name)), '缺少字段：%s', name);
v = S.(name);
end

function y = local_get_required_series(S, names)
y = [];
for i = 1:numel(names)
    nm = names{i};
    if isfield(S, nm) && ~isempty(S.(nm))
        y = S.(nm);
        break;
    end
end
if isempty(y) && isfield(S,'baseline') && isstruct(S.baseline)
    for i = 1:numel(names)
        nm = names{i};
        if isfield(S.baseline, nm) && ~isempty(S.baseline.(nm))
            y = S.baseline.(nm);
            break;
        end
    end
end
assert(~isempty(y), '缺少字段：%s', strjoin(names, ' / '));
y = double(y(:));
end

function y = local_get_required_hour_series(S, hour_field_names, mdl, y15)
y = [];
for i = 1:numel(hour_field_names)
    nm = hour_field_names{i};
    if isfield(S, nm) && ~isempty(S.(nm))
        y = double(S.(nm)(:));
        return;
    end
end
if isempty(y) && isfield(S,'baseline') && isstruct(S.baseline)
    for i = 1:numel(hour_field_names)
        nm = hour_field_names{i};
        if isfield(S.baseline, nm) && ~isempty(S.baseline.(nm))
            y = double(S.baseline.(nm)(:));
            return;
        end
    end
end
assert(~isempty(y15), '缺少小时级字段：%s', strjoin(hour_field_names, ' / '));
y15 = double(y15(:));
ns = local_get_ns_from_case_like(S, y15);
assert(mod(numel(y15), ns) == 0, '15min 序列长度不能整除 ns，无法聚合小时值。');
y = mean(reshape(y15, ns, []), 1).';
end

function ns = local_get_ns_from_case_like(S, T15)
ns = [];
if isstruct(S) && isfield(S,'mdl') && isstruct(S.mdl) && isfield(S.mdl,'ns') && ~isempty(S.mdl.ns)
    ns = double(S.mdl.ns);
elseif isstruct(S) && isfield(S,'baseline') && isstruct(S.baseline) && isfield(S.baseline,'mdl') && isstruct(S.baseline.mdl) && isfield(S.baseline.mdl,'ns') && ~isempty(S.baseline.mdl.ns)
    ns = double(S.baseline.mdl.ns);
end
if isempty(ns)
    n15 = numel(T15);
    if mod(n15,24) == 0
        ns = n15 / 24;
    else
        ns = 4;
    end
end
end

function v = local_try_get(S, fieldName, defaultVal)
v = defaultVal;
if isstruct(S) && numel(S) == 1 && isfield(S, fieldName) && ~isempty(S.(fieldName))
    v = S.(fieldName);
end
end

function xC = local_abs_temp_to_celsius(x, thresholdK)
x = double(x);
if mean(x(:), 'omitnan') > thresholdK
    xC = x - 273.15;
else
    xC = x;
end
end

function Rnat = local_compute_rnat(Pfan, par)
Pfan = double(Pfan(:));
Rnat = min(Pfan - par.Pfan_min, par.Pfan_max - Pfan);
Rnat = max(Rnat, 0);
end

function tag = local_case_tag(fj, idx)
if isfinite(fj.Ts_fixed_C)
    tag = sprintf('固定Ts%.1f℃', fj.Ts_fixed_C);
else
    tag = sprintf('固定Ts案例%d', idx);
end
end

function row = local_pad_row(row_in, ncol)
row = repmat({''}, 1, ncol);
row(1:min(numel(row_in), ncol)) = row_in(1:min(numel(row_in), ncol));
end

function A = local_pad_cell_matrix(Ain, ncol)
[nr, nc] = size(Ain);
A = repmat({''}, nr, ncol);
A(:,1:min(nc,ncol)) = Ain(:,1:min(nc,ncol));
end

function [vec15, t15h, k15, Nk] = local_build_common_15min_axis(coop, fix_cases, cfg, mode)
if strcmpi(mode, 'cop')
    vec15 = coop.COP15(:);
else
    vec15 = local_abs_temp_to_celsius(coop.T15(:), cfg.absTempThresholdK);
end
Nk = numel(vec15);
for j = 1:numel(fix_cases)
    if strcmpi(mode, 'cop')
        Nk = min(Nk, numel(fix_cases{j}.COP15));
    else
        Nk = min(Nk, numel(fix_cases{j}.T15));
    end
end
vec15 = vec15(1:Nk);
ns = coop.ns;
t15h = (0:Nk-1).' / ns;
k15 = (1:Nk).';
end
