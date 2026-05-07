function out = plot_regd_15min_historical_variance_v8(xlsxFile, sheetName, matOutFile, doPlot)
% =========================================================================
% 基于整月历史 RegD 数据，计算：
%   1) pooled 口径的 15min 原始均值/方差/标准差（主结果）
%   2) 每天 96 维 15min 均值序列（用于逐小时 4 子步协方差）
%   3) 每个小时 4 个 15min 子步的跨天均值向量/协方差矩阵
%
% 统计口径：
%   A) pooled 主结果（保留不变）
%      对同一个 15min 时段内、所有天、所有原始采样点，直接合并，
%      再求 mean / var / std.
%
%   B) hourly covariance 新增结果
%      先对每一天、每个 15min 时段求原始信号均值，得到每天 96 维序列；
%      再按每小时 4 个子步构造 4 维向量，跨天求均值与协方差。
%
% 注意：
%   1) hist_var15 仅用于与 pooled_raw_var15 对比画图，不作为主结果使用；
%   2) 不保存图片，不 writetable；
%   3) 分页绘图：每类统计量单独一个 figure()；
%   4) MAT 中保存 pooled 主结果 + hourly covariance 结果。
%
% 默认调用：
%   out = plot_regd_15min_historical_variance_v9;
%   out = plot_regd_15min_historical_variance_v9(project_data_file('raw', '07 2020.xlsx'));
%   out = plot_regd_15min_historical_variance_v9(project_data_file('raw', '07 2020.xlsx'),'Dynamic');
% =========================================================================

if nargin < 1 || isempty(xlsxFile)
    xlsxFile = project_data_file('raw', '07 2020.xlsx');
end
if nargin < 2 || isempty(sheetName)
    sheetName = 'Dynamic';
end
if nargin < 3 || isempty(matOutFile)
    matOutFile = project_data_file('regd', sprintf('regd_15min_moments_and_hourly_cov_%s.mat', lower(sheetName)));
end
if nargin < 4 || isempty(doPlot)
    doPlot = true;
end

assert(exist(xlsxFile,'file') == 2, '未找到文件：%s', xlsxFile);

%% 1) 读取单元格
raw = readcell(xlsxFile, 'Sheet', sheetName);
assert(size(raw,1) >= 10 && size(raw,2) >= 2, '表格尺寸异常，无法解析。');

header_dates = raw(1, 2:end);
valid_day_mask = ~cellfun(@(x) isempty(x) || (isnumeric(x) && isnan(x)), header_dates);
header_dates = header_dates(valid_day_mask);

raw_time = raw(2:end, 1);
raw_data = raw(2:end, 2:end);
raw_data = raw_data(:, valid_day_mask);

%% 2) 时间解析（鲁棒）
sec_of_day = nan(numel(raw_time),1);
for i = 1:numel(raw_time)
    sec_of_day(i) = local_time_to_seconds(raw_time{i});
end

valid_time_mask = isfinite(sec_of_day);
if nnz(valid_time_mask) < 0.8 * numel(sec_of_day)
    warning('时间列解析成功率较低，将按样本数自动重建等间隔时间轴。');
    nRows = size(raw_data,1);
    if nRows >= 2
        dt_guess = round(24*3600/(nRows-1));
    else
        dt_guess = 2;
    end
    sec_of_day = (0:nRows-1)' * dt_guess;
    valid_time_mask = true(size(sec_of_day));
end

sec_of_day = sec_of_day(valid_time_mask);
raw_data = raw_data(valid_time_mask, :);

% 去重并排序
[sec_of_day, ia] = unique(sec_of_day, 'stable');
raw_data = raw_data(ia, :);
[sec_of_day, order] = sort(sec_of_day);
raw_data = raw_data(order, :);

assert(numel(sec_of_day) >= 10, '有效时间样本过少。');

%% 3) 数据数值化
X = nan(size(raw_data));
for r = 1:size(raw_data,1)
    for c = 1:size(raw_data,2)
        v = raw_data{r,c};
        if isempty(v)
            X(r,c) = NaN;
        elseif isnumeric(v)
            X(r,c) = v;
        elseif ischar(v) || isstring(v)
            tmp = str2double(v);
            if ~isnan(tmp)
                X(r,c) = tmp;
            end
        end
    end
end

% 删除全空列
valid_col = any(isfinite(X), 1);
X = X(:, valid_col);
header_dates = header_dates(valid_col);

nDays = size(X,2);
assert(nDays >= 1, '没有有效日期列。');

%% 4) 自动识别采样间隔
finiteDiff = diff(sec_of_day);
finiteDiff = finiteDiff(isfinite(finiteDiff) & finiteDiff > 0);
assert(~isempty(finiteDiff), '无法识别采样间隔。');

