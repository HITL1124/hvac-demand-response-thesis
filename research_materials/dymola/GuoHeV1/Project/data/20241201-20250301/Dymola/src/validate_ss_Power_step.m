%% validate_ss_Power_step.m
% 目的：
% 1) 验证 N4SID 离散状态空间模型能否复现 Dymola 温度状态
% 2) 改成"在线滚动"：每个时间步预测温度 -> 立刻算该步热泵功率/热量 -> 再滚动到下一步
% 3) 基于质量流量-功率拟合模型计算风机功率，并与 Dymola 真值对比
%
% 数据说明：
%   输入 u = [Tsup, mdot, To, Isol, Qint]
%   输出 y = [Tw, Ti]
%
% 文件说明：
%   processed_state.mat      : N×2, [Tw, Ti]
%   processed_input.mat      : N×5, [Tsup, mdot, To, Isol, Qint]
%   processed_HPdata.mat     : N×3, [Pele(W), QCon_flow(W), COP]
%   processed_Fandata.mat    : N×2, [SupFan_P(W), RetFan_P(W)]

clear; clc; close all;

%% =========================
%  1. 用户配置区
% =========================

% (1) 离散状态空间模型矩阵（N4SID 识别结果）
A = [0.969, -0.01113;
     0.06823, 0.9002];

B = [0.001245, 0.0002569, 5.861e-05, 2.681e-06, 3.665e-08;
     0.002678, -0.0007502, -0.008811, 4.99e-06, 2.588e-08];

C = [15.58, -7.268;
     19.13, -0.3258];

D = zeros(2,5);

% (2) 一步预测校正增益（创新形式）
K = [0.002133, 0.02767;
     -0.1276, 0.05851];

% (3) 采样时间（s）
Ts = 60;

% (4) 是否对数据去均值（需与识别阶段一致）
useRemoveMean = true;

% (5) 绘图时间单位
plotTimeInHours = true;

%% =========================
%  2. 读取数据（状态与输入）
% =========================
stateFile = "../data/processeddata/processed_state.mat";   % N×2: [Tw, Ti]
inputFile = "../data/processeddata/processed_input.mat";   % N×5: [Tsup, mdot, To, Isol, Qint]

Sx = load(stateFile);
Su = load(inputFile);

% 从 mat 中自动提取"最大的数值矩阵"作为数据
state = pickLargestNumericMatrix(Sx);
inp   = pickLargestNumericMatrix(Su);

% 数据维度检查
if size(state,2) ~= 2
    error("stateFile 中识别到的状态矩阵列数不是2。实际 size=[%d,%d]", size(state,1), size(state,2));
end
if size(inp,2) ~= 5
    error("inputFile 中识别到的输入矩阵列数不是5。实际 size=[%d,%d]", size(inp,1), size(inp,2));
end

y = state;   % 输出 y=[Tw Ti]，单位 K
u = inp;     % 输入 u=[Tsup mdot To Isol Qint]，温度单位 K，流量 kg/s

N = size(u,1);
if size(y,1) ~= N
    error("state 与 input 行数不一致：state=%d, input=%d", size(y,1), N);
end

% 时间向量：优先从文件中读取，否则按 Ts 构造
t = [];
t = tryGetTimeVector(Sx);
if isempty(t), t = tryGetTimeVector(Su); end

if isempty(t)
    t = (0:N-1)' * Ts;
else
    t = t(:);
    if numel(t) ~= N
        error("时间向量长度与数据长度不一致：length(t)=%d, N=%d", numel(t), N);
    end
end

% 检查采样步长
if numel(t) > 1
    dt = median(diff(t));
    if abs(dt - Ts) > 1e-6
        warning("数据时间步长 median(diff(t))=%.6g 与 Ts=%.6g 不一致。", dt, Ts);
    end
end

% 统一生成绘图时间轴 tt
if plotTimeInHours
    tt   = (t - t(1))/3600;
    xlab = "Time (h)";
else
    tt   = t - t(1);
    xlab = "Time (s)";
end

%% =========================
%  3. 可选：去均值（需与识别阶段一致）
% =========================
if useRemoveMean
    uMean = mean(u,1);
    yMean = mean(y,1);
    uZ = u - uMean;
    yZ = y - yMean;
