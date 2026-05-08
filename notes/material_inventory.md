# 材料盘点

## 1. 文件定位

本文件用于记录当前仓库中已有材料、材料用途、后续写作价值和待补充事项。它不是论文正文，也不替代 `project_scope.md`、`paper_to_thesis_mapping.md` 或 `figure_registry.md`。

## 2. 总体结论

当前仓库的写作基础设施已经基本齐全。工作流说明、风格指南、导出链路说明、任务模板、材料盘点、范围控制、材料映射和图表候选池均已入库；`project_scope.md`、`paper_to_thesis_mapping.md`、`figure_registry.md` 已形成 v0.1；`thesis_source/chapters/` 下已建立 5 个章节模板。

小论文材料、cleanroom 主线仿真材料、Dymola 基础材料、中期阶段过程材料和学位论文风格样本也已入库，可用于后续正文写作、图表筛选、结果追溯和风格复核。基于当前状态，仓库已经具备进入逐章逐节正式正文写作的条件。

当前尚未完成的主要内容包括：正式正文逐节写入、中文文献候选补充、部分术语和成本口径确认、图表最终取舍与中文化、以及 Word/PDF 导出链路实测和固化。中文文献候选仍需补充，但当前不阻塞第 2—5 章技术章节初稿写作。

## 3. 材料分类总表

| 材料类别 | 仓库位置 | 当前已有内容 | 后续用途 | 完整性判断 | 待补充事项 |
| --- | --- | --- | --- | --- | --- |
| 学校要求与模板 | `requirements/` | 3 个学校写作指南、书写范例与书写要求文件 | 用于格式要求核对和写作规范约束 | 基本齐全 | 后续如有学校正式模板，可继续补充 |
| 学位论文风格样本 | `style_samples/` | 已导入 17 篇样本 PDF，并维护 `style_samples/README.md` | 用于 `style_guide.md` 和风格复核 | 已形成较完整的基础样本集 | 后续可按需要继续补充样本，并沉淀长期规则到 `notes/style_guide.md` |
| IEEE TSTE 小论文材料 | `journal_paper/` | `v31_TSTE.tex`、`v31_TSTE.pdf`、`tse_bibliography.bib`、`fig1` 到 `fig14`、`notes.md` | 用于材料映射、公式与图表追溯、英文文献基础整理 | 基本齐全 | 如需更多历史版本或配套文件，可后续补充 |
| 仿真代码与数据 | `research_materials/` | `simulation/` cleanroom 主线项目、`dymola/` 基础模型与数据、`simulation_notes.md` | 用于结果可追溯、图表候选、仿真设置说明和结果分析支撑 | 主线材料已入库 | 后续如需独立运行或补充更多配套材料，仍需进一步整理 |
| 阶段性研究过程材料 | `research_materials/progress_reports/` | 中期报告 `.doc` 和中期答辩 `.pptx` 已入库 | 用于补充 `project_scope`、Dymola/N4SID/CQR 定位、章节结构设计和完整工作量梳理 | 已形成基础材料 | 仍需由 Web GPT 提炼可参考内容边界 |
| 图表与候选图 | `assets/`、`journal_paper/`、`research_materials/`、`notes/figure_registry.md` | 已建立 `assets/figures/source/tste/`、`assets/figures/source/midterm/`、`assets/figures/working/`、`assets/figures/final/`；TSTE 小论文图表素材已复制到 `assets`；中期图表绘制文件夹中的已识别图和可编辑源文件已复制到 `assets`；`figure_registry.md` 已形成轻量候选图表池 | 用于后续筛选首批入文图、追踪来源、组织中文化和重画工作 | 候选池与素材目录已建立，最终入文图尚未形成 | 部分中期图表用途仍需作者确认；`working/` 和 `final/` 当前仍为空或待后续生成；后续需随正文写作筛选首批入文图 |
| 参考文献 | `references/`、`journal_paper/` | `references.bib` 占位、中文文献候选说明、引用说明、`tse_bibliography.bib` | 用于中英文文献管理和引用决策记录 | 结构已建，英文基础已有 | 中文文献候选仍需补充，但当前可先进入第 2—5 章技术内容初稿写作；第 1 章正式写作前应补充中文文献 |
| 论文正文源文件 | `thesis_source/` | `thesis_source/README.md` 已有；`thesis_source/chapters/` 下已创建五个章节模板；章节模板已明确各章功能、主线、输入材料、候选图表、待写内容、待确认问题和写作边界 | 用于后续逐章逐节正式正文写作 | 章节模板已建立，正式正文尚未逐节写入 | 后续按写作闭环逐节推进正文内容 |
| 项目 notes | `notes/` | `project_scope.md`、`paper_to_thesis_mapping.md`、`figure_registry.md` 已形成 v0.1；`writing_workflow.md`、`style_guide.md`、`material_inventory.md`、`midterm_material_notes.md` 等已有实质内容；`writing_decisions.md` 本次补充关键决策 | 用于范围控制、映射管理、图表登记、决策沉淀和审阅协同 | 基本齐全 | 后续仍需随正文写作持续维护 |
| 导出链路 | `notes/tooling/`、`exports/`、`scripts/export/` | 导出链路说明模板、`exports/review` 与 `exports/submission` 目录、`scripts/export/` 占位目录 | 用于后续 Markdown 到 Word/PDF 的审阅和提交流程 | 结构已建 | 仍需继续验证并固化实际导出脚本与实测链路 |
| 归档文件 | `archive/` | 当前仅有 `.gitkeep` | 用于未来保存不删除但暂不启用的历史材料 | 仅有占位 | 暂无必须补充内容 |

