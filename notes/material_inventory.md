# 材料盘点

## 1. 文件定位

本文件用于记录当前仓库中已有材料、材料用途、后续写作价值和待补充事项。它不是论文正文，也不替代 `project_scope.md`、`paper_to_thesis_mapping.md` 或 `figure_registry.md`。

## 2. 总体结论

当前仓库的写作基础设施已经基本齐全，工作流说明、风格指南、导出链路说明、任务模板和变更记录均已入库。IEEE TSTE 小论文材料已经基本齐全，cleanroom 主线仿真材料、Dymola 基础材料以及中期阶段过程材料也已入库，可用于后续材料映射、图表证据链整理和结果追溯。

当前仍明显不足的部分主要是：风格样本尚未导入、中文文献候选仍待补充、若干写作控制文件仍处于模板阶段、正式章节结构和正文源文件尚未展开。基于现有材料，仓库已经可以进入 `project_scope.md` 讨论和 `paper_to_thesis_mapping.md` 梳理阶段。

## 3. 材料分类总表

| 材料类别 | 仓库位置 | 当前已有内容 | 后续用途 | 完整性判断 | 待补充事项 |
| --- | --- | --- | --- | --- | --- |
| 学校要求与模板 | `requirements/` | 3 个学校写作指南、书写范例与书写要求文件 | 用于格式要求核对和写作规范约束 | 基本齐全 | 后续如有学校正式模板，可继续补充 |
| 学位论文风格样本 | `style_samples/` | 当前仅有 `.gitkeep` 占位 | 用于 `style_guide.md` 和风格复核 | 明显不足 | 需补充优质硕博论文样本 |
| IEEE TSTE 小论文材料 | `journal_paper/` | `v31_TSTE.tex`、`v31_TSTE.pdf`、`tse_bibliography.bib`、`fig1` 到 `fig14`、`notes.md` | 用于材料映射、公式与图表追溯、英文文献基础整理 | 基本齐全 | 如需更多历史版本或配套文件，可后续补充 |
| 仿真代码与数据 | `research_materials/` | `simulation/` cleanroom 主线项目、`dymola/` 基础模型与数据、`simulation_notes.md` | 用于结果可追溯、图表候选、仿真设置说明和结果分析支撑 | 主线材料已入库 | 后续如需独立运行或补充更多配套材料，仍需进一步整理 |
| 阶段性研究过程材料 | `research_materials/progress_reports/` | 中期报告 `.doc` 和中期答辩 `.pptx` 已入库 | 用于补充 `project_scope`、Dymola/N4SID/CQR 定位、章节结构设计和完整工作量梳理 | 已形成基础材料 | 仍需由 Web GPT 提炼可参考内容边界 |
| 图表与候选图 | `assets/`、`journal_paper/`、`research_materials/` | `assets/` 仍为目录骨架；小论文图和仿真检查图已存在 | 用于后续轻量登记候选图和入文图表管理 | 部分具备基础 | 需补充 `assets/` 实际候选图表，并登记到 `figure_registry.md` |
| 参考文献 | `references/`、`journal_paper/` | `references.bib` 占位、中文文献候选说明、引用说明、`tse_bibliography.bib` | 用于中英文文献管理和引用决策记录 | 结构已建，内容不足 | 需补充中文文献候选和正式 bib 条目 |
| 论文正文源文件 | `thesis_source/` | `README.md` 与 `front_matter/`、`chapters/`、`appendices/` 占位目录 | 用于后续正式章节写作 | 仅有骨架 | 尚未进入正式章节写作 |
| 项目 notes | `notes/` | 已有工作流、风格指南、变更记录、任务模板和多个控制文件模板 | 用于范围控制、映射管理、图表登记、审阅与决策沉淀 | 基本齐全 | 若干控制文件仍待正式填充 |
| 导出链路 | `notes/tooling/`、`exports/`、`scripts/export/` | 导出链路说明模板、`exports/review` 与 `exports/submission` 占位目录、`scripts/export/` 占位目录 | 用于后续 Markdown 到 Word/PDF 的审阅和提交流程 | 结构已建 | 需继续验证并固化实际导出脚本 |
| 归档文件 | `archive/` | 当前仅有 `.gitkeep` | 用于未来保存不删除但暂不启用的历史材料 | 仅有占位 | 暂无必须补充内容 |

## 4. 学校要求与模板

`requirements/` 当前已包含 3 个学校相关文件：

- 本科毕业论文（设计）书写范例
- 本科毕业论文（设计）书写范例及书写指南
- 本科毕业论文（设计）写作指南（理工类）

这些材料后续主要用于格式要求核对、写作规范约束和最终导出稿自查，不需要在本文件中展开排版细节。

## 5. 学位论文风格样本

