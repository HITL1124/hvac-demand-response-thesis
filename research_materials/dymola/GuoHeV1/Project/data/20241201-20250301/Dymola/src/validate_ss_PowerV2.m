%% validate_ss_PowerV2.m
% 目的：
% 查看COP各项
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

% 统一生成绘图时间轴 tt（避免 tt 未定义错误）
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
end

%% =========================
%  4. 初始化状态 x0（由 y0 反推）
%     y0 = C x0 + D u0
%     此处 D=0 -> x0 = C^{-1} y0（若 C 不可逆则用 pinv）
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
%  5. 验证：开环仿真（e=0，不使用 K）
% =========================
yhat_ol = zeros(N,2);
x_ol = x0;

for k = 1:N
    yhat_ol(k,:) = (C*x_ol + D*uZ(k,:)')';
    x_ol = A*x_ol + B*uZ(k,:)';
end

%% =========================
%  6. 验证：一步预测/跟踪（使用 K 与创新 e）
%     e(k) = y(k) - yhat(k)
%     x(k+1) = A x(k) + B u(k) + K e(k)
% =========================
yhat_1s = zeros(N,2);
x_1s = x0;

for k = 1:N
    ypred = C*x_1s + D*uZ(k,:)';
    yhat_1s(k,:) = ypred';
    e = yZ(k,:)' - ypred;
    x_1s = A*x_1s + B*uZ(k,:)' + K*e;
end

% 去均值后恢复原量纲
if useRemoveMean
    yhat_ol = yhat_ol + yMean;
    yhat_1s = yhat_1s + yMean;
end

%% =========================
%  7. 热泵功率计算（机理模型）
% =========================

% --- 热泵机理模型参数（与 Dymola 设定对应） ---
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

% 名义蒸发温度
hpPar.Teva_nom = 273.15 + 1.8;

% 部分负荷多项式 a={0.9,0.1,0}
hpPar.aPL = [0.9, 0.1, 0.0];

% --- 从输入/预测输出中提取需要的信号 ---
Tsup = u(:,1);   % K
mAir = u(:,2);   % kg/s
Tout = u(:,3);   % K

Ti_ol = yhat_ol(:,2);  % K
Ti_1s = yhat_1s(:,2);  % K

% --- 热泵机理功率 + Debug 中间量（直接来自函数内部） ---
[Php_ol, COP_ol, Qcoil_ol, ~, dbg_ol] = calcHpPowerCarnotEpsNTU(Tsup, mAir, Tout, Ti_ol, hpPar);
[Php_1s, COP_1s, Qcoil_1s, ~, dbg_1s] = calcHpPowerCarnotEpsNTU(Tsup, mAir, Tout, Ti_1s, hpPar);

%% ===== 画出 COP 分解各项（对应 COP=etaCarnot0*COP_Carnot*etaPL）=====
% --- 以 1-step 为例 ---
etaCarnot0_1s = dbg_1s.etaCarnot0;
COPc_1s       = dbg_1s.COP_Carnot;
etaPL_1s      = dbg_1s.etaPL;

% 乘积项
etaCOPc_1s = etaCarnot0_1s .* COPc_1s;
COP_recon_1s = etaCOPc_1s .* etaPL_1s;

fprintf("\n===== COP 分解项（1-step）=====\n");
fprintf("etaCarnot0 = %.6f (const)\n", etaCarnot0_1s);
fprintf("COP_Carnot: min=%.3f, mean=%.3f, max=%.3f\n", min(COPc_1s), mean(COPc_1s), max(COPc_1s));
fprintf("eta_PL    : min=%.3f, mean=%.3f, max=%.3f\n", min(etaPL_1s), mean(etaPL_1s), max(etaPL_1s));
fprintf("COP_recon : min=%.3f, mean=%.3f, max=%.3f\n", min(COP_recon_1s), mean(COP_recon_1s), max(COP_recon_1s));
fprintf("COP_1s    : min=%.3f, mean=%.3f, max=%.3f\n", min(COP_1s), mean(COP_1s), max(COP_1s));
fprintf("Recon-COP_1s: RMSE=%.6g, MAE=%.6g, MaxAbs=%.6g\n", ...
    sqrt(mean((COP_recon_1s-COP_1s).^2)), mean(abs(COP_recon_1s-COP_1s)), max(abs(COP_recon_1s-COP_1s)));

figure;
plot(tt, etaCarnot0_1s*ones(N,1), 'LineWidth', 1);
grid on; xlabel(xlab); ylabel('\eta_{Carnot,0}');
title('\eta_{Carnot,0}（常数）');

figure;
plot(tt, COPc_1s, 'LineWidth', 1);
grid on; xlabel(xlab); ylabel('COP_{Carnot}(k)');
title('COP_{Carnot}(k)（来自函数内部迭代末值）');

figure;
plot(tt, etaPL_1s, 'LineWidth', 1);
grid on; xlabel(xlab); ylabel('\eta_{PL}(k)');
title('\eta_{PL}(k)');

figure;
plot(tt, etaCOPc_1s, 'LineWidth', 1); hold on;
plot(tt, COP_1s, 'LineWidth', 1);
grid on; xlabel(xlab); ylabel('(-)');
legend('\eta_{Carnot,0}\cdot COP_{Carnot}', 'COP_{model}', 'Location','best');
title('Carnot项乘积 与 最终 COP');

figure;
plot(tt, COP_recon_1s, 'LineWidth', 1); hold on;
plot(tt, COP_1s, 'LineWidth', 1);
grid on; xlabel(xlab); ylabel('COP');
legend('Recon: \eta_{Carnot,0}COP_{Carnot}\eta_{PL}', 'COP_{model}', 'Location','best');
title('COP 重构校验');

% --- 如果你也要 OL 的分解图（同样画出来） ---
etaCarnot0_ol = dbg_ol.etaCarnot0;
COPc_ol       = dbg_ol.COP_Carnot;
etaPL_ol      = dbg_ol.etaPL;
etaCOPc_ol    = etaCarnot0_ol .* COPc_ol;
COP_recon_ol  = etaCOPc_ol .* etaPL_ol;

figure;
plot(tt, etaCarnot0_ol*ones(N,1), 'LineWidth', 1);
grid on; xlabel(xlab); ylabel('\eta_{Carnot,0}');
title('\eta_{Carnot,0}（OL，常数）');

figure;
plot(tt, COPc_ol, 'LineWidth', 1);
grid on; xlabel(xlab); ylabel('COP_{Carnot}(k)');
title('COP_{Carnot}(k)（OL）');

figure;
plot(tt, etaPL_ol, 'LineWidth', 1);
grid on; xlabel(xlab); ylabel('\eta_{PL}(k)');
title('\eta_{PL}(k)（OL）');

figure;
plot(tt, etaCOPc_ol, 'LineWidth', 1); hold on;
plot(tt, COP_ol, 'LineWidth', 1);
grid on; xlabel(xlab); ylabel('(-)');
legend('\eta_{Carnot,0}\cdot COP_{Carnot}', 'COP_{model}', 'Location','best');
title('Carnot项乘积 与 最终 COP（OL）');

figure;
plot(tt, COP_recon_ol, 'LineWidth', 1); hold on;
plot(tt, COP_ol, 'LineWidth', 1);
grid on; xlabel(xlab); ylabel('COP');
legend('Recon: \eta_{Carnot,0}COP_{Carnot}\eta_{PL}', 'COP_{model}', 'Location','best');
title('COP 重构校验（OL）');

%% --- 读取 Dymola 热泵真值：processed_HPdata.mat（N×3） ---
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
%  8. 风机功率计算（基于质量流量的三次多项式拟合：总功率）
% =========================
fanPar = struct();
fanPar.p1 = 3.133064171;
fanPar.p2 = 6.087791979;
fanPar.p3 = -59.56637575;
fanPar.p4 = 208.2979381;

Pfan_tot_fit = calcFanPowerPoly3(mAir, fanPar);

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
%  9. 绘图：热泵对比
% =========================

% 电功率
figure;
plot(tt, Php_ol/1e3, 'LineWidth', 1); hold on;
plot(tt, Php_1s/1e3, 'LineWidth', 1);
ylim([0, inf]);
if ~isempty(Pele_sim)
    plot(tt, Pele_sim/1e3, 'LineWidth', 1);
    legend("热泵机理(OL室温)", "热泵机理(1-step室温)", "Dymola 热泵Pele", "Location","best");
else
    legend("热泵机理(OL室温)", "热泵机理(1-step室温)", "Location","best");
end
grid on; xlabel(xlab); ylabel("P_{hp} (kW)");
title("热泵电功率：机理预测 vs Dymola");

% 热功率
figure;
plot(tt, Qcoil_ol/1e3, 'LineWidth', 1); hold on;
plot(tt, Qcoil_1s/1e3, 'LineWidth', 1);
ylim([0, inf]);
if ~isempty(Qcon_sim)
    plot(tt, Qcon_sim/1e3, 'LineWidth', 1);
    legend("盘管机理Qcoil(OL室温)", "盘管机理Qcoil(1-step室温)", "Dymola QCon\_flow", "Location","best");
else
    legend("盘管机理Qcoil(OL室温)", "盘管机理Qcoil(1-step室温)", "Location","best");
end
grid on; xlabel(xlab); ylabel("Q (kW)");
title("热功率：盘管机理Qcoil vs Dymola QCon\_flow");

% COP
figure;
plot(tt, COP_ol, 'LineWidth', 1); hold on;
plot(tt, COP_1s, 'LineWidth', 1);
ylim([0, inf]);
if ~isempty(COP_sim)
    plot(tt, COP_sim, 'LineWidth', 1);
    legend("机理COP(OL室温)", "机理COP(1-step室温)", "Dymola COP", "Location","best");
else
    legend("机理COP(OL室温)", "机理COP(1-step室温)", "Location","best");
end
grid on; xlabel(xlab); ylabel("COP");
title("COP：机理预测 vs Dymola");

%% =========================
%  10. 绘图：风机总功率对比
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
%  11. 误差指标：热泵（机理 vs Dymola）
% =========================
if ~isempty(Pele_sim)
    eP_ol = Php_ol - Pele_sim;
    eP_1s = Php_1s - Pele_sim;

    eQ_ol = Qcoil_ol - Qcon_sim;
    eQ_1s = Qcoil_1s - Qcon_sim;

    eCOP_ol = COP_ol - COP_sim;
    eCOP_1s = COP_1s - COP_sim;

    fprintf("\n===== 热泵对比误差（机理 vs Dymola）=====\n");
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
%  12. 误差指标：风机总功率（拟合 vs Dymola）
% =========================
if ~isempty(Pfan_tot_sim)
    eFanTot = Pfan_tot_fit - Pfan_tot_sim;

    fprintf("\n===== 风机总功率对比误差（拟合 vs Dymola）=====\n");
    fprintf("RMSE=%.4g W, MAE=%.4g W, MaxAbs=%.4g W\n", ...
        sqrt(mean(eFanTot.^2)), mean(abs(eFanTot)), max(abs(eFanTot)));
end

%% =========================
%  13. 温度状态验证误差（yhat vs y）
% =========================
err_ol = yhat_ol - y;
err_1s = yhat_1s - y;

metrics = @(e) struct( ...
    "RMSE",   sqrt(mean(e.^2,1)), ...
    "MAE",    mean(abs(e),1), ...
    "MaxAbs", max(abs(e),[],1) );

m_ol = metrics(err_ol);
m_1s = metrics(err_1s);

fprintf("\n===== 温度状态验证：开环仿真（e=0）=====\n");
fprintf("Tw: RMSE=%.4g, MAE=%.4g, MaxAbs=%.4g\n", m_ol.RMSE(1), m_ol.MAE(1), m_ol.MaxAbs(1));
fprintf("Ti: RMSE=%.4g, MAE=%.4g, MaxAbs=%.4g\n", m_ol.RMSE(2), m_ol.MAE(2), m_ol.MaxAbs(2));

fprintf("\n===== 温度状态验证：一步预测/跟踪（用 K）=====\n");
fprintf("Tw: RMSE=%.4g, MAE=%.4g, MaxAbs=%.4g\n", m_1s.RMSE(1), m_1s.MAE(1), m_1s.MaxAbs(1));
fprintf("Ti: RMSE=%.4g, MAE=%.4g, MaxAbs=%.4g\n", m_1s.RMSE(2), m_1s.MAE(2), m_1s.MaxAbs(2));

%% =========================
%  14. 绘图：温度状态对比
% =========================
figure;
plot(tt, y(:,1)-273.15, 'LineWidth', 1); hold on;
plot(tt, yhat_ol(:,1)-273.15, 'LineWidth', 1);
plot(tt, yhat_1s(:,1)-273.15, 'LineWidth', 1);
grid on; xlabel(xlab); ylabel("Tw (°C)");
legend("Dymola", "开环", "一步预测", "Location","best");
title("墙体节点温度 Tw");

figure;
plot(tt, y(:,2)-273.15, 'LineWidth', 1); hold on;
plot(tt, yhat_ol(:,2)-273.15, 'LineWidth', 1);
plot(tt, yhat_1s(:,2)-273.15, 'LineWidth', 1);
grid on; xlabel(xlab); ylabel("Ti (°C)");
legend("Dymola", "开环", "一步预测", "Location","best");
title("室内温度 Ti");

%% =========================
%  15. 稳定性检查（A 矩阵极点）
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

function [Php, COP, Qcoil, Tret, dbg] = calcHpPowerCarnotEpsNTU(Tsup, mAir, Tout, Ti, par)
% calcHpPowerCarnotEpsNTU
% 用「盘管 UA(t) + ε-NTU」+「Carnot_TCon 结构 COP」预测热泵电功率
% 并输出 dbg 结构体，包含 COP 分解各项：etaCarnot0、COP_Carnot(k)、etaPL(k)

N = numel(Tsup);
Php   = zeros(N,1);
COP   = zeros(N,1);
Qcoil = zeros(N,1);
Tret  = zeros(N,1);

dbg = struct();
dbg.etaCarnot0 = NaN;
dbg.COP_Carnot = zeros(N,1);
dbg.etaPL      = zeros(N,1);
dbg.Teva_out   = zeros(N,1);   % 可用于论文/调试
dbg.Tin        = zeros(N,1);   % 可用于论文/调试
dbg.UA         = zeros(N,1);   % 可用于论文/调试
dbg.NTU        = zeros(N,1);   % 可用于论文/调试
dbg.epsHX      = zeros(N,1);   % 可用于论文/调试

eps_small = 1e-9;

% -------- 默认/保护 --------
if ~isfield(par,'r_nominal') || isempty(par.r_nominal), par.r_nominal = 2/3; end
if ~isfield(par,'mAir_nominal') || isempty(par.mAir_nominal)
    v = mAir(mAir > 0);
    par.mAir_nominal = max(median(v), 1);
end
if ~isfield(par,'TairIn_nominal') || isempty(par.TairIn_nominal)
    Tmix_tmp = par.beta*Tout + (1-par.beta)*Ti;
    par.TairIn_nominal = median(Tmix_tmp);
end
if ~isfield(par,'TwIn_nominal') || isempty(par.TwIn_nominal), par.TwIn_nominal = median(Tsup); end
if ~isfield(par,'nAir') || isempty(par.nAir), par.nAir = 0.80; end
if ~isfield(par,'tauCon') || isempty(par.tauCon), par.tauCon = 0; end
if ~isfield(par,'Ts') || isempty(par.Ts), par.Ts = 60; end

% -------- Carnot_TCon：名义 Carnot 有效度 etaCarnot0 --------
den0 = par.Tcon_nom + par.TAppCon - (par.Teva_nom - par.TAppEva);
den0 = max(den0, 0.5);
etaCarnot0 = par.COP_nom / ( par.Tcon_nom / den0 );
dbg.etaCarnot0 = etaCarnot0;

% -------- HADryCoil 思路：UA_nominal 分解并随工况变化合成 UA(t) --------
r = max(par.r_nominal, 1e-6);
UA0 = max(par.UA, eps_small);

hAw0 = UA0*(r+1)/r;
hAa0 = UA0*(r+1);

% -------- 供水温度(盘管入口)可选一阶滞后 --------
Tin_prev = Tsup(1);
if par.tauCon > 0
    alpha = par.Ts / max(par.tauCon + par.Ts, eps_small);
else
    alpha = 1;
end

for k = 1:N
    % 0) 回风/新风混合
    Tmix = par.beta*Tout(k) + (1-par.beta)*Ti(k);

    % 1) 盘管水侧入口温度（可选滞后）
    Tin_sp = Tsup(k);
    Tin = Tin_prev + alpha*(Tin_sp - Tin_prev);
    Tin_prev = Tin;
    dbg.Tin(k) = Tin;

    % 2) 温度修正因子
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

    % 3) 对流换热能力随流量变化
    ma = max(mAir(k), 0);
    ma0 = max(par.mAir_nominal, eps_small);
    hAa = hAa0 * (ma/ma0)^par.nAir * x_a;

    mw  = max(par.mw, eps_small);
    mw0 = max(par.mw, eps_small);
    hAw = hAw0 * (mw/mw0)^0.85 * x_w;

    % 串联热阻合成 UA(t)
    UA = (hAa*hAw) / max(hAa + hAw, eps_small);
    UA = max(UA, eps_small);
    dbg.UA(k) = UA;

    % 4) ε-NTU 计算盘管显热
    Cair = max(ma*par.cp_air, eps_small);
    Cw   = max(mw*par.cp_w,  eps_small);
    Cmin = min(Cair, Cw);
    Cmax = max(Cair, Cw);
    Cr   = Cmin / max(Cmax, eps_small);
    NTU  = UA / max(Cmin, eps_small);
    dbg.NTU(k) = NTU;

    if abs(Cr-1) < 1e-8
        epsHX = NTU/(1+NTU);
    else
        epsHX = (1 - exp(-NTU*(1-Cr))) / (1 - Cr*exp(-NTU*(1-Cr)));
    end
    epsHX = min(max(epsHX,0),1);
    dbg.epsHX(k) = epsHX;

    % 关键：热量差采用 (Tin - Ti)，与你现有对齐逻辑一致
    Qraw = epsHX*Cmin*(Tin - Ti(k));

    Qk = max(0, Qraw);
    Qk = min(Qk, par.Qcon_max);

    Qcoil(k) = Qk;
    Tret(k)  = Tin - Qk / Cw;

    % 5) 部分负荷效率 eta_PL
    yPL = min(max(Qk / max(par.Qcon_nom, eps_small), 0), 1);
    a1 = par.aPL(1); a2 = par.aPL(2); a3 = par.aPL(3);
    etaPL = a1 + a2*yPL + a3*(yPL^2);
    etaPL = max(etaPL, 1e-3);
    dbg.etaPL(k) = etaPL;

    % 6) 自洽迭代求 COP，并把迭代末的 COP_Carnot、Teva_out 存入 dbg
    COPk = max(par.COP_nom, 1.01);
    Teva_out_last = Tout(k);
    COP_carnot_last = par.COP_nom;

    for it = 1:20
        COPk = max(COPk, 1.01);

        Qsrc = Qk*(COPk-1)/COPk;

        Teva_out = Tout(k) - Qsrc / max(par.mEva*par.cp_air, eps_small);

        den = Tin + par.TAppCon - (Teva_out - par.TAppEva);
        den = max(den, 0.5);
        COP_carnot = Tin / den;

        COPnew = etaCarnot0 * COP_carnot * etaPL;

        % 松弛
        COPk = 0.5*COPk + 0.5*COPnew;

        % 记录迭代末值
        Teva_out_last = Teva_out;
        COP_carnot_last = COP_carnot;
    end

    dbg.Teva_out(k)   = Teva_out_last;
    dbg.COP_Carnot(k) = COP_carnot_last;

    COP(k) = max(COPk, 1.01);

    % 7) 电功率
    Php(k) = Qk / COP(k);
end
end
