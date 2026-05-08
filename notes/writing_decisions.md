# 写作决策记录

## 决策日志

| 日期 | 主题 | 决策 | 原因 | 确认人 | 相关文件 | 状态 | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-05-08 | 章节结构 v0.2 | 采用 5 章结构：绪论；商业建筑 HVAC 系统建模与风机功率基线形成机理；面向动态需求响应的建筑热动态预测与不确定性表征；基于工作点重构与部署可信筛选的 HVAC 备用能力评估方法；仿真结果与可信备用成本分析。 | 该结构将研究背景、系统机理、热动态预测与不确定性、备用能力评估方法、仿真与成本分析分开，便于避免第2章和第4章重复。 | 作者 | thesis_source/chapters/; notes/project_scope.md; notes/paper_to_thesis_mapping.md; notes/figure_registry.md | 已记录 | 当前结构仍是章节模板，不是最终正式目录。 |
| 2026-05-08 | 第1章结构 | 第1章不设置“本章小结”。 | 绪论主要负责提出问题、综述现状和说明全文安排，不作为论文主体分析章。 | 作者 | thesis_source/chapters/chapter_01_introduction.md | 已记录 | 后续正文写作仍需按学校要求组织绪论。 |
| 2026-05-08 | 第2章结构 | 第2章先讲 HVAC 系统结构、机理模型和风机功率基线形成，再讲 Dymola 高保真模型。 | 避免一开始写成 Dymola 软件介绍，突出研究对象和水-空气耦合机理。 | 作者 | thesis_source/chapters/chapter_02_hvac_modeling_baseline.md | 已记录 | Dymola 是模型和数据基础，不是论文唯一核心方法。 |
| 2026-05-08 | 第3章命名 | 第3章命名为“面向动态需求响应的建筑热动态预测与不确定性表征”。 | 该章负责 N4SID 热动态预测、CQR 温度不确定性和风险收紧舒适约束，为第4章提供接口。 | 作者 | thesis_source/chapters/chapter_03_thermal_prediction_uncertainty.md | 已记录 | 本章不直接筛选可信备用。 |
| 2026-05-08 | 第4章命名与能力层级 | 第4章命名为“基于工作点重构与部署可信筛选的 HVAC 备用能力评估方法”；工作点重构主要对应最大可行备用能力，部署风险约束筛选对应可信备用能力。 | 明确最大可行备用与可信备用的边界，避免两者混写。 | 作者 | thesis_source/chapters/chapter_04_reserve_assessment.md | 已记录 | 第4章不重复第2章供水温度影响基线的机理。 |
| 2026-05-08 | 第5章成本分析 | 第5章将可信备用能力成本曲线单独成节，成本口径保持待确认。 | 成本曲线是结果分析重点，但 holding cost、net cost、noRevenue、revenue 等口径仍需专题确认。 | 作者 | thesis_source/chapters/chapter_05_simulation_cost_analysis.md | 已记录 | 后续写作前需确认成本口径和 TSTE 图表取舍。 |
