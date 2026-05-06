%% validate_ss_model.m
% 验证 N4SID 得到的离散状态空间模型是否能复现 Dymola 状态输出
% 验证数据：20250112-20250115仿真数据
% 输入顺序 u=[Tsup, mdot, To, Isol, Qint]
% 输出顺序 y=[Tw, Ti]
%

clear; clc; close all;

%% =========================
%  用户配置区
% =========================

% 1) 模型矩阵
% A = [0.9719, -0.006437;
%      0.08269, 0.9143];
% 
% B = [-0.002104, -0.003107, -0.0009276, -5.163e-06, -8.777e-08;
%      -0.004438, -0.00984,   0.01242,   -1.146e-05, -1.855e-07];
% 
% C = [-9.901,  4.479;
%      -9.04,  -0.237];
% 
% D = zeros(2,5);
% 
% K = [-0.004976, -0.07891;
%       0.1785,   -0.2511];
A = [0.9696 0.007143;
    -0.0561 0.9167];
B = [-0.001752 -0.003164 -0.000807 -4.601e-06 -7.539e-08;
    0.002768 0.007083 -0.009526 7.753e-06 1.184e-07;];
C = [-9.872 -5.973;
    -10.74 0.3544];
D = zeros(2,5);
K = [-0.004552 -0.06978;
    -0.1353 0.1574];

% 2) 采样时间（秒）——必须跟你识别时一致
Ts = 60;

% 3) 是否对数据去均值（如果你在 App 里对 estimation data 做过 detrend/remove mean，就设 true）
useRemoveMean = true;

% 4) 图像显示的时间单位
plotTimeInHours = true;

%% =========================
%  读取数据（从 state.mat 和 input.mat）
% =========================

stateFile = "../data/processeddata/processed_state.mat";   % N×2: [Tw, Ti]
inputFile = "../data/processeddata/processed_input.mat";   % N×5: [Tsup, mdot, To, Isol, Qint]

Sx = load(stateFile);
Su = load(inputFile);

% --- 从 mat 中自动找出"最大的数值矩阵"作为数据 ---
state = pickLargestNumericMatrix(Sx);
inp   = pickLargestNumericMatrix(Su);

% 基本检查
if size(state,2) ~= 2
    error("state.mat 里识别到的状态矩阵列数不是2。实际 size(state) = [%d,%d]", size(state,1), size(state,2));
end
if size(inp,2) ~= 5
    error("input.mat 里识别到的输入矩阵列数不是5。实际 size(input) = [%d,%d]", size(inp,1), size(inp,2));
end

% 输出 y=[Tw Ti]
y = state;   % N×2

% 输入 u=[Tsup mdot To Isol Qint]
u = inp;     % N×5

N = size(u,1);
if size(y,1) ~= N
    error("state 与 input 的行数不一致：size(state,1)=%d, size(input,1)=%d", size(y,1), N);
end

% 时间向量：如果 mat 里带了 t，就用它；否则自动生成
t = [];
t = tryGetTimeVector(Sx);
if isempty(t), t = tryGetTimeVector(Su); end

if isempty(t)
    % 没有时间向量，直接按 Ts 生成
    t = (0:N-1)' * Ts;
else
    t = t(:);
    if numel(t) ~= N
        error("时间向量长度与数据长度不一致：length(t)=%d, N=%d", numel(t), N);
    end
end

% 检查采样间隔是否接近 Ts（如果有 t）
if numel(t) > 1
    dt = median(diff(t));
    if abs(dt - Ts) > 1e-6
        warning("数据时间步长 median(diff(t))=%.6g，与 Ts=%.6g 不一致。请确认。", dt, Ts);
    end
end

%% =========================
%  可选：去均值（必须与识别阶段一致）
% =========================
if useRemoveMean
    uMean = mean(u,1);
    yMean = mean(y,1);
    uZ = u - uMean;
    yZ = y - yMean;
else
    uZ = u;
    yZ = y;
end

%% =========================
%  初始化状态 x0：用 y(0)=C x(0) + D u(0) 反推
%  你这里 D=0，所以 x0 = C^{-1} y0
% =========================
y0 = yZ(1,:)';
u0 = uZ(1,:)';

rhs = y0 - D*u0;
% 如果 C 可逆，用反斜杠更稳；否则用 pinv
if abs(det(C)) > 1e-10
    x = C \ rhs;
else
    warning("C 可能不可逆，改用 pinv(C) 初始化。");
    x = pinv(C) * rhs;
end

%% =========================
%  验证 1：开环仿真（e=0，不用 K）
% =========================
yhat_ol = zeros(N,2);
x_ol = x;

