# 执行计划

## 前置条件

* 用户已确认全历史重写。
* 用户已确认不保留任何 tags。
* 用户已确认删除远端 tags。
* 仍需用户最后确认允许 force push `main`。

## 步骤

1. 提交当前 task planning 文件，保证工作树干净。
2. 记录当前 `HEAD` 为 `OLD_HEAD`。
3. 创建备份分支：`backup/pre-history-rewrite-<timestamp>` 指向 `OLD_HEAD`。
4. 导出当前文件树快照或使用当前工作树作为最终目标内容。
5. 创建临时 orphan 分支并按设计中的 12 个语义提交构建新历史。
6. 将最终文件树恢复到与 `OLD_HEAD` 一致。
7. 验证 `git diff --exit-code OLD_HEAD new-head`。
8. 删除本地所有 tags。
9. 将 `main` 指向新历史。
10. 如用户最终确认远端落地：
    * 删除远端 tags：`git push origin :refs/tags/<tag>`。
    * Force push main：`git push --force-with-lease origin main`。
11. 验证远端状态。

## 禁止事项

* 未最终确认前，不 force push `main`。
* 未最终确认前，不删除远端 tags。
* 不改应用代码内容。
* 不丢失当前 `HEAD` 文件树。

## 回滚

* 本地回滚：将 `main` 指回 `backup/pre-history-rewrite-<timestamp>`。
* 远端回滚：如果已经 force push，需要用备份分支再次 force push；远端 tags 若已删除，需要从记录中重建。
