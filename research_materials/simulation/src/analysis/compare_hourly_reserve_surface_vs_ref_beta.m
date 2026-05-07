function S = compare_hourly_reserve_surface_vs_ref_beta(in, cfg)
% =========================================================================
% 基于"基准置信度"的空间曲面增量成本比较（保存为 xlsx）
% -------------------------------------------------------------------------
% 功能：
%   1) 从多置信度结果 results_all 中读取各 beta 的逐小时备用成本结果；
%   2) 用户指定/输入一个基准置信度 beta_ref；
%   3) 严格按当前 plot_ch3_hourly_reserve_costcurve_results_V2.m 的思路：
%        - 从可行散点 (h, R, delta_total) 构造曲面；
%        - 基准 beta 的曲面网格作为公共比较网格；
%        - 其他 beta 的曲面插值到该基准网格上；
%   4) 输出：
%        - 基准网格 TimeGrid_ref, RGrid_ref
%        - 基准曲面 Z_ref
%        - 所有 beta 在基准网格上的 Z_interp
%        - 所有 beta 相对基准面的 DeltaZ = Z_interp - Z_ref
%   5) 默认保存为 Excel 工作簿 xlsx；
%   6) 可选绘图、可选另存 mat。
%
% -------------------------------------------------------------------------
% 最简调用：
%   S = compare_hourly_reserve_surface_vs_ref_beta();
%
% 指定文件：
%   S = compare_hourly_reserve_surface_vs_ref_beta( ...
%       project_data_file('reserve', 'hourly_reserve_costcurve_all_beta.mat'));
%
% 指定基准置信度：
%   cfg = struct();
%   cfg.beta_ref = 0.90;
%   S = compare_hourly_reserve_surface_vs_ref_beta( ...
%       project_data_file('reserve', 'hourly_reserve_costcurve_all_beta.mat'), cfg);
%
% 输出结果说明：
%   S.beta_ref               基准置信度
%   S.beta_list              所有可用置信度
%   S.TimeGrid_ref           基准时间网格
%   S.RGrid_ref              基准备用水平网格
%   S.Z_ref                  基准置信度曲面矩阵
%   S.Z_all(:,:,k)           第 k 个 beta 在基准网格上的 Z 矩阵
%   S.DeltaZ_all(:,:,k)      第 k 个 beta 相对基准面的增量矩阵
%   S.beta_info(k)           每个 beta 的详细信息
%   S.saved_xlsx             保存出的 xlsx 路径
%
% 备注：
%   - Z 即"增量成本 delta_total"
%   - 基准 beta 自身也会输出到 Z_all 中
%   - 对于基准 beta，自增量矩阵 DeltaZ_ref 在有效网格点上为 0
%   - 若某些区域原本无数据、插值后仍无定义，则保留 NaN
% =========================================================================

%% 0) 默认输入
if nargin < 1 || isempty(in)
    in = project_data_file('reserve', 'hourly_reserve_costcurve_all_beta.mat');
end
if nargin < 2 || isempty(cfg)
    cfg = struct();
end
cfg = local_fill_defaults(cfg);

%% 1) 读取结果
Sraw = local_load_any(in);
results_all = local_extract_results_all(Sraw);

beta_all = [results_all.beta_use];
if isempty(beta_all)
    error('未读取到任何 beta 结果。');
end

% 排序，防止文件内部顺序混乱
[beta_all, idx_sort] = sort(beta_all(:).');
results_all = results_all(idx_sort);

%% 2) 确定基准置信度
if isempty(cfg.beta_ref)
    fprintf('\n可用置信度列表：\n');
    fprintf('  ');
    fprintf('%.2f  ', beta_all);
    fprintf('\n');
    beta_ref_in = input('请输入基准置信度 beta_ref（例如 0.90）： ');
    if isempty(beta_ref_in)
        error('未输入基准置信度。');
    end
    cfg.beta_ref = beta_ref_in;
end

[~, idx_ref] = min(abs(beta_all - cfg.beta_ref));
beta_ref = beta_all(idx_ref);
out_ref  = results_all(idx_ref).out;

fprintf('\n============================================================\n');
fprintf('基准置信度请求值 beta_ref_req = %.4f\n', cfg.beta_ref);
fprintf('实际匹配使用值 beta_ref_use  = %.4f\n', beta_ref);
fprintf('共读取到 %d 个 beta 结果\n', numel(beta_all));
fprintf('============================================================\n');