else
    uZ = u;
    yZ = y;
    yMean = zeros(1,2); % 方便后面统一写法
end

%% =========================
%  4. 初始化状态 x0（由 y0 反推）
%     y0 = C x0 + D u0, 这里 D=0
% =========================
y0 = yZ(1,:)';
u0 = uZ(1,:)';
rhs = y0 - D*u0;

if abs(det(C)) > 1e-10
    x0 = C \ rhs;
else
    warning("C 可能不可逆，改用 pinv(C) 初始化。");
    x0 = pinv(C) * rhs;
end

%% =========================
%  5. 热泵功率计算：参数（保持你的源代码标定常数）
% =========================
hpPar = struct();
hpPar.beta     = 0.30;     % 新风比
hpPar.UA       = 9.5e4;    % 盘管 UA_nominal
hpPar.cp_air   = 1006;     % 空气比热
hpPar.cp_w     = 4200;     % 水比热
hpPar.mw       = 55;       % 水侧质量流量（常数）
hpPar.Qcon_nom = 450e3;    % 名义供热量
hpPar.Qcon_max = 650e3;    % 最大供热量
hpPar.COP_nom  = 3.0;      % 名义 COP

hpPar.Tcon_nom = 313.15;   % 名义冷凝温度
hpPar.TAppCon  = 2.0;      % 冷凝器逼近温差
hpPar.TAppEva  = 5.0;      % 蒸发器逼近温差
hpPar.mEva     = 64;       % 蒸发器空气侧质量流量

hpPar.r_nominal      = 2/3;
hpPar.mAir_nominal   = 25;
hpPar.TairIn_nominal = 287.45;  % 空气入口名义温度 (K)
hpPar.TwIn_nominal   = 313.15;  % 水入口名义温度 (K)
hpPar.nAir           = 0.8;
hpPar.Ts             = Ts;      % 供水温度一阶滞后离散步长（与外部采样一致）

% 名义蒸发温度（需给定）
hpPar.Teva_nom = 273.15+1.8;

% 部分负荷多项式 a={0.9,0.1,0}
hpPar.aPL = [0.9, 0.1, 0.0];

%（如需一阶滞后）hpPar.tauCon = ...;  % 如果你源代码本来就有就保留，没有就不加
if ~isfield(hpPar,'tauCon')
    hpPar.tauCon = 0;
end

%% =========================
%  6. 提前拆分输入
% =========================
Tsup = u(:,1);   % K
mAir = u(:,2);   % kg/s
Tout = u(:,3);   % K

%% =========================
%  7. 在线滚动：一步一步预测温度 + 同步计算热泵功率
% =========================

% 预测输出（原量纲）
yhat_ol = zeros(N,2);
yhat_1s = zeros(N,2);

% 热泵结果（每步）
Php_ol   = zeros(N,1);  COP_ol   = zeros(N,1);  Qcoil_ol = zeros(N,1);  Tret_ol = zeros(N,1);
Php_1s   = zeros(N,1);  COP_1s   = zeros(N,1);  Qcoil_1s = zeros(N,1);  Tret_1s = zeros(N,1);

% 状态初始化（在去均值域中递推）
x_ol = x0;
x_1s = x0;

% 热泵内部状态（用于 Tin_prev / COP_prev 连续）
hpState_ol = struct();
hpState_1s = struct();
hpState_ol.Tin_prev = Tsup(1);
hpState_1s.Tin_prev = Tsup(1);
hpState_ol.COP_prev = hpPar.COP_nom;
hpState_1s.COP_prev = hpPar.COP_nom;

