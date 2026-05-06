%% 根据 m=7.5:2.5:30 提取稳态功率，并进行三次多项式拟合与绘图（不保存）
clear; clc; close all;

%% 1) 读取数据
S = load('../data/rawdata/Fandata_for_fit.mat');      % 确保 Fan.mat 在当前工作路径
data = S.data_2;

t  = data(1,:).';         % 第1行：时间
m  = data(2,:).';         % 第2行：流量 m
Ps = data(3,:).';         % 第3行：送风机功率
Pr = data(4,:).';         % 第4行：回风机功率

%% 2) 参数（按需要调整）
mTargets  = (7.5:2.5:30).';  % 目标流量
mTol      = 1e-6;            % 判断"m是否相等"的容差（m是台阶值一般够用）

% 稳态判据：滑动窗口内功率波动足够小 -> 认为进入稳态
stdRelTol = 1e-3;            % 相对波动阈值：std <= stdRelTol * mean（0.1%）
winSec    = 300;             % 稳态检测窗口长度(秒)，例如 5分钟=300秒

% 如果某段找不到稳态：是否退而求其次用"该段最后一个窗口"当稳态
fallbackLastWindow = true;

% 是否画出每一段(每个台阶)的原始功率，并标出稳态开始点，用于检查瞬态剔除
plotSegments = false;

%% 3) 估计采样间隔，换算窗口点数
dt = median(diff(t), 'omitnan');
if ~isfinite(dt) || dt <= 0
    error('时间向量 t 不合法或不是单调递增。');
end
winN = max(3, round(winSec / dt));  % 稳态窗口长度(点)

%% 4) 按"m台阶不变"切分数据段
dm = [0; abs(diff(m))];
breakIdx = find(dm > mTol);         % m跳变点（新段起点）
segStart = [1; breakIdx];
segEnd   = [breakIdx-1; numel(m)];

%% 5) 逐段找稳态，记录每段的稳态均值
% segResults 每行含义：
% [mTarget, 段起点idx, 段终点idx, 稳态起点idx, Ps稳态均值, Pr稳态均值]
segResults = [];

% 每个目标m出现的段数
nSegments = zeros(size(mTargets));

for k = 1:numel(segStart)
    i1 = segStart(k);
    i2 = segEnd(k);
    L  = i2 - i1 + 1;
    if L < winN
        continue; % 段太短，无法做稳态窗口判断
    end

    % 该段的m值（基本是常数）
    mVal = mean(m(i1:i2), 'omitnan');

    % 看该段是否属于目标m集合
    [minErr, idxTarget] = min(abs(mTargets - mVal));
    if minErr > mTol
        continue;
    end

    Ps_seg = Ps(i1:i2);
    Pr_seg = Pr(i1:i2);

    % 在该段内找稳态开始点（相对索引）
    steadyRel = localFindSteadyStart(Ps_seg, Pr_seg, winN, stdRelTol);

    % 找不到稳态时的处理
    if isnan(steadyRel)
        if fallbackLastWindow
            steadyRel = L - winN + 1;  % 用最后一个窗口作为稳态
        else
            continue;
        end
    end

    steadyAbs = i1 + steadyRel - 1;    % 稳态开始点（绝对索引）

    % 稳态均值：从稳态开始到该段结束
    PsMean = mean(Ps(steadyAbs:i2), 'omitnan');
    PrMean = mean(Pr(steadyAbs:i2), 'omitnan');

    segResults = [segResults; ...
        mTargets(idxTarget), i1, i2, steadyAbs, PsMean, PrMean]; %#ok<AGROW>

    nSegments(idxTarget) = nSegments(idxTarget) + 1;

    % 可选：画每一段原始曲线+稳态起点
    if plotSegments
        figure('Name', sprintf('m=%.2f 第%d段', mTargets(idxTarget), nSegments(idxTarget)));
        plot(t(i1:i2), Ps(i1:i2), '-'); hold on;
        plot(t(i1:i2), Pr(i1:i2), '-');
        xline(t(steadyAbs), '--', '稳态开始');
        grid on;
        xlabel('时间'); ylabel('功率 (W)');
        title(sprintf('m=%.2f：段[%d,%d]，稳态从 idx=%d 开始', mTargets(idxTarget), i1, i2, steadyAbs));
        legend('送风机功率 Ps','回风机功率 Pr','稳态开始','Location','best');
    end
end

%% 6) 按目标m汇总（同一m可能出现多段：对各段稳态均值再取平均）
PsSteady   = nan(size(mTargets));
PrSteady   = nan(size(mTargets));
PtotSteady = nan(size(mTargets));

for i = 1:numel(mTargets)
    rows = segResults(:,1) == mTargets(i);
    if any(rows)
        PsSteady(i) = mean(segResults(rows,5), 'omitnan');
        PrSteady(i) = mean(segResults(rows,6), 'omitnan');
        PtotSteady(i) = PsSteady(i) + PrSteady(i);
    end
end

%% 7) 画"稳态功率-流量m"曲线（原始稳态点）
figure('Name','稳态功率随流量变化');
plot(mTargets, PsSteady, '-o'); hold on;
plot(mTargets, PrSteady, '-s');
plot(mTargets, PtotSteady, '-^');
grid on;
xlabel('流量 m');
ylabel('稳态功率 (W)');
title('稳态功率随风机流量变化');
legend('送风机稳态功率 Ps','回风机稳态功率 Pr','总稳态功率 Ps+Pr','Location','best');