%% 3) 构造基准曲面散点与网格
[t_ref, r_ref, z_ref_scatter] = local_collect_surface_scatter(out_ref, cfg);
if isempty(t_ref)
    error('基准置信度 beta=%.4f 下没有可用的可行曲面散点。', beta_ref);
end

% 严格沿用当前程序思路：meshgrid(unique(time), unique(R))
time_unique_ref = unique(t_ref);
R_unique_ref    = unique(r_ref);

[TimeGrid_ref, RGrid_ref] = meshgrid(time_unique_ref, R_unique_ref);
Z_ref = griddata(t_ref, r_ref, z_ref_scatter, TimeGrid_ref, RGrid_ref, cfg.interp_method);

if all(isnan(Z_ref), 'all')
    error('基准置信度 beta=%.4f 的曲面插值后全为 NaN，请检查数据。', beta_ref);
end

%% 4) 对所有 beta 插值到基准网格，并计算 DeltaZ
nBeta = numel(beta_all);
nR    = size(RGrid_ref, 1);
nT    = size(TimeGrid_ref, 2);

Z_all      = nan(nR, nT, nBeta);
DeltaZ_all = nan(nR, nT, nBeta);

beta_info = repmat(struct( ...
    'beta_use', [], ...
    'n_scatter', [], ...
    'time_scatter', [], ...
    'R_scatter', [], ...
    'Z_scatter', [], ...
    'Z_interp', [], ...
    'DeltaZ', [], ...
    'minZ', [], ...
    'maxZ', [], ...
    'minDeltaZ', [], ...
    'maxDeltaZ', []), nBeta, 1);

for k = 1:nBeta
    outk = results_all(k).out;
    betak = results_all(k).beta_use;

    [tk, rk, zk] = local_collect_surface_scatter(outk, cfg);

    beta_info(k).beta_use     = betak;
    beta_info(k).n_scatter    = numel(zk);
    beta_info(k).time_scatter = tk;
    beta_info(k).R_scatter    = rk;
    beta_info(k).Z_scatter    = zk;

    if isempty(tk)
        fprintf('beta = %.4f: 无可行散点，跳过插值。\n', betak);
        continue;
    end

    Zk_interp = griddata(tk, rk, zk, TimeGrid_ref, RGrid_ref, cfg.interp_method);

    % 基准自身：保留 Z_ref；Delta 在有效点为 0，无效点仍为 NaN
    if abs(betak - beta_ref) < cfg.beta_tol
        Zk_interp = Z_ref;
        Dk = zeros(size(Z_ref));
        Dk(isnan(Z_ref)) = NaN;
    else
        Dk = Zk_interp - Z_ref;
    end

    Z_all(:,:,k)      = Zk_interp;
    DeltaZ_all(:,:,k) = Dk;

    beta_info(k).Z_interp   = Zk_interp;
    beta_info(k).DeltaZ     = Dk;
    beta_info(k).minZ       = min(Zk_interp(:), [], 'omitnan');
    beta_info(k).maxZ       = max(Zk_interp(:), [], 'omitnan');
    beta_info(k).minDeltaZ  = min(Dk(:), [], 'omitnan');
    beta_info(k).maxDeltaZ  = max(Dk(:), [], 'omitnan');

    fprintf('beta = %.4f | 散点数 = %4d | Z范围 = [%.6f, %.6f] | Delta范围 = [%.6f, %.6f]\n', ...
        betak, beta_info(k).n_scatter, ...
        beta_info(k).minZ, beta_info(k).maxZ, ...
        beta_info(k).minDeltaZ, beta_info(k).maxDeltaZ);
end

%% 5) 输出结构体
S = struct();
S.input                = in;
S.cfg                  = cfg;
S.beta_ref             = beta_ref;
S.beta_ref_index       = idx_ref;
S.beta_list            = beta_all(:);
S.results_all          = results_all;

S.TimeGrid_ref         = TimeGrid_ref;
S.RGrid_ref            = RGrid_ref;
S.Z_ref                = Z_ref;

S.Z_all                = Z_all;
S.DeltaZ_all           = DeltaZ_all;
S.beta_info            = beta_info;

S.ref_scatter.time     = t_ref;
S.ref_scatter.R        = r_ref;
S.ref_scatter.Z        = z_ref_scatter;

