# 图表登记表

## 1. 文件定位

本文档用于轻量登记本科毕业论文《商业建筑 HVAC 系统动态需求响应》的候选图表池，记录候选图表可能来自哪里、可能支撑什么内容、是否需要重画或中文化处理。

本文档当前版本为 v0.1，用于建立初步候选图表池，而不是确定最终入文图表。

本文档不是论文正文，不确定最终图号，不决定最终章节结构，也不限制后续新增图表。当前登记结果只表示“可能有入文价值”，不表示已经确定进入最终论文。

本文档是候选图表池，不是最终图表清单。后续 Web GPT 仍可开放式提出新增图、合并图、删减图或重画图建议。

后续正式写作时，图表是否入文、入文位置、最终图号、图题、坐标轴、图例和正文解释均需结合章节结构、论文主线和作者确认结果进一步确定。

## 2. 登记原则

当前 v0.1 采用以下原则：

- 不确定最终图号；
- 不强行给图排序；
- 不把图表池当成章节结构；
- 不限制后续新增图；
- 不编造不存在的图；
- 对不确定来源、口径或用途的图表标注“待确认”；
- 对 TSTE 英文图原则上记录为“需中文化或重画”；
- 对中期报告/PPT 图原则上记录为“需重画或重新绘制为论文风格”；
- 对 cleanroom 图表优先记录其导出 Excel、export 脚本和上游 run 脚本关系；
- 对机制示意图、流程图等尚不存在但可能需要绘制的图，单独标注为“待绘制”，不写成已有图。

## 3. 状态说明

| 状态 | 含义 |
| --- | --- |
| 候选 | 有潜在入文价值，但尚未确定最终使用 |
| 重点候选 | 与当前论文主线关系较强，后续优先讨论 |
| 暂不采用 | 当前不建议进入候选池或暂时排除 |
| 待核对 | 图表来源、数据口径或是否仍有效需要进一步确认 |
| 待绘制 | 当前没有现成图，但可能需要新增示意图或流程图 |
| 需重画 | 有现成材料，但需要按本科论文风格重新绘制或中文化 |

同一图表可同时具有多个状态，例如“重点候选 / 需重画”表示该图与主线关系较强，但进入正文前需要重新绘制或中文化。

## 4. 本科论文可能需要的图表类型

当前从材料映射角度看，本科论文可能需要以下几类图表：

| 类型 | 作用 | 可能来源 | 当前判断 |
| --- | --- | --- | --- |
| 系统结构图 | 说明商业建筑 HVAC 系统、水侧、空气侧、建筑热区和边界输入之间的关系 | TSTE Fig1、中期 Dymola 模型图、中期 PPT 模块图 | 需要，建议重画 |
| 技术路线图 | 说明 Dymola、N4SID、CQR、可信备用评估和成本曲线之间的关系 | 当前无现成正式图 | 待绘制 |
| 模型校核图 | 说明 Dymola 高保真模型与实测数据的一致性 | 中期报告/PPT | 候选，需重画 |
| 预测模型验证图 | 说明 N4SID 状态空间模型预测效果 | 中期报告/PPT、TSTE Fig4 | 候选 |
| CQR 不确定性图 | 说明预测区间、覆盖率、风险边界和安全裕量 | TSTE Fig4/Fig5、中期 PPT | 重点候选 |
| 工作点重构图 | 说明供水温度、风量、备用水平和风机功率基线之间的关系 | TSTE Fig10 | 重点候选 |
| 备用能力结果图 | 对比天然备用、最大可行备用和可信备用 | TSTE Fig9/Fig14 | 重点候选 |
| 风险传播图 | 说明不同备用水平下的温度轨迹、风险收紧边界和舒适约束 | TSTE Fig11 | 重点候选 |
| 控制/运行对比图 | 比较协调策略与固定水侧或 air-only 基线 | TSTE Fig6/Fig7 | 重点候选 |
| 成本曲线图 | 说明可信备用能力与成本之间的关系 | TSTE Fig12/Fig13 | 当前优先级较高，成本口径待确认 |
| 参数表 | 说明 Dymola 建筑热区或模型关键参数 | 中期报告表格 | 候选，是否入文待定 |

