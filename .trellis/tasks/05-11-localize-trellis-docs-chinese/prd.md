# 将面向 Trellis 的文档本地化为中文

## 目标

在不改变 Trellis 运行时行为的前提下，让面向 Trellis 的项目指导文档可用中文阅读。

## 已知信息

* 用户要求将 Trellis 相关内容改为中文。
* 用户明确排除 Python 脚本，不纳入本次修改。
* `AGENTS.md` 已包含项目级指令：与用户沟通时使用中文。
* Trellis 本地架构包含 `.trellis/` 文档，以及 `.agents/skills/` 等平台/共享 skill 文件。

## 需求

* 将面向 Trellis 的 Markdown 指导文档翻译或改写为中文。
* 纳入 `.agents/skills/**` 下的共享本地 skill 文档，包括 `SKILL.md` 和引用的 Markdown 文件。
* 不修改 Python 脚本或运行时实现逻辑。
* 行为依赖的 commands、file paths、code fences、placeholders、workflow-state tags 和 machine-readable examples 必须保持有效。
* 除非用户明确要求，task 历史记录和 workspace journals 不在本次范围内。
* 保留原有含义和操作指令；这是本地化，不是 workflow 重新设计。
* 后续新建或更新的 PRD 应使用中文；涉及 PRD 创建/更新的 Trellis workflow、brainstorm/start skill 文档和模板都应明确这一点。
* `.opencode` 下的 Trellis 相关 Markdown 也纳入本次本地化范围，包括 `.opencode/skills/**/*.md`、`.opencode/agents/trellis-*.md` 和 `.opencode/commands/trellis/**/*.md`。

## 验收标准

* [ ] 当前面向 Trellis、用于持续 AI/用户指导的 Markdown 文件为中文，包括 `.agents/skills/**` 文档。
* [ ] `.opencode/skills/**/*.md`、`.opencode/agents/trellis-*.md` 和 `.opencode/commands/trellis/**/*.md` 中的 Trellis 指导内容已本地化为中文。
* [ ] 未来 PRD 的创建/更新说明和模板明确要求使用中文。
* [ ] `AGENTS.md` 中“与用户沟通时使用中文。”这一要求没有被弱化或丢失。
* [ ] `.py` 文件未被修改。
* [ ] 历史归档 task PRD 和 workspace journals 未被修改。
* [ ] Workflow-state tags 和 command examples 仍然有效。
* [ ] 轻量验证确认没有 Python 文件变更，且文档没有明显 malformed Markdown。

## 完成定义

* 变更已由 `trellis-check` 审查。
* 工作通过 Trellis workflow 提交。
* finish-work 后 git working tree 干净。

## 技术方案

翻译项目本地、作为当前指导使用的 Trellis Markdown，包括 `.trellis/workflow.md`、`.trellis/spec/**/*.md`，以及 `.agents/skills/**` 下的共享/本地 skill `SKILL.md` 与 reference docs。避免修改生成的 runtime/history 文件。补充本轮用户要求后，也检查并本地化 `.opencode` 下的 Trellis skill、agent 和 command Markdown。

## 不在范围内

* `.trellis/scripts/**/*.py` 和其他可执行 runtime implementation 文件。
* `.trellis/tasks/archive/**` 历史 task 记录。
* `.trellis/workspace/**` journals 和 session memory。
* 修改应用代码或 Flutter/Dart 行为。
* runtime state、JSON/JSONL machine files，以及非 Trellis 的无关文件。

## 技术备注

* `.trellis/spec/tooling/index.md` 说明 tooling 工作应在适用时使用 `just` wrappers。
* `trellis-meta` reference 将 `.trellis/`、platform directories 和 `.agents/skills/` 识别为本地 Trellis 自定义目标。
* 用户确认 `.agents/skills/**` 应纳入范围。
* 用户追加要求 `.opencode` Trellis 相关 Markdown 也纳入范围。
