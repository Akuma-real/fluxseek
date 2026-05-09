# Testing

## Test Layout

- `test/services/`：service、parser、network、cookie 测试。
- `test/utils/`：纯工具函数测试。
- `test/widgets/`：widget 渲染和交互测试。
- 本地 package 有自己的 `test/` 时，在对应 package 下维护，例如 `packages/enhanced_cookie_jar/test/`。

## What To Test

- NodeSeek HTML/SSR 解析必须用固定 HTML fixture 或 inline HTML 覆盖边界，参考 `test/services/nodeseek/ssr_parser_test.dart`。
- URL、路由、分页、emoji、cookie 去重等纯逻辑优先写单元测试。
- 网络适配器、Cookie、Cloudflare 相关修复必须补回归测试，避免会话和 cookie 状态回退。
- UI 测试聚焦稳定行为，不测试动画细节。

## Commands

- 全量测试：`just test`
- 单点测试：`just test -- test/services/nodeseek/ssr_parser_test.dart`
- 静态检查：`just analyze`

## Do Not

- 不要依赖真实 NodeSeek 网络请求做单元测试。
- 不要在测试里写入用户真实 cookie、token、私钥或本地账号数据。
- 不要跳过 `just sync`/l10n 生成状态直接判断代码失败。
