# 商业建筑 HVAC 系统动态需求响应

本仓库用于管理本科毕业论文《商业建筑 HVAC 系统动态需求响应》的写作材料、论文源文件、图表、参考文献、导出稿，以及围绕 **网页端 GPT × 本地 Codex × GitHub × Word/PDF** 搭建的协同写作流程。

这个仓库不是单纯的文件存放处，而是一个可持续维护的论文写作工作区。它的目标是让论文材料、写作决策、章节修改、版本记录和最终导出过程尽可能清晰、可追踪、可审阅、可回滚。

---

## 1. 项目定位

本毕业论文的研究方向是商业建筑 HVAC 系统参与电力系统动态需求响应和灵活性调度。

目前，相关研究工作已经基本完成，并已形成一篇准备投稿的 IEEE TSTE 英文小论文。该小论文是本毕业论文的重要技术基础，包含水-空气耦合 HVAC 系统、备用能力表征、运行点重构、可信备用域筛选、备用成本供给函数等核心研究内容。

本科毕业论文并不是英文小论文的简单中文翻译。两者在写作目标和表达方式上存在差异：

- 英文小论文强调创新点集中、篇幅压缩和结果精炼；
- 本科毕业论文需要更完整地展示研究背景、理论基础、建模过程、仿真设置、结果分析和工程意义；
- 小论文中的图表数量有限，毕业论文可以根据论证需要补充更多结果图、过程图和说明图；
- 小论文中未充分展开的材料，例如 Dymola 仿真平台、数据生成过程、N4SID 相关建模过程等，需要在后续写作中判断是否进入正文、附录或仅作为支撑材料保留。

因此，本仓库的核心任务是：

> 以已经完成的研究工作和 IEEE TSTE 小论文为基础，重新按照中文本科毕业论文的逻辑组织、扩写和打磨论文。

---

## 2. 工作方式

本仓库主要服务于以下工作方式：

1. **统一管理论文材料**
   包括英文小论文材料、仿真代码、候选图表、参考文献、学校模板、优秀论文样本等。

2. **以 Markdown 维护论文源文件**
   后续毕业论文正文尽量以 Markdown 文件维护，便于 GitHub 展示修改差异，也便于 Codex 稳定修改。

3. **用网页端 GPT 讨论和审阅**
   网页端 GPT 用于分析论文结构、章节逻辑、语言表达、图表证据链和写作风险，并帮助形成修改决策。

4. **用本地 Codex 执行确认后的修改**
   Codex 基于本地克隆仓库执行文件修改、整理目录、更新 notes、提交分支，并将修改推送到 GitHub。

5. **用 GitHub 管理版本**
   GitHub 的 `main` 分支保存当前稳定版本；每轮重要修改通过分支和 Pull Request 审阅后再合并。

6. **用 Word/PDF 做审阅和提交导出**
   Word/PDF 用于阶段性审阅、格式检查和最终提交，但不作为长期正文源文件。

---

## 3. 协同流程

本项目采用以下协同模式：

```text
网页端 GPT 读取 GitHub main 最新版本
        ↓
作者与 GPT 讨论结构、逻辑、语言和修改方向
        ↓
作者确认本轮修改目标和边界
        ↓
Codex 在本地仓库中 pull 最新 main
        ↓
Codex 创建本轮任务分支
        ↓
Codex 修改指定 Markdown / notes 文件
        ↓
Codex commit 并 push 到 GitHub
        ↓
作者通过 Pull Request / diff 审阅
        ↓
确认后 merge 到 main
        ↓
本地仓库 pull 最新 main，进入下一轮
```

可以概括为：

> Web GPT 负责讨论和审阅，作者负责判断和确认，Codex 负责本地执行和提交，GitHub 负责同步和版本管理。

---

## 4. 仓库目录说明

当前仓库采用以下长期目录结构。文件夹名和文件名使用英文，说明文档和论文正文主要使用中文。

```text
requirements/        学校要求、写作指南、格式范例和模板文件
style_samples/       可参考的优秀硕博论文样本
journal_paper/       IEEE TSTE 小论文材料，统一存放
research_materials/  仿真项目、Dymola 材料和研究过程记录
thesis_source/       毕业论文 Markdown 源文件
assets/              论文写作阶段使用的图表资产
references/          参考文献、中文文献候选和引用说明
notes/               项目范围、流程、映射、决策、审阅和变更记录
exports/             Word/PDF 审阅稿和提交稿
scripts/             导出、图表处理和辅助检查脚本
archive/             暂时不用但不确定是否可删除的历史文件
```

### `requirements/`

用于直接存放学校层面的写作要求、写作指南、格式范例和模板文件。

```text
requirements/
  <school-requirement-files>
```

这个目录回答的问题是：学校要求论文应该写成什么样、排版成什么样、提交什么格式。当前不再继续拆分子目录，避免学校文件层级过深。

### `style_samples/`

用于直接存放你认为值得参考的优秀硕士/博士论文样本。

```text
style_samples/
  <sample-thesis-files>
```

这些文件用于学习章节组织、中文学术表达、图表说明、结果分析和摘要/结论写法。这个目录不再按论文类型继续细分；后续从样本中提炼出的写作规则，应整理到 `notes/style_guide.md`。

### `journal_paper/`

用于统一存放已经完成或正在投稿准备中的 IEEE TSTE 小论文材料。

```text
journal_paper/
  notes.md      小论文材料说明
  <paper-files>
```

这个目录是毕业论文的重要技术基础，但毕业论文正文不应从这里逐句翻译生成。小论文材料不再强制按文件类型拆分；尤其是小论文中的表格主要跟随 LaTeX 源文件或论文材料本身管理，不单独建立表格子目录。