## 4. 学校要求与模板

`requirements/` 当前已包含 3 个学校相关文件：

- 本科毕业论文（设计）书写范例
- 本科毕业论文（设计）书写范例及书写指南
- 本科毕业论文（设计）写作指南（理工类）

这些材料后续主要用于格式要求核对、写作规范约束和最终导出稿自查，不需要在本文件中展开排版细节。

## 5. 学位论文风格样本

`style_samples/` 当前已纳入：

- `style_samples/README.md`
- `quadrotor_control_system_jiang_2014.pdf`
- `high_power_high_speed_pmsm_xu_2024.pdf`
- `grid_forming_energy_storage_frequency_support_zheng_2025.pdf`
- `controllable_commutation_freewheeling_bldcm_wei_2016.pdf`
- `cnn_bearing_fault_diagnosis_zhang_2017.pdf`
- `data_model_driven_converter_admittance_identification.pdf`
- `predictive_pmsm_fast_response_servo_control_li_2024.pdf`
- `renewable_uncertainty_power_system_risk_assessment_zhang_2025.pdf`
- `renewable_station_storage_market_li_2025.pdf`
- `dab_single_stage_dc_ac_pv_microinverter_control_strategy.pdf`
- `multi_condition_pmsm_electrical_parameter_identification.pdf`
- `intelligent_vehicle_local_trajectory_planning_tracking_control.pdf`
- `pmsm_high_frequency_signal_injection_sensorless_low_speed_control.pdf`
- `vpp_multi_timescale_optimal_dispatch_with_power_energy_balance.pdf`
- `high_precision_servo_system_for_mechatronic_joints.pdf`
- `presubmission_thesis_sample_23s130524.pdf`
- `presubmission_thesis_sample_23s130526.pdf`

这些样本后续主要用于：

- 支撑 `notes/style_guide.md` 的持续完善；
- 为章节语言风格、结构密度、摘要组织、文献综述逻辑、结果分析表述和结论写法提供形式层面的复核参照。

需要强调的是，这些样本只用于形式参考，不复用其中的具体研究内容、数据、图表、结论或原创观点。

## 6. IEEE TSTE 小论文材料

`journal_paper/` 当前已纳入：

