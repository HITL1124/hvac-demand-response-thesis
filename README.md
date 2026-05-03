# HVAC 需求响应毕业论文仓库

本仓库用于支持本科毕业论文《商业建筑HVAC系统动态需求响应》的协同写作与材料管理。

当前仓库的作用是保存项目结构、工作流说明、写作规则、材料索引和后续论文 Markdown 源文件。这里不用于存放未经确认的学术结论、编造的数据或无法追溯的一次性修改。

## 工作模式

- 作者负责研究判断、写作取舍和最终确认。
- Web ChatGPT 用于讨论、审阅、提出修改建议和比较不同表达方案。
- Codex 根据已确认的要求修改仓库文件、维护目录结构并更新项目记录。
- GitHub 用于保存版本历史、分支工作和 Pull Request 审阅。

## 源文件规则

- Markdown 是论文内容和项目记录的主要源文件格式。
- 实质性论文写作应在 `thesis_source/` 下进行。
- Word 和 PDF 只作为审阅、提交或格式检查用的导出稿。
- 来自 Web ChatGPT、导师或人工审阅的意见，应回流到 Markdown 源文件或 `notes/` 记录中。

## 仓库区域

- `requirements/`：学校要求、模板和示例，其中 `school/`、`templates/`、`examples/` 按用途区分。
- `style_samples/`：用于学习写作风格的优秀论文或论文样本。
- `journal_paper/`：与 IEEE TSTE 论文及其图表、参考材料相关的文件。
- `research_materials/`：研究过程材料，其中 `code/`、`data/`、`figures/` 分别管理代码、数据和研究阶段图表。
- `thesis_source/`：后续论文 Markdown 源文档。
- `assets/`：论文资产目录，统一管理 `figures/` 和 `tables/`。
- `references/`：参考文献、候选文献和引用说明。
- `notes/`：项目范围、写作流程、决策、审阅意见和变更记录。
- `exports/`：后续生成的审阅稿或提交稿，其中 `review/` 和 `submission/` 按用途区分。
- `scripts/`：导出、图表处理等辅助脚本，对应 `export/` 和 `figures/`。

## 当前阶段

本仓库目前只包含初始化后的目录结构、工作流说明和项目规则。当前不包含论文正文、正式论文章节、最终论文大纲、学术结论、数据结果或已验证研究结论。