dt_seconds = median(finiteDiff);
samples_per_15min = round(15*60 / dt_seconds);

nSlots = 96;
slot_start_sec = (0:nSlots-1)' * 15*60;
slot_index = (1:nSlots)';
slot_label = cell(nSlots,1);
for k = 1:nSlots
    slot_label{k} = local_sec_to_hhmm(slot_start_sec(k));
end

hour_index = repelem((1:24)', 4, 1);
substep_index = repmat((1:4)', 24, 1);
substep_label = cell(nSlots,1);
for k = 1:nSlots
    substep_label{k} = sprintf('h%02d-s%d', hour_index(k), substep_index(k));
end

%% 5) 计算 15min 统计量
slot_mean15_daily = nan(nSlots, nDays);   % 每天的96维15min均值序列
hist_var15 = nan(nSlots,1);               % 仅用于对比画图
pooled_raw_mean15 = nan(nSlots,1);        % 主结果：pooled均值
pooled_raw_var15  = nan(nSlots,1);        % 主结果：pooled方差
pooled_raw_std15  = nan(nSlots,1);        % 主结果：pooled标准差

for k = 1:nSlots
    t0 = (k-1) * 15 * 60;
    t1 = k * 15 * 60;

    if k < nSlots
        idx = (sec_of_day >= t0) & (sec_of_day < t1);
    else
        idx = (sec_of_day >= t0) & (sec_of_day <= t1);
    end

    Y = X(idx, :);
    if isempty(Y)
        continue;
    end

    % 每天该15min时段的均值（供后续hourly covariance使用）
    slot_mean15_daily(k,:) = mean(Y, 1, 'omitnan');

    % 仅用于对比的 hist 口径：先日内均值，再跨天方差
    valid_day_vals = slot_mean15_daily(k, isfinite(slot_mean15_daily(k,:)));
    if numel(valid_day_vals) >= 2
        hist_var15(k) = var(valid_day_vals, 0, 2, 'omitnan');
    end

    % 主结果：同一15min时段内、所有天、所有原始点直接合并
    vals = Y(:);
    vals = vals(isfinite(vals));
    if ~isempty(vals)
        pooled_raw_mean15(k) = mean(vals, 'omitnan');
    end
    if numel(vals) >= 2
        pooled_raw_var15(k) = var(vals, 0, 'omitnan');
        pooled_raw_std15(k) = std(vals, 0, 'omitnan');
    end
end

%% 6) 逐小时4子步均值向量/协方差矩阵
mu_s_hourly = nan(4,24);
Sigma_s_hourly = nan(4,4,24);
nValid_days_hourly = zeros(24,1);

for h = 1:24
    rows = (4*(h-1)+1):(4*h);      % 该小时内4个15min时段
    Shd = slot_mean15_daily(rows, :);  % 4 x nDays

    valid_day = all(isfinite(Shd), 1);
    Shd_valid = Shd(:, valid_day);     % 4 x nValid
    nValid_days_hourly(h) = size(Shd_valid, 2);

    if ~isempty(Shd_valid)
        mu_s_hourly(:,h) = mean(Shd_valid, 2, 'omitnan');
    end

    if size(Shd_valid, 2) >= 2
        Sigma_s_hourly(:,:,h) = cov(Shd_valid.');  % cov 输入: 样本在行, 变量在列 => nValid x 4
    elseif size(Shd_valid, 2) == 1
        Sigma_s_hourly(:,:,h) = zeros(4,4);
    end
end

%% 7) 保存 MAT（保留主结果 + 新增hourly covariance）
out = struct();
out.xlsxFile = xlsxFile;
out.sheetName = sheetName;
out.matOutFile = matOutFile;
out.dt_seconds = dt_seconds;
out.samples_per_15min = samples_per_15min;
out.nDays = nDays;
out.slot_index = slot_index;
out.slot_start_sec = slot_start_sec;
out.slot_label = slot_label;
out.hour_index = hour_index;
out.substep_index = substep_index;
out.substep_label = substep_label;

% 主结果：保持不变
out.pooled_raw_mean15 = pooled_raw_mean15;
out.pooled_raw_var15  = pooled_raw_var15;
out.pooled_raw_std15  = pooled_raw_std15;

% 仅返回，不作为主结果使用
out.hist_var15 = hist_var15;
out.slot_mean15_daily = slot_mean15_daily;

% 新增：每小时4子步统计量
out.mu_s_hourly = mu_s_hourly;
out.Sigma_s_hourly = Sigma_s_hourly;
out.nValid_days_hourly = nValid_days_hourly;

