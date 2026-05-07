function out_export = export_hourly_feasible_costcurve_xlsx(inReserve, cfg)
% =========================================================================
% 导出：未经过可信截断的逐小时成本曲线（到最大可行备用）
% -------------------------------------------------------------------------
% 数据来源：
%   run_ch3_hourly_reserve_costcurve_main_V2.m 的原始逐小时扫描结果
%
% 功能：
%   1) 导出查看型长表（不同置信度分不同表单）
%   2) 导出 Origin 友好宽表（不同置信度分不同表单）
%
% Origin 友好宽表格式：
%   每个小时两列：
%     - 第1列：备用水平 R
%     - 第2列：成本
%   横向依次排为：
%     [h01_R, h01_cost, h02_R, h02_cost, ..., h24_R, h24_cost]
%
% 默认成本字段：
%   delta_total
%
% 说明：
%   - 不做可信域截断；
%   - 导出范围为 0 ~ max_feasible_R(h)；
%   - 对 0 ~ R_nat(h) 的天然备用段，成本补为 0；
%   - R > R_nat(h) 的部分，直接取原始小时扫描中 is_feasible=true
%     且 R <= max_feasible_R(h) 的点。
%
% 常用调用：
%   out_export = export_hourly_feasible_costcurve_xlsx();
% =========================================================================

%% 0) 默认输入
if nargin < 1 || isempty(inReserve)
    inReserve = project_data_file('reserve','hourly_reserve_costcurve_all_beta.mat');
end
if nargin < 2
    cfg = struct();
end
cfg = local_fill_defaults(cfg);

if ~exist(cfg.outdir, 'dir')
    mkdir(cfg.outdir);
end

curve_xlsx  = fullfile(cfg.outdir, cfg.curve_xlsx_name);
origin_xlsx = fullfile(cfg.outdir, cfg.origin_xlsx_name);

if exist(curve_xlsx, 'file') == 2, delete(curve_xlsx); end
if exist(origin_xlsx, 'file') == 2, delete(origin_xlsx); end

%% 1) beta 列表
if isfield(cfg,'beta_list') && ~isempty(cfg.beta_list)
    beta_list = cfg.beta_list(:).';
else
    beta_list = local_detect_beta_list(inReserve);
end
assert(~isempty(beta_list), '未能识别可导出的 beta 列表。');

%% 2) 逐个 beta 导出
out_export = struct();
out_export.case_label = 'export_hourly_feasible_costcurve_xlsx';
out_export.beta_list = beta_list(:);
out_export.curve_xlsx = curve_xlsx;
out_export.origin_xlsx = origin_xlsx;
out_export.sheet_names = cell(numel(beta_list),1);

for ib = 1:numel(beta_list)
    beta = beta_list(ib);
    sheet_name = local_beta_to_sheet(beta);
    out_export.sheet_names{ib} = sheet_name;

    out_i = local_load_one_beta_reserve(inReserve, beta);

    Tcurve = local_build_curve_long_table(out_i, cfg);
    writetable(Tcurve, curve_xlsx, 'Sheet', sheet_name, 'WriteMode', 'overwritesheet');

    Torigin = local_build_origin_curve_table(out_i, cfg);
    writetable(Torigin, origin_xlsx, 'Sheet', sheet_name, 'WriteMode', 'overwritesheet');

    fprintf('\n[export feasible] beta = %.2f 已完成\n', beta);
    fprintf('  查看表单  : %s -> %s\n', sheet_name, curve_xlsx);
    fprintf('  Origin表单: %s -> %s\n', sheet_name, origin_xlsx);
end

fprintf('\n============================================================\n');
fprintf('未可信截断的逐小时成本曲线导出完成\n');
fprintf('查看数据文件 : %s\n', out_export.curve_xlsx);
fprintf('Origin文件   : %s\n', out_export.origin_xlsx);
fprintf('beta 列表    : '); fprintf('%.2f ', beta_list); fprintf('\n');
fprintf('成本字段     : %s\n', cfg.cost_field);
fprintf('============================================================\n');

end

function cfg = local_fill_defaults(cfg)
if ~isfield(cfg,'outdir') || isempty(cfg.outdir)
    cfg.outdir = project_data_file('exports', '06_Fig12_Fig13_cost_curves_surfaces');
end
if ~isfield(cfg,'curve_xlsx_name') || isempty(cfg.curve_xlsx_name)
    cfg.curve_xlsx_name = 'export_hourly_feasible_cost_curves_all_beta.xlsx';
end
if ~isfield(cfg,'origin_xlsx_name') || isempty(cfg.origin_xlsx_name)
    cfg.origin_xlsx_name = 'export_hourly_feasible_cost_curves_for_origin_all_beta.xlsx';
