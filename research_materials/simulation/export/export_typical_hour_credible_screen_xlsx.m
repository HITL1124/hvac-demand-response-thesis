function out = export_typical_hour_credible_screen_xlsx(inCred, cfg)
% =========================================================================
% 导出指定置信度下"全部小时"的可信判定数据到一个 xlsx 表单
% -------------------------------------------------------------------------
% 说明：
%   1) 默认读取 hourly_credible_feasibility_v2_all_beta.mat；
%   2) 默认导出某个 beta（如 0.90）下的全部 24 个小时；
%   3) 全部内容只写入一个 sheet，并按小时分块竖排；
%   4) 温度轨迹/风险边界按 ℃ 导出；
%   5) mu_theta 与 z_beta*sigma_theta 为温差，数值与 K 相同，直接按 ℃ 标注。
%
% 每个小时块包含两部分：
%   A. 4 个子步的详细宽表
%      - 风险下界/上界
%      - 各备用水平下的名义室温轨迹
%      - 判定下轨 / 判定上轨
%      - mu_theta
%      - z_beta*sigma_theta
%   B. 该小时所有备用水平的汇总表
%
% 默认调用：
%   export_typical_hour_credible_screen_xlsx();
%
% 可选调用：
%   cfg = struct();
%   cfg.beta_select = 0.90;
%   export_typical_hour_credible_screen_xlsx([], cfg);
%
%   cfg = struct();
%   cfg.beta_select = 0.90;
%   cfg.hour_list = [12 13];
%   export_typical_hour_credible_screen_xlsx([], cfg);
% =========================================================================

%% 0) 默认输入
if nargin < 1 || isempty(inCred)
    inCred = project_data_file('reserve','hourly_credible_feasibility_v2_all_beta.mat');
end
if nargin < 2
    cfg = struct();
end
cfg = local_fill_defaults(cfg);

if ~isfield(cfg,'outfile') || isempty(cfg.outfile)
    cfg.outfile = project_data_file('exports', '05_Fig10_Fig11_workpoint_risk', ...
        sprintf('export_credible_screen_beta_%02d_all_hours.xlsx', round(100*cfg.beta_select)));
end

outdir = fileparts(cfg.outfile);
if ~isempty(outdir) && ~exist(outdir, 'dir')
    mkdir(outdir);
end

%% 1) 读取并选定 beta
[credOne, beta_use] = local_load_cred_any(inCred, cfg.beta_select, cfg.beta_tol);
assert(isfield(credOne,'hours') && ~isempty(credOne.hours), '结果中不存在 hours 字段。');
Nh = numel(credOne.hours);

hour_list = cfg.hour_list(:).';
if isempty(hour_list)
    hour_list = 1:Nh;
end
hour_list = unique(hour_list, 'stable');
hour_list = hour_list(hour_list >= 1 & hour_list <= Nh);
assert(~isempty(hour_list), '筛选后没有可导出的小时。');

z_beta = local_pick_zbeta(credOne, cfg);

%% 2) 按小时分块构造单表内容（只保留一个 sheet）
rows = {};

rows{end+1,1} = {'beta_select', beta_use, 'z_beta', z_beta, '导出小时数', numel(hour_list), '温度单位', '℃'}; %#ok<AGROW>
rows{end+1,1} = {''}; %#ok<AGROW>