S.desc = struct();
S.desc.Z_ref      = '基准置信度曲面矩阵（增量成本）';
S.desc.Z_all      = '所有置信度在基准网格上的曲面矩阵，第三维对应 beta_list';
S.desc.DeltaZ_all = '所有置信度相对基准面的差值矩阵，第三维对应 beta_list';

%% 6) 可选绘图
if cfg.make_plots
    local_make_plots(S, cfg);
end

%% 7) 可选保存
S.saved_xlsx = '';
S.saved_mat  = '';

if ~exist(cfg.outdir, 'dir')
    mkdir(cfg.outdir);
end

% 优先保存为 xlsx
if cfg.save_xlsx
    xlsx_name = sprintf('surface_delta_vs_ref_beta_%02d.xlsx', round(100*beta_ref));
    xlsx_path = fullfile(cfg.outdir, xlsx_name);

    if exist(xlsx_path, 'file') == 2
        delete(xlsx_path);
    end

    local_write_outputs_to_xlsx(xlsx_path, S);
    S.saved_xlsx = xlsx_path;

    fprintf('\n结果已保存到 Excel：%s\n', xlsx_path);
end

% 可选同时保存 mat
if cfg.save_mat
    mat_name = sprintf('surface_delta_vs_ref_beta_%02d.mat', round(100*beta_ref));
    mat_path = fullfile(cfg.outdir, mat_name);
    save(mat_path, 'S', '-v7.3');
    S.saved_mat = mat_path;
    fprintf('结果同时保存到 MAT：%s\n', mat_path);
end

end

% =========================================================================
% 默认参数
% =========================================================================
function cfg = local_fill_defaults(cfg)

if ~isfield(cfg, 'beta_ref')
    cfg.beta_ref = [];
end
if ~isfield(cfg, 'outdir') || isempty(cfg.outdir)
    cfg.outdir = project_data_file('reserve');
end
if ~isfield(cfg, 'interp_method') || isempty(cfg.interp_method)
    cfg.interp_method = 'linear';   % 与当前空间曲面代码一致
end
if ~isfield(cfg, 'beta_tol') || isempty(cfg.beta_tol)
    cfg.beta_tol = 1e-10;
end
if ~isfield(cfg, 'make_plots') || isempty(cfg.make_plots)
    cfg.make_plots = true;
end

% 默认保存 xlsx
if ~isfield(cfg, 'save_xlsx') || isempty(cfg.save_xlsx)
    cfg.save_xlsx = true;
end
if ~isfield(cfg, 'save_mat') || isempty(cfg.save_mat)
    cfg.save_mat = false;
end

if ~isfield(cfg, 'show_only_selected_beta') || isempty(cfg.show_only_selected_beta)
    cfg.show_only_selected_beta = false; % false: 全部beta；true: 只画 compare_list
end
if ~isfield(cfg, 'beta_compare_list') || isempty(cfg.beta_compare_list)
    cfg.beta_compare_list = [];
end
if ~isfield(cfg, 'fill_missing_for_plot') || isempty(cfg.fill_missing_for_plot)
    cfg.fill_missing_for_plot = false;   % 仅绘图时是否做二次填补
end
if ~isfield(cfg, 'plot_view') || isempty(cfg.plot_view)
    cfg.plot_view = [45 30];
end
if ~isfield(cfg, 'font_size') || isempty(cfg.font_size)
    cfg.font_size = 11;
end

end

% =========================================================================
% 读取输入
% =========================================================================
function Sraw = local_load_any(in)

if isstruct(in)
    Sraw = in;
    return;
end

if ischar(in) || isstring(in)
    matFile = char(in);
    assert(exist(matFile, 'file') == 2, '未找到结果文件：%s', matFile);
    Sraw = load(matFile);
    return;
end

error('输入必须是结构体或 .mat 文件路径。');

end

% =========================================================================
% 提取 results_all
% =========================================================================
function results_all = local_extract_results_all(Sraw)

if isfield(Sraw, 'results_all')
    results_all = Sraw.results_all;
    return;
end

% 兼容直接传进来的就是 results_all
if isstruct(Sraw) && all(isfield(Sraw, {'beta_use', 'out'}))
    results_all = Sraw;
    return;
end

error('输入中未找到 results_all，无法继续。');

end

% =========================================================================
% 从 out 中提取曲面散点：(time_all, Rgrid_all, cost_all)
% 与现有 plot_ch3_hourly_reserve_costcurve_results_V2.m 保持一致
% =========================================================================
function [time_all, Rgrid_all, cost_all] = local_collect_surface_scatter(out, cfg)

