%% 清理环境
clear; clc; close all;

set(groot, 'defaultTextInterpreter', 'none');
set(groot, 'defaultAxesTickLabelInterpreter', 'none');
set(groot, 'defaultLegendInterpreter', 'none');

%% ===================== 用户参数 =====================
xlsPath = "Data.xlsx";
outDir  = "../processed_data";
figDir  = "../figs";

smoothWin = 15;
savePng   = true;
closeFigs = true;

fillShortGapMaxMin = 10;
waterDensity = 1000;

clipNegativeSolar = true;
clipNegativeFlow  = true;

forceFixedRange = true;
fixedStart = datetime(2024,12,1,0,0,0);
fixedEnd   = datetime(2025,3,1,23,59,0);

tempAggMethod  = 'median';
flowAggMethod  = 'median';
solarAggMethod = 'median';

solarNoiseFloor = 5;      % W/m^2

% ===== 流量鲁棒清洗参数（单位：m^3/h）=====
flowMedianWin1        = 11;   % 第一轮局部中位数窗口
flowMedianWin2        = 21;   % 第二轮局部中位数窗口
flowHardLowAbs        = 120;  % 低于该值直接认为异常（你的正常值大约在 190~210）
flowRatioLow1         = 0.75; % 若当前值 < 基线*0.75，判为异常候选
flowRatioLow2         = 0.85; % 第二轮更温和修正
flowMadScale          = 3.5;  % MAD 阈值倍数
flowFinalReplaceRatio = 0.90; % 最终若仍低于基线 90%，直接替换
flowFinalAbsMin       = 150;  % 最终兜底阈值

%% ===================== 路径检查 =====================
if ~isfile(xlsPath)
    error("找不到文件：%s", xlsPath);
end
if ~isfolder(outDir), mkdir(outDir); end
if ~isfolder(figDir), mkdir(figDir); end

%% ===================== 读表 =====================
T = readtable(xlsPath, 'PreserveVariableNames', true);

requiredVars = ["上传时间","瞬时水流量","室外温度","总回水温度","总供水温度","室外辐照"];
for v = requiredVars
    if ~ismember(v, string(T.Properties.VariableNames))
        error("缺少必要列：%s", v);
    end
end

rawRowCount = height(T);

%% ===================== 时间列转 datetime =====================
T.("上传时间") = localParseDatetimeCol(T.("上传时间"));

idxValidTime = ~isnat(T.("上传时间"));
badTimeCount = sum(~idxValidTime);
T = T(idxValidTime, :);

if isempty(T)
    error("时间列全部无法解析。");
end

%% ===================== 数值列转 double =====================
numVars = ["瞬时水流量","室外温度","总回水温度","总供水温度","室外辐照"];
for v = numVars
    T.(v) = localToDoubleCol(T.(v));
end

%% ===================== 排序 + 精确重复时间去重 =====================
T = sortrows(T, "上传时间");
[~, ia] = unique(T.("上传时间"), 'last');
T = T(ia, :);
T = sortrows(T, "上传时间");

%% ===================== 基本物理边界处理 =====================
if clipNegativeSolar
    x = T.("室外辐照");
    x(x < 0) = NaN;
    T.("室外辐照") = x;
end

if clipNegativeFlow
    x = T.("瞬时水流量");
    x(x < 0) = NaN;
    T.("瞬时水流量") = x;
end

%% ===================== 原始时间间隔统计 =====================
dtRaw = diff(T.("上传时间"));
dtSec = seconds(dtRaw);
dtSecValid = dtSec(~isnan(dtSec));

fprintf('\n================ 原始数据概况 ================\n');
fprintf('原始记录数                : %d\n', rawRowCount);
fprintf('剔除非法时间后记录数      : %d\n', height(T));
fprintf('非法时间行数              : %d\n', badTimeCount);
fprintf('原始起始时间              : %s\n', char(string(T.("上传时间")(1))));
fprintf('原始结束时间              : %s\n', char(string(T.("上传时间")(end))));
fprintf('原始间隔中位数(秒)        : %.3f\n', median(dtSecValid));
fprintf('原始最小间隔(秒)          : %.3f\n', min(dtSecValid));
fprintf('原始最大间隔(秒)          : %.3f\n', max(dtSecValid));
fprintf('>90 秒断点数量            : %d\n', sum(dtSec > 90));