for k = 1:N
    % 输出
    yhat_ol(k,:) = (C*x_ol + D*uZ(k,:)')';
    % 状态更新（开环）
    x_ol = A*x_ol + B*uZ(k,:)';
end

%% =========================
%  验证 2：一步预测/跟踪（使用 K 与 e）
%  e(k)=y(k)-yhat(k)，并用 K e(k) 修正
% =========================
yhat_1s = zeros(N,2);
x_1s = x;

for k = 1:N
    % 预测输出
    ypred = C*x_1s + D*uZ(k,:)';
    yhat_1s(k,:) = ypred';
    % 创新/残差
    e = yZ(k,:)' - ypred;
    % 更新状态（含 K e）
    x_1s = A*x_1s + B*uZ(k,:)' + K*e;
end

%% =========================
%  如果去均值了，把输出加回均值，便于和原始 y 对比
% =========================
if useRemoveMean
    yhat_ol = yhat_ol + yMean;
    yhat_1s = yhat_1s + yMean;
end

%% =========================
%  误差指标
% =========================
err_ol = yhat_ol - y;    % N×2
err_1s = yhat_1s - y;

metrics = @(e) struct( ...
    "RMSE", sqrt(mean(e.^2,1)), ...
    "MAE",  mean(abs(e),1), ...
    "MaxAbs", max(abs(e),[],1) ...
);

m_ol = metrics(err_ol);
m_1s = metrics(err_1s);

fprintf("\n===== 验证结果（开环仿真 e=0）=====\n");
fprintf("Tw: RMSE=%.4g, MAE=%.4g, MaxAbs=%.4g\n", m_ol.RMSE(1), m_ol.MAE(1), m_ol.MaxAbs(1));
fprintf("Ti: RMSE=%.4g, MAE=%.4g, MaxAbs=%.4g\n", m_ol.RMSE(2), m_ol.MAE(2), m_ol.MaxAbs(2));

fprintf("\n===== 验证结果（一步预测/跟踪 用K）=====\n");
fprintf("Tw: RMSE=%.4g, MAE=%.4g, MaxAbs=%.4g\n", m_1s.RMSE(1), m_1s.MAE(1), m_1s.MaxAbs(1));
fprintf("Ti: RMSE=%.4g, MAE=%.4g, MaxAbs=%.4g\n", m_1s.RMSE(2), m_1s.MAE(2), m_1s.MaxAbs(2));

%% =========================
%  绘图对比
% =========================
if plotTimeInHours
    tt = (t - t(1))/3600;
    xlab = "Time (h)";
else
    tt = t - t(1);
    xlab = "Time (s)";
end

figure; 
plot(tt, y(:,1)-273.15, 'LineWidth', 1); hold on;
plot(tt, yhat_ol(:,1)-273.15, 'LineWidth', 1);
plot(tt, yhat_1s(:,1)-273.15, 'LineWidth', 1);
grid on; xlabel(xlab); ylabel("Tw");
legend("Measured (Dymola)", "Open-loop (e=0)", "1-step (with K)", "Location","best");
title("Wall node temperature Tw");

figure; 
plot(tt, y(:,2)-273.15, 'LineWidth', 1); hold on;
plot(tt, yhat_ol(:,2)-273.15, 'LineWidth', 1);
plot(tt, yhat_1s(:,2)-273.15, 'LineWidth', 1);
grid on; xlabel(xlab); ylabel("Ti");
legend("Measured (Dymola)", "Open-loop (e=0)", "1-step (with K)", "Location","best");
title("Indoor temperature Ti");

%% =========================
%  稳定性检查（可选但建议）
% =========================
eigA = eig(A);
fprintf("\nA 的特征值（极点）= [%.6g, %.6g]\n", eigA(1), eigA(2));
fprintf("是否稳定（|lambda|<1）= %d\n", all(abs(eigA)<1));


function M = pickLargestNumericMatrix(S)
% 从 load() 得到的 struct 里，挑出"元素个数最多"的数值矩阵
fn = fieldnames(S);
bestNumel = -1;
M = [];

for i = 1:numel(fn)
    v = S.(fn{i});
    if isnumeric(v) && ismatrix(v) && ~isempty(v)
        n = numel(v);
        if n > bestNumel
            bestNumel = n;
            M = v;
        end
    end
end

if isempty(M)
    error("MAT 文件中没有找到可用的数值矩阵。请确认 state.mat/input.mat 里保存的是矩阵。");
end
end

function t = tryGetTimeVector(S)
% 尝试从 struct 中找时间向量，常见变量名：t, time, Time
cands = ["t","time","Time","T"];
t = [];
for name = cands
    if isfield(S, name)
        v = S.(name);
        if isnumeric(v) && isvector(v) && ~isempty(v)
            t = v(:);
            return;
        end
    end
end
end
