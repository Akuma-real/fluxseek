import 'package:dio/dio.dart';

import '../../../constants.dart';
import '../cookie/csrf_token_service.dart';

/// 请求头拦截器
/// 负责设置 User-Agent 和 CSRF Token
/// NodeSeek CSRF 策略：写操作保留 `x-csrf-challenge: simple-token`，
/// 内容写接口同时复用会话中的动态 CSRF token。
class RequestHeaderInterceptor extends Interceptor {
  RequestHeaderInterceptor(
    CsrfTokenService csrfTokenService, {
    String? Function()? readCsrfToken,
    Future<void> Function()? updateCsrfToken,
  }) : _readCsrfToken = readCsrfToken ?? (() => csrfTokenService.csrfToken),
       _updateCsrfToken = updateCsrfToken ?? csrfTokenService.updateCsrfToken;

  final String? Function() _readCsrfToken;
  final Future<void> Function() _updateCsrfToken;

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
        options.headers['x-csrf-challenge'] = 'simple-token';
        var csrfToken = _readCsrfToken();
        if ((csrfToken == null || csrfToken.isEmpty) &&
            _isNodeSeekContentWrite(options)) {
          await _updateCsrfToken();
          csrfToken = _readCsrfToken();
        }
        if (csrfToken != null && csrfToken.isNotEmpty) {
          options.headers['X-CSRF-Token'] = csrfToken;
        }
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

  bool _isNodeSeekContentWrite(RequestOptions options) {
    return options.uri.path.startsWith('/api/content/');
  }
}