%% ===================== floor 到分钟并聚合 =====================
T.MinuteTime = dateshift(T.("上传时间"), 'start', 'minute');

[grpID, minuteKeys] = findgroups(T.MinuteTime);
sampleCount = splitapply(@numel, T.MinuteTime, grpID);
CountTbl = table(minuteKeys, sampleCount, ...
    'VariableNames', {'MinuteTime','SamplesPerMinute'});

FlowTbl    = localGroupAggregate(T, "MinuteTime", "瞬时水流量", flowAggMethod,  "Flow");
ToutTbl    = localGroupAggregate(T, "MinuteTime", "室外温度",   tempAggMethod,  "Tout");
TreturnTbl = localGroupAggregate(T, "MinuteTime", "总回水温度", tempAggMethod,  "Treturn");
TsupplyTbl = localGroupAggregate(T, "MinuteTime", "总供水温度", tempAggMethod,  "Tsupply");
SolTbl     = localGroupAggregate(T, "MinuteTime", "室外辐照",   solarAggMethod, "Sol");

G = table;
G.MinuteTime = unique(T.MinuteTime);
G = sortrows(G, "MinuteTime");

G.SamplesPerMinute = NaN(height(G),1);
G.Flow    = NaN(height(G),1);
G.Tout    = NaN(height(G),1);
G.Treturn = NaN(height(G),1);
G.Tsupply = NaN(height(G),1);
G.Sol     = NaN(height(G),1);

[tf, loc] = ismember(CountTbl.MinuteTime, G.MinuteTime);
G.SamplesPerMinute(loc(tf)) = CountTbl.SamplesPerMinute(tf);

[tf, loc] = ismember(FlowTbl.MinuteTime, G.MinuteTime);
G.Flow(loc(tf)) = FlowTbl.Flow(tf);

[tf, loc] = ismember(ToutTbl.MinuteTime, G.MinuteTime);
G.Tout(loc(tf)) = ToutTbl.Tout(tf);

[tf, loc] = ismember(TreturnTbl.MinuteTime, G.MinuteTime);
G.Treturn(loc(tf)) = TreturnTbl.Treturn(tf);

[tf, loc] = ismember(TsupplyTbl.MinuteTime, G.MinuteTime);
G.Tsupply(loc(tf)) = TsupplyTbl.Tsupply(tf);

[tf, loc] = ismember(SolTbl.MinuteTime, G.MinuteTime);
G.Sol(loc(tf)) = SolTbl.Sol(tf);

G.SamplesPerMinute(isnan(G.SamplesPerMinute)) = 0;

%% ===================== 建立完整分钟时间轴 =====================
if forceFixedRange
    tMin = dateshift(fixedStart, 'start', 'minute');
    tMax = dateshift(fixedEnd,   'start', 'minute');
else
    tMin = min(G.MinuteTime);
    tMax = max(G.MinuteTime);
end

fullMinute = (tMin:minutes(1):tMax)';
TT = table;
TT.MinuteTime = fullMinute;

TT.SamplesPerMinute = NaN(height(TT),1);
TT.Flow    = NaN(height(TT),1);
TT.Tout    = NaN(height(TT),1);
TT.Treturn = NaN(height(TT),1);
TT.Tsupply = NaN(height(TT),1);
TT.Sol     = NaN(height(TT),1);

[tf, loc] = ismember(G.MinuteTime, TT.MinuteTime);

TT.SamplesPerMinute(loc(tf)) = G.SamplesPerMinute(tf);
TT.Flow(loc(tf))    = G.Flow(tf);
TT.Tout(loc(tf))    = G.Tout(tf);
TT.Treturn(loc(tf)) = G.Treturn(tf);
TT.Tsupply(loc(tf)) = G.Tsupply(tf);
TT.Sol(loc(tf))     = G.Sol(tf);

fprintf('\n================ 分钟规整概况 ================\n');
fprintf('规整起始时间              : %s\n', char(string(TT.MinuteTime(1))));
fprintf('规整结束时间              : %s\n', char(string(TT.MinuteTime(end))));
fprintf('最终分钟点数              : %d\n', height(TT));
fprintf('存在数据的分钟数          : %d\n', height(G));
fprintf('同一分钟额外重复记录数    : %d\n', sum(max(TT.SamplesPerMinute - 1, 0)));

