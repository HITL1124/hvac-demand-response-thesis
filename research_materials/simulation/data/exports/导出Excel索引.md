# 导出 Excel 索引

优先按论文图号找文件。一般规则：

- 画论文图时，优先用对应文件夹里的 `export_*.xlsx`。
- 文件名带 `for_origin` 的是 Origin 宽表，更适合直接导入 Origin 作图。
- `noRevenue` 是不含容量收益的成本版本；Fig12 caption 写 holding cost 时需要重点核对这一版。
- `credible_reserve_summary_coop_beta_95.xlsx` 和 `hourly_credible_revenue_costcurve_data.xlsx` 是旧/手工参考表，优先级低于同文件夹里的 `export_*.xlsx`。

| 文件夹 | 什么时候用 | 主要文件 |
|---|---|---|
| `01_Fig3_Fig4_stage1_inputs_cqr` | Fig3/Fig4，代表日输入和 CQR 预测区间 | `export_stage1_cqr_prediction_intervals.xlsx`, `export_one_day_outdoor_temp_irradiance.xlsx` |
| `02_Fig5_cqr_gaussian` | Fig5，CQR 与 Gaussian 风险边界/安全裕量对比 | `export_cqr_gaussian_risk_bounds_and_margins.xlsx` |
| `03_Fig6_Fig7_baseline_control_power` | Fig6/Fig7，协调策略和固定 Ts/air-only 基线对比 | `export_baseline_fixedTs_vs_coop.xlsx`, `baseline_power_breakdown_compare_fixTs_vs_coord_all_beta.xlsx` |
| `04_Fig9_Fig14_reserve_summary` | Fig9/Fig14，天然备用、最大可行备用、可信备用汇总 | `export_hourly_max_feasible_and_credible_reserve_all_beta.xlsx` |
| `05_Fig10_Fig11_workpoint_risk` | Fig10/Fig11，R-Ts-ma 工作点和 15min 风险传播 | `export_hourly_reserve_ts_ma.xlsx`, `export_hourly_risk_bounds_and_temperature_trajectories.xlsx`, `export_credible_screen_beta_90_all_hours.xlsx` |
| `06_Fig12_Fig13_cost_curves_surfaces` | Fig12/Fig13，可信备用成本曲面、成本曲线和 Origin 宽表 | `export_hourly_credible_netcost_surface_all_beta.xlsx`, `export_hourly_credible_cost_curves_for_origin_all_beta.xlsx`, `export_hourly_feasible_cost_curves_for_origin_all_beta.xlsx` |
| `07_multiday_robustness_beta90_nscan20` | 多测试日稳健性补充，不是当前 Origin 主图数据源 | `multiday_robustness_beta90_nscan20_summary.xlsx` |

## 按图号快速找

| 图号 | 先看哪个文件 |
|---|---|
| Fig3 | `01_Fig3_Fig4_stage1_inputs_cqr/export_one_day_outdoor_temp_irradiance.xlsx` + `export_stage1_cqr_prediction_intervals.xlsx` |
| Fig4 | `01_Fig3_Fig4_stage1_inputs_cqr/export_stage1_cqr_prediction_intervals.xlsx` |
| Fig5 | `02_Fig5_cqr_gaussian/export_cqr_gaussian_risk_bounds_and_margins.xlsx` |
| Fig6 | `03_Fig6_Fig7_baseline_control_power/export_baseline_fixedTs_vs_coop.xlsx` |
| Fig7 | `03_Fig6_Fig7_baseline_control_power/baseline_power_breakdown_compare_fixTs_vs_coord_all_beta.xlsx` |
| Fig9 | `04_Fig9_Fig14_reserve_summary/export_hourly_max_feasible_and_credible_reserve_all_beta.xlsx` |
| Fig10 | `05_Fig10_Fig11_workpoint_risk/export_hourly_reserve_ts_ma.xlsx` |
| Fig11 | `05_Fig10_Fig11_workpoint_risk/export_hourly_risk_bounds_and_temperature_trajectories.xlsx` |
| Fig12 | `06_Fig12_Fig13_cost_curves_surfaces/export_hourly_credible_netcost_surface_all_beta.xlsx`，必要时对比 `noRevenue` 版本 |
| Fig13 | `06_Fig12_Fig13_cost_curves_surfaces/export_hourly_feasible_cost_curves_for_origin_all_beta.xlsx` + `export_hourly_credible_cost_curves_for_origin_all_beta.xlsx` |
| Fig14 | `04_Fig9_Fig14_reserve_summary/export_hourly_max_feasible_and_credible_reserve_all_beta.xlsx` |
