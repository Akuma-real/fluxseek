# 开发工作流

## Workspace

根目录 `pubspec.yaml` 使用 Dart workspace members：

- `packages/ai_model_manager`
- `packages/enhanced_cookie_jar`
- `packages/extended_image_lite`
- `packages/pangutext`
- `packages/paper_shaders`

使用 `dart run melos bootstrap` 或 `just bootstrap` 初始化 workspace 依赖。

## 生成代码

- l10n source: `lib/l10n/modules/**/*.arb`
- l10n config: `slang.yaml`
- l10n generator: `tool/gen_l10n.dart`
- compatibility generator: `tool/gen_slang_compat.dart`

规则：

- 依赖或 l10n 变更后运行 `just sync`。
- 完成 l10n 工作前运行 `just l10n-check`。
- 不要手写修改生成的本地化输出。
- 如果更新 `font_awesome_flutter`，按 `pubspec.yaml` 说明运行 `dart run tool/gen_fa_name_mapping.dart`。
- `PUB_CACHE` 未设置时，`tool/gen_fa_name_mapping.dart` 必须支持 Linux/macOS (`$HOME/.pub-cache`) 和 Windows (`%LOCALAPPDATA%\Pub\Cache`) 当前 pub cache 布局。
- `font_awesome_flutter` 11.x 将常量暴露为 `FaIconData`；生成的 CSS 映射应继续返回普通 `IconData`，供通过 Flutter `Icon` 渲染的 NodeSeek 分类/icon alias 消费者使用。

## Flutter Wrapper

`tool/flutterw.dart` 会在 `run`、`build`、`drive` 和 `test` 前运行项目准备。它还会通过 `tool/project_tasks.dart` 为 Android/Linux 目标准备原生产物。

除非正在调试 wrapper 本身，否则正常 build/run/test 工作流不要绕过 `tool/flutterw.dart`。

## 场景：Wrapper 准备的 Flutter 命令

### 1. 范围 / 触发

- 触发：修改 `just` recipes、`tool/flutterw.dart` 或 `tool/project_prep.dart`。
- 适用于项目准备后运行 Flutter 的命令：`run`、`build`、`drive` 和 `test`。

### 2. 签名

- `dart run tool/flutterw.dart <flutter-command> [flutter args...]`
- `just run -- -d linux`
- `just build -- apk --release --target-platform android-arm64`
- `just test`

### 3. 契约

- `tool/flutterw.dart` 必须容忍 `just` varargs 使用的可选 `--` 分隔符，且不得把该分隔符传给 Flutter。
- wrapper 准备成功后，支持 pub 控制的 Flutter 命令应收到 `--no-pub`，除非用户已经传入 `--pub`、`--no-pub`、`--help` 或 `-h`。
- 对 `flutter build <target>`，在 `<target>` 后插入 `--no-pub`；`flutter build --no-pub apk` 无效。
- 对 `run`、`drive` 和 `test`，在 Flutter 命令后插入 `--no-pub`。

### 4. 验证与错误矩阵

- `just build -- apk ...` 把字面量 `--` 传给 Flutter -> wrapper 必须移除它。
- `flutter build --no-pub apk ...` -> 无效；使用 `flutter build apk --no-pub ...`。
- 用户请求帮助 -> 不要注入 `--no-pub`；保留 help 输出行为。

### 5. Good/Base/Bad 案例

- Good：`just build -- apk --release --target-platform android-arm64` 运行 `flutter build apk --no-pub --release --target-platform android-arm64`。
- Base：`dart run tool/flutterw.dart run -d linux` 运行 `flutter run --no-pub -d linux`。
- Bad：`flutter build -- apk ...` 或 `flutter build --no-pub apk ...`。

### 6. 必需测试

- 对 wrapper 变更，完整构建前先运行 help/config-only 冒烟检查：
  - `dart run tool/flutterw.dart build -- apk --help`
  - `dart run tool/flutterw.dart run -- -d linux --help`
  - `dart run tool/flutterw.dart build -- apk --config-only --release --target-platform android-arm64`
- 运行 `just analyze`；当行为影响测试准备时运行 `just test`。

### 7. 错误 vs 正确

#### 错误

```bash
flutter build -- apk --release
flutter build --no-pub apk --release
```

#### 正确

```bash
flutter build apk --no-pub --release
```