%% ===================== 记录填补前缺失 =====================
missingBefore.Flow    = sum(isnan(TT.Flow));
missingBefore.Tout    = sum(isnan(TT.Tout));
missingBefore.Treturn = sum(isnan(TT.Treturn));
missingBefore.Tsupply = sum(isnan(TT.Tsupply));
missingBefore.Sol     = sum(isnan(TT.Sol));

fprintf('\n================ 填补前缺失统计 ================\n');
fprintf('Flow    缺失数: %d\n', missingBefore.Flow);
fprintf('Tout    缺失数: %d\n', missingBefore.Tout);
fprintf('Treturn 缺失数: %d\n', missingBefore.Treturn);
fprintf('Tsupply 缺失数: %d\n', missingBefore.Tsupply);
fprintf('Sol     缺失数: %d\n', missingBefore.Sol);

%% ===================== 温度/辐照先补缺 =====================
TT.Tout    = localFillSeries(TT.Tout,    fillShortGapMaxMin, "temp");
TT.Treturn = localFillSeries(TT.Treturn, fillShortGapMaxMin, "temp");
TT.Tsupply = localFillSeries(TT.Tsupply, fillShortGapMaxMin, "temp");
TT.Sol     = localFillSeries(TT.Sol,     fillShortGapMaxMin, "solar");

%% ===================== 流量鲁棒清洗：第一轮 =====================
flow = TT.Flow;

% 先只对短缺失做一次初步补齐，便于后续估计局部基线
flow = localFillSeries(flow, fillShortGapMaxMin, "flow");

base1 = localMovMedianOmitNaN(flow, flowMedianWin1);
mad1  = localMovMadOmitNaN(flow, flowMedianWin1);

mask1 = false(size(flow));
for i = 1:length(flow)
    if isnan(flow(i)) || isnan(base1(i))
        continue;
    end

    cond1 = flow(i) < flowHardLowAbs;
    cond2 = flow(i) < base1(i) * flowRatioLow1;

    if isnan(mad1(i)) || mad1(i) == 0
        cond3 = false;
    else
        cond3 = (base1(i) - flow(i)) > flowMadScale * mad1(i);
    end

    if cond1 || cond2 || cond3
        mask1(i) = true;
    end
end

flow(mask1) = NaN;
flow = localFillSeries(flow, fillShortGapMaxMin, "flow");

fprintf('\n================ 第一轮流量修复统计 ================\n');
fprintf('第一轮异常低值点数        : %d\n', sum(mask1));

%% ===================== 流量鲁棒清洗：第二轮 =====================
base2 = localMovMedianOmitNaN(flow, flowMedianWin2);
mad2  = localMovMadOmitNaN(flow, flowMedianWin2);

mask2 = false(size(flow));
for i = 1:length(flow)
    if isnan(flow(i)) || isnan(base2(i))
        continue;
    end

    cond1 = flow(i) < flowHardLowAbs;
    cond2 = flow(i) < base2(i) * flowRatioLow2;

    if isnan(mad2(i)) || mad2(i) == 0
        cond3 = false;
    else
        cond3 = (base2(i) - flow(i)) > flowMadScale * mad2(i);
    end

    if cond1 || cond2 || cond3
        mask2(i) = true;
    end
end

flow(mask2) = base2(mask2);

fprintf('\n================ 第二轮流量修复统计 ================\n');
fprintf('第二轮被基线替换点数      : %d\n', sum(mask2));

%% ===================== 流量最终兜底 =====================
base3 = localMovMedianOmitNaN(flow, flowMedianWin2);

mask3 = false(size(flow));
for i = 1:length(flow)
    if isnan(flow(i)) || isnan(base3(i))
        continue;
    end

    if flow(i) < flowFinalAbsMin || flow(i) < base3(i) * flowFinalReplaceRatio
        mask3(i) = true;
    end
end

flow(mask3) = base3(mask3);
TT.Flow = flow;

fprintf('\n================ 最终流量兜底统计 ================\n');
fprintf('最终被替换点数            : %d\n', sum(mask3));

%% ===================== 其他约束 =====================
if clipNegativeSolar
    TT.Sol(TT.Sol < 0) = 0;
