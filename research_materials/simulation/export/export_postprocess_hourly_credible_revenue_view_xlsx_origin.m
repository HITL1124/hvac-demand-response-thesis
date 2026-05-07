function out_export = export_postprocess_hourly_credible_revenue_view_xlsx_origin(inReserve, inCred, cfg)
% =========================================================================
% 导出：可信备用域后处理结果 -> 三个 XLSX 文件
% -------------------------------------------------------------------------
% 文件1：所有小时的成本曲线查看表（不同置信度分不同表单）
% 文件2：净成本空间曲面数据（不同置信度分不同表单）
% 文件3：Origin 友好格式的逐小时成本曲线（不同置信度分不同表单）
%
% Origin 友好格式：
%   每个小时两列，第一列为备用水平 R，第二列为成本；
%   横向依次排为 [h1_R, h1_cost, h2_R, h2_cost, ...]。
%
% 默认成本字段为 delta_net_cred，可通过 cfg.origin_curve_field 修改。
%
% 常用调用：
%   out_export = export_postprocess_hourly_credible_revenue_view_xlsx_origin();
% =========================================================================

%% 0) 默认输入
if nargin < 1 || isempty(inReserve)
    inReserve = project_data_file('reserve','hourly_reserve_costcurve_all_beta.mat');
end
if nargin < 2 || isempty(inCred)
    inCred = project_data_file('reserve','hourly_credible_feasibility_v2_all_beta.mat');
end
if nargin < 3
    cfg = struct();
end
cfg = local_fill_defaults(cfg);

if ~exist(cfg.outdir, 'dir')
    mkdir(cfg.outdir);
end

curve_xlsx   = fullfile(cfg.outdir, cfg.curve_xlsx_name);
surface_xlsx = fullfile(cfg.outdir, cfg.surface_xlsx_name);
origin_xlsx  = fullfile(cfg.outdir, cfg.origin_xlsx_name);

if exist(curve_xlsx, 'file') == 2, delete(curve_xlsx); end
if exist(surface_xlsx, 'file') == 2, delete(surface_xlsx); end
if exist(origin_xlsx, 'file') == 2, delete(origin_xlsx); end

%% 1) 确定 beta 列表
if isfield(cfg,'beta_list') && ~isempty(cfg.beta_list)
    beta_list = cfg.beta_list(:).';
else
    beta_list = local_detect_common_beta_list(inReserve, inCred);
end
assert(~isempty(beta_list), '未能识别可导出的 beta 列表。');

%% 2) 逐个 beta 导出
out_export = struct();
out_export.case_label = 'export_postprocess_hourly_credible_revenue_view_xlsx_origin';
out_export.beta_list = beta_list(:);
out_export.curve_xlsx = curve_xlsx;
out_export.surface_xlsx = surface_xlsx;
out_export.origin_xlsx = origin_xlsx;
out_export.sheet_names = cell(numel(beta_list),1);
out_export.n_rows_curve = zeros(numel(beta_list),1);
out_export.surface_sizes = cell(numel(beta_list),1);
out_export.origin_sizes = cell(numel(beta_list),1);

for ib = 1:numel(beta_list)
    beta = beta_list(ib);
    sheet_name = local_beta_to_sheet(beta);
    out_export.sheet_names{ib} = sheet_name;

    cfg_i = cfg;
    cfg_i.beta_select = beta;
    cfg_i.makePlots = false;

    out_market = run_postprocess_hourly_credible_revenue_view_full(inReserve, inCred, cfg_i);

    Tcurve = local_build_curve_long_table(out_market);
    writetable(Tcurve, curve_xlsx, 'Sheet', sheet_name, 'WriteMode', 'overwritesheet');
    out_export.n_rows_curve(ib) = height(Tcurve);

    Tsurf = local_build_netcost_surface_grid_table(out_market, cfg.surface_interp_method);
    writetable(Tsurf, surface_xlsx, 'Sheet', sheet_name, 'WriteMode', 'overwritesheet');
    out_export.surface_sizes{ib} = size(Tsurf);

    Torigin = local_build_origin_curve_table(out_market, cfg.origin_curve_field);
    writetable(Torigin, origin_xlsx, 'Sheet', sheet_name, 'WriteMode', 'overwritesheet');
    out_export.origin_sizes{ib} = size(Torigin);

    fprintf('\n[export] beta = %.2f 已完成\n', beta);
    fprintf('  查看表单  : %s -> %s\n', sheet_name, curve_xlsx);
    fprintf('  曲面表单  : %s -> %s\n', sheet_name, surface_xlsx);
    fprintf('  Origin表单: %s -> %s\n', sheet_name, origin_xlsx);