hours = out.hours;
Nh    = out.mdl.Nh;

time_all  = [];
Rgrid_all = [];
cost_all  = [];

for h = 1:Nh
    Hr = hours(h);

    if ~isfield(Hr, 'R_grid') || isempty(Hr.R_grid)
        continue;
    end
    if ~isfield(Hr, 'is_feasible') || isempty(Hr.is_feasible)
        continue;
    end
    if ~isfield(Hr, 'delta_total') || isempty(Hr.delta_total)
        continue;
    end

    feasible_idx = find(Hr.is_feasible);
    if isempty(feasible_idx)
        continue;
    end

    Rh = Hr.R_grid(feasible_idx);
    Zh = Hr.delta_total(feasible_idx);
    Th = h * ones(numel(feasible_idx), 1);

    good = ~(isnan(Rh) | isnan(Zh) | isnan(Th));
    Rh = Rh(good);
    Zh = Zh(good);
    Th = Th(good);

    if isempty(Rh)
        continue;
    end

    time_all  = [time_all;  Th(:)];
    Rgrid_all = [Rgrid_all; Rh(:)];
    cost_all  = [cost_all;  Zh(:)];
end

% 去除完全重复的散点，避免某些 griddata 的数值问题
if ~isempty(time_all)
    M = [time_all(:), Rgrid_all(:), cost_all(:)];
    M = unique(M, 'rows', 'stable');
    time_all  = M(:,1);
    Rgrid_all = M(:,2);
    cost_all  = M(:,3);
end

% 保留 cfg 参数接口
~ = cfg;

end

% =========================================================================
% 绘图
% =========================================================================
function local_make_plots(S, cfg)

beta_all = S.beta_list(:).';
TimeGrid = S.TimeGrid_ref;
RGrid    = S.RGrid_ref;
Z_ref    = S.Z_ref;

if cfg.show_only_selected_beta && ~isempty(cfg.beta_compare_list)
    beta_pick = cfg.beta_compare_list(:).';
    idx_plot = [];
    for i = 1:numel(beta_pick)
        [~, idxi] = min(abs(beta_all - beta_pick(i)));
        idx_plot(end+1) = idxi; %#ok<AGROW>
    end
    idx_plot = unique(idx_plot, 'stable');
else
    idx_plot = 1:numel(beta_all);
end

% ---------- 图1：基准曲面 ----------
f1 = figure('Color', 'w');
surf(TimeGrid, RGrid, local_plot_fill_if_needed(Z_ref, cfg), 'EdgeColor', 'none');
hold on; box on; grid on;
xlabel('时间 h');
ylabel('备用水平 R (kW)');
zlabel('增量成本 \Delta J');
title(sprintf('基准置信度曲面：\\beta_{ref}=%.2f', S.beta_ref));
colorbar;
view(cfg.plot_view(1), cfg.plot_view(2));
set(gca, 'FontSize', cfg.font_size);

% ---------- 图2：所有 beta 的绝对曲面（子图） ----------
nPlot = numel(idx_plot);
[nr, nc] = local_best_subplot_layout(nPlot);

f2 = figure('Color', 'w');
tiledlayout(nr, nc, 'TileSpacing', 'compact', 'Padding', 'compact');

for ii = 1:nPlot
    k = idx_plot(ii);
    Zk = S.Z_all(:,:,k);

    nexttile;
    surf(TimeGrid, RGrid, local_plot_fill_if_needed(Zk, cfg), 'EdgeColor', 'none');
    hold on; box on; grid on;
    xlabel('h');
    ylabel('R');
    zlabel('\Delta J');
    title(sprintf('\\beta=%.2f', beta_all(k)));
    view(cfg.plot_view(1), cfg.plot_view(2));
    set(gca, 'FontSize', max(cfg.font_size-1, 9));
end

sgtitle(sprintf('各置信度在基准网格上的绝对曲面（基准 \\beta=%.2f）', S.beta_ref), ...
    'FontWeight', 'bold');

% ---------- 图3：所有 beta 的相对基准增量曲面（子图） ----------
f3 = figure('Color', 'w');
tiledlayout(nr, nc, 'TileSpacing', 'compact', 'Padding', 'compact');

