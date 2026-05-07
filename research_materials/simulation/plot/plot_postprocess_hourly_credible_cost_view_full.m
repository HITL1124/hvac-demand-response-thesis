function plot_postprocess_hourly_credible_cost_view_full(in, cfg)
% =========================================================================
% 纯成本绘图（最简版）
% -------------------------------------------------------------------------
% 支持：
%   plot_postprocess_hourly_credible_cost_view_full
%   plot_postprocess_hourly_credible_cost_view_full(out_cost)
%   plot_postprocess_hourly_credible_cost_view_full('xxx.mat')
% =========================================================================

if nargin < 1, in = []; end
if nargin < 2, cfg = struct(); end

out_cost = local_load_any(in);
cfg = local_fill_defaults(cfg);
out = out_cost.base;
Nh = double(out.mdl.Nh);
hvec = (1:Nh).';

%% 图1：天然 / 热可行 / 可信备用
Rnat = out_cost.R_nat_hour(:);
Rcred = out_cost.R_cred_hour(:);
Rmax = nan(Nh,1);
for h = 1:Nh
    if isfield(out.hours(h),'max_feasible_R') && ~isempty(out.hours(h).max_feasible_R)
        Rmax(h) = out.hours(h).max_feasible_R;
    end
end

figure('Color','w'); hold on; box on; grid on;
plot(hvec, Rnat, '-o', 'LineWidth',1.6, 'MarkerSize',4, 'DisplayName','天然备用');
plot(hvec, Rmax, '-s', 'LineWidth',1.6, 'MarkerSize',4, 'DisplayName','最大热可行备用');
plot(hvec, Rcred,'-^', 'LineWidth',1.6, 'MarkerSize',4, 'DisplayName','最大可信备用');
xlabel('小时 h'); ylabel('备用 R (kW)');
title(sprintf('逐小时备用边界 (beta=%.2f)', out_cost.beta_use));
legend('Location','best');

%% 图2：1x3 分组逐小时成本曲线
figure('Color','w');
tiledlayout(1,3,'TileSpacing','compact','Padding','compact');
groups = {1:8, 9:18, 19:24};
titles = {'0~8h','9~18h','19~24h'};
for g = 1:3
    nexttile; hold on; box on; grid on;
    idx = groups{g};
    for h = idx
        Rh = out_cost.hours(h).R_grid_cred(:);
        Jh = out_cost.hours(h).delta_total_cred(:);
        if ~isempty(Rh)
            plot(Rh, Jh, 'LineWidth', 1.2, 'DisplayName', sprintf('h=%02d',h));
        end
    end
    xlabel('备用水平 R (kW)'); ylabel('\Delta J');
    title(['可信域逐小时成本曲线：', titles{g}]);
    legend('Location','best');
end

%% 图3：4x6 全天逐小时成本曲线
figure('Color','w');
tiledlayout(4,6,'TileSpacing','compact','Padding','compact');
for h = 1:Nh
    nexttile; hold on; box on; grid on;
    Rh = out_cost.hours(h).R_grid_cred(:);
    Jh = out_cost.hours(h).delta_total_cred(:);
    if ~isempty(Rh)
        plot(Rh, Jh, '-o', 'LineWidth', 1.0, 'MarkerSize', 3);
        xline(Rnat(h), ':k', 'LineWidth', 0.8);
        xline(Rcred(h), '--r', 'LineWidth', 0.8);
    end
    title(sprintf('h=%02d', h));
    xlabel('R'); ylabel('\Delta J');
end

%% 图4：3D 曲面
[RR, HH, ZZ] = local_build_surface(out_cost, cfg.nSurf);
figure('Color','w');
surf(HH, RR, ZZ, 'EdgeColor','none');
view(135,30); box on; grid on; colorbar;
xlabel('时间 h'); ylabel('备用水平 R (kW)'); zlabel('\Delta J');
title(sprintf('可信域纯成本空间曲面 (beta=%.2f)', out_cost.beta_use));

%% 图5：俯视等值图
figure('Color','w');
contourf(HH, RR, ZZ, cfg.nContour, 'LineStyle', 'none');
box on; grid on; colorbar;
xlabel('时间 h'); ylabel('备用水平 R (kW)');
title('可信域纯成本俯视等值图');

end

% =========================================================================
% 默认配置
% =========================================================================
function cfg = local_fill_defaults(cfg)
if ~isfield(cfg,'nSurf') || isempty(cfg.nSurf)
    cfg.nSurf = 200;
end
if ~isfield(cfg,'nContour') || isempty(cfg.nContour)
    cfg.nContour = 20;
end
end

% =========================================================================
% 读取输入
% =========================================================================
function out_cost = local_load_any(in)
if isempty(in)
    default_file = project_data_file('postprocess_cost', 'hourly_reserve_credible_cost_full_beta_95.mat');
    if exist(default_file, 'file') == 2
        S = load(default_file);
    else
        dd = dir(project_data_file('postprocess_cost','hourly_reserve_credible_cost_full_beta_*.mat'));
        assert(~isempty(dd), '未找到默认 out_cost MAT 文件。');
        [~, idx] = max([dd.datenum]);
        S = load(fullfile(dd(idx).folder, dd(idx).name));
    end
elseif ischar(in) || isstring(in)
    S = load(in);
else
    S = in;
end

if isfield(S,'out_cost')
    out_cost = S.out_cost;
elseif isfield(S,'hours') && isfield(S,'R_cred_hour')
    out_cost = S;
else
    error('无法识别输入。');
end
end

% =========================================================================
% 生成曲面矩阵：域外全用 NaN，不补 0
% =========================================================================
function [RR, HH, ZZ] = local_build_surface(out_cost, nSurf)
Nh = numel(out_cost.hours);
Rmax = 0;
for h = 1:Nh
    Rh = out_cost.hours(h).R_grid_cred(:);
    if ~isempty(Rh)
        Rmax = max(Rmax, max(Rh));
    end
end

Rq = linspace(0, Rmax, nSurf).';
ZZ = nan(nSurf, Nh);

for h = 1:Nh
    Rh = out_cost.hours(h).R_grid_cred(:);
    Jh = out_cost.hours(h).delta_total_cred(:);
    if isempty(Rh) || isempty(Jh)
        continue;
    end

    [Rh, ia] = unique(Rh, 'stable');
    Jh = Jh(ia);
    if numel(Rh) == 1
        ZZ(:,h) = nan;
        ZZ(Rq <= Rh(end), h) = Jh(1);
        continue;
    end

    valid = (Rq >= Rh(1)) & (Rq <= Rh(end));
    ZZ(valid, h) = interp1(Rh, Jh, Rq(valid), 'linear');
end

[HH, RR] = meshgrid(1:Nh, Rq);
end