%% 8) ===== 三次多项式拟合：PtotSteady = p1*m^3 + p2*m^2 + p3*m + p4 =====
% 去除 NaN 点（如果某些 m 没找到稳态）
idxFit = isfinite(mTargets) & isfinite(PtotSteady);
x = mTargets(idxFit);
y = PtotSteady(idxFit);

if numel(x) < 4
    error('可用于拟合的数据点少于4个，无法进行三次多项式拟合。');
end

% polyfit 返回 [a3 a2 a1 a0]，对应 a3*x^3 + a2*x^2 + a1*x + a0
p = polyfit(x, y, 3);

% 拟合值与残差
yhat = polyval(p, x);
res  = y - yhat;

% 评价指标：SSE、R^2、调整R^2、RMSE、DFE
SSE = sum(res.^2, 'omitnan');
SST = sum((y - mean(y,'omitnan')).^2, 'omitnan');
R2  = 1 - SSE / SST;

n = numel(y);          % 样本点数
k = 4;                 % 参数个数（3次多项式有4个系数）
DFE = n - k;           % 自由度
RMSE = sqrt(SSE / DFE);

R2_adj = 1 - (SSE/DFE) / (SST/(n-1));  % 调整R^2

% 按 curve fitter 的格式输出：p1..p4
p1 = p(1); p2 = p(2); p3 = p(3); p4 = p(4);

fprintf('\n===== 三次多项式拟合结果（poly3）=====\n');
fprintf('拟合模型：Ptot(m) = p1*m^3 + p2*m^2 + p3*m + p4\n');
fprintf('p1 = %.10g\n', p1);
fprintf('p2 = %.10g\n', p2);
fprintf('p3 = %.10g\n', p3);
fprintf('p4 = %.10g\n', p4);
fprintf('SSE  = %.10g\n', SSE);
fprintf('R^2  = %.10g\n', R2);
fprintf('调整R^2 = %.10g\n', R2_adj);
fprintf('RMSE = %.10g\n', RMSE);
fprintf('DFE  = %d\n', DFE);

% 也用表格显示（更清晰）
Tfit = table(p1, p2, p3, p4, SSE, R2, R2_adj, RMSE, DFE, ...
    'VariableNames', {'p1','p2','p3','p4','SSE','R2','R2_adj','RMSE','DFE'});
disp(Tfit);

%% 9) 拟合绘图：散点 + 拟合曲线
xq = linspace(min(x), max(x), 200).';
yq = polyval(p, xq);

figure('Name','总功率-流量 三次多项式拟合');
plot(x, y, 'ko', 'MarkerFaceColor','k'); hold on;  % 数据点（稳态总功率）
plot(xq, yq, 'b-', 'LineWidth', 1.8);             % 拟合曲线
grid on;
xlabel('流量 m');
ylabel('总稳态功率 P_{tot} (W)');
title('总稳态功率随流量变化（poly3 拟合）');
legend('数据点（稳态）','三次多项式拟合','Location','best');

% 在图上标注公式和指标（避免太长，保留关键）
txt1 = sprintf('P = %.3g m^3 + %.3g m^2 + %.3g m + %.3g', p1, p2, p3, p4);
txt2 = sprintf('R^2 = %.5f, RMSE = %.5g', R2, RMSE);
xText = min(xq) + 0.02*(max(xq)-min(xq));
yText = max(yq) - 0.08*(max(yq)-min(yq));
text(xText, yText, {txt1; txt2}, 'FontSize', 10, 'BackgroundColor', 'w');

%% 10) 在命令行显示稳态结果表（不保存）
Tsteady = table(mTargets, PsSteady, PrSteady, PtotSteady, nSegments, ...
    'VariableNames', {'m','送风机稳态功率_W','回风机稳态功率_W','总稳态功率_W','该m出现段数'});
disp(Tsteady);

%% ====== 局部函数：稳态检测（滑动窗口）======
function steadyStartRel = localFindSteadyStart(x1, x2, winN, stdRelTol)
% 功能：在一个台阶段内，用滑动窗口寻找"进入稳态"的最早时刻
% 判据：窗口内 std <= stdRelTol * mean（对 x1、x2 都成立）
% 输出：steadyStartRel 为相对索引（从1开始）；找不到则返回 NaN

n = numel(x1);
steadyStartRel = NaN;

for s = 1:(n - winN + 1)
    w1 = x1(s:s+winN-1);
    w2 = x2(s:s+winN-1);

    m1 = mean(w1, 'omitnan');  sd1 = std(w1, 'omitnan');
    m2 = mean(w2, 'omitnan');  sd2 = std(w2, 'omitnan');

    % 避免均值接近0导致阈值失效
    if ~isfinite(m1) || abs(m1) < eps || ~isfinite(m2) || abs(m2) < eps
        continue;
    end

    if (sd1 <= stdRelTol * abs(m1)) && (sd2 <= stdRelTol * abs(m2))
        steadyStartRel = s;
        return;
    end
end
end