## 5. TSTE 小论文图表候选

说明：

- TSTE Fig2 当前不纳入候选；
- 除当前明确排除的图外，其余 TSTE 图可先作为候选图进入后续筛选；
- 作者后续将基于 Origin 原图进行中文化或重画；
- 图表最终是否入文、入文位置和图题，需后续通过 `notes/figure_registry.md` 进一步登记确认。

| 候选ID | 原图 | 文件或材料线索 | 数据/脚本来源 | 可能支撑内容 | 处理建议 | 状态 | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| TSTE-Fig1 | Fig1 水-空气耦合 HVAC 系统示意图 | `journal_paper/fig1_schematic.png`; `assets/figures/source/tste/tste_fig01_hvac_schematic.png` | 手工图，无 xlsx | 说明水侧、空气侧、盘管、建筑热区之间的耦合关系 | 重画中文版 | 重点候选 / 需重画 | 可与中期 Dymola 模型图共同参考 |
| TSTE-Fig2 | Fig2 机理示意或旧图 | `journal_paper/fig2_mechanism.pdf`; `assets/figures/source/tste/tste_fig02_mechanism.pdf` | 无 | 暂不使用 | 不登记为入文候选 | 暂不采用 | 已在 mapping 中排除，但素材副本已保留为排除参考 |
| TSTE-Fig3 | Fig3 代表日输入与预测相关输入 | `journal_paper/fig3_input.pdf`; `assets/figures/source/tste/tste_fig03_inputs.pdf` | `export_stage1_cqr_prediction_intervals.xlsx`、`export_one_day_outdoor_temp_irradiance.xlsx` 等 | 说明代表日气象、输入剖面或 CQR 预测输入 | 中文化，是否保留待章节结构确定 | 候选 | 可能与中期边界输入图功能重叠 |
| TSTE-Fig4 | Fig4 代表日真实室温、N4SID 点预测和 90% CQR 区间 | `journal_paper/fig4_Temperature_under_90_converge.pdf`; `assets/figures/source/tste/tste_fig04_temperature_cqr_interval.pdf` | `export_stage1_cqr_prediction_intervals.xlsx`；上游 `Stage1Code_CQR.m`、`stage1_cqr.py` | 支撑 N4SID 点预测与 CQR 区间预测效果 | 中文化或重画 | 重点候选 | 可用于“预测模型与不确定性表征” |
| TSTE-Fig5 | Fig5 CQR 与 Gaussian 风险边界/安全裕量对比 | `journal_paper/fig5_cqr_vs_gau.pdf`; `assets/figures/source/tste/tste_fig05_cqr_gaussian_comparison.pdf` | `export_cqr_gaussian_risk_bounds_and_margins.xlsx`；上游 `stage1_cqr.py` | 说明 CQR 相比 Gaussian 风险边界的差异和必要性 | 中文化或重画 | 重点候选 | 若 CQR 作为重点方法展开，建议保留 |
| TSTE-Fig6 | Fig6 协调策略与固定水侧 / air-only 基线控制对比 | `journal_paper/fig6_control_compare.pdf`; `assets/figures/source/tste/tste_fig06_control_comparison.pdf` | `export_baseline_fixedTs_vs_coop.xlsx`；上游 reserve scan 与 fixedTs suite | 支撑水-空气协调对室温、供水温度、风量等运行变量的影响 | 中文化或重画 | 重点候选 | 可用于工作点重构效果分析 |
| TSTE-Fig7 | Fig7 功率分解对比 | `journal_paper/fig7_Power_breakdown.pdf`; `assets/figures/source/tste/tste_fig07_power_breakdown.pdf` | `baseline_power_breakdown_compare_fixTs_vs_coord_all_beta.xlsx`、`export_baseline_fixedTs_vs_coop.xlsx` | 支撑协调策略对风机、热源或水泵等功率构成的影响 | 中文化或重画 | 候选 | 功率分解口径需后续核对 |
| TSTE-Fig8 | Fig8 旧自然备用或对比图 | `journal_paper/fig8_nature_compare.pdf`; `assets/figures/source/tste/tste_fig08_natural_reserve_old.pdf` | 可能与 `export_hourly_max_feasible_and_credible_reserve_all_beta.xlsx` 或旧表有关 | 可能支撑自然备用或备用对比 | 先不优先使用 | 待核对 | cleanroom 说明中判断可能是旧图或被 Fig9 替代 |
| TSTE-Fig9 | Fig9 天然备用、最大可行备用、可信备用对照 | `journal_paper/fig9_credible_reserve.pdf`; `assets/figures/source/tste/tste_fig09_reserve_comparison.pdf` | `export_hourly_max_feasible_and_credible_reserve_all_beta.xlsx`；上游 reserve scan 与 credible screen | 支撑备用能力、最大可行备用能力和可信备用能力的分层对比 | 中文化或重画 | 重点候选 | 当前主线关键结果图 |
| TSTE-Fig10 | Fig10 代表小时 R-Ts-ma 工作点族 | `journal_paper/fig10_R_Ts_ma.pdf`; `assets/figures/source/tste/tste_fig10_workpoint_family.pdf` | `export_hourly_reserve_ts_ma.xlsx`、`export_credible_screen_beta_90_all_hours.xlsx` | 说明不同备用水平下供水温度、风量和工作点重构关系 | 中文化或重画 | 重点候选 | 可支撑“工作点重构”主线 |
| TSTE-Fig11 | Fig11 不同备用水平下风险传播和舒适边界 | `journal_paper/fig11_error.pdf`; `assets/figures/source/tste/tste_fig11_risk_boundary_temperature.pdf` | `export_hourly_risk_bounds_and_temperature_trajectories.xlsx`、`export_credible_screen_beta_90_all_hours.xlsx` | 说明备用部署下室温轨迹、风险收紧边界和可信筛选依据 | 中文化或重画 | 重点候选 | 可支撑可信备用筛选 |
| TSTE-Fig12 | Fig12 逐小时可信备用成本曲面 | `journal_paper/fig12_cost_wall.pdf`; `assets/figures/source/tste/tste_fig12_cost_surface.pdf` | `export_hourly_credible_netcost_surface_all_beta.xlsx` 或 `noRevenue` 版本 | 支撑可信备用成本曲面分析 | 中文化或重画，成本口径需核对 | 重点候选 / 待核对 | holding cost / net cost / noRevenue 需专题确认 |
| TSTE-Fig13 | Fig13 H10/H12 成本曲线、可行域与可信域 | `journal_paper/fig13_cost_curve_of_H10_H12.pdf`; `assets/figures/source/tste/tste_fig13_cost_curve_typical_hours.pdf` | `export_hourly_feasible_cost_curves_for_origin_all_beta.xlsx`、可能叠加 `export_hourly_credible_cost_curves_for_origin_all_beta.xlsx` | 支撑典型小时备用成本曲线、可行域和可信域关系 | 中文化或重画，成本口径需核对 | 重点候选 / 待核对 | 成本曲线是高优先级候选结果图，但具体采用方式待讨论 |
| TSTE-Fig14 | Fig14 不同置信度下可信备用与最大可行备用敏感性 | `journal_paper/fig14_credible_vs_max_reserve_blue.png`; `assets/figures/source/tste/tste_fig14_confidence_sensitivity.png` | `export_hourly_max_feasible_and_credible_reserve_all_beta.xlsx` | 支撑置信度对可信备用能力的影响 | 中文化或重画 | 候选 | TeX 中可能为 inactive，但可作为置信度讨论 |