for hh = 1:numel(hour_list)
    h = hour_list(hh);
    Hr = credOne.hours(h);

    if ~isfield(Hr,'R_grid_cred') || isempty(Hr.R_grid_cred) || ...
       ~isfield(Hr,'Tref_work_15') || isempty(Hr.Tref_work_15)
        rows{end+1,1} = {sprintf('第%02d小时', h), '该小时无可导出数据'}; %#ok<AGROW>
        rows{end+1,1} = {''}; %#ok<AGROW>
        continue;
    end

    ns = size(Hr.Tref_work_15, 1);
    R_all = Hr.R_grid_cred(:);
    nR_all = numel(R_all);

    pick = true(nR_all,1);
    if cfg.only_credible && isfield(Hr,'is_credible') && ~isempty(Hr.is_credible)
        pick = pick & logical(Hr.is_credible(:));
    end
    if cfg.only_finite
        pick = pick & isfinite(R_all);
    end
    idx_pick = find(pick);

    rows{end+1,1} = {sprintf('第%02d小时', h), '导出备用点数', numel(idx_pick)}; %#ok<AGROW>

    if isempty(idx_pick)
        rows{end+1,1} = {'该小时筛选后没有可导出的备用点'}; %#ok<AGROW>
        rows{end+1,1} = {''}; %#ok<AGROW>
        continue;
    end

    % ---------- A. 子步详细宽表 ----------
    theta_lb = local_pick_common_col(Hr.theta_risk_lb_15, ns);
    theta_ub = local_pick_common_col(Hr.theta_risk_ub_15, ns);
    theta_lb_C = local_abs_temp_to_celsius(theta_lb);
    theta_ub_C = local_abs_temp_to_celsius(theta_ub);

    base_ncol = 4;   % 子步序号、子步标签、风险下界、风险上界
    perR_ncol = 5;   % 名义室温、判定下轨、判定上轨、mu_theta、z_beta sigma_theta
    nR = numel(idx_pick);
    ncol = base_ncol + perR_ncol * nR;

    detail = cell(ns + 1, ncol);
    detail(1,1:4) = {'子步序号','子步标签','风险下界_℃','风险上界_℃'};

    for j = 1:ns
        detail{j+1,1} = j;
        detail{j+1,2} = sprintf('h%02d-s%d', h, j);
        detail{j+1,3} = theta_lb_C(j);
        detail{j+1,4} = theta_ub_C(j);
    end

    for kk = 1:nR
        i = idx_pick(kk);
        r = R_all(i);
        col0 = base_ncol + (kk-1)*perR_ncol;

        Tref_C = local_abs_temp_to_celsius(local_pick_col(Hr.Tref_work_15, i, ns));
        risk_lo_C = local_abs_temp_to_celsius(local_pick_col(Hr.risk_lower_15, i, ns));
        risk_up_C = local_abs_temp_to_celsius(local_pick_col(Hr.risk_upper_15, i, ns));
        mu_theta = local_pick_col(Hr.mu_theta_15, i, ns);
        sigma_theta = local_pick_col(Hr.sigma_theta_15, i, ns);
        zsig = z_beta * sigma_theta;

        detail{1,col0+1} = sprintf('R=%.6g_名义室温_℃', r);
        detail{1,col0+2} = sprintf('R=%.6g_判定下轨_℃', r);
        detail{1,col0+3} = sprintf('R=%.6g_判定上轨_℃', r);
        detail{1,col0+4} = sprintf('R=%.6g_mu_theta_℃', r);
        detail{1,col0+5} = sprintf('R=%.6g_zbeta_sigma_theta_℃', r);

        for j = 1:ns
            detail{j+1,col0+1} = Tref_C(j);
            detail{j+1,col0+2} = risk_lo_C(j);
            detail{j+1,col0+3} = risk_up_C(j);
            detail{j+1,col0+4} = mu_theta(j);
            detail{j+1,col0+5} = zsig(j);
        end
    end

    rows{end+1,1} = {'子步明细'}; %#ok<AGROW>
    rows = local_append_block(rows, detail);
    rows{end+1,1} = {''}; %#ok<AGROW>

    % ---------- B. 备用汇总表 ----------
    sum_headers = { ...
        '备用水平_kW', ...
        '是否可信', ...
        '最早失效子步', ...
        '失效方向', ...
        '最小裕量_℃', ...
        'Ts工作点_℃', ...
        'ma工作点', ...
        'Pfan工作点_kW', ...
        'mu_theta最大值_℃', ...
        'zbeta_sigma最大值_℃'};

    sumtab = cell(nR + 1, numel(sum_headers));
    sumtab(1,:) = sum_headers;

    for kk = 1:nR
        i = idx_pick(kk);
        r = R_all(i);
        mu_theta = local_pick_col(Hr.mu_theta_15, i, ns);
        sigma_theta = local_pick_col(Hr.sigma_theta_15, i, ns);
        zsig = z_beta * sigma_theta;

        iscred = local_pick_scalar(Hr, 'is_credible', i, false);
        fail_step = local_pick_scalar(Hr, 'fail_step', i, NaN);
        fail_side = local_pick_cellstr(Hr, 'fail_side', i, '');
        margin_min = local_pick_scalar(Hr, 'margin_min', i, NaN);
        Ts_work_C = local_abs_temp_to_celsius(local_pick_scalar(Hr, 'Ts_work', i, NaN));
        ma_work = local_pick_scalar(Hr, 'ma_work', i, NaN);
        Pfan_work = local_pick_scalar(Hr, 'Pfan_work', i, NaN);

        sumtab(kk+1,:) = { ...
            r, ...
            double(iscred), ...
            fail_step, ...
            fail_side, ...
            margin_min, ...
            Ts_work_C, ...
            ma_work, ...
            Pfan_work, ...
            max(mu_theta, [], 'omitnan'), ...
            max(zsig, [], 'omitnan')};
    end

    rows{end+1,1} = {'备用汇总'}; %#ok<AGROW>
    rows = local_append_block(rows, sumtab);

    if hh < numel(hour_list)
        rows{end+1,1} = {''}; %#ok<AGROW>
        rows{end+1,1} = {''}; %#ok<AGROW>
    end