end

fprintf('\n============================================================\n');
fprintf('XLSX 导出完成\n');
fprintf('查看数据文件 : %s\n', out_export.curve_xlsx);
fprintf('曲面数据文件 : %s\n', out_export.surface_xlsx);
fprintf('Origin文件   : %s\n', out_export.origin_xlsx);
fprintf('beta 列表    : '); fprintf('%.2f ', beta_list); fprintf('\n');
fprintf('Origin成本列 : %s\n', cfg.origin_curve_field);
fprintf('============================================================\n');

end

function cfg = local_fill_defaults(cfg)
if ~isfield(cfg,'outdir') || isempty(cfg.outdir)
    cfg.outdir = project_data_file('exports', '06_Fig12_Fig13_cost_curves_surfaces');
end
if ~isfield(cfg,'curve_xlsx_name') || isempty(cfg.curve_xlsx_name)
    cfg.curve_xlsx_name = 'export_hourly_credible_cost_curves_all_beta.xlsx';
end
if ~isfield(cfg,'surface_xlsx_name') || isempty(cfg.surface_xlsx_name)
    cfg.surface_xlsx_name = 'export_hourly_credible_netcost_surface_all_beta.xlsx';
end
if ~isfield(cfg,'origin_xlsx_name') || isempty(cfg.origin_xlsx_name)
    cfg.origin_xlsx_name = 'export_hourly_credible_cost_curves_for_origin_all_beta.xlsx';
end
if ~isfield(cfg,'surface_interp_method') || isempty(cfg.surface_interp_method)
    cfg.surface_interp_method = 'linear';
end
if ~isfield(cfg,'origin_curve_field') || isempty(cfg.origin_curve_field)
    cfg.origin_curve_field = 'delta_net_cred';
end
if ~isfield(cfg,'beta_list')
    cfg.beta_list = [];
end
end

function beta_list = local_detect_common_beta_list(inReserve, inCred)
Sres = local_load_any(inReserve);
Scred = local_load_any(inCred);

beta_res = local_extract_beta_list_from_reserve(Sres);
beta_cred = local_extract_beta_list_from_cred(Scred);

if isempty(beta_res) && ~isempty(beta_cred)
    beta_list = beta_cred;
    return;
elseif isempty(beta_cred) && ~isempty(beta_res)
    beta_list = beta_res;
    return;
elseif isempty(beta_res) && isempty(beta_cred)
    beta_list = [];
    return;
end

beta_res_r  = round(beta_res(:), 6);
beta_cred_r = round(beta_cred(:), 6);
beta_common = intersect(beta_res_r, beta_cred_r, 'stable');