for k = 1:N
    % 1) 当前步输出预测（去均值域）
    ypred_ol_Z = C*x_ol + D*uZ(k,:)';
    ypred_1s_Z = C*x_1s + D*uZ(k,:)';

    % 2) 保存预测（恢复到原量纲）
    yhat_ol(k,:) = (ypred_ol_Z' + yMean);
    yhat_1s(k,:) = (ypred_1s_Z' + yMean);

    % 3) 该步热泵功率计算：用"当前步预测室温 Ti_hat(k)"
    Ti_hat_ol = yhat_ol(k,2);
    Ti_hat_1s = yhat_1s(k,2);

    [Php_ol(k), COP_ol(k), Qcoil_ol(k), Tret_ol(k), hpState_ol] = ...
        calcHpPowerCarnotEpsNTU_step(Tsup(k), mAir(k), Tout(k), Ti_hat_ol, hpPar, hpState_ol);

    [Php_1s(k), COP_1s(k), Qcoil_1s(k), Tret_1s(k), hpState_1s] = ...
        calcHpPowerCarnotEpsNTU_step(Tsup(k), mAir(k), Tout(k), Ti_hat_1s, hpPar, hpState_1s);

    % 4) 状态更新到下一步（仍在去均值域）
    % 开环：e=0
    x_ol = A*x_ol + B*uZ(k,:)';

    % 一步预测/跟踪：创新 e(k)
    e = yZ(k,:)' - ypred_1s_Z;
    x_1s = A*x_1s + B*uZ(k,:)' + K*e;
end

%% =========================
%  8. 读取 Dymola 热泵真值：processed_HPdata.mat（N×3）
% =========================
hpTruthFile = "../data/processeddata/processed_HPdata.mat";
Pele_sim = [];
Qcon_sim = [];
COP_sim  = [];

if isfile(hpTruthFile)
    Sp = load(hpTruthFile);
    HPdat = pickLargestNumericMatrix(Sp);

    if size(HPdat,2) ~= 3
        warning("processed_HPdata.mat 最大矩阵不是 N×3，实际 size=[%d,%d]，跳过热泵对比。", size(HPdat,1), size(HPdat,2));
        HPdat = [];
    end

    if ~isempty(HPdat)
        if size(HPdat,1) ~= N
            warning("热泵真值数据行数与 N 不一致：HP=%d, N=%d，跳过热泵对比。", size(HPdat,1), N);
        else
            Pele_sim = HPdat(:,1);
            Qcon_sim = HPdat(:,2);
            COP_sim  = HPdat(:,3);
        end
    end
else
    warning("未找到 %s，将仅输出热泵机理结果，不进行热泵对比。", hpTruthFile);
end

% 真值一致性自检：Pele ?= Qcon/COP
if ~isempty(Pele_sim)
    Pele_from_QCOP = Qcon_sim ./ max(COP_sim, 1e-6);
    err_cons = Pele_from_QCOP - Pele_sim;

    fprintf("\n===== 真值一致性自检：Pele ?= Qcon/COP =====\n");
    fprintf("RMSE=%.6g W, MAE=%.6g W, MaxAbs=%.6g W\n", ...
        sqrt(mean(err_cons.^2)), mean(abs(err_cons)), max(abs(err_cons)));
end

%% =========================
%  9. 风机功率计算（基于质量流量的三次多项式拟合：总功率）
% =========================
fanPar = struct();
fanPar.p1 = 3.133064171;
fanPar.p2 = 6.087791979;
fanPar.p3 = -59.56637575;
fanPar.p4 = 208.2979381;

Pfan_tot_fit = calcFanPowerPoly3(mAir, fanPar);

% 读取 Dymola 风机真值：processed_Fandata.mat（N×2）
fanTruthFile = "../data/processeddata/processed_Fandata.mat";
Pfan_sup_sim = [];
Pfan_ret_sim = [];
Pfan_tot_sim = [];

if isfile(fanTruthFile)
    Sf = load(fanTruthFile);
    Fdat = pickLargestNumericMatrix(Sf);

    if size(Fdat,2) ~= 2
        warning("processed_Fandata.mat 最大矩阵不是 N×2，实际 size=[%d,%d]，跳过风机对比。", size(Fdat,1), size(Fdat,2));
        Fdat = [];
    end

    if ~isempty(Fdat)
        if size(Fdat,1) ~= N
            warning("风机真值数据行数与 N 不一致：Fan=%d, N=%d，跳过风机对比。", size(Fdat,1), N);
        else
            Pfan_sup_sim = Fdat(:,1);
            Pfan_ret_sim = Fdat(:,2);
            Pfan_tot_sim = Pfan_sup_sim + Pfan_ret_sim;
        end
    end