## 6. cleanroom 仿真数据与图表来源登记

本节不新增独立图号，只登记 cleanroom 中与图表追溯相关的数据来源。正式入文图仍应回到上节候选图或后续新增图中登记。

本节中的路径、文件名和脚本关系需由 Codex 基于本地仓库进一步核对；若发现路径或文件名不一致，应标注为“待核对”，不得强行写成确定来源。

| 候选ID | 材料 | 路径/文件 | 可能用途 | 状态 | 备注 |
| --- | --- | --- | --- | --- | --- |
| DATA-Fig3-Fig4 | Stage1 输入和 CQR 预测区间导出数据 | `research_materials/simulation/data/exports/01_Fig3_Fig4_stage1_inputs_cqr/` | 支撑 Fig3/Fig4 中文化重画 | 候选数据源 | 主要文件包括 `export_stage1_cqr_prediction_intervals.xlsx`、`export_one_day_outdoor_temp_irradiance.xlsx` |
| DATA-Fig5 | CQR 与 Gaussian 对比导出数据 | `research_materials/simulation/data/exports/02_Fig5_cqr_gaussian/` | 支撑 Fig5 中文化重画 | 候选数据源 | 主要文件为 `export_cqr_gaussian_risk_bounds_and_margins.xlsx` |
| DATA-Fig6-Fig7 | 协调策略与固定 Ts / air-only 基线对比数据 | `research_materials/simulation/data/exports/03_Fig6_Fig7_baseline_control_power/` | 支撑 Fig6/Fig7 中文化重画 | 候选数据源 | 包含控制对比和功率分解数据 |
| DATA-Fig9-Fig14 | 最大可行备用、可信备用和置信度敏感性汇总 | `research_materials/simulation/data/exports/04_Fig9_Fig14_reserve_summary/` | 支撑 Fig9/Fig14 中文化重画 | 候选数据源 | 主要文件为 `export_hourly_max_feasible_and_credible_reserve_all_beta.xlsx` |
| DATA-Fig10-Fig11 | 工作点和风险传播数据 | `research_materials/simulation/data/exports/05_Fig10_Fig11_workpoint_risk/` | 支撑 Fig10/Fig11 中文化重画 | 候选数据源 | 包括 `export_hourly_reserve_ts_ma.xlsx`、`export_hourly_risk_bounds_and_temperature_trajectories.xlsx` 等 |
| DATA-Fig12-Fig13 | 成本曲面与成本曲线数据 | `research_materials/simulation/data/exports/06_Fig12_Fig13_cost_curves_surfaces/` | 支撑 Fig12/Fig13 中文化重画 | 候选数据源 / 待核对 | 需核对 holding cost、net cost、noRevenue 口径 |
| DATA-Multiday | 多测试日稳健性补充数据 | `research_materials/simulation/data/exports/07_multiday_robustness_beta90_nscan20/` | 可能用于稳健性补充说明 | 候选 / 暂不优先 | 当前不是 TSTE 主图数据源，是否入文待确认 |