end
if ~isfield(cfg,'cost_field') || isempty(cfg.cost_field)
    cfg.cost_field = 'delta_total';
end
if ~isfield(cfg,'nNatSeg') || isempty(cfg.nNatSeg)
    cfg.nNatSeg = 21;
end
if ~isfield(cfg,'reserve_tol') || isempty(cfg.reserve_tol)
    cfg.reserve_tol = 1e-9;
end
if ~isfield(cfg,'beta_list')
    cfg.beta_list = [];
end
end

function beta_list = local_detect_beta_list(inReserve)
S = local_load_any(inReserve);
beta_list = [];

if isfield(S,'results_all') && ~isempty(S.results_all)
    R = S.results_all;
    if isstruct(R)
        if isfield(R,'beta_use')
            beta_list = [R.beta_use];
            return;
        elseif isfield(R,'out')
            tmp = nan(1, numel(R));
            for i = 1:numel(R)
                tmp(i) = local_get_beta_from_out(R(i).out);
            end
            beta_list = tmp;
            return;
        end
    end
end

if isfield(S,'out')
    beta_list = local_get_beta_from_out(S.out);
elseif isfield(S,'out_i')
    beta_list = local_get_beta_from_out(S.out_i);
elseif isfield(S,'hours')
    beta_list = local_get_beta_from_out(S);
end
end

function S = local_load_any(in)
if ischar(in) || isstring(in)
    assert(exist(in,'file') == 2, '未找到文件：%s', char(in));
    S = load(char(in));
elseif isstruct(in)
    S = in;
else
    error('输入必须为结构体或 MAT 文件路径。');
end
end

function beta = local_get_beta_from_out(out)
beta = NaN;
if isfield(out,'beta_use') && ~isempty(out.beta_use)
    beta = double(out.beta_use);
elseif isfield(out,'mdl') && isfield(out.mdl,'beta_use') && ~isempty(out.mdl.beta_use)
    beta = double(out.mdl.beta_use);
elseif isfield(out,'cfg') && isfield(out.cfg,'beta_target') && ~isempty(out.cfg.beta_target)
    beta = double(out.cfg.beta_target);
end
end

function out_i = local_load_one_beta_reserve(inReserve, beta_select)
S = local_load_any(inReserve);

if isfield(S,'results_all') && ~isempty(S.results_all)
    R = S.results_all;
    if isstruct(R)
        beta_all = nan(1, numel(R));
        for i = 1:numel(R)
            if isfield(R(i),'beta_use') && ~isempty(R(i).beta_use)
                beta_all(i) = double(R(i).beta_use);
            elseif isfield(R(i),'out')
                beta_all(i) = local_get_beta_from_out(R(i).out);
            end
        end
        [~, idx] = min(abs(beta_all - beta_select));
        if isfield(R(idx),'out')
            out_i = R(idx).out;
        else
            out_i = R(idx);
        end
        return;
    end
end

if isfield(S,'out')
    out_i = S.out;
elseif isfield(S,'out_i')
    out_i = S.out_i;
elseif isfield(S,'hours')
    out_i = S;
else
    error('无法从输入中识别 reserve 结果结构。');
end
end

function [Rplot, Zplot, maPlot, pfPlot, tsPlot, segType] = local_build_one_hour_curve(Hr, baseline, h, cfg)
Rnat = double(Hr.R_nat);
if isfield(Hr,'max_feasible_R') && ~isempty(Hr.max_feasible_R) && isfinite(Hr.max_feasible_R)
    Rmax = double(Hr.max_feasible_R);
else
    Rmax = Rnat;
end

R0 = max(Rnat, 0);
if R0 > cfg.reserve_tol
    R_nat_seg = linspace(0, R0, cfg.nNatSeg).';
else
    R_nat_seg = 0;
end
Z_nat_seg  = zeros(size(R_nat_seg));
ma_nat_seg = baseline.ma_hour(h)   * ones(size(R_nat_seg));
pf_nat_seg = baseline.Pfan_hour(h) * ones(size(R_nat_seg));
ts_nat_seg = (baseline.Ts_hour(h) - 273.15) * ones(size(R_nat_seg));
seg_nat = repmat({'天然备用零成本段'}, numel(R_nat_seg), 1);

R_keep = [];
Z_keep = [];
ma_keep = [];
pf_keep = [];
ts_keep = [];

if isfield(Hr,'R_grid') && ~isempty(Hr.R_grid) && isfield(Hr,'is_feasible') && ~isempty(Hr.is_feasible)
    feas = logical(Hr.is_feasible(:));
    R_all = Hr.R_grid(:);

    keep = feas & isfinite(R_all) & (R_all <= Rmax + cfg.reserve_tol) & (R_all > R0 + cfg.reserve_tol);

    if any(keep)
        R_keep = R_all(keep);
        Z_keep = local_pick_vector(Hr, cfg.cost_field, keep);
        ma_keep = local_pick_vector(Hr, 'ma_hour', keep);
        pf_keep = local_pick_vector(Hr, 'Pfan_hour', keep);
        ts_keep = local_pick_vector(Hr, 'Ts_hour_C', keep);
    end