end
if clipNegativeFlow
    TT.Flow(TT.Flow < 0) = 0;
end

TT.Sol(TT.Sol < solarNoiseFloor) = 0;

%% ===================== 单位换算 =====================
TT.mdot = TT.Flow * waterDensity / 3600;

%% ===================== 输出数值矩阵 =====================
t0 = TT.MinuteTime(1);
time_s = round(seconds(TT.MinuteTime - t0));

DayData = [ ...
    time_s, ...
    TT.Tout, ...
    TT.Tsupply, ...
    TT.Treturn, ...
    TT.mdot, ...
    TT.Sol];

%% ===================== 平滑 =====================
Tout_s    = smoothdata(TT.Tout,    'movmean', smoothWin);
Tsupply_s = smoothdata(TT.Tsupply, 'movmean', smoothWin);
Treturn_s = smoothdata(TT.Treturn, 'movmean', smoothWin);
mdot_s    = smoothdata(TT.mdot,    'movmean', smoothWin);
Sol_s     = smoothdata(TT.Sol,     'movmean', smoothWin);

% 再保险：对平滑后的质量流量做一次最终兜底，避免残余竖线
mdotBase = localMovMedianOmitNaN(mdot_s, flowMedianWin2);
for i = 1:length(mdot_s)
    if ~isnan(mdot_s(i)) && ~isnan(mdotBase(i))
        if mdot_s(i) < mdotBase(i) * 0.90
            mdot_s(i) = mdotBase(i);
        end
    end
end

%% ===================== 清洗报告 =====================
missingAfter.Flow    = sum(isnan(TT.Flow));
missingAfter.Tout    = sum(isnan(TT.Tout));
missingAfter.Treturn = sum(isnan(TT.Treturn));
missingAfter.Tsupply = sum(isnan(TT.Tsupply));
missingAfter.Sol     = sum(isnan(TT.Sol));

Report = struct;
Report.File = xlsPath;
Report.RawRowCount = rawRowCount;
Report.RowCountAfterBadTimeRemoved = height(T);
Report.BadTimeCount = badTimeCount;

Report.RawTimeStart = T.("上传时间")(1);
Report.RawTimeEnd   = T.("上传时间")(end);
Report.RegularizedTimeStart = TT.MinuteTime(1);
Report.RegularizedTimeEnd   = TT.MinuteTime(end);

Report.RawMedianDtSec = median(dtSecValid);
Report.RawMinDtSec    = min(dtSecValid);
Report.RawMaxDtSec    = max(dtSecValid);
Report.RawGapCountOver90s = sum(dtSec > 90);

Report.FinalMinuteCount = height(TT);
Report.MinutesWithSamples = height(G);
Report.ExtraRecordsWithinSameMinute = sum(max(TT.SamplesPerMinute - 1, 0));

Report.MissingBefore = missingBefore;
Report.MissingAfter  = missingAfter;
Report.FlowRepairMask1Count = sum(mask1);
Report.FlowRepairMask2Count = sum(mask2);
Report.FlowRepairMask3Count = sum(mask3);

Report.Range.Flow    = [localMinOmitNaN(TT.Flow),    localVecMaxOmitNaN(TT.Flow)];
Report.Range.Tout    = [localMinOmitNaN(TT.Tout),    localVecMaxOmitNaN(TT.Tout)];
Report.Range.Treturn = [localMinOmitNaN(TT.Treturn), localVecMaxOmitNaN(TT.Treturn)];
Report.Range.Tsupply = [localMinOmitNaN(TT.Tsupply), localVecMaxOmitNaN(TT.Tsupply)];
Report.Range.Sol     = [localMinOmitNaN(TT.Sol),     localVecMaxOmitNaN(TT.Sol)];
Report.Range.mdot    = [localMinOmitNaN(TT.mdot),    localVecMaxOmitNaN(TT.mdot)];

Report.FlatRun.FlowMin    = localLongestFlatRun(TT.Flow);
Report.FlatRun.ToutMin    = localLongestFlatRun(TT.Tout);
Report.FlatRun.TreturnMin = localLongestFlatRun(TT.Treturn);
Report.FlatRun.TsupplyMin = localLongestFlatRun(TT.Tsupply);
Report.FlatRun.SolMin     = localLongestFlatRun(TT.Sol);