## 7. 中期报告 / PPT 图表候选

说明：

- 中期材料属于阶段性过程材料；
- 中期图表如进入本科论文，应重新绘制为论文风格；
- 中期报告中的阶段性计划不作为最终结论；
- 中期 PPT 的汇报式图不直接复制到正文。

| 候选ID | 中期图表 | 来源 | 可能支撑内容 | 处理建议 | 状态 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| MID-Dymola-Struct | Dymola 高保真物理模型结构图 | 中期报告 图1；中期 PPT 相关模块页；`assets/figures/source/midterm/midterm_dymola_system_structure.svg` | 说明 Dymola 高保真模型总体结构，包括热源、水系统、AHU、建筑热区、边界数据驱动模块 | 参考原图重画 | 重点候选 / 需重画 | 可与 TSTE Fig1 共同整合为本科论文系统结构图 |
| MID-Boundary-Inputs | 模型校核时段主要边界输入条件图 | 中期报告 图2；`assets/figures/source/midterm/midterm_boundary_inputs.png` | 说明 Dymola 校核所用室外温度、供水温度、辐照度等边界输入 | 视需要重画 | 候选 | 可能用于仿真基础或模型校核说明 |
| MID-Internal-Gains | ASHRAE Guideline 14 典型内部得热时序设定 | 中期报告 图3 | 说明内部得热设定方式 | 视需要重画或改为文字说明 | 候选 | 当前未在图表绘制文件夹中识别到对应独立素材，待核对 |
| MID-Dymola-Calib | 模型回水温度校核结果 | 中期报告 图4；中期 PPT 第8页；`assets/figures/source/midterm/midterm_dymola_calibration.png`; `assets/figures/source/midterm/midterm_dymola_calibration_source.fig`; `assets/figures/source/midterm/midterm_dymola_calibration_alt_source.fig`; `assets/figures/source/midterm/midterm_dymola_calibration_error.png` | 说明 Dymola 高保真模型与实测回水温度的一致性 | 重画或重新排版 | 重点候选 / 需重画 | 中期报告含 MAE、RMSE、CVRMSE、R2 等指标，数值是否最终采用需确认 |
| MID-N4SID-Flow | N4SID 状态空间模型辨识流程图 | 中期报告 图5；中期 PPT 第10页；`assets/figures/source/midterm/midterm_all_figures_overview.vsdx` | 说明 N4SID 辨识流程 | 不优先作为正文图；如使用需简化 | 候选 / 非重点 | 当前未识别到独立导出图，可从汇总 Visio 源文件中提取或重画 |
| MID-N4SID-Fit | N4SID 在验证集上的拟合效果图 | 中期报告 图6；中期 PPT 第11页；`assets/figures/source/midterm/midterm_n4sid_fit.pdf`; `assets/figures/source/midterm/midterm_n4sid_fit.png` | 说明状态空间主模型对室温变化的拟合效果 | 可重画 | 候选 | 可与 TSTE Fig4 功能重叠，后续需二选一或合并 |
| MID-CQR-Flow | CQR 概率波动表征与鲁棒约束构造流程 | 中期 PPT 第12页；`assets/figures/source/midterm/midterm_all_figures_overview.vsdx` | 说明 CQR 从名义响应、分位学习、保形校准到鲁棒温度约束的流程 | 建议重画为论文技术流程图 | 重点候选 / 需重画 | 当前未识别到独立导出图，可从汇总 Visio 源文件中提取或重画 |
| MID-CQR-Coverage | 不同目标覆盖率下未来室温区间预测与经验覆盖率 | 中期 PPT 第13页 | 说明 CQR 区间宽度、覆盖率和预测步长之间的关系 | 可重画 | 候选 | 当前未在图表绘制文件夹中识别到对应独立素材，待核对 |
| MID-Module-HeatSource | 热源及输配模块图 | 中期 PPT 第4页；`assets/figures/source/midterm/midterm_heat_source_module.png` | 说明热泵、水泵、供回水管道和边界连接 | 仅作为重画参考 | 候选素材 | 不建议直接作为独立论文图 |
| MID-Module-Zone-AHU | 建筑热区模块图 | 中期 PPT 第5页；`assets/figures/source/midterm/midterm_all_figures_overview.vsdx` | 说明 Zone、AHU、盘管、风机、混风箱和回风结构 | 仅作为重画参考 | 候选素材 | 当前未识别到独立导出图，可从汇总 Visio 源文件中提取或重画 |
| MID-Data-Input | 数据输入模块图 | 中期 PPT 第6页；`assets/figures/source/midterm/midterm_data_input_module.svg` | 说明分钟级气象/运行数据表、内部得热和单位转换 | 仅作为重画参考 | 候选素材 | 可辅助绘制数据流图 |
| MID-Params-Table | 建筑热区模型主要参数表 | 中期报告 表2 | 说明 Dymola 建筑热区参数 | 是否入文待定 | 候选表 | 参数表可能较长，后续需压缩或选择关键参数 |