- `v31_TSTE.tex`
- `v31_TSTE.pdf`
- `tse_bibliography.bib`
- `fig1` 到 `fig14` 主图文件
- `notes.md`

这些材料后续可用于：

- 小论文到本科论文的材料映射
- 公式、模型、图表和英文参考文献的追溯
- 为 `paper_to_thesis_mapping.md` 提供输入材料

需要强调的是，这些材料不能直接作为本科论文正文翻译来源，只能作为映射、核对和追溯材料。

## 7. 仿真代码、数据与结果材料

`research_materials/` 当前主要包含三部分：

- `simulation/`：已入库的 cleanroom 主线仿真项目，包含 `README.md`、`run/`、`export/`、`plot/`、`src/`、`data/`、`docs/` 和根路径脚本
- `dymola/`：已入库的 Dymola 基础材料，包含 `ASHP_guohe.mo`、`GuoHeV1/Project/data/20241201-20250301/` 和 `GuoHeV1/AHU/IntGains_perturbed.mat`
- `progress_reports/`：已入库的中期报告和中期答辩 PPT 等阶段性研究过程材料

其中 `simulation/` 目录下已经有：

- 仿真运行脚本
- 导出脚本
- 绘图脚本
- 原始数据、处理中间数据和结果数据
- 按图号分组的导出 Excel
- 仿真说明、数据清单和验证记录

这些材料后续主要用于：

- 结果可追溯
- 图表候选
- 仿真设置说明
- 结果分析支撑

本文件只做盘点，不运行代码，不分析数值结论，不评价技术内容。

## 8. 图表与候选图材料

与图表相关的材料目前分散在三处：

- `assets/`：已建立 `assets/figures/source/tste/`、`assets/figures/source/midterm/`、`assets/figures/working/` 和 `assets/figures/final/`
- `journal_paper/`：已有 `fig1` 到 `fig14` 主图文件，且当前已复制一份到 `assets/figures/source/tste/`
- `research_materials/`：已有 cleanroom 检查图、导出图表材料，以及 Dymola 数据目录下的配套图表来源

此外，`notes/figure_registry.md` 已形成轻量候选图表池，初步登记了：

- TSTE 图
- cleanroom 导出数据对应图
- 中期报告 / PPT 候选图
- 可能需要新增绘制的示意图和流程图

此外，本次已从本地中期图表绘制文件夹复制一批已识别图表素材和可编辑源文件到 `assets/figures/source/midterm/`，并将暂时无法稳妥归类的文件放入 `assets/figures/source/midterm/unclassified/`，等待作者后续确认用途。

当前图表候选池和素材目录已经建立，但：

- 尚未形成最终入文图；
- `assets/figures/working/` 和 `assets/figures/final/` 当前仍为空或待后续生成；
- 图表中文化、重画和最终取舍仍需随章节写作推进。

## 9. 参考文献材料

当前参考文献相关材料包括：

- `references/references.bib`：占位文件
- `references/chinese_literature_candidates.md`：中文文献候选说明模板
- `references/citation_notes.md`：引用说明模板
- `journal_paper/tse_bibliography.bib`：小论文英文 bib 基础

当前可以判断：

- 英文文献基础已经有一个可追溯起点
- 中文文献候选结构已经建立，但实质内容仍需补充
- 中文文献候选仍需补充，但当前可先进入第 2—5 章技术章节初稿写作
- 第 1 章绪论和国内外研究现状正式写作前，应集中补充中文文献

## 10. 论文正文源文件

`thesis_source/` 当前已有：

- `README.md`
- `front_matter/`
- `chapters/`
- `appendices/`

其中 `thesis_source/chapters/` 已创建以下五个章节模板：

- `thesis_source/chapters/chapter_01_introduction.md`
- `thesis_source/chapters/chapter_02_hvac_modeling_simulation.md`
- `thesis_source/chapters/chapter_03_thermal_prediction_uncertainty.md`
- `thesis_source/chapters/chapter_04_reserve_assessment.md`
- `thesis_source/chapters/chapter_05_simulation_cost_analysis.md`