`style_samples/` 当前只有 `.gitkeep`，说明风格样本目录已经预留，但尚未实际导入参考样本。

这些材料后续应主要用于：

- 支撑 `notes/style_guide.md` 的持续完善
- 为章节语言风格、结构密度和表达习惯提供复核参照

当前这一类材料仍需补充。

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
- `progress_reports/`：已入库的中期报告和中期答辩PPT等阶段性研究过程材料

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

- `assets/`：当前有 `figures/` 和 `tables/` 的目录骨架，但尚无正式入库图表
- `journal_paper/`：已有 `fig1` 到 `fig14` 主图文件
- `research_materials/`：已有 cleanroom 检查图、导出图表材料，以及 Dymola 数据目录下的配套图表来源

这说明图表候选材料已经具备初步来源，但最终入文图、候选图和表格还没有统一登记。后续应通过轻量版 `notes/figure_registry.md` 管理候选图及其来源、用途和状态。

## 9. 参考文献材料

当前参考文献相关材料包括：

- `references/references.bib`：占位文件
- `references/chinese_literature_candidates.md`：中文文献候选说明模板
- `references/citation_notes.md`：引用说明模板
- `journal_paper/tse_bibliography.bib`：小论文英文 bib 基础

当前可以判断：

- 英文文献基础已经有一个可追溯起点
- 中文文献候选结构已经建立，但实质内容仍需补充
- 后续仍需要继续整理中文 literature candidates，并逐步形成正式引用清单

## 10. 论文正文源文件

`thesis_source/` 当前已有：

- `README.md`
- `front_matter/`
- `chapters/`
- `appendices/`

其中三个子目录目前都只有占位文件，没有正式章节 Markdown。这说明仓库仍处于章节结构设计前阶段，尚未进入正式正文写作阶段。

## 11. notes 控制文件状态

| 文件 | 当前状态 | 用途 | 是否需要优先补充 |
| --- | --- | --- | --- |
| `notes/style_guide.md` | 已有实质内容 | 长期写作风格指南与语言规则沉淀 | 否，后续按需要持续扩充 |
| `notes/writing_workflow.md` | 已有实质内容 | 记录 Web GPT、作者、Codex 与 GitHub 的执行闭环流程 | 否 |
| `notes/project_scope.md` | 已有模板，待填充 | 约束论文写什么、不写什么和开放问题 | 是 |
| `notes/paper_to_thesis_mapping.md` | 已有模板，待填充 | 梳理 TSTE 材料如何转化为本科论文材料 | 是 |
| `notes/figure_registry.md` | 已有模板，待填充 | 轻量登记候选图、来源、用途和状态 | 是 |
| `notes/change_log.md` | 已有实质内容 | 记录仓库重要变更 | 否 |
| `notes/tooling/export_chain.md` | 已有实质内容 | 记录 Markdown 到 Word/PDF 的导出链路说明 | 否，但后续需继续验证 |
| `notes/codex_task_template.md` | 已有实质内容 | 统一 Web GPT 向 Codex 交付任务的模板 | 否 |
| `notes/midterm_material_notes.md` | 已有实质内容 | 记录中期报告和中期答辩PPT与最终论文的关系 | 否，后续按讨论结果继续补充 |
| `notes/thesis_positioning.md` | 已有模板，待填充 | 记录论文定位、边界和开放问题 | 否，可在范围确认后再补 |
| `notes/writing_decisions.md` | 已有模板，待填充 | 记录已确认的写作决策 | 否，按实际任务逐步填充 |
| `notes/review_comments.md` | 已有模板，待填充 | 记录审阅意见与处理状态 | 否，按实际任务逐步填充 |

## 12. 当前仍缺或需要明确的内容

从材料管理角度看，当前仍需补充或明确的内容包括：

- `project_scope.md` 仍需正式填充
- `paper_to_thesis_mapping.md` 仍需正式填充
- `figure_registry.md` 仍需开始轻量登记
- `style_samples/` 仍需补充实际风格样本
- 中文参考文献候选仍需补充
- 中期材料需要进一步提炼为可用于最终论文的内容边界
- Dymola 材料虽已入库，但是否需要继续补充可独立运行所需配套文件仍待明确
- 最终章节结构尚未确定
- Word/PDF 导出链路仍需后续验证并固化

## 13. 建议下一步

1. Web GPT 基于 `material_inventory.md` 讨论 `project_scope.md`
2. Web GPT 基于 `journal_paper/` 和 `research_materials/` 讨论 `paper_to_thesis_mapping.md`
3. 轻量填充 `figure_registry.md`
4. 再进入章节结构设计

## 14. 注意事项

- 本文件只做材料盘点
- 本文件不作为技术结论
- 本文件不替代作者判断
- 本文件不用于直接生成论文正文
- 本文件不限制 Web GPT 后续开放式思考
