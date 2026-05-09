# Changelog

## 0.1.0-beta.5 — 2026-05-09

### 修复
- 修复 `TickerMode.valuesOf` 仅在新版 Flutter SDK 可用导致 GitHub Actions `Flutter 3.38.9` Android release 构建失败的问题。
- 保持本机新版 Flutter analyzer 零 issue，同时兼容 CI 固定 SDK。

## 0.1.0-beta.4 — 2026-05-09

### 修复
- 恢复 `tool/project_tasks.dart native:prepare` 任务，修复 `tool/flutterw.dart` 在 Android / Linux build 前调用缺失任务导致 CI 以 64 退出的问题。
- 为 Android target platform 参数增加校验，保证三架构 APK 构建流程能进入实际 Flutter / Gradle 阶段。

## 0.1.0-beta.3 — 2026-05-09

### 修复
- 修复 GitHub Actions 发版 workflow 中 Telegram 多行通知文本的 YAML 解析问题。
- 重新触发预发布构建与 GitHub Release 发布流程。

## 0.1.0-beta.2 — 2026-05-09

### 变更
- 修正应用内源码、反馈、更新检查与发版脚本中的 GitHub 仓库地址为 `Akuma-real/fluxseek`。
- 清理残留的 Linux.do / fluxdo 命名：登录按钮、NodeSeek CDK 文案、能力开关、CLI 环境变量与 Linux CMake 变量。
- 将 enhanced cookie jar 示例和测试域名切换到 NodeSeek 场景。

### 质量
- 清理 `lib/` 下 analyzer info 级问题，让 `just analyze lib/` 达到零 issue。
- 更新 WebView 下载回调到 `onDownloadStarting`，适配 flutter_inappwebview 新 API。
- 修复图片菜单异步回调后的 `BuildContext` 使用检查。
- 更新 `TickerMode`、Dropdown 初始值、null-aware collection 等 Flutter / Dart 新版本推荐写法。

## 0.1.0-beta.1 — 2026-05-09

fluxseek 第一个公开 beta 版本。NodeSeek 非官方第三方客户端。

### 核心功能
- 话题浏览（首页 / 分类 / 搜索），按发帖时间从新到旧排序
- 话题详情、分页加载、楼层跳转
- 回复 / 发帖 / 编辑 / 删除（区分楼主帖和评论）
- 点赞 / 踩 / 投鸡腿 / 收藏 / 置顶评论
- 关注 / 取关 / 粉丝 / 关注列表 / 黑名单
- 私信会话列表、会话详情、收发私信
- @ 我 / 回复我 / 私信 三通道通知（合并渲染 + 批量已读）
- 用户资料、登录历史、Telegram 绑定、鸡腿明细
- 邀请码列表 + 购买（扣鸡腿强确认流程）
- Stardust 流水、转账预检、发送
- 偏好读写、自定义 CSS 读写
- 签到 / 签到排行榜 / 今日额度
- 头像上传、简介 / 签名 / README 编辑
- 书签 / 浏览历史 / 草稿

### NodeSeek 专属适配
- 认证 Cookie 为 `session`（兼容旧 `_t` 回退路径）
- 写操作使用 `x-csrf-challenge: simple-token` 静态 header
- 贴图（sticker）系统：`:xhj003:` / `:ac01:` / `:yct015:` / `:emoji00:` 短码渲染，
  对齐网页端 `max-width: 90px; vertical-align: middle;` 的内联样式
- 14 个官方分类，IconPark 图标
- SSR `unViewedCount` 映射到未读通知计数
- 帖子列表 SSR HTML DOM 解析 + `rotateTopics` 置顶区 hydration

### 技术栈
- Flutter + Riverpod
- Dio + Native Dio Adapter + WebView HTTP fallback
- flutter_widget_from_html + flutter_inappwebview
- shared_preferences + flutter_secure_storage
- slang 本地化（中文简 / 繁 / 港 / 英文）
