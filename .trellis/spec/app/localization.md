# 本地化

## 源文件

项目使用 `slang`：

- 配置：`slang.yaml`
- 源 ARB：`lib/l10n/modules/<namespace>/<namespace>_<locale>.arb`
- 生成输出：`lib/l10n/slang/strings.g.dart`
- 兼容访问器：`lib/l10n/s.dart`

基础语言是 `zh`，当前包含 `zh`、`zh_HK`、`zh_TW`、`en`。

## 规则

- 新增用户可见文案时，同步更新对应 namespace 下所有 locale 的 ARB。
- Widget 中有 `BuildContext` 时用 `context.l10n`。
- Service、Toast、Interceptor 等无 context 场景用 `S.current`。
- 修改 ARB 后运行 `just l10n`；提交前用 `just l10n-check` 确认生成结果最新。
- 不要手写修改 `lib/l10n/slang/strings.g.dart`。

## 示例

- `lib/l10n/s.dart` 定义 `S.current` 和 `context.l10n`。
- `lib/services/network/interceptors/cf_challenge_interceptor.dart` 在 service/interceptor 层使用 `S.current`。
- `lib/l10n/modules/network/` 存放网络设置和提示文案。