### `research_materials/`

用于存放研究过程中产生的仿真项目、Dymola 材料和研究过程记录。

```text
research_materials/
  simulation/    整理完成的仿真 cleanroom 项目
  dymola/        Dymola 平台、模型或原始导出材料
  progress_reports/  开题、中期、阶段汇报等研究过程材料
  simulation_notes.md
```

这个目录回答的问题是：论文中的模型、结果、图表和结论可以追溯到哪些代码、数据和仿真材料。

`progress_reports/` 用于存放中期报告、阶段汇报 PPT 等过程材料。这些材料用于追溯研究过程和辅助 `project_scope`、章节结构设计，但它们不是正文源文件，不能直接复制到 `thesis_source/`。

`simulation/` 应整体保留 cleanroom 项目的自包含结构，包括 `run/`、`export/`、`plot/`、`src/`、`data/`、`docs/`、`paper/`、`origin/`、`archive/` 等内部目录，不再按编程语言拆分。

### `thesis_source/`

用于存放毕业论文 Markdown 源文件。

```text
thesis_source/
  README.md
  front_matter/  中文摘要、英文摘要、关键词等前置部分
  chapters/      正文章节 Markdown 文件
  appendices/    附录材料
```

这是后续论文正文的主要维护位置。Word/PDF 中发现的内容问题，应回到这里的 Markdown 源文件中修改。

### `assets/`

用于管理论文写作阶段使用的图表资产。

```text
assets/
  figures/
    selected/      已确定进入毕业论文正文的图
    candidates/    仍在筛选中的候选图
    source_files/  可编辑图源文件
    exported/      已导出的图片文件
  tables/
    selected/      已确定进入毕业论文正文的表
    candidates/    仍在筛选中的候选表
```

如果某张图或某张表正式进入论文，应在 `notes/figure_registry.md` 中记录它的位置、作用、来源和支撑的论证内容。

### `references/`

用于管理参考文献。

```text
references/
  references.bib                       主参考文献 BibTeX 文件
  chinese_literature_candidates.md     中文文献候选清单
  citation_notes.md                    引用格式、文献筛选和引用说明
```

当前已有英文文献主要来自小论文工作。后续还需要补充中文文献，用于支撑国内外研究现状、工程背景和相关方法说明。

### `notes/`

用于存放项目过程文件，是整个仓库的“项目大脑”。

```text
notes/
  project_scope.md             项目范围、写什么、不写什么
  writing_workflow.md          工作流程说明
  thesis_positioning.md        毕业论文定位
  paper_to_thesis_mapping.md   小论文到毕业论文的内容映射
  figure_registry.md           图表候选、用途和证据链登记
  style_guide.md               写作规则
  writing_decisions.md         已确认的写作决策
  review_comments.md           Web GPT 或人工审阅意见
  change_log.md                仓库重要变更记录
  tooling/
    export_chain.md            Markdown 到 Word/PDF 的长期导出链路说明
```

这些文件不直接等于论文正文，但会长期影响正文写作。重要修改应同步记录到 `notes/change_log.md`。

### `exports/`

用于存放导出的 Word 和 PDF 文件。

```text
exports/
  review/       阶段性审阅稿
  submission/   最终提交稿
```

注意：

- `exports/` 中的文件不是正文源文件；
- Word/PDF 主要用于审阅、格式检查和最终提交；
- 如果在导出稿中发现内容问题，应回到 `thesis_source/` 中的 Markdown 修改；
- 纯格式问题可以在最终 Word 阶段处理。

### `scripts/`

用于存放辅助脚本。

```text
scripts/
  export/      Markdown 到 Word/PDF 的导出脚本
  figures/     图表处理、格式统一或批量导出脚本
```

这个目录不需要一开始就完善，可以在后续需要自动导出、图表处理或格式检查时逐步补充。

### `archive/`

用于存放暂时不用但不确定是否可以删除的旧文件、测试文件或历史结构文件。

```text
archive/
  old_structure/  旧目录结构或迁移前文件
  tests/          技术链路测试阶段遗留文件
  deprecated/     暂时不用但不确定是否删除的材料
```

原则是：不确定能不能删除的文件，优先移动到 `archive/`，不要直接删除。

---

## 5. 关键文件索引

- `AGENTS.md`
  Codex 执行任务时应遵守的项目规则，包括写作边界、Git 分支规则、禁止编造规则、文件组织规则等。

- `notes/writing_workflow.md`
  记录 Web GPT、Codex、本地仓库、GitHub 和 Word/PDF 的协作方式。

- `notes/project_scope.md`
  记录毕业论文的研究范围、材料边界、暂定内容和待确认问题。

- `notes/paper_to_thesis_mapping.md`
  记录 IEEE TSTE 小论文内容如何映射到本科毕业论文。

- `notes/figure_registry.md`
  记录候选图、入文图、图表来源、支撑结论和是否需要重画。

- `notes/style_guide.md`
  记录从学校写作指南和优秀学位论文样本中提炼出的写作规则。

- `notes/tooling/export_chain.md`
  记录 Markdown 到 Word/PDF 的长期导出链路、依赖工具和故障排查。

- `notes/change_log.md`
  记录仓库的重要修改、整理、迁移和阶段性变更。

---

## 6. 当前说明

本仓库仍处于持续整理和建设阶段。目录结构、notes 文件和写作流程会根据后续材料入库、学校要求、论文样本分析和实际写作需要继续调整。

仓库中的 Markdown 文件、notes 文件和导出稿应分别承担不同角色：

```text
Markdown 正文 = 内容源文件
notes = 过程记录和写作决策
Word/PDF = 审阅与提交文件
GitHub = 版本管理和同步中心
```