fprintf('\n================ 填补后缺失统计 ================\n');
fprintf('Flow    缺失数: %d\n', missingAfter.Flow);
fprintf('Tout    缺失数: %d\n', missingAfter.Tout);
fprintf('Treturn 缺失数: %d\n', missingAfter.Treturn);
fprintf('Tsupply 缺失数: %d\n', missingAfter.Tsupply);
fprintf('Sol     缺失数: %d\n', missingAfter.Sol);

%% ===================== 保存 MAT =====================
saveName = "Data_cleaned_minutely.mat";
save(fullfile(outDir, saveName), ...
    'DayData', 'TT', 'Report', ...
    'Tout_s', 'Tsupply_s', 'Treturn_s', 'mdot_s', 'Sol_s');

fprintf('\n处理完成，已保存: %s\n', fullfile(outDir, saveName));

%% ===================== 作图 =====================
time_min = time_s / 60;

f1 = figure('Name', "Temp");
plot(time_min, Tsupply_s, 'DisplayName','供水温度'); hold on;
plot(time_min, Treturn_s, 'DisplayName','回水温度');
plot(time_min, Tout_s,    'DisplayName','室外温度');
xlabel('时间 / min');
ylabel('温度 / ^oC');
title('供回水温度与室外温度（分钟级，平滑）');
legend('Location','best');
grid on;

f2 = figure('Name', "mdot");
plot(time_min, mdot_s);
xlabel('时间 / min');
ylabel('质量流量 / kg/s');
title('瞬时质量流量（分钟级，平滑）');
grid on;

f3 = figure('Name', "Sol");
plot(time_min, Sol_s);
xlabel('时间 / min');
ylabel('辐照度 / W/m^2');
title('室外辐照（分钟级，平滑）');
grid on;

if savePng
    localSaveFigPng(figDir, "Temp.png", f1);
    localSaveFigPng(figDir, "mdot.png", f2);
    localSaveFigPng(figDir, "Sol.png",  f3);
end

if closeFigs
    close(f1); close(f2); close(f3);
end

disp('脚本执行完毕。');
disp(Report);

%% ===================== 局部函数 =====================

function dt = localParseDatetimeCol(x)
if isdatetime(x)
    dt = x;
    return;
end

if isnumeric(x)
    try
        dt = datetime(x, 'ConvertFrom', 'excel');
    catch
        dt = NaT(size(x));
    end
    return;
end

if iscell(x)
    s = strings(size(x));
    for i = 1:numel(x)
        if isempty(x{i})
            s(i) = "";
        elseif ischar(x{i}) || isstring(x{i})
            s(i) = string(x{i});
        elseif isnumeric(x{i}) && isscalar(x{i})
            try
                s(i) = string(datetime(x{i}, 'ConvertFrom', 'excel', ...
                    'Format','yyyy-MM-dd HH:mm:ss'));
            catch
                s(i) = "";
            end
        else
            s(i) = "";
        end
    end
elseif isstring(x)
    s = x;
elseif ischar(x)
    s = string(cellstr(x));
else
    error("不支持的时间列类型：%s", class(x));
end

s = strtrim(s);
dt = NaT(size(s));

fmts = [ ...
    "yyyy/M/d H:mm:ss"
    "yyyy/M/d HH:mm:ss"
    "yyyy-MM-dd H:mm:ss"
    "yyyy-MM-dd HH:mm:ss"
    "yyyy/M/d H:mm"
    "yyyy/M/d HH:mm"
    "yyyy-MM-dd H:mm"
    "yyyy-MM-dd HH:mm"
    "M/d/yyyy H:mm:ss"
    "M/d/yyyy HH:mm:ss"];

for k = 1:numel(fmts)
    idx = isnat(dt) & s ~= "";
    if ~any(idx), break; end
    try
        tmp = datetime(s(idx), 'InputFormat', fmts(k));
        dt(idx) = tmp;
    catch
    end
end

idx = isnat(dt) & s ~= "";
if any(idx)
    try
        dt(idx) = datetime(s(idx));
    catch
    end
end
end

function y = localToDoubleCol(x)
if isnumeric(x)
    y = double(x);
    return;
end

