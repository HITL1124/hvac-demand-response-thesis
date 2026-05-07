%% Stage1_CQR_refactored_Ts_ma.m
% =========================================================================
% Stage1-CQR（重构版）：
% 基于 15min 数据 + N4SID 主模型 + CQR，生成未来 24h 室温预测区间
%
% 【重构目标】
% 1) 将控制输入从单一 Q_h 改为双控制输入 [Ts, ma]
% 2) 保持其余扰动输入不变：[To, Isol, Qint]
% 3) 为 Stage2 导出"双控制输入"的小时级模型接口
%
% 输入矩阵约定：
%   U = [Ts, ma, To, Isol, Qint]
%        1   2   3    4      5
%
% 其中：
%   Ts   : 供水/送风温度（K）
%   ma   : 供风质量流量（kg/s）
%   To   : 室外温度
%   Isol : 太阳辐照
%   Qint : 内部得热
%
% =========================================================================

clear; clc; close all;

%% =========================
% 1) 用户配置区
% =========================
stateFile = project_data_file('processed', 'processed_state.mat');
inputFile = project_data_file('processed', 'processed_input.mat');

Ts_stage1 = 15 * 60;      % 已经是 15min 数据
nx = 2;                   % N4SID 阶数
useRemoveMean = true;

% ---------- CQR 设置 ----------
H = 96;                   % 默认 24h 全时域（96 个 15min 点）
L_hist = 24;              % 历史窗口长度（24个15min=6h）
coverage_vec = [0.80 0.85 0.90 0.95];

% ---------- Stage2 导出设置 ----------
stepsPerHour = round(3600 / Ts_stage1);   % 15min -> 1h => 4
stepsPerDay  = round(24*3600 / Ts_stage1);

if stepsPerHour <= 0
    error("stepsPerHour 计算错误。");
end

% 原始舒适边界（供 Stage2 使用）
Tmin = 293.15;
Tmax = 297.15;

% 手动指定"某天 0:00"作为 Stage2 起点
useManualStage2MidnightOrigin = true;
stage2DayIndex = 2;

% 数据划分（按时间顺序，对预测起点样本划分）
trainRatio = 0.60;
calRatio   = 0.20;
testRatio  = 0.20; %#ok<NASGU>

makePlots = true;

% ---------- 是否只取前若干天数据（便于快速测试） ----------
useFirstNDays = false;
numDaysToUse  = 14;

%% =========================
% 2) 读取 15min 原始数据
% =========================
Sx = load(stateFile);
Su = load(inputFile);

T = pickLargestNumericMatrix(Sx);   % 室温
U = pickLargestNumericMatrix(Su);   % [Ts, ma, To, Isol, Qint]

if size(T,2) ~= 1
    warning("state.mat 最大矩阵不是 N×1，默认取第1列作为室温。");
    T = T(:,1);
end

if size(U,2) ~= 5
    error("input.mat 最大矩阵列数应为5：[Ts, ma, To, Isol, Qint]。实际为 %d 列。", size(U,2));
end

N = size(U,1);
if size(T,1) ~= N
    error("state 与 input 行数不一致：state=%d, input=%d", size(T,1), N);
end

Ts   = U(:,1);
ma   = U(:,2);
To   = U(:,3);
Isol = U(:,4);
Qint = U(:,5);

fprintf("已读取 15min 数据：N=%d, 覆盖时长约 %.1f 天\n", N, N*Ts_stage1/86400);
fprintf("输入列定义：[Ts, ma, To, Isol, Qint]\n");

%% =========================
% 2.1) 可选：只取前若干天数据
% =========================
if useFirstNDays
    N_use = numDaysToUse * stepsPerDay;

    if N_use < (L_hist + H + 50)
        error("numDaysToUse 太小：可用样本不足。当前至少建议 >= ceil((L_hist+H+50)/stepsPerDay) 天。");
    end

    if N_use > N
        warning("要求使用 %d 天，但数据总长度只有 %.1f 天，将使用全部数据。", ...
            numDaysToUse, N*Ts_stage1/86400);
        N_use = N;
    end

    T = T(1:N_use, :);
    U = U(1:N_use, :);

    N = size(U,1);

    Ts   = U(:,1);
    ma   = U(:,2);
    To   = U(:,3);
    Isol = U(:,4);
    Qint = U(:,5);

    fprintf("已裁剪为前 %d 天数据：N=%d, 覆盖时长约 %.1f 天\n", ...
        numDaysToUse, N, N*Ts_stage1/86400);
