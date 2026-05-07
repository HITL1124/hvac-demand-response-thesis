function out = export_one_day_outdoor_temp_irradiance_xlsx(cfg)
% =========================================================================
% 导出某一天的室外温度与室外辐照度为 xlsx
% -------------------------------------------------------------------------
% 默认优先读取 data/stage1/stage1_cqr_tree_data.mat 中的 U=[Ts,ma,To,Isol,Qint]
% 并尝试从 data/stage1/stage1_cqr_for_stage2.mat 中读取 stage2_day_index 作为默认天数。
%
% 导出列：
%   1) 时间步
%   2) 时刻标签
%   3) 室外温度_℃
%   4) 室外辐照度
%
% 说明：
%   - U 的第 3 列 To 视为绝对温度，默认按 K -> ℃ 转换：To_C = To_K - 273.15
%   - 辐照度保持原单位不变
%
% 默认调用：
%   out = export_one_day_outdoor_temp_irradiance_xlsx();
%
% 可选调用：
%   cfg = struct();
%   cfg.day_index = 2;
%   out = export_one_day_outdoor_temp_irradiance_xlsx(cfg);
% =========================================================================

if nargin < 1
    cfg = struct();
end
cfg = local_fill_defaults(cfg);

outdir = fileparts(cfg.outfile);
if ~isempty(outdir) && ~exist(outdir, 'dir')
    mkdir(outdir);
end

%% 1) 读取数据源
assert(exist(cfg.tree_data_file, 'file') == 2, '未找到文件：%s', cfg.tree_data_file);
S = load(cfg.tree_data_file);

assert(isfield(S, 'U') && isnumeric(S.U) && ~isempty(S.U), 'tree_data 文件中缺少有效字段 U。');
U = double(S.U);
assert(size(U,2) >= 4, 'U 至少应包含 [Ts, ma, To, Isol, ...] 四列。');

if isfield(S, 'Ts_stage1') && isnumeric(S.Ts_stage1) && ~isempty(S.Ts_stage1)
    Ts_stage1 = double(S.Ts_stage1(1));
else
    Ts_stage1 = 15 * 60;
end
stepsPerDay = round(24 * 3600 / Ts_stage1);
assert(stepsPerDay > 0, 'stepsPerDay 计算错误。');

N = size(U,1);
numDays = floor(N / stepsPerDay);
assert(numDays >= 1, '数据长度不足以构成 1 天。');

%% 2) 确定导出哪一天
if isempty(cfg.day_index)
    cfg.day_index = local_try_pick_default_day(cfg.stage2_file, numDays);
end

assert(cfg.day_index >= 1 && cfg.day_index <= numDays, ...
    'day_index=%d 超出范围。当前可导出天数为 1 ~ %d。', cfg.day_index, numDays);

idx0 = (cfg.day_index - 1) * stepsPerDay + 1;
idx1 = idx0 + stepsPerDay - 1;
assert(idx1 <= N, '所选天数越界。');

U_day = U(idx0:idx1, :);
To_day_raw = U_day(:, 3);
Isol_day = U_day(:, 4);
To_day_C = local_abs_temp_to_celsius(To_day_raw, cfg.absTempThresholdK);

%% 3) 构造导出表
step_in_day = (0:stepsPerDay-1).';
time_min = step_in_day * Ts_stage1 / 60;
time_label = cell(stepsPerDay,1);
for i = 1:stepsPerDay
    time_label{i} = local_min_to_hhmm(time_min(i));
end

C = cell(stepsPerDay + 1, 4);
C(1,:) = {'时间步', '时刻标签', '室外温度_℃', '室外辐照度'};
C(2:end,1) = num2cell(step_in_day);
C(2:end,2) = time_label;
C(2:end,3) = num2cell(To_day_C);
C(2:end,4) = num2cell(Isol_day);

%% 4) 写 xlsx
if exist(cfg.outfile, 'file') == 2
    delete(cfg.outfile);
end
writecell(C, cfg.outfile, 'Sheet', cfg.sheet_name);

%% 5) 输出信息
out = struct();
out.tree_data_file = cfg.tree_data_file;
out.stage2_file = cfg.stage2_file;
out.outfile = cfg.outfile;
out.sheet_name = cfg.sheet_name;
out.day_index = cfg.day_index;
out.stepsPerDay = stepsPerDay;
out.numDays_available = numDays;
out.idx_range = [idx0, idx1];
out.Ts_stage1 = Ts_stage1;
out.outdoor_temp_unit = 'degC';

fprintf('\n============================================================\n');
fprintf('已导出某一天的室外温度与室外辐照度\n');
fprintf('数据源文件        : %s\n', cfg.tree_data_file);
fprintf('导出第 %d 天       \n', cfg.day_index);
fprintf('每天天数步数      : %d\n', stepsPerDay);
fprintf('数据可用总天数    : %d\n', numDays);
fprintf('室外温度单位      : ℃\n');
fprintf('输出文件          : %s\n', cfg.outfile);
fprintf('============================================================\n');

end

% =========================================================================
% 默认参数
% =========================================================================
function cfg = local_fill_defaults(cfg)
defaults.tree_data_file = project_data_file('stage1', 'stage1_cqr_tree_data.mat');
defaults.stage2_file = project_data_file('stage1', 'stage1_cqr_for_stage2.mat');
defaults.day_index = [];
defaults.outfile = project_data_file('exports', '01_Fig3_Fig4_stage1_inputs_cqr', 'export_one_day_outdoor_temp_irradiance.xlsx');
defaults.sheet_name = '某一天气象数据';
defaults.absTempThresholdK = 100;

fns = fieldnames(defaults);
for i = 1:numel(fns)
    fn = fns{i};
    if ~isfield(cfg, fn) || isempty(cfg.(fn))
        cfg.(fn) = defaults.(fn);
    end
end
end

% =========================================================================
% 默认取 stage2_day_index
% =========================================================================
function day_index = local_try_pick_default_day(stage2_file, numDays)
day_index = 1;
if exist(stage2_file, 'file') ~= 2
    return;
end
try
    S = load(stage2_file);
    if isfield(S, 'stage2_day_index') && isnumeric(S.stage2_day_index) && ~isempty(S.stage2_day_index)
        day_index = double(S.stage2_day_index(1));
    elseif isfield(S, 'cfg') && isstruct(S.cfg) && isfield(S.cfg, 'stage2_day_index')
        day_index = double(S.cfg.stage2_day_index(1));
    end
catch
    day_index = 1;
end
if ~(isfinite(day_index) && day_index >= 1)
    day_index = 1;
end
day_index = min(max(round(day_index),1), numDays);
end

% =========================================================================
% 绝对温度转 ℃
% =========================================================================
function xC = local_abs_temp_to_celsius(x, thresholdK)
x = double(x);
if mean(x(:), 'omitnan') > thresholdK
    xC = x - 273.15;
else
    xC = x;
end
end

% =========================================================================
% 分钟转 hh:mm
% =========================================================================
function s = local_min_to_hhmm(m)
mm = round(m);
h = floor(mm / 60);
mi = mod(mm, 60);
s = sprintf('%02d:%02d', h, mi);
end