if iscell(x)
    s = strings(size(x));
    for i = 1:numel(x)
        if isempty(x{i})
            s(i) = "";
        elseif ischar(x{i}) || isstring(x{i})
            s(i) = string(x{i});
        elseif isnumeric(x{i}) && isscalar(x{i})
            s(i) = string(x{i});
        else
            s(i) = "";
        end
    end
elseif isstring(x)
    s = x;
elseif ischar(x)
    s = string(cellstr(x));
else
    error("不支持的数值列类型：%s", class(x));
end

s = strtrim(s);
s = replace(s, ",", "");
y = str2double(s);
end

function Tbl = localGroupAggregate(T, groupVar, srcVar, method, outVar)
g = T.(groupVar);
x = T.(srcVar);

[grpID, groupKey] = findgroups(g);

switch lower(char(method))
    case 'mean'
        y = splitapply(@localMeanOmitNaN, x, grpID);
    case 'median'
        y = splitapply(@localMedianOmitNaN, x, grpID);
    case 'last'
        y = splitapply(@localLastNonNan, x, grpID);
    case 'max'
        y = splitapply(@localMaxOmitNaN, x, grpID);
    otherwise
        error("不支持聚合方法：%s", method);
end

Tbl = table(groupKey, y, 'VariableNames', {char(groupVar), char(outVar)});
end

function y = localMeanOmitNaN(v)
v = v(~isnan(v));
if isempty(v)
    y = NaN;
else
    y = mean(v);
end
end

function y = localMedianOmitNaN(v)
v = v(~isnan(v));
if isempty(v)
    y = NaN;
else
    y = median(v);
end
end

function y = localMaxOmitNaN(v)
v = v(~isnan(v));
if isempty(v)
    y = NaN;
else
    y = max(v);
end
end

function v = localLastNonNan(x)
idx = find(~isnan(x), 1, 'last');
if isempty(idx)
    v = NaN;
else
    v = x(idx);
end
end

function x = localFillSeries(x, maxGapMin, modeName)
if all(isnan(x))
    return;
end

x = x(:);
x = fillmissing(x, 'linear', 'MaxGap', maxGapMin);
x = fillmissing(x, 'nearest');

switch lower(char(modeName))
    case 'solar'
        x(x < 0) = 0;
    case 'flow'
        x(x < 0) = 0;
    case 'temp'
end
end

function y = localMovMedianOmitNaN(x, win)
x = x(:);
n = length(x);
y = NaN(size(x));

halfWinLeft  = floor((win - 1) / 2);
halfWinRight = ceil((win - 1) / 2);

for i = 1:n
    leftIdx  = max(1, i - halfWinLeft);
    rightIdx = min(n, i + halfWinRight);
    v = x(leftIdx:rightIdx);
    v = v(~isnan(v));
    if ~isempty(v)
        y(i) = median(v);
    end
end
end

function y = localMovMadOmitNaN(x, win)
x = x(:);
n = length(x);
y = NaN(size(x));

halfWinLeft  = floor((win - 1) / 2);
halfWinRight = ceil((win - 1) / 2);

for i = 1:n
    leftIdx  = max(1, i - halfWinLeft);
    rightIdx = min(n, i + halfWinRight);
    v = x(leftIdx:rightIdx);
    v = v(~isnan(v));
    if ~isempty(v)
        medv = median(v);
        y(i) = median(abs(v - medv));
    end
end
end

function m = localLongestFlatRun(x)
if isempty(x) || all(isnan(x))
    m = 0;
    return;
end

m = 1;
cur = 1;
for i = 2:numel(x)
    if ~isnan(x(i)) && ~isnan(x(i-1)) && x(i) == x(i-1)
        cur = cur + 1;
        if cur > m
            m = cur;
        end
    else
        cur = 1;
    end
end
end

function y = localMinOmitNaN(x)
x = x(~isnan(x));
if isempty(x)
    y = NaN;
else
    y = min(x);
end
end

function y = localVecMaxOmitNaN(x)
x = x(~isnan(x));
if isempty(x)
    y = NaN;
else
    y = max(x);
end
end

function localSaveFigPng(figDir, filename, figHandle)
pngPath = fullfile(figDir, filename);
try
    exportgraphics(figHandle, pngPath, "Resolution", 200);
catch
    saveas(figHandle, pngPath);
end
end