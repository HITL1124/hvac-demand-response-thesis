function out = export_cqr_gaussian_risk_bounds_and_margins_xlsx(cfg)
% =========================================================================
% 导出 CQR 与 Gaussian 风险边界 + 收缩裕量对照表（xlsx）
% -------------------------------------------------------------------------
% 每个置信度一个表单，列结构固定为：
%   1) 原始舒适上边界_℃
%   2) CQR风险上边界_℃
%   3) 高斯风险上边界_℃
%   4) CQR上收缩裕量_℃
%   5) 高斯上收缩裕量_℃
%   6) 原始舒适下边界_℃
%   7) CQR风险下边界_℃
%   8) 高斯风险下边界_℃
%   9) CQR下收缩裕量_℃
%  10) 高斯下收缩裕量_℃
%
% 附加功能：
%   - 读取上游 stage1_cqr_tree_data.mat，自动识别当前 CQR 训练/构造数据集共多少天；
%   - 在命令行日志中输出：数据点数、采样步长、总天数。
%
% 默认调用：
%   out = export_cqr_gaussian_risk_bounds_and_margins_xlsx();
% =========================================================================

if nargin < 1
    cfg = struct();
end
cfg = local_fill_defaults(cfg);

outdir = fileparts(cfg.outfile);
if ~isempty(outdir) && ~exist(outdir, 'dir')
    mkdir(outdir);
end

assert(exist(cfg.cqrFile, 'file') == 2, '未找到 CQR 文件：%s', cfg.cqrFile);
assert(exist(cfg.gaussianFile, 'file') == 2, '未找到 Gaussian 文件：%s', cfg.gaussianFile);

Scqr = load(cfg.cqrFile);
Sgau = load(cfg.gaussianFile);
Smdl = struct();
if exist(cfg.stage2ModelFile, 'file') == 2
    Smdl = load(cfg.stage2ModelFile);
end

dataset_info = local_try_get_dataset_info(cfg.treeDataFile, cfg.cqrFile);