if isempty(beta_common)
    beta_list = unique(beta_res(:).', 'stable');
else
    beta_list = beta_common(:).';
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

function beta_list = local_extract_beta_list_from_reserve(S)
beta_list = [];
if isfield(S,'results_all') && ~isempty(S.results_all)
    R = S.results_all;
    if isstruct(R)
        if isfield(R,'beta_use')
            beta_list = [R.beta_use];
        elseif isfield(R,'out')
            tmp = nan(1, numel(R));
            for i = 1:numel(R)
                tmp(i) = local_get_beta_from_out(R(i).out);
            end
            beta_list = tmp;
        end
        return;
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

function beta_list = local_extract_beta_list_from_cred(S)
beta_list = [];
if isfield(S,'cred')
    S = S.cred;
end

if isfield(S,'results_all') && ~isempty(S.results_all)
    R = S.results_all;
    if iscell(R)
        tmp = nan(1, numel(R));
        for i = 1:numel(R)
            tmp(i) = local_get_beta_from_cred(R{i});
        end
        beta_list = tmp;
        return;
    elseif isstruct(R)
        tmp = nan(1, numel(R));
        for i = 1:numel(R)
            tmp(i) = local_get_beta_from_cred(R(i));
        end
        beta_list = tmp;
        return;
    end
end

if isfield(S,'summary')
    beta_list = local_get_beta_from_cred(S);
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

function beta = local_get_beta_from_cred(credOne)
beta = NaN;
if isempty(credOne)
    return;
end
if isfield(credOne,'meta') && isfield(credOne.meta,'beta_screen') && ~isempty(credOne.meta.beta_screen)
    beta = double(credOne.meta.beta_screen);
elseif isfield(credOne,'cfg') && isfield(credOne.cfg,'beta_screen') && ~isempty(credOne.cfg.beta_screen)
    beta = double(credOne.cfg.beta_screen);
elseif isfield(credOne,'beta_screen') && ~isempty(credOne.beta_screen)
    beta = double(credOne.beta_screen);
end
end

function T = local_build_curve_long_table(out_market)
out = out_market.base;
baseline = out.baseline;
Nh = numel(out_market.hours);

rows = cell(0, 16);

for h = 1:Nh
    Hr = out_market.hours(h);
    if ~isfield(Hr,'R_grid_cred') || isempty(Hr.R_grid_cred)
        continue;
    end

    Rnat = out_market.R_nat_hour(h);
    Rcred = out_market.R_cred_hour(h);
    lam = out_market.lambdaR_hour(h);

    rows(end+1,1:16) = {sprintf('第%02d小时', h), [], [], [], [], [], [], [], [], [], [], [], [], [], [], []}; %#ok<AGROW>
    rows(end+1,1:16) = {'天然备用_kW', Rnat, '最大可信备用_kW', Rcred, '容量价格', lam, [], [], [], [], [], [], [], [], [], []}; %#ok<AGROW>
    rows(end+1,1:16) = {'点序号','区段类型','备用水平_kW','总成本','能耗成本','温度成本','容量收益','净成本','盈亏平衡价格','风量_ma','风机功率_kW','Ts_℃','基线风量_ma','基线风机功率_kW','基线Ts_℃','备注'}; %#ok<AGROW>

    n = numel(Hr.R_grid_cred);
    Ts_base_C = NaN;
    if isfield(baseline,'Ts_hour') && numel(baseline.Ts_hour) >= h
        Ts_base_C = baseline.Ts_hour(h) - 273.15;
    end
    ma_base = local_safe_pick(baseline, 'ma_hour', h);
    Pf_base = local_safe_pick(baseline, 'Pfan_hour', h);

    for i = 1:n
        Rval = Hr.R_grid_cred(i);
        if Rval <= Rnat + 1e-9
            seg_type = '天然备用零成本段';
        else
            seg_type = '可信增成本段';
        end

        rows(end+1,1:16) = { ...
            i, ...
            seg_type, ...
            Rval, ...
            local_safe_pick(Hr, 'delta_total_cred', i), ...
            local_safe_pick(Hr, 'delta_energy_cred', i), ...
            local_safe_pick(Hr, 'delta_temp_cred', i), ...
            local_safe_pick(Hr, 'revenue_cap_cred', i), ...
            local_safe_pick(Hr, 'delta_net_cred', i), ...
            local_safe_pick(Hr, 'lambdaR_break_even_cred', i), ...
            local_safe_pick(Hr, 'ma_hour_cred', i), ...
            local_safe_pick(Hr, 'Pfan_hour_cred', i), ...
            local_safe_pick(Hr, 'Ts_hour_C_cred', i), ...
            ma_base, ...
            Pf_base, ...
            Ts_base_C, ...
            ''}; %#ok<AGROW>
    end

    rows(end+1,1:16) = cell(1,16); %#ok<AGROW>
end

T = cell2table(rows);
end

function Torigin = local_build_origin_curve_table(out_market, fieldname)
Nh = numel(out_market.hours);

maxN = 0;
for h = 1:Nh
    Hr = out_market.hours(h);
    if isfield(Hr,'R_grid_cred') && ~isempty(Hr.R_grid_cred)
        maxN = max(maxN, numel(Hr.R_grid_cred));
    end
end

if maxN == 0
    Torigin = table();
    return;
end

C = cell(maxN, 2*Nh);
varNames = cell(1, 2*Nh);

for h = 1:Nh
    Hr = out_market.hours(h);
    varNames{2*h-1} = sprintf('h%02d_R_kW', h);
    varNames{2*h}   = sprintf('h%02d_%s', h, fieldname);

    if ~isfield(Hr,'R_grid_cred') || isempty(Hr.R_grid_cred)
        continue;
    end

    Rv = Hr.R_grid_cred(:);
    Zv = local_get_curve_vector(Hr, fieldname, numel(Rv));

    C(1:numel(Rv), 2*h-1) = num2cell(Rv);
    C(1:numel(Zv), 2*h)   = num2cell(Zv);
end

Torigin = cell2table(C, 'VariableNames', varNames);
end

function Zv = local_get_curve_vector(Hr, fieldname, nExpect)
if isfield(Hr, fieldname) && ~isempty(Hr.(fieldname))
    Zv = Hr.(fieldname)(:);
else
    warning('未找到字段 %s，将填充 NaN。', fieldname);
    Zv = nan(nExpect,1);
end

if numel(Zv) ~= nExpect
    m = min(numel(Zv), nExpect);
    tmp = nan(nExpect,1);
    tmp(1:m) = Zv(1:m);
    Zv = tmp;
end
end

function Tsurf = local_build_netcost_surface_grid_table(out_market, interp_method)
[time_all, R_all, Z_all] = local_collect_surface_scatter(out_market, 'delta_net_cred');
Nh = numel(out_market.hours);

if isempty(R_all)
    Tsurf = table();
    return;
end

hvec = (1:Nh);
Rvec = unique(R_all(:));
[TimeGrid, RGrid] = meshgrid(hvec, Rvec);

ZGrid = griddata(time_all, R_all, Z_all, TimeGrid, RGrid, interp_method);

varNames = cell(1, Nh + 1);
varNames{1} = 'R_kW';
for h = 1:Nh
    varNames{h+1} = sprintf('h%02d', h);
end

C = num2cell([Rvec, ZGrid]);
Tsurf = cell2table(C, 'VariableNames', varNames);
end

function [time_all, R_all, Z_all] = local_collect_surface_scatter(out_market, fieldname)
time_all = [];
R_all = [];
Z_all = [];
for h = 1:numel(out_market.hours)
    Hr = out_market.hours(h);
    if ~isfield(Hr,'R_grid_cred') || isempty(Hr.R_grid_cred)
        continue;
    end
    if ~isfield(Hr,fieldname) || isempty(Hr.(fieldname))
        continue;
    end
    R_all = [R_all; Hr.R_grid_cred(:)]; %#ok<AGROW>
    Z_all = [Z_all; Hr.(fieldname)(:)]; %#ok<AGROW>
    time_all = [time_all; h*ones(numel(Hr.R_grid_cred),1)]; %#ok<AGROW>
end

mask = isfinite(time_all) & isfinite(R_all) & isfinite(Z_all);
time_all = time_all(mask);
R_all = R_all(mask);
Z_all = Z_all(mask);
end

function v = local_safe_pick(S, fn, idx)
v = NaN;
if ~isfield(S, fn) || isempty(S.(fn))
    return;
end
x = S.(fn);
if numel(x) >= idx
    v = x(idx);
end
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