else
    warning("未找到 %s，将仅输出风机拟合结果，不进行风机对比。", fanTruthFile);
end

%% =========================
%  10. 绘图：热泵对比
% =========================

% 电功率
figure;
plot(tt, Php_ol/1e3, 'LineWidth', 1); hold on;
plot(tt, Php_1s/1e3, 'LineWidth', 1);
ylim([0, inf]);
if ~isempty(Pele_sim)
    plot(tt, Pele_sim/1e3, 'LineWidth', 1);
    legend("热泵机理(OL室温,在线)", "热泵机理(1-step室温,在线)", "Dymola 热泵Pele", "Location","best");
else
    legend("热泵机理(OL室温,在线)", "热泵机理(1-step室温,在线)", "Location","best");
end
grid on; xlabel(xlab); ylabel("P_{hp} (kW)");
title("热泵电功率：在线机理预测 vs Dymola");

% 热功率
figure;
plot(tt, Qcoil_ol/1e3, 'LineWidth', 1); hold on;
plot(tt, Qcoil_1s/1e3, 'LineWidth', 1);
ylim([0, inf]);
if ~isempty(Qcon_sim)
    plot(tt, Qcon_sim/1e3, 'LineWidth', 1);
    legend("盘管机理Qcoil(OL室温,在线)", "盘管机理Qcoil(1-step室温,在线)", "Dymola QCon_flow", "Location","best");
else
    legend("盘管机理Qcoil(OL室温,在线)", "盘管机理Qcoil(1-step室温,在线)", "Location","best");
end
grid on; xlabel(xlab); ylabel("Q (kW)");
title("热功率：盘管机理Qcoil vs Dymola QCon_flow");

% COP
figure;
plot(tt, COP_ol, 'LineWidth', 1); hold on;
plot(tt, COP_1s, 'LineWidth', 1);
ylim([0, inf]);
if ~isempty(COP_sim)
    plot(tt, COP_sim, 'LineWidth', 1);
    legend("机理COP(OL室温,在线)", "机理COP(1-step室温,在线)", "Dymola COP", "Location","best");
else
    legend("机理COP(OL室温,在线)", "机理COP(1-step室温,在线)", "Location","best");
end
grid on; xlabel(xlab); ylabel("COP");
title("COP：在线机理预测 vs Dymola");

%% =========================
%  11. 绘图：风机总功率对比
% =========================
if ~isempty(Pfan_tot_sim)
    figure;
    plot(tt, Pfan_tot_fit/1e3, 'LineWidth', 1); hold on;
    plot(tt, Pfan_tot_sim/1e3, 'LineWidth', 1);
    grid on; xlabel(xlab); ylabel("P_{fan,tot} (kW)");
    legend("风机总功率拟合模型", "Dymola 风机总功率(送+回)", "Location","best");
    title("风机总功率：拟合模型 vs Dymola");
end

%% =========================
%  12. 误差指标：热泵（机理 vs Dymola）
% =========================
if ~isempty(Pele_sim)
    eP_ol = Php_ol - Pele_sim;
    eP_1s = Php_1s - Pele_sim;

    eQ_ol = Qcoil_ol - Qcon_sim;
    eQ_1s = Qcoil_1s - Qcon_sim;

    eCOP_ol = COP_ol - COP_sim;
    eCOP_1s = COP_1s - COP_sim;

    fprintf("\n===== 热泵对比误差（在线机理 vs Dymola）=====\n");
    fprintf("电功率 Pele：\n");
    fprintf("  OL : RMSE=%.4g W, MAE=%.4g W, MaxAbs=%.4g W\n", sqrt(mean(eP_ol.^2)), mean(abs(eP_ol)), max(abs(eP_ol)));
    fprintf("  1s : RMSE=%.4g W, MAE=%.4g W, MaxAbs=%.4g W\n", sqrt(mean(eP_1s.^2)), mean(abs(eP_1s)), max(abs(eP_1s)));

    fprintf("热功率 Q（Qcoil vs QCon_flow）：\n");
    fprintf("  OL : RMSE=%.4g W, MAE=%.4g W, MaxAbs=%.4g W\n", sqrt(mean(eQ_ol.^2)), mean(abs(eQ_ol)), max(abs(eQ_ol)));
    fprintf("  1s : RMSE=%.4g W, MAE=%.4g W, MaxAbs=%.4g W\n", sqrt(mean(eQ_1s.^2)), mean(abs(eQ_1s)), max(abs(eQ_1s)));

    fprintf("COP：\n");
    fprintf("  OL : RMSE=%.4g, MAE=%.4g, MaxAbs=%.4g\n", sqrt(mean(eCOP_ol.^2)), mean(abs(eCOP_ol)), max(abs(eCOP_ol)));
    fprintf("  1s : RMSE=%.4g, MAE=%.4g, MaxAbs=%.4g\n", sqrt(mean(eCOP_1s.^2)), mean(abs(eCOP_1s)), max(abs(eCOP_1s)));
