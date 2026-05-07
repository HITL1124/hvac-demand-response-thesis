function out = export_stage1_cqr_prediction_intervals_xlsx(cfg)
% =========================================================================
% 导出 Stage1-CQR 预测结果为 xlsx（预测值改为 N4SID 预测值）
% -------------------------------------------------------------------------
% 每一列依次为：
%   1) 时间步
%   2) 真实室温_K
%   3) N4SID预测室温_K
%   4) 0
%   5) 置信度1下界_K
%   6) 置信度1上界_K
%   7) 置信度2下界_K
%   8) 置信度2上界_K
%   ...
%
% 说明：
%   - CQR 区间仍读取 stage1_cqr_for_stage2.mat 中已保存的 T_low_15min / T_up_15min；
%   - 但"预测室温"不再使用树模型点预测 T_pred_15min；
%   - 而是改为基于 stage1_cqr_tree_data.mat 中保存的 N4SID 模型参数
%     A,B,C,D,u_mean,t_mean,useRemoveMean,T,U，按原 build_feature_row 中的
%     同一口径重建得到的 N4SID 名义预测值；
%   - 温度单位保持为 K，不做 273.15 转换。
%
% 默认调用：
%   out = export_stage1_cqr_prediction_intervals_xlsx();
% =========================================================================

%% 0) 默认参数
if nargin < 1
    cfg = struct();
end
cfg = local_fill_defaults(cfg);

outdir = fileparts(cfg.outfile);
if ~isempty(outdir) && ~exist(outdir, 'dir')
    mkdir(outdir);
end

%% 1) 读取 Stage2 导出结果（用于区间与选定起点）
assert(exist(cfg.infile, 'file') == 2, '未找到 CQR 结果文件：%s', cfg.infile);
S2 = load(cfg.infile);

coverage_vec = local_get_required_numeric(S2, 'coverage_vec');
T_true = local_get_required_numeric(S2, 'T_true_15min');
T_low  = local_get_required_numeric(S2, 'T_low_15min');
T_up   = local_get_required_numeric(S2, 'T_up_15min');

coverage_vec = coverage_vec(:).';
T_true = T_true(:);
H = numel(T_true);

T_low = local_orient_matrix(T_low, H, 'T_low_15min');
T_up  = local_orient_matrix(T_up,  H, 'T_up_15min');

nC = numel(coverage_vec);
assert(size(T_low,2) == nC, 'T_low_15min 列数与 coverage_vec 长度不一致。');
assert(size(T_up,2)  == nC, 'T_up_15min 列数与 coverage_vec 长度不一致。');

if isfield(S2, 'selected_origin_index') && ~isempty(S2.selected_origin_index)
    t0 = double(S2.selected_origin_index(1));
else
    error('stage1_cqr_for_stage2.mat 中缺少 selected_origin_index，无法与区间结果对齐。');
end

%% 2) 读取 tree_data，用于重建 N4SID 预测与识别数据集天数
assert(exist(cfg.tree_data_file, 'file') == 2, '未找到上游文件：%s', cfg.tree_data_file);
S1 = load(cfg.tree_data_file);

dataset_info = local_get_dataset_info(S1, cfg.tree_data_file);
T_n4sid = local_compute_n4sid_prediction_sequence(S1, t0, H);

%% 3) 表头
headers = cell(1, 4 + 2*nC);
headers{1} = '时间步';
headers{2} = '真实室温_K';
headers{3} = 'N4SID预测室温_K';
headers{4} = '0';
for ic = 1:nC
    beta_str = local_beta_to_str(coverage_vec(ic));
    headers{4 + 2*ic - 1} = sprintf('置信度%s下界_K', beta_str);
    headers{4 + 2*ic}     = sprintf('置信度%s上界_K', beta_str);
end

%% 4) 数值矩阵
M = nan(H, 4 + 2*nC);
M(:,1) = (1:H).';
M(:,2) = T_true;
M(:,3) = T_n4sid(:);
M(:,4) = 0;
for ic = 1:nC
    M(:, 4 + 2*ic - 1) = T_low(:, ic);
    M(:, 4 + 2*ic)     = T_up(:, ic);
end

%% 5) 写 xlsx
if exist(cfg.outfile, 'file') == 2
    delete(cfg.outfile);
end
C = cell(H+1, size(M,2));
C(1,:) = headers;
C(2:end,:) = num2cell(M);
writecell(C, cfg.outfile, 'Sheet', cfg.sheet_name);

%% 6) 输出
out = struct();
out.infile = cfg.infile;
out.tree_data_file = cfg.tree_data_file;
out.outfile = cfg.outfile;
out.sheet_name = cfg.sheet_name;
out.H = H;
out.selected_origin_index = t0;
out.coverage_vec = coverage_vec(:);
out.headers = headers;
out.dataset_info = dataset_info;