## 8. 可能需要新增绘制的示意图或流程图

本节记录当前没有现成正式图、但后续可能有必要新增的图。它们不是已有图，不应写成已经存在。

| 候选ID | 拟新增图 | 可能用途 | 来源依据 | 状态 | 备注 |
| --- | --- | --- | --- | --- | --- |
| NEW-Tech-Route | Dymola—N4SID—CQR—可信备用—成本曲线技术路线图 | 说明全文材料链条和方法衔接 | `project_scope.md`、`paper_to_thesis_mapping.md`、中期材料 | 待绘制 | 不等于最终章节结构 |
| NEW-Reserve-Layers | 备用能力层级关系示意图 | 解释备用能力、最大可行备用能力、可信备用能力之间的关系 | TSTE 主线和 Fig9 | 待绘制 | 可帮助降低读者理解门槛 |
| NEW-Workpoint-Mechanism | 水侧设定值重塑风机功率基线机制图 | 解释供水温度、盘管换热、风量、风机功率基线、备用范围之间的物理关系 | TSTE 模型与 Fig10 | 待绘制 | 注意不要复用已排除的 Fig2，可重新设计 |
| NEW-CQR-Risk-Constraint | CQR 到风险收紧舒适约束转换示意图 | 说明预测区间如何转化为确定性风险边界 | TSTE CQR 方法和中期 CQR 流程 | 待绘制 | 可与 MID-CQR-Flow 合并 |
| NEW-Data-Pipeline | 仿真数据与图表生成流程图 | 说明 Stage1/CQR、RegD、备用扫描、可信筛选、成本后处理、导出 Excel 的关系 | cleanroom 仿真主线说明 | 待绘制 | 适合 notes 或方法说明，是否入文待确认 |
| NEW-Cost-Meaning | 备用成本曲线含义示意图 | 帮助解释成本曲线、可行域、可信域和成本口径 | TSTE Fig12/Fig13 | 待绘制 / 待讨论 | 成本口径未确认前不绘制最终图 |