end

%% =========================
%  13. 误差指标：风机总功率（拟合 vs Dymola）
% =========================
if ~isempty(Pfan_tot_sim)
    eFanTot = Pfan_tot_fit - Pfan_tot_sim;

    fprintf("\n===== 风机总功率对比误差（拟合 vs Dymola）=====\n");
    fprintf("RMSE=%.4g W, MAE=%.4g W, MaxAbs=%.4g W\n", ...
        sqrt(mean(eFanTot.^2)), mean(abs(eFanTot)), max(abs(eFanTot)));
end

%% =========================
%  14. 温度状态验证误差（yhat vs y）
% =========================
err_ol = yhat_ol - y;
err_1s = yhat_1s - y;

metrics = @(e) struct( ...
    "RMSE",   sqrt(mean(e.^2,1)), ...
    "MAE",    mean(abs(e),1), ...
    "MaxAbs", max(abs(e),[],1) );

m_ol = metrics(err_ol);
m_1s = metrics(err_1s);

fprintf("\n===== 温度状态验证：开环仿真（e=0,在线）=====\n");
fprintf("Tw: RMSE=%.4g, MAE=%.4g, MaxAbs=%.4g\n", m_ol.RMSE(1), m_ol.MAE(1), m_ol.MaxAbs(1));
fprintf("Ti: RMSE=%.4g, MAE=%.4g, MaxAbs=%.4g\n", m_ol.RMSE(2), m_ol.MAE(2), m_ol.MaxAbs(2));

fprintf("\n===== 温度状态验证：一步预测/跟踪（用 K,在线）=====\n");
fprintf("Tw: RMSE=%.4g, MAE=%.4g, MaxAbs=%.4g\n", m_1s.RMSE(1), m_1s.MAE(1), m_1s.MaxAbs(1));
fprintf("Ti: RMSE=%.4g, MAE=%.4g, MaxAbs=%.4g\n", m_1s.RMSE(2), m_1s.MAE(2), m_1s.MaxAbs(2));

%% =========================
%  15. 绘图：温度状态对比
% =========================
figure;
plot(tt, y(:,1)-273.15, 'LineWidth', 1); hold on;
plot(tt, yhat_ol(:,1)-273.15, 'LineWidth', 1);
plot(tt, yhat_1s(:,1)-273.15, 'LineWidth', 1);
grid on; xlabel(xlab); ylabel("Tw (°C)");
legend("Dymola", "开环(在线)", "一步预测(在线)", "Location","best");
title("墙体节点温度 Tw");

figure;
plot(tt, y(:,2)-273.15, 'LineWidth', 1); hold on;
plot(tt, yhat_ol(:,2)-273.15, 'LineWidth', 1);
plot(tt, yhat_1s(:,2)-273.15, 'LineWidth', 1);
grid on; xlabel(xlab); ylabel("Ti (°C)");
legend("Dymola", "开环(在线)", "一步预测(在线)", "Location","best");
title("室内温度 Ti");

%% =========================
%  16. 稳定性检查（A 矩阵极点）
% =========================
eigA = eig(A);
fprintf("\nA 的特征值 = [%.6g, %.6g]\n", eigA(1), eigA(2));
fprintf("是否稳定（|lambda|<1）= %d\n", all(abs(eigA)<1));

