import 'package:dio/dio.dart';

import '../../../constants.dart';

/// 请求头拦截器
/// 负责设置 User-Agent 和 CSRF Token
/// NodeSeek CSRF 策略：写操作需 `x-csrf-challenge: simple-token` 静态 header
/// （页面中无 `<meta name="csrf-token">` 标签，2026-05-08 登录态复验确认）
class RequestHeaderInterceptor extends Interceptor {
  RequestHeaderInterceptor(dynamic cookieSync);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 1. 设置 User-Agent
    options.headers['User-Agent'] = await AppConstants.getUserAgent();

    // 2. 注入 Client Hints 请求头（Sec-CH-UA 系列，仅移动端可用）
    final hints = AppConstants.clientHints;
    if (hints != null) {
      options.headers.addAll(hints);
    }

    // 3. 设置 CSRF Token
    final skipCsrf = options.extra['skipCsrf'] == true;
    if (!skipCsrf) {
      final method = options.method.toUpperCase();
      if (method != 'GET') {
        // NodeSeek 使用静态 x-csrf-challenge header，无需动态获取
        options.headers['x-csrf-challenge'] = 'simple-token';
      }
    }

    // 4. API 请求（XHR）设置 Origin、Referer 和 Sec-Fetch-* 头
    if (options.headers['X-Requested-With'] == 'XMLHttpRequest') {
      options.headers['Origin'] = AppConstants.baseUrl;
      options.headers['Referer'] = '${AppConstants.baseUrl}/';
      // Sec-Fetch-* 系列头：Chrome 从 2019 年起每个请求都自动添加，
      // 缺失会被 Cloudflare Bot Management 识别为非浏览器客户端
      options.headers['Sec-Fetch-Dest'] = 'empty';
      options.headers['Sec-Fetch-Mode'] = 'cors';
      options.headers['Sec-Fetch-Site'] = 'same-origin';
    }

    handler.next(options);
  }
}