## 9. 当前不优先入文或需要谨慎处理的图表

| 候选ID | 图表 | 原因 | 当前处理 |
| --- | --- | --- | --- |
| TSTE-Fig2 | TSTE Fig2 机理示意图 | 已在映射阶段确认不纳入候选；cleanroom 说明中也显示其不属于 xlsx 主线 | 暂不采用 |
| TSTE-Fig8 | TSTE Fig8 | cleanroom 说明认为可能是旧图或被 Fig9 替代，来源与用途需核对 | 保留为待核对候选 |
| MID-N4SID-Flow | N4SID 完整流程图 | 当前暂定 N4SID 不作为重点原理展开，因此完整流程图不作为优先入文图表 | 仅作为候选素材 |
| MID-Internal-Gains | 内部得热时序图 | 可能较细，未必服务主线 | 视篇幅决定 |
| DATA-Multiday | 多测试日稳健性补充数据 | 不是当前 TSTE 主图数据源，是否进入本科论文尚不确定 | 暂不优先 |

## 10. 当前缺失或待确认信息

当前图表池仍存在以下缺口：

1. `assets/figures/source/tste/`、`assets/figures/source/midterm/`、`assets/figures/working/` 和 `assets/figures/final/` 已建立，但 `working/` 与 `final/` 当前仍为空目录，尚未形成正式中文化图源文件。

2. TSTE 图表中文化版本尚未生成，后续需要从 Origin 原图修改或基于 Excel 重新绘制。

3. Fig12 和 Fig13 的成本口径尚未确认，尤其是 holding cost、net cost、noRevenue、revenue 是否进入正文的问题。

4. Fig8 是否仍有使用价值需要核对。

5. 中期报告/PPT 中的图表是否与最终 TSTE 主线一致，需要进一步筛选。

6. Dymola 模型图是否采用中期报告图、TSTE Fig1，还是重新整合为一张新的系统结构图，待确认。

7. N4SID 验证图与 TSTE Fig4、中期 Fig6 之间是否重复，需要后续取舍。

8. CQR 相关图可能来自 TSTE Fig4/Fig5/Fig14，也可能来自中期 PPT 第12—13页，后续需要确定哪几张最能服务正文。