%% =====================================================================
%  工具函数区
% =====================================================================

function M = pickLargestNumericMatrix(S)
% 从 load() 得到的 struct 中，挑出元素个数最多的数值矩阵
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

function t = tryGetTimeVector(S)
% 从 struct 中尝试提取时间向量（常见变量名：t/time/Time/T）
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

function P = calcFanPowerPoly3(m, par)
% 风机功率拟合模型（三次多项式）
m = m(:);
P = par.p1.*m.^3 + par.p2.*m.^2 + par.p3.*m + par.p4;
P = max(P, 0);
end

function [Php, COP, Qcoil, Tret, hpState] = calcHpPowerCarnotEpsNTU_step(Tsup, mAir, Tout, Ti, par, hpState)
% 单步版本：保持你"源代码标定常数"不被改动
% 输入标量 Tsup/mAir/Tout/Ti，输出该步 Php/COP/Qcoil/Tret，并更新 hpState

eps_small = 1e-9;

% ---- 必要标定常数检查（不允许在函数里"随意补/改"）----
assert(isfield(par,'mAir_nominal')   && ~isempty(par.mAir_nominal),   "hpPar.mAir_nominal 缺失");
assert(isfield(par,'TairIn_nominal') && ~isempty(par.TairIn_nominal), "hpPar.TairIn_nominal 缺失");
assert(isfield(par,'TwIn_nominal')   && ~isempty(par.TwIn_nominal),   "hpPar.TwIn_nominal 缺失");
assert(isfield(par,'r_nominal')      && ~isempty(par.r_nominal),      "hpPar.r_nominal 缺失");
assert(isfield(par,'UA')             && ~isempty(par.UA),             "hpPar.UA 缺失");
assert(isfield(par,'mw')             && ~isempty(par.mw),             "hpPar.mw 缺失");
assert(isfield(par,'Qcon_nom')       && ~isempty(par.Qcon_nom),       "hpPar.Qcon_nom 缺失");
assert(isfield(par,'Qcon_max')       && ~isempty(par.Qcon_max),       "hpPar.Qcon_max 缺失");
assert(isfield(par,'COP_nom')        && ~isempty(par.COP_nom),        "hpPar.COP_nom 缺失");
assert(isfield(par,'Tcon_nom')       && ~isempty(par.Tcon_nom),       "hpPar.Tcon_nom 缺失");
assert(isfield(par,'Teva_nom')       && ~isempty(par.Teva_nom),       "hpPar.Teva_nom 缺失");
assert(isfield(par,'TAppCon')        && ~isempty(par.TAppCon),        "hpPar.TAppCon 缺失");
assert(isfield(par,'TAppEva')        && ~isempty(par.TAppEva),        "hpPar.TAppEva 缺失");
assert(isfield(par,'mEva')           && ~isempty(par.mEva),           "hpPar.mEva 缺失");
assert(isfield(par,'aPL')            && ~isempty(par.aPL),            "hpPar.aPL 缺失");
assert(isfield(par,'beta')           && ~isempty(par.beta),           "hpPar.beta 缺失");
assert(isfield(par,'cp_air')         && ~isempty(par.cp_air),         "hpPar.cp_air 缺失");
assert(isfield(par,'cp_w')           && ~isempty(par.cp_w),           "hpPar.cp_w 缺失");
assert(isfield(par,'nAir')           && ~isempty(par.nAir),           "hpPar.nAir 缺失");
assert(isfield(par,'Ts')             && ~isempty(par.Ts),             "hpPar.Ts 缺失");
assert(isfield(par,'tauCon')         && ~isempty(par.tauCon),         "hpPar.tauCon 缺失");

if ~isfield(hpState,'Tin_prev') || isempty(hpState.Tin_prev)
    hpState.Tin_prev = Tsup;
end
if ~isfield(hpState,'COP_prev') || isempty(hpState.COP_prev)
    hpState.COP_prev = par.COP_nom;
end

% ---- 名义卡诺有效度 etaCarnot0（与你源代码一致）----
den0 = par.Tcon_nom + par.TAppCon - (par.Teva_nom - par.TAppEva);
den0 = max(den0, 0.5);
etaCarnot0 = par.COP_nom / ( par.Tcon_nom / den0 );