end

%% =========================
% 3) 训练 N4SID 主模型
% =========================
N_id = max(100, floor(0.7 * N));
idxIdTr = 1:N_id;
idxIdVa = (N_id+1):N;

U_id_tr = U(idxIdTr,:);
T_id_tr = T(idxIdTr,:);
U_id_va = U(idxIdVa,:);
T_id_va = T(idxIdVa,:);

nU = size(U,2);

if useRemoveMean
    u_mean = mean(U_id_tr, 1);
    t_mean = mean(T_id_tr, 1);

    U_id_tr_z = U_id_tr - u_mean;
    T_id_tr_z = T_id_tr - t_mean;

    U_id_va_z = U_id_va - u_mean;
    T_id_va_z = T_id_va - t_mean;
else
    u_mean = zeros(1,nU);
    t_mean = 0;

    U_id_tr_z = U_id_tr;
    T_id_tr_z = T_id_tr;

    U_id_va_z = U_id_va;
    T_id_va_z = T_id_va;
end

data_id_tr = iddata(T_id_tr_z, U_id_tr_z, Ts_stage1);
data_id_va = iddata(T_id_va_z, U_id_va_z, Ts_stage1);

opt = n4sidOptions('Focus','simulation','EnforceStability',true);
model_ss = n4sid(data_id_tr, nx, opt);

A = model_ss.A;
B = model_ss.B;
C = model_ss.C;
D = model_ss.D;

fprintf("\n===== N4SID(15min) 主模型辨识完成 =====\n");
disp("A = "); disp(A);
disp("B = "); disp(B);
disp("C = "); disp(C);
disp("D = "); disp(D);

if makePlots
    figure;
    compare(data_id_va, model_ss);
    title('N4SID(15min) 在验证段上的 compare（中心化尺度）');
end

%% =========================
% 4) 构造预测起点索引并按时间顺序划分
% =========================
origin_idx = (L_hist : (N - H)).';
nOrigin = numel(origin_idx);

if nOrigin < 100
    error("可用预测起点太少：nOrigin=%d。请检查数据长度、L_hist、H。", nOrigin);
end

nTr  = floor(trainRatio * nOrigin);
nCal = floor(calRatio   * nOrigin);
nTe  = nOrigin - nTr - nCal;

idx_origin_tr  = origin_idx(1:nTr);
idx_origin_cal = origin_idx(nTr+1 : nTr+nCal);
idx_origin_te  = origin_idx(nTr+nCal+1 : end);

fprintf("\n===== 预测起点样本划分 =====\n");
fprintf("总起点数 nOrigin = %d\n", nOrigin);
fprintf("Train = %d, Calibration = %d, Test = %d\n", ...
    numel(idx_origin_tr), numel(idx_origin_cal), numel(idx_origin_te));

%% =========================
% 5) 为所有 horizon 构造数据集
% =========================
fprintf("\n===== 开始构造各 horizon 数据集 =====\n");

X_all = cell(H,1);
Y_all = cell(H,1);

for k = 1:H
    nSamp_k = nOrigin;
    Xk = [];
    Yk = zeros(nSamp_k, 1);

    for ii = 1:nSamp_k
        t0 = origin_idx(ii);

        x_row = build_feature_row( ...
            T, U, t0, k, L_hist, ...
            A, B, C, D, u_mean, t_mean, useRemoveMean);

        if ii == 1
            Xk = zeros(nSamp_k, numel(x_row));
        end
        Xk(ii,:) = x_row;

        Yk(ii) = T(t0 + k);
    end

    X_all{k} = Xk;
    Y_all{k} = Yk;

    if mod(k,8) == 0 || k == 1 || k == H
        fprintf("  已完成 horizon k=%d / %d\n", k, H);
    end
end

