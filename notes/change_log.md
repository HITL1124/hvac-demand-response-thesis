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
| 2026-05-07 | docs/import-simulation-cleanroom | 仿真 cleanroom 导入 | 否 | .gitattributes; research_materials/simulation/; research_materials/simulation_notes.md; notes/change_log.md | 将 `99-paper-sim-cleanroom` 主线整理版整体导入 `research_materials/simulation/`，并使用 Git LFS 管理 simulation 下的 `.mat` 文件。 | 是，本分支完成后 push 并创建 PR | 是 | 后续如需导入补充实验或历史归档，应单独确认范围；如需复现实验运行，应另行验证路径和运行环境。 |
| 2026-05-07 | docs/update-writing-workflow | 写作流程文档升级 | 否 | notes/writing_workflow.md; notes/change_log.md | 将 `notes/writing_workflow.md` 升级为可长期参考的执行版工作流说明，明确 Web GPT、作者、Codex、GitHub 与导出审阅的闭环流程、任务模板和审阅规则。 | 是，本分支完成后 push 并创建 PR | 是 | 作者审阅后决定是否合并；后续如新增材料盘点模板，可补充 `notes/material_inventory.md`。 |
