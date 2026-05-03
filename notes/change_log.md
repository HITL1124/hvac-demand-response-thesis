# 变更记录

## 记录

| 日期 | 分支 | 变更摘要 | 原因 | 受影响文件 | 后续事项 |
| --- | --- | --- | --- | --- | --- |
| 2026-05-03 | init/repository-structure | 初始化仓库目录、项目指导、工作流说明和占位记录文件。 | 在论文写作开始前建立基础工作流和源文件组织方式。 | README.md; AGENTS.md; .gitignore; notes/; thesis_source/; references/; figures/; tables/; exports/; scripts/; requirements/; style_samples/; journal_paper/; research_materials/ | 上传学校要求、源论文材料、样本文献和已验证研究材料。 |
| 2026-05-03 | docs/localize-initial-guidance-to-chinese | 将初始化阶段创建的说明性 Markdown 文件本地化为中文。 | 让仓库规则、模板和工作流说明更适合中文毕业论文协作使用。 | README.md; AGENTS.md; thesis_source/README.md; notes/; journal_paper/notes.md; research_materials/simulation_notes.md; references/ | 后续继续上传真实材料，不在本次变更中补写论文正文或学术内容。 |
| 2026-05-03 | test/export-chain | 进行 Markdown -> Word/PDF 导出链路最小化测试，并生成测试导出文件。 | 验证仓库是否具备从 Markdown 源文件导出测试用 Word/PDF 的最小链路。 | thesis_source/export_test.md; notes/export_chain_test.md; exports/latest/test_export.docx; exports/latest/test_export.pdf | 后续补装 Pandoc 后可复测主链路，并在 CI 中增加导出检查。 |
