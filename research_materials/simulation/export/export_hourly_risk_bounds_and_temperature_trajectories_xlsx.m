function out = export_hourly_risk_bounds_and_temperature_trajectories_xlsx(in, cfg)
% =========================================================================
% 导出：不同置信度下的风险上下界 + 逐小时/逐备用水平的全天室温轨迹
% -------------------------------------------------------------------------
% 每个表单对应一个置信度。
% 每个表单包含两部分：
%   1) 全日风险下界/上界（15min 或 Nk 个时间步）
%   2) 对每个小时 h，不同备用水平扫描下的全天室温轨迹 T15
%
% 默认调用：
%   out = export_hourly_risk_bounds_and_temperature_trajectories_xlsx();
%
% 可选：
%   cfg = struct();
%   cfg.only_feasible = true;    % 仅导出可行点（默认 true）
%   cfg.include_baseline = true; % 导出基线全天室温（默认 true）
%   out = export_hourly_risk_bounds_and_temperature_trajectories_xlsx([], cfg);
% =========================================================================

%% 0) 默认输入
if nargin < 1 || isempty(in)
    in = project_data_file('reserve','hourly_reserve_costcurve_all_beta.mat');
end
if nargin < 2
    cfg = struct();
end
cfg = local_fill_defaults(cfg);

outdir = fileparts(cfg.outfile);
if ~isempty(outdir) && ~exist(outdir, 'dir')
    mkdir(outdir);
end

%% 1) 读取并统一为 beta 列表
items = local_collect_beta_items(in);
assert(~isempty(items), '未能从输入中解析出任何置信度结果。');

if exist(cfg.outfile, 'file') == 2
    delete(cfg.outfile);
end

sheet_names = cell(numel(items),1);
summary = struct([]);

%% 2) 逐个 beta 写表
for ib = 1:numel(items)
    out_i = items(ib).out;
    beta_use = local_get_beta(out_i, items(ib).beta_use);
    sheet_name = local_beta_to_sheet(beta_use);
    sheet_names{ib} = sheet_name;

    C = local_build_one_sheet(out_i, cfg);
    writecell(C, cfg.outfile, 'Sheet', sheet_name);

    summary(ib).beta_use = beta_use; %#ok<AGROW>
    summary(ib).sheet_name = sheet_name; %#ok<AGROW>
    summary(ib).Nh = double(local_get_required_subfield(out_i, {'mdl','Nh'})); %#ok<AGROW>
    summary(ib).Nk = double(local_get_required_subfield(out_i, {'mdl','H15'})); %#ok<AGROW>
end

%% 3) 输出
out = struct();
out.outfile = cfg.outfile;
out.sheet_names = sheet_names;
out.summary = summary;
out.n_beta = numel(items);
out.source = in;

fprintf('\n============================================================\n');
fprintf('风险上下界与逐小时备用扫描室温轨迹已导出\n');
fprintf('输出文件          : %s\n', cfg.outfile);
fprintf('表单数量          : %d\n', numel(sheet_names));
fprintf('表单名称          : ');
for i = 1:numel(sheet_names)
    fprintf('%s  ', sheet_names{i});
end
fprintf('\n');
fprintf('温度单位          : ℃\n');
fprintf('============================================================\n');

end

% =========================================================================
% 默认参数
% =========================================================================
function cfg = local_fill_defaults(cfg)
if ~isfield(cfg,'outfile') || isempty(cfg.outfile)
    cfg.outfile = project_data_file('exports', '05_Fig10_Fig11_workpoint_risk', ...
        'export_hourly_risk_bounds_and_temperature_trajectories.xlsx');
end
if ~isfield(cfg,'only_feasible') || isempty(cfg.only_feasible)
    cfg.only_feasible = true;
end
if ~isfield(cfg,'include_baseline') || isempty(cfg.include_baseline)
    cfg.include_baseline = true;
end
if ~isfield(cfg,'blank_rows_between_hours') || isempty(cfg.blank_rows_between_hours)
    cfg.blank_rows_between_hours = 2;
end
end

% =========================================================================
% 输入统一
% =========================================================================
function items = local_collect_beta_items(in)
S = local_load_any(in);
items = struct('beta_use', {}, 'out', {});

% 1) 直接是单个 out
if local_is_out_struct(S)
    items(1).beta_use = local_get_beta(S, NaN);
    items(1).out = S;
    return;
end

% 2) MAT 中常见包装
candidate_fields = {'out','out_i'};
for k = 1:numel(candidate_fields)
    fn = candidate_fields{k};
    if isstruct(S) && isfield(S,fn)
        v = S.(fn);
        if local_is_out_struct(v)
            items(1).beta_use = local_get_beta(v, NaN);
            items(1).out = v;
            return;
        end
    end
end

% 3) results_all 包装
if isstruct(S) && isfield(S,'results_all') && ~isempty(S.results_all)
    items = local_collect_from_results_all(S.results_all);
    if ~isempty(items), return; end