9. 成本曲线图是当前优先级较高的候选结果图，但最终采用 Fig12、Fig13 的全部内容，还是仅保留典型小时成本曲线，需结合成本口径专题讨论后确认。

10. 是否需要新增技术路线图、备用能力层级图、CQR 风险约束流程图等示意图，待章节结构讨论后确定。

## 11. 后续使用方式

后续推进图表工作时，可按以下方式使用本文档：

1. 先从“重点候选”中筛选首批需要中文化或重画的图；
2. 对每一张拟入文图补充最终文件名、图源文件、数据来源和状态；
3. 对 TSTE 图优先核对 `research_materials/simulation/docs/02_论文图表数据对应关系.md` 与 `data/exports/导出Excel索引.md`；
4. 对中期图优先确认是否仍与最终研究主线一致；
5. 对新增示意图先画草图或说明逻辑，不直接写成已有成果；
6. 正式入文前再确定最终图号和图题。

本文档是候选图表池，不是最终图表清单。后续 Web GPT 仍可开放式提出新增图、合并图、删减图或重画图建议。

## 12. v0.1 阶段小结

v0.1 阶段的图表池以 TSTE 小论文图、cleanroom 导出数据和中期 Dymola/N4SID/CQR 图表为主要来源。

当前较强的候选图包括：

- 水-空气耦合 HVAC 系统结构图；
- Dymola 高保真模型结构或校核图；
- N4SID / CQR 预测区间与不确定性图；
- CQR 与 Gaussian 风险边界对比图；
- 协调策略与固定水侧或 air-only 基线对比图；
- 天然备用、最大可行备用、可信备用对比图；
- 工作点重构下的 Ts / ma / R 关系图；
- 不同备用水平下的风险传播与舒适边界图；
- 逐小时可信备用成本曲面或典型小时成本曲线；
- 置信度对可信备用能力的影响图。

这些图表当前都只是候选材料，不代表最终入文图表。后续应结合章节结构、成本口径、CQR 展开深度和图表重画工作继续筛选。

## 13. 第4章、第5章候选图表分配建议（候选 / 待确认）

本节只记录当前结构讨论下的候选分配建议，不代表最终入文图表，不确定最终图号。

### 13.1 第4章候选图表分配建议

- 4.1 水风耦合下风机功率基线重塑机理
  - 候选：`NEW-Workpoint-Mechanism`
  - 候选：`TSTE-Fig1`
  - 说明：以机理示意和系统耦合关系图为主，不放 TSTE 结果图 Fig.5、Fig.6、Fig.7、Fig.8。

- 4.2 备用容量约束下的运行点重构方法
  - 候选：`NEW-Tech-Route`
  - 候选：运行点重构流程图（待绘制）
  - 说明：以方法流程和变量/约束说明为主，不直接放仿真结果图。

- 4.3 可行备用域的策略对比与时变特征分析
  - 候选：`TSTE-Fig6`
  - 候选：`TSTE-Fig7`
  - 候选：`TSTE-Fig9`
  - 候选：`TSTE-Fig10`
  - 说明：当前建议第4章结果图集中在本节统一分析，且若使用 `TSTE-Fig7`，应重绘为突出 `R^{nat}` 与 `R^{max}` 的版本，弱化可信备用部分。

### 13.2 第5章候选图表分配建议

- 5.1 调频部署扰动下的可信判定与成本表征方法
  - 候选：`NEW-CQR-Risk-Constraint`
  - 候选：可信备用筛选判据说明表
  - 候选：成本口径说明表
  - 说明：本节以方法说明为主，不放主要结果图。

- 5.2 可信备用域收缩与成本供给特性分析
  - 候选：`TSTE-Fig9`
  - 候选：`TSTE-Fig10`
  - 候选：`TSTE-Fig11`
  - 候选：`TSTE-Fig12`
  - 候选：`TSTE-Fig13`
  - 候选：`TSTE-Fig14`
  - 说明：`TSTE-Fig14` 当前仅作为可选补充；成本曲线相关图仍受成本口径确认影响。