for ii = 1:nPlot
    k = idx_plot(ii);
    Dk = S.DeltaZ_all(:,:,k);

    nexttile;
    surf(TimeGrid, RGrid, local_plot_fill_if_needed(Dk, cfg), 'EdgeColor', 'none');
    hold on; box on; grid on;
    xlabel('h');
    ylabel('R');
    zlabel('\Delta Z');
    title(sprintf('\\beta=%.2f 相对 \\beta_{ref}=%.2f', beta_all(k), S.beta_ref));
    view(cfg.plot_view(1), cfg.plot_view(2));
    set(gca, 'FontSize', max(cfg.font_size-1, 9));
end

sgtitle(sprintf('各置信度相对基准面的增量曲面（\\Delta Z = Z_\\beta - Z_{ref}）'), ...
    'FontWeight', 'bold');

% ---------- 图4：增量曲面叠加图 ----------
f4 = figure('Color', 'w');
hold on; box on; grid on;

surf_colors = lines(max(4, nPlot));
leg_h = [];
leg_s = {};

for ii = 1:nPlot
    k = idx_plot(ii);
    Dk = local_plot_fill_if_needed(S.DeltaZ_all(:,:,k), cfg);

    hs = surf(TimeGrid, RGrid, Dk, ...
        'EdgeColor', 'none', ...
        'FaceAlpha', 0.30, ...
        'FaceColor', surf_colors(ii,:));

    leg_h(end+1) = hs; %#ok<AGROW>
    leg_s{end+1} = sprintf('\\beta=%.2f', beta_all(k)); %#ok<AGROW>
end

xlabel('时间 h');
ylabel('备用水平 R (kW)');
zlabel('\Delta Z');
title(sprintf('相对基准置信度 \\beta_{ref}=%.2f 的增量曲面叠加图', S.beta_ref));
legend(leg_h, leg_s, 'Location', 'best');
view(cfg.plot_view(1), cfg.plot_view(2));
set(gca, 'FontSize', cfg.font_size);

% ---------- 图5：每个 beta 的增量矩阵热图 ----------
f5 = figure('Color', 'w');
tiledlayout(nr, nc, 'TileSpacing', 'compact', 'Padding', 'compact');

for ii = 1:nPlot
    k = idx_plot(ii);
    Dk = S.DeltaZ_all(:,:,k);

    nexttile;
    imagesc(TimeGrid(1,:), RGrid(:,1), Dk);
    axis xy;
    xlabel('h');
    ylabel('R');
    title(sprintf('\\beta=%.2f', beta_all(k)));
    colorbar;
    set(gca, 'FontSize', max(cfg.font_size-1, 9));
end

sgtitle(sprintf('各置信度相对基准面的增量热图（\\beta_{ref}=%.2f）', S.beta_ref), ...
    'FontWeight', 'bold');

% 保存图
if ~exist(cfg.outdir, 'dir')
    mkdir(cfg.outdir);
end

tag = sprintf('betaRef_%02d', round(100*S.beta_ref));

saveas(f1, fullfile(cfg.outdir, ['fig_surface_ref_' tag '.png']));
saveas(f2, fullfile(cfg.outdir, ['fig_surface_abs_all_' tag '.png']));
saveas(f3, fullfile(cfg.outdir, ['fig_surface_delta_all_' tag '.png']));
saveas(f4, fullfile(cfg.outdir, ['fig_surface_delta_overlay_' tag '.png']));
saveas(f5, fullfile(cfg.outdir, ['fig_surface_delta_heatmap_' tag '.png']));

fprintf('\n图已保存到目录：%s\n', cfg.outdir);

end

% =========================================================================
% 绘图前对 NaN 做可选填补
% =========================================================================
function Zp = local_plot_fill_if_needed(Z, cfg)

Zp = Z;
if ~cfg.fill_missing_for_plot
    return;
end

mask = isnan(Zp);
if ~any(mask, 'all')
    return;
end

% 仅用于显示，尽量不改变主输出数据
% 先按列线性补，再按行线性补
for j = 1:size(Zp,2)
    col = Zp(:,j);
    x = (1:numel(col))';
    good = ~isnan(col);
    if nnz(good) >= 2
        col(~good) = interp1(x(good), col(good), x(~good), 'linear', 'extrap');
    end
    Zp(:,j) = col;
end

for i = 1:size(Zp,1)
    row = Zp(i,:);
    x = 1:numel(row);
    good = ~isnan(row);
    if nnz(good) >= 2
        row(~good) = interp1(x(good), row(good), x(~good), 'linear', 'extrap');
    end
    Zp(i,:) = row;
end

end

