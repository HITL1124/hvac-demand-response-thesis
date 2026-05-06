# 变更记录

## 记录

| 日期 | 分支/任务 | 变更类型 | 是否涉及正文 | 修改文件 | 修改摘要 | 是否已 push/PR | 是否需作者审阅 | 后续事项 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-05-03 | init/repository-structure | 仓库初始化 | 否 | README.md; AGENTS.md; .gitignore; notes/; thesis_source/; references/; figures/; tables/; exports/; scripts/; requirements/; style_samples/; journal_paper/; research_materials/ | 初始化仓库目录、项目指导、工作流说明和占位记录文件。 | 已 push/PR，已合并 | 已审阅 | 上传学校要求、源论文材料、样本文献和已验证研究材料。 |
| 2026-05-03 | docs/localize-initial-guidance-to-chinese | 文档本地化 | 否 | README.md; AGENTS.md; thesis_source/README.md; notes/; journal_paper/notes.md; research_materials/simulation_notes.md; references/ | 将初始化阶段创建的说明性 Markdown 文件本地化为中文。 | 已 push/PR，已合并 | 已审阅 | 后续继续上传真实材料，不在本次变更中补写论文正文或学术内容。 |
| 2026-05-03 | cleanup/restructure-repo | 仓库清理与重组 | 否 | README.md; AGENTS.md; notes/change_log.md; assets/; exports/; requirements/; research_materials/; scripts/ | 清理测试残留并重组仓库目录，使结构更适合长期毕业论文写作。 | 已 push/PR，已合并 | 已审阅 | 若后续需要导出链路记录，可在 notes 下新增长期工具链说明文件。 |
| 2026-05-03 | docs/align-readme-agents-workflow | 文档一致性修复 | 否 | README.md; AGENTS.md; notes/change_log.md; notes/tooling/export_chain.md; archive/.gitkeep | 对齐 README 与当前真实目录结构，更新 Codex Git 工作流和变更记录模板，并新增 Markdown 到 Word/PDF 长期导出链路说明模板。 | 是，本分支完成后 push 并创建 PR | 是 | 作者审阅 PR 后决定是否合并。 |
| 2026-05-05 | docs/align-readme-agents-workflow | 材料目录简化 | 否 | README.md; AGENTS.md; notes/change_log.md; research_materials/simulation_notes.md; requirements/; style_samples/; journal_paper/; research_materials/ | 简化学校材料、样本论文、小论文材料和研究材料目录说明，明确仿真 cleanroom 后续整体放入 `research_materials/simulation/`，Dymola 材料单独放入 `research_materials/dymola/`。 | 是，本分支完成后 push 并更新 PR #6 | 是 | 后续由作者整理完成 cleanroom 后再决定是否导入真实仿真文件。 |
| 2026-05-05 | docs/align-readme-agents-workflow | 学校要求材料入库 | 否 | README.md; AGENTS.md; notes/change_log.md; requirements/ | 删除空的学校要求和模板占位子目录，将学校要求、写作指南和书写范例文件直接纳入 `requirements/` 根目录管理。 | 是，本分支完成后 push 并更新 PR #7 | 是 | 作者审阅 PR 后决定是否合并。 |
| 2026-05-06 | docs/import-journal-paper-v31-assets | 期刊论文材料导入 | 否 | journal_paper/; notes/change_log.md | 将 `v31_TSTE.tex/pdf`、`tse_bibliography.bib` 和 `fig1` 到 `fig14` 主图文件导入 `journal_paper/` 根目录，并补充材料边界说明。 | 是，本分支完成后 push 并创建 PR | 是 | 后续如需补充 class 文件、参考文献目录或其他版本材料，应单独确认后再导入。 |
| 2026-05-06 | docs/import-dymola-d20241201-20250301 | Dymola 材料导入 | 否 | research_materials/dymola/; research_materials/simulation_notes.md; notes/change_log.md | 导入 `ASHP_guohe.mo`、`GuoHeV1/Project/data/20241201-20250301/` 和 `GuoHeV1/AHU/IntGains_perturbed.mat`，作为 `D20241201_20250301` 的最小直接依赖材料归档。 | 是，本分支完成后 push 并创建 PR | 是 | 如需在仓库内独立运行 Dymola 模型，后续需单独处理 `.mo` 中的绝对路径。 |