% MAT 中保存的变量
pooled_raw_mean15_save = pooled_raw_mean15;
pooled_raw_var15_save  = pooled_raw_var15;
pooled_raw_std15_save  = pooled_raw_std15;
mu_s_hourly_save       = mu_s_hourly;
Sigma_s_hourly_save    = Sigma_s_hourly;
slot_index_save        = slot_index;
slot_start_sec_save    = slot_start_sec;
slot_label_save        = slot_label;
hour_index_save        = hour_index;
substep_index_save     = substep_index;
substep_label_save     = substep_label;
dt_seconds_save        = dt_seconds;
samples_per_15min_save = samples_per_15min;
nDays_save             = nDays;
nValid_days_hourly_save = nValid_days_hourly;

save(matOutFile, ...
    'pooled_raw_mean15_save', 'pooled_raw_var15_save', 'pooled_raw_std15_save', ...
    'mu_s_hourly_save', 'Sigma_s_hourly_save', ...
    'slot_index_save', 'slot_start_sec_save', 'slot_label_save', ...
    'hour_index_save', 'substep_index_save', 'substep_label_save', ...
    'dt_seconds_save', 'samples_per_15min_save', 'nDays_save', 'nValid_days_hourly_save');

% 为方便 load 后直接使用，再追加一个更友好的结构体名
S_regd = struct();
S_regd.pooled_raw_mean15 = pooled_raw_mean15;
S_regd.pooled_raw_var15 = pooled_raw_var15;
S_regd.pooled_raw_std15 = pooled_raw_std15;
S_regd.mu_s_hourly = mu_s_hourly;
S_regd.Sigma_s_hourly = Sigma_s_hourly;
S_regd.slot_index = slot_index;
S_regd.slot_start_sec = slot_start_sec;
S_regd.slot_label = {slot_label{:}}.';
S_regd.hour_index = hour_index;
S_regd.substep_index = substep_index;
S_regd.substep_label = {substep_label{:}}.';
S_regd.dt_seconds = dt_seconds;
S_regd.samples_per_15min = samples_per_15min;
S_regd.nDays = nDays;
S_regd.nValid_days_hourly = nValid_days_hourly;
save(matOutFile, 'S_regd', '-append');

%% 8) 分页绘图（保留上一版统计量图）
if doPlot
    % Page 1: 逐日15min代表值热图
    figure('Color','w', 'Name', 'Page 1 - 逐日15min代表值热图');
    imagesc(slot_mean15_daily');
    set(gca, 'YDir', 'normal');
    colormap(parula);
    colorbar;
    grid on; box on;
    title('逐日15min代表值热图');
    xlabel('15 min 时段');
    ylabel('日期');
    xticks(1:8:nSlots);
    xticklabels(slot_label(1:8:nSlots));
    if nDays <= 31
        yticks(1:nDays);
        yticklabels(local_make_date_labels(header_dates));
    end

    % Page 2: 两种口径对比图
    figure('Color','w', 'Name', 'Page 2 - 两种口径对比');
    hold on; box on; grid on;
    plot(1:nSlots, hist_var15, '-o', 'LineWidth', 1.5, 'MarkerSize', 4, 'DisplayName', '历史方差 hist\_var15');
    plot(1:nSlots, pooled_raw_var15, '-s', 'LineWidth', 1.5, 'MarkerSize', 4, 'DisplayName', '参考 pooled\_raw\_var15');
    legend('Location','best');
    title('两种口径对比');
    xlabel('15 min 时段');
    ylabel('方差');
    xticks(1:8:nSlots);
    xticklabels(slot_label(1:8:nSlots));

    % Page 3: pooled_raw_var15
    figure('Color','w', 'Name', 'Page 3 - pooled\_raw\_var15');
    bar(1:nSlots, pooled_raw_var15);
    grid on; box on;
    title('你拟采用的 pooled\_raw\_var15');
    xlabel('15 min 时段');
    ylabel('方差');
    xticks(1:8:nSlots);
    xticklabels(slot_label(1:8:nSlots));

    % Page 4: pooled_raw_std15
    figure('Color','w', 'Name', 'Page 4 - pooled\_raw\_std15');
    plot(1:nSlots, pooled_raw_std15, '-o', 'LineWidth', 1.5, 'MarkerSize', 5);
    grid on; box on;
    title('你拟采用的 pooled\_raw\_std15');
    xlabel('15 min 时段');
    ylabel('标准差');
    xticks(1:8:nSlots);
    xticklabels(slot_label(1:8:nSlots));

    % Page 5: pooled_raw_mean15
    figure('Color','w', 'Name', 'Page 5 - pooled\_raw\_mean15');
    plot(1:nSlots, pooled_raw_mean15, '-o', 'LineWidth', 1.5, 'MarkerSize', 5);
    grid on; box on;
    title('你拟采用的 pooled\_raw\_mean15');
    xlabel('15 min 时段');
    ylabel('均值');
    xticks(1:8:nSlots);
    xticklabels(slot_label(1:8:nSlots));

    % Page 6: 仅补一张检查图——以小时内4子步协方差的 Frobenius 范数为例
    sigma_norm = nan(24,1);
    for h = 1:24
        S = Sigma_s_hourly(:,:,h);
        if all(isfinite(S(:)))
            sigma_norm(h) = norm(S, 'fro');
        end
    end
    figure('Color','w', 'Name', 'Page 6 - hourly covariance check');
    plot(1:24, sigma_norm, '-o', 'LineWidth', 1.5, 'MarkerSize', 5);
    grid on; box on;
    title('检查图：每小时 4 子步协方差矩阵的 Frobenius 范数');
    xlabel('小时 h');
    ylabel('||\Sigma_{s,h}||_F');
    xticks(1:24);
end

%% 9) 命令行摘要
fprintf('\n===== 完成：RegD 15min统计量 + 小时内4子步协方差 =====\n');
fprintf('文件                    : %s\n', xlsxFile);
fprintf('工作表                  : %s\n', sheetName);
fprintf('识别采样间隔            : %.6f s\n', dt_seconds);
fprintf('每15min采样点数         : %d\n', samples_per_15min);
fprintf('历史天数                : %d\n', nDays);
fprintf('主结果（保留）          : pooled_raw_mean15 / pooled_raw_var15 / pooled_raw_std15\n');
fprintf('新增结果                : mu_s_hourly(4,24) / Sigma_s_hourly(4,4,24)\n');
fprintf('MAT输出                 : %s\n', matOutFile);
fprintf('===============================================\n\n');

