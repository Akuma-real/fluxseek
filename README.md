# fluxseek

> 面向 [NodeSeek](https://www.nodeseek.com/) 的第三方 Android 客户端

[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-blue.svg)](LICENSE)
[![GitHub Releases](https://img.shields.io/github/v/release/Akuma-real/fluxseek?logo=github&label=release&include_prereleases)](https://github.com/Akuma-real/fluxseek/releases)

fluxseek 是为 NodeSeek 社区打造的 Flutter 客户端。

## 致谢 & 代码来源

本项目在 [Lingyan000/fluxdo](https://github.com/Lingyan000/fluxdo)（作者 [@Lingyan000](https://github.com/Lingyan000)）的源代码基础上改造而来，主要工作是将目标站点迁移到 NodeSeek，并按 NodeSeek 的 API 和 UI 习惯做了大量适配与重写。

fluxdo 采用 [GPL-3.0](https://github.com/Lingyan000/fluxdo/blob/main/LICENSE) 协议，本项目继承同样的 GPL-3.0 协议继续开源。由衷感谢原作者开源的高质量代码。

## 平台范围

- Android：正式使用和发布目标
- Linux：开发、调试和验证目标
- iOS / macOS / Windows / Web：暂未适配

## 核心功能

- 话题浏览（首页 / 分类 / 搜索），按发帖时间从新到旧排序
- 话题详情 / 楼层跳转 / 分页加载
- 回复 / 发帖 / 编辑 / 删除（区分楼主帖与评论）
- 点赞 / 踩 / 投鸡腿 / 收藏 / 置顶评论
- 关注 / 取关 / 粉丝 / 关注列表 / 黑名单
- 私信会话列表、详情、收发、批量已读
- @ 我 / 回复我 / 私信 三通道通知
- 用户资料、登录历史、Telegram 绑定、鸡腿明细
- 邀请码列表 + 购买（扣鸡腿强确认流程）
- Stardust 流水、转账预检、发送
- 签到 / 今日额度 / 签到排行榜
- 偏好读写、自定义 CSS
- NodeSeek 贴图（sticker）系统完整渲染：`:xhj003:` / `:ac01:` / `:yct015:` / `:emoji00:`
- WebView 登录 / Cookie 同步 / Cloudflare challenge 适配
- 图片查看保存 / 图片缓存 / 代码高亮 / Markdown 编辑预览

## 快速开始

### 前置要求

- Flutter SDK 3.41.9（通过 `.fvmrc` 锁定）
- Android Studio / Android SDK / Android NDK（Android 构建）
- Linux 桌面依赖（`flutter run -d linux`）
- `just`（推荐的本地命令入口）

### 初始化

```bash
dart run melos bootstrap
just sync
```

### 运行

Android：

```bash
just run -- -d android --dart-define=cronetHttpNoPlay=true
```

Linux 开发：

```bash
just run -- -d linux
```

不使用 `just` 时：

```bash
dart run tool/project_prep.dart app
dart run tool/flutterw.dart run -d linux
```

## 常用命令

| 命令 | 作用 |
| --- | --- |
| `just sync` | 同步依赖 + 生成 l10n |
| `just run -- -d <device>` | 运行 |
| `just build -- apk --release --dart-define=cronetHttpNoPlay=true` | 构建 Android APK |
| `just test` | 执行测试 |
| `just analyze` | 静态检查 |
| `just release-check` | 发版前全量检查 |

## 项目结构

```text
fluxseek/
├── android/                 # Android 平台工程
├── linux/                   # Linux 平台工程
├── lib/
│   ├── config/              # 站点 / 应用配置
│   ├── models/              # 数据模型
│   ├── pages/               # 页面
│   ├── providers/           # Riverpod 状态
│   ├── services/            # 业务与网络服务
│   ├── utils/               # 工具
│   └── widgets/             # 可复用组件
├── packages/                # 本地 pub workspace 子包
├── docs/                    # API 逆向文档
├── scripts/ci/linux/        # CI 构建脚本
└── tool/                    # 开发与发版脚本
```

## 技术栈

- Flutter 3.38 + Riverpod
- Dio + Native Dio Adapter + WebView HTTP fallback
- flutter_widget_from_html + flutter_inappwebview
- shared_preferences + flutter_secure_storage
- slang（zh / zh_HK / zh_TW / en）

## 关于 NodeSeek

[NodeSeek](https://www.nodeseek.com/) 是一个技术社区。fluxseek 是非官方第三方客户端，与 NodeSeek 官方无直接关联。所有 API 对接均基于对公开网页端的逆向整理，详见 [`docs/nodeseek-api.md`](docs/nodeseek-api.md)。

## 开源协议

本项目基于 [GPL-3.0](LICENSE) 协议开源，继承自 [Lingyan000/fluxdo](https://github.com/Lingyan000/fluxdo)。