fprintf('\n============================================================\n');
fprintf('Stage1-CQR 预测区间结果已导出（预测值= N4SID）\n');
fprintf('区间来源文件      : %s\n', cfg.infile);
fprintf('N4SID来源文件     : %s\n', cfg.tree_data_file);
fprintf('输出文件          : %s\n', cfg.outfile);
fprintf('表单              : %s\n', cfg.sheet_name);
fprintf('selected_origin   : %d\n', t0);
fprintf('时间步数          : %d\n', H);
fprintf('置信度列表        : '); fprintf('%.2f ', coverage_vec); fprintf('\n');
fprintf('温度单位          : K\n');
fprintf('原始数据点数 N    : %d\n', dataset_info.N_total);
fprintf('采样步长          : %.0f s\n', dataset_info.Ts_stage1_sec);
fprintf('对应数据集时长    : %.4f 天\n', dataset_info.days_total);
fprintf('============================================================\n');

end

% =========================================================================
% 默认参数
% =========================================================================
function cfg = local_fill_defaults(cfg)
defaults.infile = project_data_file('stage1', 'stage1_cqr_for_stage2.mat');
defaults.tree_data_file = project_data_file('stage1', 'stage1_cqr_tree_data.mat');
defaults.outfile = project_data_file('exports', '01_Fig3_Fig4_stage1_inputs_cqr', 'export_stage1_cqr_prediction_intervals.xlsx');
defaults.sheet_name = 'CQR结果';

fns = fieldnames(defaults);
for i = 1:numel(fns)
    fn = fns{i};
    if ~isfield(cfg, fn) || isempty(cfg.(fn))
        cfg.(fn) = defaults.(fn);
    end
end
end

% =========================================================================
% 读取必需数值字段
% =========================================================================
function x = local_get_required_numeric(S, fieldName)
assert(isfield(S, fieldName), '缺少字段：%s', fieldName);
x = S.(fieldName);
assert(isnumeric(x) && ~isempty(x), '字段 %s 不是有效数值。', fieldName);
end

% =========================================================================
% 矩阵方向整理为 H x nC
% =========================================================================
function X = local_orient_matrix(X, H_expect, varName)
assert(isnumeric(X) && ~isempty(X), '%s 不是有效数值矩阵。', varName);
if isvector(X)
    X = X(:);
end
if size(X,1) == H_expect
    return;
elseif size(X,2) == H_expect
    X = X.';
else
    error('%s 的尺寸与目标步数 H=%d 不匹配。实际尺寸为 [%d, %d]。', ...
        varName, H_expect, size(X,1), size(X,2));
end
end

% =========================================================================
% 数据集信息
% =========================================================================
function info = local_get_dataset_info(S, source_file)
T = local_get_required_numeric(S, 'T');
Ts_stage1 = local_get_required_numeric(S, 'Ts_stage1');
info = struct();
info.source_file = source_file;
info.N_total = numel(T);
info.Ts_stage1_sec = double(Ts_stage1(1));
info.days_total = info.N_total * info.Ts_stage1_sec / 86400;
end

% =========================================================================
% 用 tree_data 中保存的 N4SID 参数，按 build_feature_row 同口径重建预测序列
% =========================================================================
function T_pred = local_compute_n4sid_prediction_sequence(S, t0, H)
A = double(local_get_required_numeric(S, 'A'));
B = double(local_get_required_numeric(S, 'B'));
C = double(local_get_required_numeric(S, 'C'));
D = double(local_get_required_numeric(S, 'D'));
T = double(local_get_required_numeric(S, 'T'));
U = double(local_get_required_numeric(S, 'U'));

if isfield(S, 'u_mean') && ~isempty(S.u_mean)
    u_mean = double(S.u_mean(:));
else
    u_mean = zeros(size(U,2),1);
end
if isfield(S, 't_mean') && ~isempty(S.t_mean)
    t_mean = double(S.t_mean(1));
else
    t_mean = 0;
end
if isfield(S, 'useRemoveMean') && ~isempty(S.useRemoveMean)
    useRemoveMean = logical(S.useRemoveMean(1));
else
    useRemoveMean = true;
end

N = size(U,1);
assert(t0 >= 1 && t0 <= N, 'selected_origin_index 越界：t0=%d, N=%d', t0, N);
assert(t0 + H <= N, 'selected_origin_index + H 越界：t0+H=%d, N=%d', t0 + H, N);

T_pred = nan(H,1);
for k = 1:H
    if useRemoveMean
        y0_z = T(t0) - t_mean;
        x = pinv(C) * y0_z;
    else
        x = pinv(C) * T(t0);
    end

    for j = 1:k
        u_j = U(t0 + j, :).';
        if useRemoveMean
            u_j = u_j - u_mean;
        end
        x = A * x + B * u_j;
    end

    u_k = U(t0 + k, :).';
    if useRemoveMean
        u_k_z = u_k - u_mean;
        yhat_k = C * x + D * u_k_z + t_mean;
    else
        yhat_k = C * x + D * u_k;
    end

    T_pred(k) = double(yhat_k(1));
end
end

% =========================================================================
% 置信度转字符串
% =========================================================================
function s = local_beta_to_str(beta)
s = sprintf('%.2f', beta);
end