end

% 4) 直接传 results_all 数组
if isstruct(S) && numel(S) > 1
    items = local_collect_from_results_all(S);
    if ~isempty(items), return; end
end

error('无法识别输入结果格式。');
end

function tf = local_is_out_struct(x)
tf = isstruct(x) && isscalar(x) && isfield(x,'hours') && isfield(x,'mdl') && isfield(x,'baseline');
end

function items = local_collect_from_results_all(arr)
items = struct('beta_use', {}, 'out', {});
count = 0;
for i = 1:numel(arr)
    oi = [];
    beta_i = NaN;

    if isstruct(arr(i)) && isfield(arr(i),'out') && local_is_out_struct(arr(i).out)
        oi = arr(i).out;
        if isfield(arr(i),'beta_use') && ~isempty(arr(i).beta_use)
            beta_i = double(arr(i).beta_use);
        end
    elseif local_is_out_struct(arr(i))
        oi = arr(i);
    end

    if isempty(oi)
        continue;
    end

    count = count + 1;
    items(count).beta_use = local_get_beta(oi, beta_i); %#ok<AGROW>
    items(count).out = oi; %#ok<AGROW>
end
end

% =========================================================================
% 单个 beta 表单
% =========================================================================
function C = local_build_one_sheet(out_i, cfg)
Nh = double(local_get_required_subfield(out_i, {'mdl','Nh'}));
Nk = double(local_get_required_subfield(out_i, {'mdl','H15'}));
hours = out_i.hours;

risk_lb = local_abs_temp_to_celsius(local_pick_global_risk_bound(out_i, 'lb', Nk));
risk_ub = local_abs_temp_to_celsius(local_pick_global_risk_bound(out_i, 'ub', Nk));

% ---------- A. 风险上下界 ----------
secA = cell(Nk + 2, 3);
secA{1,1} = '风险边界汇总';
secA(2,:) = {'时间步','风险下界_℃','风险上界_℃'};
for k = 1:Nk
    secA{k+2,1} = k;
    secA{k+2,2} = risk_lb(k);
    secA{k+2,3} = risk_ub(k);
end

C = secA;
C = local_append_rows(C, cell(1, size(C,2)));
C = local_append_rows(C, {'逐小时-逐备用水平-全天室温轨迹'});

% ---------- B. 每小时块 ----------
for h = 1:Nh
    blk = local_build_hour_block(out_i, hours(h), h, cfg, Nk);
    C = local_append_rows(C, blk);
    for ii = 1:cfg.blank_rows_between_hours
        C = local_append_rows(C, cell(1, size(C,2)));
    end
end
end

% =========================================================================
% 单小时块
% =========================================================================
function blk = local_build_hour_block(out_i, Hr, h, cfg, Nk)
risk_lb = local_abs_temp_to_celsius(local_pick_hour_risk_bound(Hr, out_i, 'lb', Nk));
risk_ub = local_abs_temp_to_celsius(local_pick_hour_risk_bound(Hr, out_i, 'ub', Nk));

R_grid = [];
if isfield(Hr,'R_grid') && ~isempty(Hr.R_grid)
    R_grid = Hr.R_grid(:);
end

is_ok = true(size(R_grid));
if isfield(Hr,'is_feasible') && ~isempty(Hr.is_feasible)
    is_ok = logical(Hr.is_feasible(:));
end

sols = {};
if isfield(Hr,'solutions') && ~isempty(Hr.solutions)
    sols = Hr.solutions;
end

idx_keep = [];
for i = 1:numel(R_grid)
    tf = true;
    if cfg.only_feasible
        tf = tf && is_ok(i);
    end
    if isempty(sols) || numel(sols) < i || isempty(sols{i}) || ~isstruct(sols{i}) || ~isfield(sols{i},'T15') || isempty(sols{i}.T15)
        tf = false;
    end
    if tf
        idx_keep(end+1,1) = i; %#ok<AGROW>
    end
end

nR = numel(idx_keep);
nCol = 3 + double(cfg.include_baseline) + nR;
blk = cell(Nk + 4, nCol);

blk{1,1} = sprintf('第%02d小时', h);
blk{2,1} = '风险边界与该小时不同备用水平下的全天室温轨迹（℃）';
blk{3,1} = '说明';
blk{3,2} = sprintf('导出点数=%d', nR);

col = 1;
blk{4,col} = '时间步'; col = col + 1;
blk{4,col} = '风险下界_℃'; col = col + 1;
blk{4,col} = '风险上界_℃'; col = col + 1;
if cfg.include_baseline
    blk{4,col} = '基线室温_℃'; col = col + 1;
end
for j = 1:nR
    ii = idx_keep(j);
    blk{4,col} = sprintf('R=%.6f_kW', R_grid(ii));
    col = col + 1;
end