end

%% 3) 统一补齐列宽并写入一个 sheet
C = local_pad_rows(rows);
if exist(cfg.outfile,'file') == 2
    delete(cfg.outfile);
end
sheet_name = cfg.sheet_name;
writecell(C, cfg.outfile, 'Sheet', sheet_name);

%% 4) 输出
out = struct();
out.outfile = cfg.outfile;
out.beta_use = beta_use;
out.hour_list = hour_list(:);
out.z_beta = z_beta;
out.sheet_name = sheet_name;
out.n_hours = numel(hour_list);

fprintf('\n============================================================\n');
fprintf('全部小时可信判定数据已导出\n');
fprintf('输入结果          : %s\n', local_input_desc(inCred));
fprintf('beta              : %.4f\n', beta_use);
fprintf('导出小时          : '); fprintf('%d ', hour_list); fprintf('\n');
fprintf('z_beta            : %.6f\n', z_beta);
fprintf('输出文件          : %s\n', cfg.outfile);
fprintf('表单              : %s\n', sheet_name);
fprintf('温度单位          : ℃\n');
fprintf('============================================================\n');

end

% =========================================================================
% 默认参数
% =========================================================================
function cfg = local_fill_defaults(cfg)
if ~isfield(cfg,'beta_select') || isempty(cfg.beta_select), cfg.beta_select = 0.90; end
if ~isfield(cfg,'hour_list'), cfg.hour_list = []; end
if ~isfield(cfg,'beta_tol') || isempty(cfg.beta_tol), cfg.beta_tol = 1e-8; end
if ~isfield(cfg,'only_credible') || isempty(cfg.only_credible), cfg.only_credible = false; end
if ~isfield(cfg,'only_finite') || isempty(cfg.only_finite), cfg.only_finite = true; end
if ~isfield(cfg,'sheet_name') || isempty(cfg.sheet_name), cfg.sheet_name = '全部小时'; end
end

% =========================================================================
% 读取 cred 结果并选 beta
% =========================================================================
function [credOne, beta_use] = local_load_cred_any(inCred, beta_select, beta_tol)
if ischar(inCred) || isstring(inCred)
    assert(exist(inCred,'file') == 2, '未找到文件：%s', inCred);
    S = load(inCred);
else
    S = inCred;
end

cand = local_try_parse_single_cred(S);
if ~isempty(cand)
    credOne = cand;
    beta_use = local_get_beta_from_cred(credOne);
    return;
end

batch = local_try_parse_batch_cred(S);
assert(~isempty(batch), '无法从输入中识别 credible 结果结构。');

beta_list = batch.beta_list(:);
[err, idx] = min(abs(beta_list - beta_select));
assert(err <= beta_tol, '未找到匹配 beta=%.4f 的结果。', beta_select);
credOne = batch.results_all{idx};
beta_use = local_get_beta_from_cred(credOne);
end

function out = local_try_parse_single_cred(S)
out = [];
if isstruct(S) && isfield(S,'hours') && isfield(S,'summary')
    out = S;
    return;
