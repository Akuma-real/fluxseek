# 重新中文化 Trellis 更新后的文档

## 目标

在 `trellis update` 更新本地 Trellis 文件后，恢复面向用户和 AI 的中文指导文案，同时保留 Trellis 更新带来的运行时代码和元数据改动。

## 已知信息

* 用户说明“trellis更新了”，要求“再次中文化”。
* 当前工作树已有大量 Trellis update 变更，包括 `.agents/skills/**`、`.opencode/**`、`.trellis/workflow.md`、`.trellis/scripts/**/*.py`、`.opencode/**/*.js`、`.trellis/.template-hashes.json`、`.trellis/.version` 和 `AGENTS.md`。
* 用户此前要求 Trellis 相关说明使用中文，但 Python 脚本等运行时逻辑不需要中文化。
* `AGENTS.md` 需要保留“与用户沟通时使用中文。”这类项目级中文沟通要求。

## 需求

* 将 Trellis update 后重新变成英文的 Markdown 指导文档、skill 文档、agent/command 文档和用户可见提示说明重新中文化。
* 范围包括 `AGENTS.md`、`.trellis/workflow.md`、`.agents/skills/**/*.md`、`.opencode/skills/**/*.md`、`.opencode/agents/trellis-*.md`、`.opencode/commands/trellis/**/*.md`。
* 保留 Trellis update 对 `.py`、`.js`、`.json`、`.template-hashes.json`、`.version` 等运行时/元数据文件的改动，不做中文化改写。
* 保留 commands、paths、code fences、frontmatter keys、workflow-state tags、JSON/YAML/TOML examples、placeholders、agent/skill IDs 等机器可读或协议性文本。
* 后续 PRD 创建/更新说明和模板仍应明确使用中文。
* 不修改历史归档任务、workspace journal 或应用业务代码。

## 验收标准

* [ ] Trellis 面向用户/AI 的当前 Markdown 指导文档恢复中文。
* [ ] `AGENTS.md` 保留明确中文沟通要求。
* [ ] PRD 创建/更新模板和流程说明明确要求中文。
* [ ] `.py`、`.js`、`.json`、`.trellis/.version`、`.trellis/.template-hashes.json` 未被本地化改写。
* [ ] 不修改 `.trellis/tasks/archive/**`、`.trellis/workspace/**` 或应用代码。
* [ ] `git diff --check` 通过。

## 完成定义

* 实现和检查子代理完成。
* 工作通过 Trellis workflow 提交。
* finish-work 后工作树干净，或仅剩用户明确保留的无关并行变更。

## 技术方案

先对当前 dirty paths 分类：Markdown 指导文档执行中文化；脚本/插件/元数据只保留 Trellis update 结果并在检查中确认没有被误改。完成后运行 lightweight checks，重点检查 diff 范围、机器可读 token 保留和 Markdown patch sanity。

## 不在范围内

* 修改 `.trellis/scripts/**/*.py` 或 `.opencode/**/*.js` 运行逻辑。
* 修改 `.trellis/.template-hashes.json`、`.trellis/.version` 等 Trellis 元数据。
* 修改历史 task archive、workspace journal。
* 修改 Flutter/Dart 应用功能代码。

## 技术备注

* `.trellis/spec/tooling/index.md` 要求优先使用 `just` 和 `tool/` 包装命令。
* `.trellis/spec/guides/index.md` 要求修改任何值前先搜索相关使用位置。