end

% =========================================================================
function sec = local_time_to_seconds(x)
if isa(x, 'duration')
    sec = seconds(x);
    return;
end
if isa(x, 'datetime')
    sec = hour(x)*3600 + minute(x)*60 + second(x);
    return;
end
if isnumeric(x)
    if isscalar(x) && isfinite(x)
        frac = x - floor(x);
        sec = frac * 24 * 3600;
        return;
    else
        sec = NaN;
        return;
    end
end
if ischar(x) || isstring(x)
    s = char(string(x));
    s = strtrim(s);
    if isempty(s)
        sec = NaN;
        return;
    end
    % 尝试 HH:mm:ss / HH:mm
    tok = regexp(s, '^(\d{1,2}):(\d{2})(?::(\d{2}))?$', 'tokens', 'once');
    if ~isempty(tok)
        hh = str2double(tok{1});
        mm = str2double(tok{2});
        if numel(tok) >= 3 && ~isempty(tok{3})
            ss = str2double(tok{3});
        else
            ss = 0;
        end
        if all(isfinite([hh,mm,ss]))
            sec = hh*3600 + mm*60 + ss;
            return;
        end
    end
    % 尝试 datetime / duration
    try
        tt = datetime(s, 'InputFormat','HH:mm:ss');
        sec = hour(tt)*3600 + minute(tt)*60 + second(tt);
        return;
    catch
    end
    try
        tt = datetime(s, 'InputFormat','HH:mm');
        sec = hour(tt)*3600 + minute(tt)*60 + second(tt);
        return;
    catch
    end
    try
        tt = duration(s, 'InputFormat','hh:mm:ss');
        sec = seconds(tt);
        return;
    catch
    end
    try
        tt = duration(s, 'InputFormat','hh:mm');
        sec = seconds(tt);
        return;
    catch
    end
end
sec = NaN;
end

% =========================================================================
function s = local_sec_to_hhmm(sec)
sec = round(sec);
h = floor(sec/3600);
m = floor(mod(sec,3600)/60);
s = sprintf('%02d:%02d', h, m);
end

% =========================================================================
function lbl = local_make_date_labels(header_dates)
n = numel(header_dates);
lbl = cell(n,1);
for i = 1:n
    x = header_dates{i};
    if isa(x, 'datetime')
        lbl{i} = datestr(x, 'yyyy-mm-dd');
    elseif isnumeric(x) && isfinite(x)
        try
            lbl{i} = datestr(x, 'yyyy-mm-dd');
        catch
            lbl{i} = sprintf('day%02d', i);
        end
    elseif ischar(x) || isstring(x)
        lbl{i} = char(string(x));
    else
        lbl{i} = sprintf('day%02d', i);
    end
end
end