end

seg_keep = repmat({'热可行增成本段'}, numel(R_keep), 1);

Rplot = [R_nat_seg; R_keep];
Zplot = [Z_nat_seg; Z_keep];
maPlot = [ma_nat_seg; ma_keep];
pfPlot = [pf_nat_seg; pf_keep];
tsPlot = [ts_nat_seg; ts_keep];
segType = [seg_nat; seg_keep];

[~, ia] = unique(round(Rplot, 10), 'stable');
Rplot = Rplot(ia);
Zplot = Zplot(ia);
maPlot = maPlot(ia);
pfPlot = pfPlot(ia);
tsPlot = tsPlot(ia);
segType = segType(ia);
end

function v = local_pick_vector(Hr, fieldname, keep)
if isfield(Hr, fieldname) && ~isempty(Hr.(fieldname))
    x = Hr.(fieldname)(:);
    v = x(keep);
else
    v = nan(nnz(keep),1);
end
end

function T = local_build_curve_long_table(out_i, cfg)
Nh = numel(out_i.hours);
baseline = out_i.baseline;

rows = cell(0, 15);

for h = 1:Nh
    Hr = out_i.hours(h);
    [Rplot, Zplot, maPlot, pfPlot, tsPlot, segType] = local_build_one_hour_curve(Hr, baseline, h, cfg);

    Rnat = double(Hr.R_nat);
    if isfield(Hr,'max_feasible_R') && ~isempty(Hr.max_feasible_R) && isfinite(Hr.max_feasible_R)
        Rmax = double(Hr.max_feasible_R);
    else
        Rmax = Rnat;
    end

    rows(end+1,1:15) = {sprintf('第%02d小时', h), [], [], [], [], [], [], [], [], [], [], [], [], [], []}; %#ok<AGROW>
    rows(end+1,1:15) = {'天然备用_kW', Rnat, '最大可行备用_kW', Rmax, [], [], [], [], [], [], [], [], [], [], []}; %#ok<AGROW>
    rows(end+1,1:15) = {'点序号','区段类型','备用水平_kW','成本','风量_ma','风机功率_kW','Ts_℃','基线风量_ma','基线风机功率_kW','基线Ts_℃','原始字段','beta','小时','备注1','备注2'}; %#ok<AGROW>

    Ts_base_C = baseline.Ts_hour(h) - 273.15;
    ma_base   = baseline.ma_hour(h);
    pf_base   = baseline.Pfan_hour(h);
    beta_use  = local_get_beta_from_out(out_i);

    for i = 1:numel(Rplot)
        rows(end+1,1:15) = { ...
            i, ...
            segType{i}, ...
            Rplot(i), ...
            Zplot(i), ...
            maPlot(i), ...
            pfPlot(i), ...
            tsPlot(i), ...
            ma_base, ...
            pf_base, ...
            Ts_base_C, ...
            cfg.cost_field, ...
            beta_use, ...
            h, ...
            '', ...
            ''}; %#ok<AGROW>
    end

    rows(end+1,1:15) = cell(1,15); %#ok<AGROW>
end

T = cell2table(rows);
end

function Torigin = local_build_origin_curve_table(out_i, cfg)
Nh = numel(out_i.hours);
baseline = out_i.baseline;

maxN = 0;
cache = cell(Nh, 1);
for h = 1:Nh
    [Rplot, Zplot] = local_build_one_hour_curve(out_i.hours(h), baseline, h, cfg);
    cache{h} = {Rplot, Zplot};
    maxN = max(maxN, numel(Rplot));
end

if maxN == 0
    Torigin = table();
    return;
end

C = cell(maxN, 2*Nh);
varNames = cell(1, 2*Nh);

for h = 1:Nh
    varNames{2*h-1} = sprintf('h%02d_R_kW', h);
    varNames{2*h}   = sprintf('h%02d_cost', h);

    Rplot = cache{h}{1};
    Zplot = cache{h}{2};

    C(1:numel(Rplot), 2*h-1) = num2cell(Rplot);
    C(1:numel(Zplot), 2*h)   = num2cell(Zplot);
end

Torigin = cell2table(C, 'VariableNames', varNames);
end

function sheet = local_beta_to_sheet(beta)
s = sprintf('%.2f', beta);
s = strrep(s, '.', 'p');
s = strrep(s, '-', 'm');
sheet = ['beta_' s];
if numel(sheet) > 31
    sheet = sheet(1:31);
end
end