需要明确的是：

- 当前这些文件仍是章节模板，不是正式正文；
- 但已经可以作为逐节写作的直接入口；
- 后续写作应按 “Web GPT 讨论 -> 作者确认 -> Codex 执行前审阅 -> Codex 写入 -> PR 审阅 -> 合并” 的闭环推进。

## 11. notes 控制文件与章节模板状态

| 文件 | 当前状态 | 用途 | 是否需要优先补充 |
| --- | --- | --- | --- |
| `notes/style_guide.md` | 已有实质内容，且已扩展为更完整的长期写作风格指南 | 长期写作风格指南与语言规则沉淀 | 否，后续按需要持续扩充 |
| `notes/writing_workflow.md` | 已有实质内容 | 记录 Web GPT、作者、Codex 与 GitHub 的执行闭环流程 | 否 |
| `notes/project_scope.md` | 已有 v0.1 实质内容，后续随写作迭代 | 约束论文写什么、不写什么和开放问题 | 否，后续持续维护 |
| `notes/paper_to_thesis_mapping.md` | 已有 v0.1 实质内容，后续随章节写作迭代 | 梳理 TSTE 材料如何转化为本科论文材料 | 否，后续持续维护 |
| `notes/figure_registry.md` | 已有 v0.1 候选图表池，后续需随正文筛选入文图 | 轻量登记候选图、来源、用途和状态 | 否，后续持续维护 |
| `notes/change_log.md` | 已有实质内容 | 记录仓库重要变更 | 否 |
| `notes/tooling/export_chain.md` | 已有实质内容 | 记录 Markdown 到 Word/PDF 的导出链路说明 | 否，但后续需继续验证 |
| `notes/codex_task_template.md` | 已有实质内容 | 统一 Web GPT 向 Codex 交付任务的模板 | 否 |
| `notes/midterm_material_notes.md` | 已有实质内容 | 记录中期报告和中期答辩 PPT 与最终论文的关系 | 否，后续按讨论结果继续补充 |
| `notes/thesis_positioning.md` | 已有模板，待按需要补充 | 记录论文定位、边界和开放问题 | 否 |
| `notes/writing_decisions.md` | 本次补充关键写作决策，后续持续维护 | 记录已确认的写作决策 | 否，后续持续维护 |
| `notes/review_comments.md` | 已有模板，待按实际任务补充 | 记录审阅意见与处理状态 | 否 |
| `thesis_source/chapters/` | 已创建章节模板 | 作为逐章逐节正式写作的直接入口 | 是，下一步进入正文写作 |

## 12. 当前仍缺或需要明确的内容

从材料管理角度看，当前仍需补充或明确的内容包括：

- 正文各章节尚未逐节正式写入
- 中文文献候选仍需补充，但不阻塞技术章节初稿
- 成本曲线口径仍需专题确认
- Dymola 校核图和指标是否进入正文仍需确认
- N4SID、CQR 展开深度仍需随章节写作确认
- 图表中文化版本尚未生成
- `assets/` 中正式入文图仍待建立
- Word/PDF 导出链路仍需实测和固化

## 13. 建议下一步

1. 后续随正式写作持续维护 `notes/writing_decisions.md`
2. 进入逐章逐节正式写作
3. 每章按“章节启动检查—小节提纲—候选正文—作者确认—Codex 执行前审阅—Codex 写入—PR 审阅—合并”的闭环推进
4. 优先从第 2 章或第 3 章技术基础章节开始写作
5. 中文文献候选可后续补充，重点服务第 1 章绪论和文献综述
6. 随写作推进持续更新 `figure_registry.md`、`writing_decisions.md` 和 `change_log.md`

## 14. 注意事项

- 本文件只做材料盘点
- 本文件不作为技术结论
- 本文件不替代作者判断
- 本文件不用于直接生成论文正文
- 本文件不限制 Web GPT 后续开放式思考
