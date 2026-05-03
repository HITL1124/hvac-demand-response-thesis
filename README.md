# 商业建筑 HVAC 系统动态需求响应

本仓库用于管理本科毕业论文《商业建筑 HVAC 系统动态需求响应》的写作材料、论文源文件、图表、参考文献、导出稿，以及围绕 **网页端 GPT × 本地 Codex × GitHub × Word/PDF** 搭建的协同写作流程。

这个仓库不是单纯的文件存放处，而是一个可持续维护的论文写作工作区。它的目标是让论文材料、写作决策、章节修改、版本记录和最终导出过程尽可能清晰、可追踪、可审阅、可回滚。

---

## 1. 项目背景

本毕业论文的研究方向是商业建筑 HVAC 系统参与电力系统动态需求响应和灵活性调度。

目前，相关研究工作已经基本完成，并已形成一篇准备投稿的 IEEE TSTE 英文小论文。该小论文是本毕业论文的重要技术基础，包含水-空气耦合 HVAC 系统、备用能力表征、运行点重构、可信备用域筛选、备用成本供给函数等核心研究内容。

不过，本科毕业论文并不是英文小论文的简单中文翻译。两者在写作目标和表达方式上存在明显差异：

- 英文小论文强调创新点集中、篇幅压缩和结果精炼；
- 本科毕业论文需要更完整地展示研究背景、理论基础、建模过程、仿真设置、结果分析和工程意义；
- 小论文中的图表数量有限，而毕业论文可以根据论证需要补充更多结果图、过程图和说明图；
- 小论文中未充分展开的材料，例如 Dymola 仿真平台、数据生成过程、N4SID 相关建模过程等，需要在后续写作中判断是否进入正文、附录或仅作为支撑材料保留。

因此，本仓库的核心任务是：

> 以已经完成的研究工作和 IEEE TSTE 小论文为基础，重新按照中文本科毕业论文的逻辑组织、扩写和打磨论文。

---

## 2. 仓库核心诉求

本仓库主要服务于以下目标：

1. **统一管理论文材料**  
   包括英文小论文材料、仿真代码、候选图表、参考文献、学校模板、优秀论文样本等。

2. **支持 Markdown 源文件写作**  
   毕业论文正文后续尽量以 Markdown 文件维护，便于 GitHub 展示修改差异，也便于 Codex 稳定修改。

3. **支持网页端 GPT 审阅和讨论**  
   网页端 GPT 用于分析论文结构、章节逻辑、语言表达、图表证据链和写作风险，并帮助形成修改决策。

4. **支持本地 Codex 执行修改**  
   Codex 基于本地克隆仓库执行文件修改、整理目录、更新 notes、提交分支，并将修改推送到 GitHub。

5. **使用 GitHub 进行版本管理**  
   GitHub 的 `main` 分支保存当前稳定版本；每轮重要修改通过分支和 Pull Request 审阅后再合并。

6. **保留 Word/PDF 审阅与提交方式**  
   Word/PDF 用于阶段性审阅和最终提交，但不作为长期正文源文件。

---

## 3. 协同工作流概览

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

下面是本仓库建议采用的长期目录结构。文件夹名称使用英文，正文和 notes 内容主要使用中文。

### `requirements/`

用于存放学校层面的写作要求和格式材料。

建议内容包括：

```text
requirements/
  guidelines/    学校论文写作指南、格式说明、提交要求
  templates/     学校 Word 模板、封面模板、格式模板
  examples/      学校提供的范例论文或格式示例
```

这个目录回答的问题是：

> 学校要求论文应该写成什么样、排版成什么样、提交什么格式？

---

### `samples/`

用于存放可供学习的优秀论文样本。

建议内容包括：

```text
samples/
  theses/        优秀硕士/博士学位论文样本
  papers/        可参考的中文或英文论文样本
```

这些文件不是用来直接模仿或照搬的，而是用于帮助提炼：