% ---- HADryCoil 思路：UA_nominal 分解并随工况变化合成 UA(t) ----
r = max(par.r_nominal, 1e-6);
UA0 = max(par.UA, eps_small);
hAw0 = UA0*(r+1)/r;
hAa0 = UA0*(r+1);

% ---- 供水温度(盘管入口)一阶滞后 ----
Tin_prev = hpState.Tin_prev;
if par.tauCon > 0
    alpha = par.Ts / max(par.tauCon + par.Ts, eps_small);
else
    alpha = 1;
end
Tin = Tin_prev + alpha*(Tsup - Tin_prev);
hpState.Tin_prev = Tin;

% 0) 回风/新风混合（仅用于温度修正 x_a）
Tmix = par.beta*Tout + (1-par.beta)*Ti;

% 1) 温度修正因子（与你源代码一致）
theta_a    = (Tmix - 273.15);
theta_a0   = (par.TairIn_nominal - 273.15);
x_a = 1 + 4.769e-3*(theta_a - theta_a0);
x_a = max(x_a, 1e-3);

theta_w    = (Tin - 273.15);
theta_w0   = (par.TwIn_nominal - 273.15);
theta_w0_safe = max(theta_w0, 1e-3);
s_w = 0.014 / ( theta_w0_safe * (1 + 0.014*theta_w0_safe) );
x_w = 1 + s_w*(theta_w - theta_w0);
x_w = max(x_w, 1e-3);

% 2) 对流换热能力随流量变化
ma = max(mAir, 0);
ma0 = max(par.mAir_nominal, eps_small);
hAa = hAa0 * (ma/ma0)^par.nAir * x_a;

mw  = max(par.mw, eps_small);
mw0 = max(par.mw, eps_small);
hAw = hAw0 * (mw/mw0)^0.85 * x_w;

UA = (hAa*hAw) / max(hAa + hAw, eps_small);
UA = max(UA, eps_small);

% 3) ε-NTU 计算盘管显热
Cair = max(ma*par.cp_air, eps_small);
Cw   = max(mw*par.cp_w,  eps_small);
Cmin = min(Cair, Cw);
Cmax = max(Cair, Cw);
Cr   = Cmin / max(Cmax, eps_small);
NTU  = UA / max(Cmin, eps_small);

if abs(Cr-1) < 1e-8
    epsHX = NTU/(1+NTU);
else
    epsHX = (1 - exp(-NTU*(1-Cr))) / (1 - Cr*exp(-NTU*(1-Cr)));
end
epsHX = min(max(epsHX,0),1);

% 关键：热量差采用 (Tin - Ti)（与你源代码一致）
Qraw = epsHX*Cmin*(Tin - Ti);

% 供暖：不允许负值；容量上限
Qcoil = max(0, Qraw);
Qcoil = min(Qcoil, par.Qcon_max);

Tret  = Tin - Qcoil / max(Cw, eps_small);

% 4) 部分负荷效率 eta_PL
yPL = min(max(Qcoil / max(par.Qcon_nom, eps_small), 0), 1);
a1 = par.aPL(1); a2 = par.aPL(2); a3 = par.aPL(3);
etaPL = a1 + a2*yPL + a3*(yPL^2);
etaPL = max(etaPL, 1e-3);

% 5) 自洽迭代求 COP（用上一时刻 COP 作初值，保持"在线连续"）
COPk = max(hpState.COP_prev, 1.01);

for it = 1:20
    COPk = max(COPk, 1.01);

    Qsrc = Qcoil*(COPk-1)/COPk;
    Teva_out = Tout - Qsrc / max(par.mEva*par.cp_air, eps_small);

    den = Tin + par.TAppCon - (Teva_out - par.TAppEva);
    den = max(den, 0.5);
    COP_carnot = Tin / den;

    COPnew = etaCarnot0 * COP_carnot * etaPL;

    % 松弛
    COPk = 0.5*COPk + 0.5*COPnew;
end

COP = max(COPk, 1.01);
hpState.COP_prev = COP;

% 6) 电功率
Php = Qcoil / COP;
end