fprintf("所有 horizon 数据集构造完成。\n");

%% =========================
% 导出 CQR 数据给 Python 树模型
% =========================
CQRData = struct();

CQRData.H = H;
CQRData.L_hist = L_hist;
CQRData.coverage_vec = coverage_vec;
CQRData.Ts_stage1 = Ts_stage1;

CQRData.A = A;
CQRData.B = B;
CQRData.C = C;
CQRData.D = D;
CQRData.u_mean = u_mean;
CQRData.t_mean = t_mean;
CQRData.useRemoveMean = useRemoveMean;

CQRData.T = T;
CQRData.U = U;
CQRData.input_names = {'Ts','ma','To','Isol','Qint'};
CQRData.ctrl_input_idx = [1 2];
CQRData.dist_input_idx = [3 4 5];

CQRData.X_all = X_all;
CQRData.Y_all = Y_all;

CQRData.origin_idx = origin_idx;
CQRData.idx_origin_tr = idx_origin_tr;
CQRData.idx_origin_cal = idx_origin_cal;
CQRData.idx_origin_te = idx_origin_te;

save(project_data_file('stage1', 'stage1_cqr_tree_data.mat'), '-struct', 'CQRData', '-v7.3');
fprintf('已保存 stage1_cqr_tree_data.mat，供 Python 树模型使用。\n');

Stage2Model = struct();
Stage2Model.A = A;
Stage2Model.B = B;
Stage2Model.C = C;
Stage2Model.D = D;
Stage2Model.u_mean = u_mean;
Stage2Model.t_mean = t_mean;
Stage2Model.useRemoveMean = useRemoveMean;
Stage2Model.H = H;
Stage2Model.Nh = H / 4;
Stage2Model.ns = 4;
Stage2Model.Ts_stage1 = Ts_stage1;
Stage2Model.stepsPerHour = round(3600 / Ts_stage1);
Stage2Model.stepsPerDay = round(24 * 3600 / Ts_stage1);
Stage2Model.Tmin = 293.15;
Stage2Model.Tmax = 297.15;
Stage2Model.input_names = {'Ts','ma','To','Isol','Qint'};
Stage2Model.ctrl_input_idx = [1 2];
Stage2Model.dist_input_idx = [3 4 5];

save(project_data_file('stage1', 'stage1_hour_model_for_stage2.mat'), '-struct', 'Stage2Model');
fprintf('已保存 stage1_hour_model_for_stage2.mat，供 Stage2 默认加载。\n');


%% =====================================================================
% 工具函数区
% =====================================================================

function M = pickLargestNumericMatrix(S)
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
    error("MAT 文件中未找到可用数值矩阵。");
end
end

function x_row = build_feature_row(T, U, t0, k, L_hist, A, B, C, D, u_mean, t_mean, useRemoveMean)
N = size(U,1);

if t0 < L_hist
    error('build_feature_row: t0=%d < L_hist=%d', t0, L_hist);
end
if (t0 + k) > N
    error('build_feature_row: t0+k=%d 超出数据长度 N=%d', t0+k, N);
end

idx_hist = (t0 - L_hist + 1):t0;
T_hist = T(idx_hist, :).';
U_hist = U(idx_hist, :).';

feat_T_hist = T_hist(:).';
feat_U_hist = U_hist(:).';

idx_fut = (t0 + 1):(t0 + k);
U_fut = U(idx_fut, :).';
feat_U_fut = U_fut(:).';

if useRemoveMean
    y0_z = T(t0) - t_mean;
    x = pinv(C) * y0_z;
else
    y0_z = T(t0);
    x = pinv(C) * y0_z;
end

for j = 1:k
    u_j = U(t0 + j, :).';
    if useRemoveMean
        u_j = u_j - u_mean(:);
    end
    x = A * x + B * u_j;
end

u_k = U(t0 + k, :).';
if useRemoveMean
    u_k_z = u_k - u_mean(:);
    yhat_k = C * x + D * u_k_z + t_mean;
else
    yhat_k = C * x + D * u_k;
end

feat_time = [k];
x_row = [feat_T_hist, feat_U_hist, feat_U_fut, yhat_k, feat_time];
end