coverage_vec = local_get_required_numeric(Scqr, 'coverage_vec');
coverage_vec = double(coverage_vec(:).');

T_pred = local_get_required_numeric(Scqr, 'T_pred_15min');
T_low  = local_get_required_numeric(Scqr, 'T_low_15min');
T_up   = local_get_required_numeric(Scqr, 'T_up_15min');

T_pred = T_pred(:);
H = numel(T_pred);
T_low = local_orient_matrix(T_low, H, 'T_low_15min');
T_up  = local_orient_matrix(T_up,  H, 'T_up_15min');
assert(size(T_low,2) == numel(coverage_vec), 'T_low_15min 列数与 coverage_vec 不一致。');
assert(size(T_up,2)  == numel(coverage_vec), 'T_up_15min 列数与 coverage_vec 不一致。');

beta_vec_gauss = local_get_required_numeric(Sgau, 'beta_vec');
beta_vec_gauss = double(beta_vec_gauss(:).');

has_sua  = isfield(Sgau, 's_ua')  && isnumeric(Sgau.s_ua)  && ~isempty(Sgau.s_ua);
has_Tlow = isfield(Sgau, 'Tlow')  && isnumeric(Sgau.Tlow)  && ~isempty(Sgau.Tlow);
has_Tup  = isfield(Sgau, 'Tup')   && isnumeric(Sgau.Tup)   && ~isempty(Sgau.Tup);
assert(has_sua || (has_Tlow && has_Tup), ...
    'Gaussian 文件中既没有 s_ua，也没有 Tlow/Tup，无法构造风险边界与裕量。');

if has_sua
    s_ua = local_orient_unknown_h(Sgau.s_ua, 's_ua');
else
    s_ua = [];
end
if has_Tlow
    Tlow_g = local_orient_unknown_h(Sgau.Tlow, 'Tlow');
else
    Tlow_g = [];
end
if has_Tup
    Tup_g = local_orient_unknown_h(Sgau.Tup, 'Tup');
else
    Tup_g = [];
end

if has_sua
    H_g = size(s_ua,1);
elseif has_Tlow
    H_g = size(Tlow_g,1);
else
    H_g = size(Tup_g,1);
end

if has_sua
    s_ua = local_orient_matrix(s_ua, H_g, 's_ua');
    assert(size(s_ua,2) == numel(beta_vec_gauss), 's_ua 列数与 beta_vec 不一致。');
end
if has_Tlow
    Tlow_g = local_orient_matrix(Tlow_g, H_g, 'Tlow');
    assert(size(Tlow_g,2) == numel(beta_vec_gauss), 'Tlow 列数与 beta_vec 不一致。');
end
if has_Tup
    Tup_g = local_orient_matrix(Tup_g, H_g, 'Tup');
    assert(size(Tup_g,2) == numel(beta_vec_gauss), 'Tup 列数与 beta_vec 不一致。');
end

H_use = min(H, H_g);
if H ~= H_g
    warning('CQR 与 Gaussian 时段长度不一致：CQR=%d, Gaussian=%d。将按前 %d 个时段导出。', H, H_g, H_use);
end
T_pred = T_pred(1:H_use);
T_low  = T_low(1:H_use,:);
T_up   = T_up(1:H_use,:);
if has_sua,  s_ua   = s_ua(1:H_use,:);   end
if has_Tlow, Tlow_g = Tlow_g(1:H_use,:); end
if has_Tup,  Tup_g  = Tup_g(1:H_use,:);  end

[Tmin_raw, Tmax_raw] = local_get_original_comfort_bounds(Sgau, Smdl, cfg, H_use);
Tmin_C = local_abs_temp_to_celsius(Tmin_raw, cfg.absTempThresholdK);
Tmax_C = local_abs_temp_to_celsius(Tmax_raw, cfg.absTempThresholdK);

if exist(cfg.outfile, 'file') == 2
    delete(cfg.outfile);
end

sheet_names = cell(numel(cfg.beta_list),1);
for i = 1:numel(cfg.beta_list)
    beta_tar = cfg.beta_list(i);
    [~, ic] = min(abs(coverage_vec - beta_tar));
    [~, ig] = min(abs(beta_vec_gauss - beta_tar));

    % CQR margins and risk bounds
    cqr_up_margin = T_up(:,ic) - T_pred;
    cqr_lo_margin = T_pred - T_low(:,ic);
    cqr_up_margin = max(cqr_up_margin, 0);
    cqr_lo_margin = max(cqr_lo_margin, 0);

    cqr_upper_risk = Tmax_raw - cqr_up_margin;
    cqr_lower_risk = Tmin_raw + cqr_lo_margin;

    % Gaussian margins and risk bounds
    if has_Tlow && has_Tup
        gauss_upper_risk = Tup_g(:,ig);
        gauss_lower_risk = Tlow_g(:,ig);
        gauss_up_margin = Tmax_raw - gauss_upper_risk;
        gauss_lo_margin = gauss_lower_risk - Tmin_raw;
    else
        gauss_up_margin = s_ua(:,ig);
        gauss_lo_margin = s_ua(:,ig);
        gauss_upper_risk = Tmax_raw - gauss_up_margin;
        gauss_lower_risk = Tmin_raw + gauss_lo_margin;
    end
    gauss_up_margin = max(gauss_up_margin, 0);
    gauss_lo_margin = max(gauss_lo_margin, 0);

    T = table( ...
        Tmax_C(:), ...
        local_abs_temp_to_celsius(cqr_upper_risk, cfg.absTempThresholdK), ...
        local_abs_temp_to_celsius(gauss_upper_risk, cfg.absTempThresholdK), ...
        cqr_up_margin(:), ...
        gauss_up_margin(:), ...
        Tmin_C(:), ...
        local_abs_temp_to_celsius(cqr_lower_risk, cfg.absTempThresholdK), ...
        local_abs_temp_to_celsius(gauss_lower_risk, cfg.absTempThresholdK), ...
        cqr_lo_margin(:), ...
        gauss_lo_margin(:), ...
        'VariableNames', { ...
            '原始舒适上边界_℃', ...
            'CQR风险上边界_℃', ...
            '高斯风险上边界_℃', ...
            'CQR上收缩裕量_℃', ...
            '高斯上收缩裕量_℃', ...
            '原始舒适下边界_℃', ...
            'CQR风险下边界_℃', ...
            '高斯风险下边界_℃', ...
            'CQR下收缩裕量_℃', ...
            '高斯下收缩裕量_℃'});

    sheet = local_make_sheet_name(beta_tar, i);
    sheet_names{i} = sheet;
    writetable(T, cfg.outfile, 'Sheet', sheet);

    if cfg.write_summary_row
        Tsum = table(coverage_vec(ic), beta_vec_gauss(ig), ...
            'VariableNames', {'CQR实际使用置信度','高斯实际使用置信度'});
        writetable(Tsum, cfg.outfile, 'Sheet', sheet, 'Range', 'L1');
    end
end

out = struct();
out.outfile = cfg.outfile;
out.cqrFile = cfg.cqrFile;
out.gaussianFile = cfg.gaussianFile;
out.stage2ModelFile = cfg.stage2ModelFile;
out.treeDataFile = cfg.treeDataFile;
out.beta_list = cfg.beta_list(:);
out.sheet_names = sheet_names;
out.n_rows_each_sheet = H_use;
out.dataset_info = dataset_info;

fprintf('\n============================================================\n');
fprintf('CQR / Gaussian 风险边界 + 裕量导出完成\n');
fprintf('CQR 文件          : %s\n', cfg.cqrFile);
fprintf('Gaussian 文件     : %s\n', cfg.gaussianFile);
fprintf('输出文件          : %s\n', out.outfile);
if dataset_info.available
    fprintf('训练数据源        : %s\n', dataset_info.source_file);
    fprintf('原始数据点数 N    : %d\n', dataset_info.N_total);
    fprintf('采样步长          : %.0f s\n', dataset_info.Ts_stage1_sec);
    fprintf('当前数据集时长    : %.4f 天\n', dataset_info.days_total);
else
    fprintf('当前数据集时长    : 无法自动识别\n');
    if ~isempty(dataset_info.message)
        fprintf('原因              : %s\n', dataset_info.message);
    end
end
fprintf('============================================================\n');

end

function cfg = local_fill_defaults(cfg)
if ~isfield(cfg, 'cqrFile') || isempty(cfg.cqrFile)
    cfg.cqrFile = project_data_file('stage1', 'stage1_cqr_for_stage2.mat');
end
if ~isfield(cfg, 'gaussianFile') || isempty(cfg.gaussianFile)
    cfg.gaussianFile = project_data_file('gaussian', 'rousseau_gaussian_shrinkage_15min_results.mat');
end
if ~isfield(cfg, 'stage2ModelFile') || isempty(cfg.stage2ModelFile)
    cfg.stage2ModelFile = project_data_file('stage1', 'stage1_hour_model_for_stage2.mat');
end
if ~isfield(cfg, 'treeDataFile') || isempty(cfg.treeDataFile)
    cfg.treeDataFile = project_data_file('stage1', 'stage1_cqr_tree_data.mat');
end
if ~isfield(cfg, 'outfile') || isempty(cfg.outfile)
    cfg.outfile = project_data_file('exports', '02_Fig5_cqr_gaussian', 'export_cqr_gaussian_risk_bounds_and_margins.xlsx');
end
if ~isfield(cfg, 'beta_list') || isempty(cfg.beta_list)
    cfg.beta_list = [0.80 0.85 0.90 0.95];
end
if ~isfield(cfg, 'default_Tmin') || isempty(cfg.default_Tmin)
    cfg.default_Tmin = 293.15;
end
if ~isfield(cfg, 'default_Tmax') || isempty(cfg.default_Tmax)
    cfg.default_Tmax = 297.15;
end
if ~isfield(cfg, 'write_summary_row') || isempty(cfg.write_summary_row)
    cfg.write_summary_row = true;
end
if ~isfield(cfg, 'absTempThresholdK') || isempty(cfg.absTempThresholdK)
    cfg.absTempThresholdK = 100;
end
end

function x = local_get_required_numeric(S, fieldName)
assert(isfield(S, fieldName), '缺少字段：%s', fieldName);
x = S.(fieldName);
assert(isnumeric(x) && ~isempty(x), '字段 %s 不是有效数值。', fieldName);
end

function X = local_orient_unknown_h(X, varName)
assert(isnumeric(X) && ~isempty(X), '%s 不是有效数值矩阵。', varName);
if isvector(X)
    X = X(:);
elseif size(X,1) < size(X,2)
    X = X.';
end
end

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

function [Tmin_raw, Tmax_raw] = local_get_original_comfort_bounds(Sgau, Smdl, cfg, H)
Tmin_raw = [];
Tmax_raw = [];

if isfield(Sgau, 'Tmin') && isnumeric(Sgau.Tmin) && ~isempty(Sgau.Tmin)
    Tmin_raw = double(Sgau.Tmin(:));
end
if isfield(Sgau, 'Tmax') && isnumeric(Sgau.Tmax) && ~isempty(Sgau.Tmax)
    Tmax_raw = double(Sgau.Tmax(:));
end

if isempty(Tmin_raw) || isempty(Tmax_raw)
    if isfield(Smdl, 'Tmin') && isnumeric(Smdl.Tmin) && ~isempty(Smdl.Tmin)
        Tmin_raw = double(Smdl.Tmin(:));
    end
    if isfield(Smdl, 'Tmax') && isnumeric(Smdl.Tmax) && ~isempty(Smdl.Tmax)
        Tmax_raw = double(Smdl.Tmax(:));
    end
end

if isempty(Tmin_raw)
    Tmin_raw = cfg.default_Tmin * ones(H,1);
end
if isempty(Tmax_raw)
    Tmax_raw = cfg.default_Tmax * ones(H,1);
end

if isscalar(Tmin_raw), Tmin_raw = repmat(Tmin_raw, H, 1); end
if isscalar(Tmax_raw), Tmax_raw = repmat(Tmax_raw, H, 1); end

if numel(Tmin_raw) ~= H
    if numel(Tmin_raw) > H
        Tmin_raw = Tmin_raw(1:H);
    else
        Tmin_raw = repmat(Tmin_raw(1), H, 1);
    end
end
if numel(Tmax_raw) ~= H
    if numel(Tmax_raw) > H
        Tmax_raw = Tmax_raw(1:H);
    else
        Tmax_raw = repmat(Tmax_raw(1), H, 1);
    end
end
end

function xC = local_abs_temp_to_celsius(x, thresholdK)
x = double(x);
if mean(x(:), 'omitnan') > thresholdK
    xC = x - 273.15;
else
    xC = x;
end
end

function sheet = local_make_sheet_name(beta, idx)
sheet = sprintf('置信度%.2f', beta);
if strlength(sheet) > 31
    sheet = sprintf('beta_%02d_%d', round(100*beta), idx);
end
end

function info = local_try_get_dataset_info(treeDataFile, cqrFile)
info = struct('available', false, ...
              'source_file', '', ...
              'N_total', NaN, ...
              'Ts_stage1_sec', NaN, ...
              'days_total', NaN, ...
              'message', '');

% 优先读取完整 tree_data
if exist(treeDataFile, 'file') == 2
    try
        S = load(treeDataFile);
        if isfield(S, 'T') && isnumeric(S.T) && ~isempty(S.T) && ...
           isfield(S, 'Ts_stage1') && isnumeric(S.Ts_stage1) && ~isempty(S.Ts_stage1)
            info.available = true;
            info.source_file = treeDataFile;
            info.N_total = numel(S.T(:));
            info.Ts_stage1_sec = double(S.Ts_stage1(1));
            info.days_total = info.N_total * info.Ts_stage1_sec / 86400;
            return;
        else
            info.message = 'tree_data 文件缺少 T 或 Ts_stage1。';
        end
    catch ME
        info.message = ME.message;
    end
end

% 退回：若 cqrFile 本身保存了 Ts_stage1 和某些完整长度字段，则尝试提示
if exist(cqrFile, 'file') == 2
    try
        S = load(cqrFile);
        if isfield(S, 'Ts_stage1') && isnumeric(S.Ts_stage1) && ~isempty(S.Ts_stage1)
            if isfield(S, 'T_true_15min') && isnumeric(S.T_true_15min) && ~isempty(S.T_true_15min)
                info.source_file = cqrFile;
                info.Ts_stage1_sec = double(S.Ts_stage1(1));
                info.message = sprintf(['当前仅能从 %s 读到 24h 导出序列长度=%d；', ...
                    '这不足以反推完整训练数据总天数，请提供/保留 stage1_cqr_tree_data.mat。'], ...
                    cqrFile, numel(S.T_true_15min(:)));
            else
                info.message = sprintf('%s 中也无法识别完整数据长度。', cqrFile);
            end
        end
    catch
    end
end
end
