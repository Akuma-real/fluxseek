# AI 助手指引

本文件为 AI 编码助手（Kiro / Claude / Codex 等）提供项目上下文和工作流规范。

---

## 语言要求

- 必须使用中文与用户交流。所有回复、解释、提问均使用中文，代码注释和变量命名除外。

---

## 项目概述

**fluxseek** 是 [NodeSeek](https://www.nodeseek.com/) 的非官方第三方 Flutter 客户端。

- 代码基础来自 [Lingyan000/fluxdo](https://github.com/Lingyan000/fluxdo)（GPL-3.0）
- 目标站点：NodeSeek（非 Discourse，自研 SSR 论坛）
- 平台：Android（正式发布）+ Linux（开发调试）
- 仓库：[Akuma-real/fluxseek](https://github.com/Akuma-real/fluxseek)

---

## 技术栈

| 层 | 技术 |
|---|---|
| 框架 | Flutter 3.38+ (Dart 3.11+) |
| 状态管理 | Riverpod |
| HTTP | Dio + Native Dio Adapter + WebView HTTP adapter |
| HTML 渲染 | flutter_widget_from_html |
| WebView | flutter_inappwebview (全平台) |
| 本地化 | slang (ARB → 代码生成) |
| 持久化 | shared_preferences + flutter_secure_storage |
| 缓存 | flutter_cache_manager (分池: app/emoji/sticker/external) |
| 构建 | justfile + tool/*.dart 脚本 |
| CI | GitHub Actions (push tag → build → release → Telegram) |

---

## 目录结构

```
fluxseek/
├── android/                 # Android 平台工程
├── linux/                   # Linux 平台工程
├── lib/
│   ├── config/              # 站点配置 (link 安全策略等)
│   ├── constants.dart       # 全局常量 (baseUrl / UA / features)
│   ├── main.dart            # 应用入口
│   ├── models/              # 数据模型
│   ├── navigation/          # 底栏 entry + action bus
│   ├── pages/               # 页面 (37+)
│   ├── providers/           # Riverpod 状态层
│   ├── services/            # 业务与网络服务
│   │   ├── network/         # Dio 工厂 / adapters / cookie / interceptors
│   │   ├── nodeseek/        # NodeSeek API client (SSR + REST)
│   │   ├── emoji_handler.dart
│   │   ├── sticker_handler.dart
│   │   └── ...
│   ├── settings/            # 数据驱动的设置定义
│   ├── utils/               # 工具函数
│   └── widgets/             # 可复用组件 (17 个子目录)
├── packages/                # 本地 pub workspace 子包
├── docs/                    # 研发文档 (gitignore)
├── test/                    # 单元测试
├── tool/                    # 开发脚本 (gen_l10n / project_prep / release)
├── scripts/ci/              # CI 构建脚本
├── assets/                  # 图标 / 字体 / 图片
├── .github/workflows/       # GitHub Actions
├── justfile                 # 本地命令入口
└── pubspec.yaml
```

---

## 开发工作流

### 环境准备

```bash
# 1. 安装 Flutter (通过 FVM 或直接安装)
fvm install 3.38.9
fvm use 3.38.9

# 2. 拉依赖 + 生成 l10n
just sync
# 等价于: dart run tool/project_prep.dart app

# 3. 运行
just run -- -d linux          # Linux 开发
just run -- -d android --dart-define=cronetHttpNoPlay=true  # Android
```

### 日常开发命令

| 命令 | 作用 |
|---|---|
| `just sync` | pub get + l10n 生成 |
| `just run -- -d <device>` | 运行 |
| `just build -- apk --release --target-platform android-arm64 --dart-define=cronetHttpNoPlay=true` | 构建 APK |
| `just test` | 跑测试 |
| `just analyze` | 静态检查 |
| `just l10n` | 单独生成 l10n |
| `just release-check` | 发版前全量检查 (analyze + test) |

### 发版流程

```bash
# 1. 改 pubspec.yaml 版本号
#    格式: X.Y.Z-beta.N+YYYYMMDDHH (beta) 或 X.Y.Z+YYYYMMDDHH (stable)

# 2. 提交
git add pubspec.yaml
git commit -m "chore: bump version to X.Y.Z-beta.N"

# 3. 打 tag 并推送
git tag vX.Y.Z-beta.N
git push origin main --tags

# 4. CI 自动完成:
#    - 构建 3 个 arch APK (arm64 / arm / x64)
#    - 生成 SHA256 checksum
#    - 创建 GitHub Release (beta tag 自动标 prerelease)
#    - 发 Telegram 通知到 @fluxseek 频道
```

### 分支策略

- `main` 是唯一长期分支
- 功能开发直接在 main 上 commit（个人项目，不需要 PR 流程）
- 推 tag 触发 CI 构建和发布

---

## NodeSeek API 对接规范

### 核心原则

1. **认证 Cookie 是 `session`**（兼容旧 `_t` 回退路径）
2. **写操作统一使用 `x-csrf-challenge: simple-token` 静态 header**（不是动态 CSRF token）
3. **话题列表来自 SSR HTML DOM 解析**（不是 JSON API）
4. **帖子详情来自 SSR `__config__.postData`**（base64 → JSON）
5. **排序由 Cookie `sortBy` 控制**（`postTime` = 按发帖时间）

### API 文档

完整逆向文档在私有仓库 [Akuma-real/fluxseek-docs](https://github.com/Akuma-real/fluxseek-docs)（`nodeseek-api.md`）。

本地开发时文档在 `docs/nodeseek-api.md`（已 gitignore，不会推到公开仓）。

### 贴图（sticker）系统

NodeSeek 的 `:xhj003:` / `:ac01:` / `:yct015:` / `:emoji00:` 是自研贴图，不是 Twitter emoji。

- 短码格式：`:{group}{number}:`
- URL 模板：`/static/image/sticker/{group}/{filename}`
- 4 个分组：`ac`(137) / `yct`(22) / `xhj`(32) / `emoji`(49)
- 实现：`lib/services/sticker_handler.dart`（硬编码 files 映射）
- 渲染：`html_widget_factory.dart` 里 `class="sticker"` 独立分支，`InlineCustomWidget` + `maxWidth: 90`

---

## 代码规范

### Dart 风格

- 遵循 `analysis_options.yaml`（基于 Flutter 推荐规则）
- 目标：`dart analyze` 零 error、零 warning（info 级别可接受）
- 文件命名：`snake_case.dart`
- 类命名：`PascalCase`
- 私有前缀：`_`

### NodeSeek Client 架构

```
NodeSeekClient (门面, singleton)
  ├── _AuthMixin          # 登录/登出/session 管理
  ├── _TopicsMixin        # 话题列表/详情/创建
  ├── _PostsMixin         # 回复/编辑/删除/点赞/收藏
  ├── _UsersMixin         # 用户资料/关注/粉丝
  ├── _SearchMixin        # 搜索
  ├── _NotificationsMixin # 通知
  ├── _UploadsMixin       # 文件上传
  ├── _CategoriesMixin    # 分类
  ├── _UtilsMixin         # 私信/杂项
  ├── _DraftsMixin        # 草稿
  ├── _NestedMixin        # 嵌套视图 (stub)
  └── _NodeSeekApisMixin  # NodeSeek 专属 API (签到/stardust/黑名单/邀请码等)
```

每个 mixin 在 `lib/services/nodeseek/client_parts/` 下独立文件。

### 网络层架构

```
Dio (NodeSeekDio.create())
  ├── SessionGuardInterceptor    # 过期请求拦截
  ├── RequestSchedulerInterceptor # 并发限流
  ├── AppCookieManager           # Cookie 管理
  ├── CronetFallbackInterceptor  # Cronet 降级
  ├── RetryInterceptor           # 智能重试
  ├── RequestHeaderInterceptor   # UA + x-csrf-challenge
  ├── RedirectInterceptor        # 手动重定向
  ├── ErrorInterceptor           # 错误标准化
  ├── CfChallengeInterceptor     # Cloudflare 验证
  └── NetworkLogInterceptor      # 日志
```

适配器链：`WebView → NetworkHttp → Native (Cronet/Cupertino/IO)`

### 提交规范

```
<type>: <简短描述>

<可选的详细说明>
```

type 取值：
- `feat`: 新功能
- `fix`: 修复
- `docs`: 文档
- `chore`: 构建/配置/依赖
- `ci`: CI 相关
- `refactor`: 重构（不改行为）
- `test`: 测试

---

## 注意事项

### 不要做的事

- ❌ 不要把 `docs/nodeseek-api.md` 提交到公开仓库
- ❌ 不要把 `android/key.properties` 或 `*.jks` 提交到 git
- ❌ 不要把 `.kiro/` `.claude/` `.trellis/` 提交到 git
- ❌ 不要在没有用户二次确认的情况下调用 `buyInviteCode()`（扣鸡腿不可逆）
- ❌ 不要给 `getInfo/{uid}` 加 `readme=1&signature=1` 参数（会导致 USER NOT FOUND）
- ❌ 不要用 `X-CSRF-Token` header（NodeSeek 用 `x-csrf-challenge: simple-token`）

### 要做的事

- ✅ 修改 l10n 后跑 `just l10n` 重新生成
- ✅ 修改代码后跑 `dart analyze lib/` 确认零 error/warning
- ✅ 新增 API 对接时先更新 `docs/nodeseek-api.md`
- ✅ 贴图分组有变动时同步更新 `sticker_handler.dart` 的 `_stickerGroups`
- ✅ 发版前确认 `pubspec.yaml` 版本号已更新

---

## CI Secrets 清单

| Secret | 用途 | 必需? |
|---|---|---|
| `TELEGRAM_BOT_TOKEN` | Telegram 发版通知 | 是 |
| `TELEGRAM_CHAT_ID` | Telegram 频道 ID | 是 |
| `ANDROID_KEYSTORE_BASE64` | 正式签名 keystore | 否 (fallback debug) |
| `ANDROID_KEY_PROPERTIES` | key.properties 内容 | 否 |
| `GOOGLE_SERVICES_JSON` | Firebase 配置 (base64) | 否 |