- 学位论文的章节组织方式；
- 绪论和研究现状的展开方式；
- 图表说明和结果分析写法；
- 中文学术表达风格；
- 摘要、结论、章节过渡的常见写法。

后续从这些样本中提炼出的写作规则，应整理到 `notes/style_guide.md`。

---

### `paper/`

用于存放已经完成或正在投稿准备中的 IEEE TSTE 小论文材料。

建议内容包括：

```text
paper/
  pdf/           小论文 PDF 版本
  tex/           小论文 LaTeX 源文件
  figures/       小论文中使用过的图
  tables/        小论文中使用过的表
  refs/          小论文 BibTeX 或参考文献文件
  notes.md       小论文材料说明
```

这个目录是毕业论文的重要技术基础，但毕业论文正文不应直接从这里逐句翻译生成。

它主要用于支持：

- 小论文到毕业论文的内容映射；
- 技术主线梳理；
- 公式、图表、结果和参考文献的追溯；
- 判断哪些内容适合在毕业论文中扩展。

---

### `materials/`

用于存放研究过程中产生的原始材料、代码、数据和候选结果。

建议内容包括：

```text
materials/
  matlab/                MATLAB 代码
  python/                Python 代码
  dymola/                Dymola 平台相关材料
  data/                  原始数据或处理后数据
  candidate_figures/     候选结果图、补充图、未入小论文的图
  notes.md               材料说明
```

这个目录回答的问题是：

> 论文中的模型、结果、图表和结论可以追溯到哪些代码、数据和仿真材料？

其中，`candidate_figures/` 后续会和 `notes/figure_registry.md` 配合使用，用于判断每张图是否进入毕业论文正文，以及它支撑哪个结论。

---

### `thesis/`

用于存放毕业论文 Markdown 源文件。

建议内容包括：

```text
thesis/
  front_matter/    中文摘要、英文摘要、关键词等前置部分
  chapters/        正文章节 Markdown 文件
  appendices/      附录材料
```

这是后续论文正文的主要维护位置。

原则上：

- 正文内容写在这里；
- 每章可以单独维护为一个 `.md` 文件；
- 重要内容修改应通过 GitHub 分支和 PR 审阅；
- Word/PDF 中发现的内容问题，应回到这里修改。

---

### `figures/`

用于管理最终入文图和图源文件。

建议内容包括：

```text
figures/
  selected/      已确定进入毕业论文正文的图
  candidates/    仍在筛选中的候选图
  source/        可编辑图源文件，例如 Visio、绘图脚本或原始导出文件
```

这个目录和 `materials/candidate_figures/` 的区别是：

- `materials/` 更偏原始研究材料；
- `figures/` 更偏论文写作阶段的图表管理。

后续如果某张图正式进入论文，应从候选状态进入 `figures/selected/`，并在 `notes/figure_registry.md` 中记录它的位置、作用和支撑结论。

---

### `references/`

用于管理参考文献。

建议内容包括：

```text
references/
  references.bib             主参考文献 BibTeX 文件
  chinese_candidates.md      中文文献候选清单
  notes.md                   引用格式、文献筛选和引用说明
```

当前已有英文文献主要来自小论文工作。后续还需要补充一定数量的中文文献，用于支撑国内外研究现状、工程背景、需求响应、建筑负荷柔性、HVAC 建模与控制等内容。

---

### `notes/`

用于存放项目过程文件，是整个仓库的“项目大脑”。

建议内容包括：

```text
notes/
  project_scope.md             项目范围、写什么、不写什么
  workflow.md                  工作流程说明
  thesis_positioning.md        毕业论文定位
  paper_to_thesis_mapping.md   小论文到毕业论文的内容映射
  figure_registry.md           图表候选、用途和证据链登记
  style_guide.md               从学校指南和优秀论文中提炼出的写作规则
  writing_decisions.md         已确认的写作决策
  review_comments.md           Web GPT 或人工审阅意见
  change_log.md                仓库重要变更记录
```