baseline_T15 = nan(Nk,1);
if cfg.include_baseline
    if isfield(out_i,'baseline') && isstruct(out_i.baseline) && isfield(out_i.baseline,'T15') && ~isempty(out_i.baseline.T15)
        baseline_T15 = local_abs_temp_to_celsius(out_i.baseline.T15(:));
    end
    if numel(baseline_T15) ~= Nk
        baseline_T15 = nan(Nk,1);
    end
end

traj_cache = cell(nR,1);
for j = 1:nR
    ii = idx_keep(j);
    traj_cache{j} = local_abs_temp_to_celsius(local_pick_T15_from_solution(sols{ii}, Nk));
end

for k = 1:Nk
    col = 1;
    blk{k+4,col} = k; col = col + 1;
    blk{k+4,col} = risk_lb(k); col = col + 1;
    blk{k+4,col} = risk_ub(k); col = col + 1;
    if cfg.include_baseline
        blk{k+4,col} = baseline_T15(k); col = col + 1;
    end
    for j = 1:nR
        Tk = traj_cache{j};
        blk{k+4,col} = Tk(k);
        col = col + 1;
    end
end
end

% =========================================================================
% 风险边界
% =========================================================================
function v = local_pick_global_risk_bound(out_i, side, Nk)
switch lower(side)
    case 'lb'
        f1 = 'theta_risk_lb';
    otherwise
        f1 = 'theta_risk_ub';
end

if isfield(out_i, f1) && ~isempty(out_i.(f1))
    v = out_i.(f1)(:);
elseif isfield(out_i,'hours') && ~isempty(out_i.hours) && isfield(out_i.hours(1), f1) && ~isempty(out_i.hours(1).(f1))
    v = out_i.hours(1).(f1)(:);
else
    error('未找到风险边界字段：%s', f1);
end
assert(numel(v) == Nk, '风险边界长度与 Nk 不一致。');
end

function v = local_pick_hour_risk_bound(Hr, out_i, side, Nk)
switch lower(side)
    case 'lb'
        f1 = 'theta_risk_lb';
    otherwise
        f1 = 'theta_risk_ub';
end

if isfield(Hr, f1) && ~isempty(Hr.(f1))
    v = Hr.(f1)(:);
elseif isfield(out_i, f1) && ~isempty(out_i.(f1))
    v = out_i.(f1)(:);
else
    error('未找到小时风险边界字段：%s', f1);
end
assert(numel(v) == Nk, '小时风险边界长度与 Nk 不一致。');
end

% =========================================================================
% 提取 T15
% =========================================================================
function T15 = local_pick_T15_from_solution(sol, Nk)
assert(isstruct(sol) && isfield(sol,'T15') && ~isempty(sol.T15), 'solution 中缺少 T15。');
T15 = sol.T15(:);
assert(numel(T15) == Nk, 'solution.T15 长度与 Nk 不一致。');
end

% =========================================================================
% 绝对温度转摄氏度
% =========================================================================
function xC = local_abs_temp_to_celsius(x)
x = double(x);
if mean(x(:), 'omitnan') > 100
    xC = x - 273.15;
else
    xC = x;
end
end

% =========================================================================
% 工具
% =========================================================================
function S = local_load_any(in)
if ischar(in) || isstring(in)
    assert(exist(in, 'file') == 2, '未找到文件：%s', char(in));
    S = load(char(in));
else
    S = in;
end
end

function beta_use = local_get_beta(out_i, fallback)
beta_use = fallback;
if isfield(out_i,'beta_use') && ~isempty(out_i.beta_use) && isfinite(out_i.beta_use)
    beta_use = double(out_i.beta_use);
elseif isfield(out_i,'mdl') && isstruct(out_i.mdl) && isfield(out_i.mdl,'beta_use') && ~isempty(out_i.mdl.beta_use)
    beta_use = double(out_i.mdl.beta_use);
end
if isempty(beta_use) || ~isfinite(beta_use)
    beta_use = NaN;
end
end

function v = local_get_required_subfield(S, fns)
v = S;
for i = 1:numel(fns)
    fn = fns{i};
    assert(isstruct(v) && isfield(v, fn), '缺少字段：%s', strjoin(fns(1:i), '.'));
    v = v.(fn);
end
end

function s = local_beta_to_sheet(beta)
if ~isfinite(beta)
    s = '未识别置信度';
else
    s = sprintf('置信度%.2f', beta);
end
end

function C = local_append_rows(A, B)
if isempty(A)
    C = B;
    return;
end
if isempty(B)
    C = A;
    return;
end
if ~iscell(B)
    B = {B};
end
na = size(A,2);
nb = size(B,2);
n = max(na, nb);
if na < n
    A(:, end+1:n) = cell(size(A,1), n-na);
end
if nb < n
    B(:, end+1:n) = cell(size(B,1), n-nb);
end
C = [A; B];
end