end
if isstruct(S)
    fns = fieldnames(S);
    for i = 1:numel(fns)
        v = S.(fns{i});
        if isstruct(v) && isfield(v,'hours') && isfield(v,'summary')
            out = v;
            return;
        end
    end
end
end

function out = local_try_parse_batch_cred(S)
out = [];
if isstruct(S) && isfield(S,'results_all') && isfield(S,'beta_list')
    out = S;
    return;
end
if isstruct(S)
    fns = fieldnames(S);
    for i = 1:numel(fns)
        v = S.(fns{i});
        if isstruct(v) && isfield(v,'results_all') && isfield(v,'beta_list')
            out = v;
            return;
        end
    end
end
end

function beta = local_get_beta_from_cred(credOne)
beta = NaN;
if isfield(credOne,'cfg') && isstruct(credOne.cfg) && isfield(credOne.cfg,'beta_screen')
    beta = credOne.cfg.beta_screen;
elseif isfield(credOne,'meta') && isstruct(credOne.meta) && isfield(credOne.meta,'beta_screen')
    beta = credOne.meta.beta_screen;
end
end

function z = local_pick_zbeta(credOne, cfg)
z = NaN;
if isfield(credOne,'cfg') && isstruct(credOne.cfg) && isfield(credOne.cfg,'z_beta') && ~isempty(credOne.cfg.z_beta)
    z = double(credOne.cfg.z_beta);
elseif isfield(credOne,'meta') && isstruct(credOne.meta) && isfield(credOne.meta,'z_beta') && ~isempty(credOne.meta.z_beta)
    z = double(credOne.meta.z_beta);
end
if ~isfinite(z)
    z = -sqrt(2) * erfcinv(2*cfg.beta_select);
end
end

% =========================================================================
% 小工具
% =========================================================================
function rows = local_append_block(rows, blk)
for ii = 1:size(blk,1)
    rows{end+1,1} = blk(ii,:); %#ok<AGROW>
end
end

function C = local_pad_rows(rows)
maxw = 1;
for i = 1:numel(rows)
    if ischar(rows{i}) || isstring(rows{i}) || isnumeric(rows{i}) || islogical(rows{i})
        rows{i} = {rows{i}};
    end
    maxw = max(maxw, size(rows{i},2));
end
C = cell(numel(rows), maxw);
for i = 1:numel(rows)
    ri = rows{i};
    if isempty(ri)
        continue;
    end
    C(i,1:size(ri,2)) = ri;
end
end

function x = local_pick_common_col(A, ns)
if isempty(A)
    x = nan(ns,1);
    return;
end
A = double(A);
if size(A,1) ~= ns && size(A,2) == ns
    A = A.';
end
if size(A,1) ~= ns
    x = nan(ns,1);
else
    x = A(:,1);
end
end

function x = local_pick_col(A, i, ns)
if isempty(A)
    x = nan(ns,1);
    return;
end
A = double(A);
if size(A,1) ~= ns && size(A,2) == ns
    A = A.';
end
if size(A,1) ~= ns || i > size(A,2)
    x = nan(ns,1);
else
    x = A(:,i);
end
end

function v = local_pick_scalar(S, field, i, defaultVal)
v = defaultVal;
if isfield(S, field) && ~isempty(S.(field))
    x = S.(field);
    if isnumeric(x) || islogical(x)
        x = x(:);
        if i <= numel(x)
            v = x(i);
        end
    end
end
end

function s = local_pick_cellstr(S, field, i, defaultVal)
s = defaultVal;
if isfield(S, field) && ~isempty(S.(field))
    x = S.(field);
    if iscell(x)
        if i <= numel(x)
            xi = x{i};
            if isstring(xi) || ischar(xi)
                s = char(string(xi));
            end
        end
    elseif isstring(x) || ischar(x)
        s = char(string(x));
    end
end
end

function y = local_abs_temp_to_celsius(x)
y = double(x);
if ~isempty(y)
    mask = isfinite(y) & (abs(y) > 100);
    y(mask) = y(mask) - 273.15;
end
end

function s = local_input_desc(in)
if ischar(in) || isstring(in)
    s = char(in);
else
    s = 'struct input';
end
end