这些文件不直接等于论文正文，但会长期影响正文写作。

例如：

- `project_scope.md` 决定论文边界；
- `paper_to_thesis_mapping.md` 决定小论文内容如何转化；
- `figure_registry.md` 决定图表如何进入正文；
- `style_guide.md` 决定中文学位论文的表达风格；
- `writing_decisions.md` 记录已经确认的写作选择。

---

### `exports/`

用于存放导出的 Word 和 PDF 文件。

建议内容包括：

```text
exports/
  latest/    阶段性导出的最新版 Word/PDF
  final/     最终提交版本
```

注意：

- `exports/` 中的文件不是正文源文件；
- Word/PDF 主要用于审阅、格式检查和最终提交；
- 如果在导出稿中发现内容问题，应回到 `thesis/` 中的 Markdown 修改；
- 纯格式问题可以在最终 Word 阶段处理。

---

### `scripts/`

用于存放辅助脚本。

建议内容包括：

```text
scripts/
  export/     Markdown 到 Word/PDF 的导出脚本
  figures/    图表处理、格式统一或批量导出脚本
```

这个目录不是一开始必须完善，可以在后续需要自动导出、图表处理或格式检查时逐步补充。

---

### `archive/`

用于存放暂时不用但不确定是否可以删除的旧文件、测试文件或历史结构文件。

建议内容包括：

```text
archive/
  old_structure/     旧目录结构或迁移前文件
  tests/             技术链路测试阶段遗留文件
  deprecated/        暂时不用但不确定是否删除的材料
```

原则是：

> 不确定能不能删的文件，优先移动到 `archive/`，不要直接删除。

---

## 5. 关键文档索引

本仓库中几个重要文档的作用如下：

- `AGENTS.md`  
  Codex 执行任务时应遵守的项目规则，包括写作边界、Git 分支规则、禁止编造规则、文件组织规则等。

- `notes/workflow.md`  
  记录本项目的具体工作流程，包括 Web GPT、Codex、本地仓库、GitHub 和 Word/PDF 的协作方式。

- `notes/project_scope.md`  
  记录毕业论文的研究范围、材料边界、暂定内容和待确认问题。

- `notes/paper_to_thesis_mapping.md`  
  记录 IEEE TSTE 小论文内容如何映射到本科毕业论文。

- `notes/figure_registry.md`  
  记录候选图、入文图、图表来源、支撑结论和是否需要重画。

- `notes/style_guide.md`  
  记录从学校写作指南和优秀学位论文样本中提炼出的写作规则。

- `notes/writing_decisions.md`  
  记录作者和 Web GPT 已经确认的重要写作决策。

- `notes/change_log.md`  
  记录仓库的重要修改、整理、迁移和阶段性变更。

---

## 6. 使用方式简述

本仓库后续主要按照以下方式使用：

1. 将论文相关材料放入合适目录；
2. 由 Web GPT 基于 GitHub 最新版本进行讨论和审阅；
3. 作者确认本轮修改方向；
4. Codex 在本地仓库中创建分支并执行修改；
5. Codex push 到 GitHub；
6. 作者通过 PR 或 diff 审阅修改；
7. 确认后 merge 到 `main`；
8. 本地仓库 pull 最新 `main`，进入下一轮。

详细规则和执行边界请参考 `AGENTS.md` 与 `notes/workflow.md`。

---

## 7. 当前说明

本仓库仍处于持续整理和建设阶段。目录结构、notes 文件和写作流程会根据后续材料入库、学校要求、论文样本分析和实际写作需要继续调整。

仓库中的 Markdown 文件、notes 文件和导出稿应分别承担不同角色：

```text
Markdown 正文 = 内容源文件
notes = 过程记录和写作决策
Word/PDF = 审阅与提交文件
GitHub = 版本管理和同步中心
```