% =========================================================================
% 子图布局
% =========================================================================
function [nr, nc] = local_best_subplot_layout(n)

if n <= 1
    nr = 1; nc = 1;
elseif n == 2
    nr = 1; nc = 2;
elseif n <= 4
    nr = 2; nc = 2;
elseif n <= 6
    nr = 2; nc = 3;
elseif n <= 9
    nr = 3; nc = 3;
else
    nr = ceil(sqrt(n));
    nc = ceil(n / nr);
end

end

% =========================================================================
% 写出到 Excel
% =========================================================================
function local_write_outputs_to_xlsx(xlsxFile, S)

beta_all = S.beta_list(:).';
time_vec = S.TimeGrid_ref(1, :);
R_vec    = S.RGrid_ref(:, 1);

% ---------- Summary ----------
summary = cell(8 + numel(beta_all), 2);
summary(1,:) = {'字段', '值'};
summary(2,:) = {'beta_ref', S.beta_ref};
summary(3,:) = {'基准网格小时数', numel(time_vec)};
summary(4,:) = {'基准网格备用层数', numel(R_vec)};
summary(5,:) = {'插值方法', S.cfg.interp_method};
summary(6,:) = {'说明1', '所有 Z 表均为基准网格上的增量成本矩阵'};
summary(7,:) = {'说明2', '所有 DeltaZ 表满足 DeltaZ = Z_beta - Z_ref'};
summary(8,:) = {'说明3', '首行是小时 h，首列是备用水平 R'};

for k = 1:numel(beta_all)
    summary{8+k, 1} = sprintf('beta_%03d', round(100*beta_all(k)));
    summary{8+k, 2} = beta_all(k);
end

local_write_cell_to_excel(xlsxFile, 'Summary', summary);

% ---------- 网格说明 ----------
grid_info = local_make_grid_info_cell(time_vec, R_vec);
local_write_cell_to_excel(xlsxFile, 'Grid', grid_info);

% ---------- 基准 Z ----------
Cref = local_make_matrix_cell(time_vec, R_vec, S.Z_ref, 'R\h');
local_write_cell_to_excel(xlsxFile, 'Z_ref', Cref);

% ---------- 所有 beta 的 Z 和 DeltaZ ----------
for k = 1:numel(beta_all)
    beta_tag = sprintf('%03d', round(100*beta_all(k)));

    sheetZ  = ['Z_'  beta_tag];
    sheetDZ = ['DZ_' beta_tag];

    CZ  = local_make_matrix_cell(time_vec, R_vec, S.Z_all(:,:,k),      'R\h');
    CDZ = local_make_matrix_cell(time_vec, R_vec, S.DeltaZ_all(:,:,k), 'R\h');

    local_write_cell_to_excel(xlsxFile, sheetZ,  CZ);
    local_write_cell_to_excel(xlsxFile, sheetDZ, CDZ);
end

end

% =========================================================================
% 生成带行列头的矩阵单元格
% =========================================================================
function C = local_make_matrix_cell(time_vec, R_vec, Z, topLeftLabel)

nH = numel(time_vec);
nR = numel(R_vec);

C = cell(nR + 1, nH + 1);
C{1,1} = topLeftLabel;

for j = 1:nH
    C{1, j+1} = time_vec(j);
end
for i = 1:nR
    C{i+1, 1} = R_vec(i);
end

for i = 1:nR
    for j = 1:nH
        C{i+1, j+1} = Z(i,j);
    end
end

end

% =========================================================================
% 网格说明 sheet
% =========================================================================
function C = local_make_grid_info_cell(time_vec, R_vec)

nH = numel(time_vec);
nR = numel(R_vec);
n  = max(nH, nR);

C = cell(n + 2, 2);
C(1,:) = {'小时 h', '备用水平 R (kW)'};

for i = 1:nH
    C{i+1, 1} = time_vec(i);
end
for i = 1:nR
    C{i+1, 2} = R_vec(i);
end

end

% =========================================================================
% 写 cell 到 Excel，兼容 writecell / xlswrite
% =========================================================================
function local_write_cell_to_excel(xlsxFile, sheetName, C)

try
    writecell(C, xlsxFile, 'Sheet', sheetName, 'Range', 'A1');
catch
    try
        xlswrite(xlsxFile, C, sheetName, 'A1');
    catch ME
        error('写入 Excel 失败（Sheet=%s）：%s', sheetName, ME.message);
    end
end

end