import '../constants.dart';

/// URL 工具类
///
/// NodeSeek 部署在根路径，图片资源走绝对路径分发，因此这里只做：
/// - 站内相对路径补全（`/post-123` → `https://www.nodeseek.com/post-123`）
/// - 协议相对 URL 补全（`//foo/bar.png` → `https://foo/bar.png`）
///
/// 不再支持 Discourse 的子路径部署（`baseUri`）和 CDN 重写。
class UrlHelper {
  /// 补全站内相对路径为绝对 URL。
  ///
  /// - 绝对 URL（http/https）：原样返回
  /// - 协议相对（`//...`）：补 `https:` 前缀
  /// - 相对路径（`/xxx`）：拼接 origin
  /// - `upload://` 短链接：原样返回，由下游解析
  static String resolveUrl(String url) {
    if (!_shouldResolve(url)) {
      return url;
    }

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    if (url.startsWith('//')) {
      return 'https:$url';
    }

    if (_isRelativePath(url)) {
      return '$_origin$url';
    }

    if (url == '/') {
      return '$_origin/';
    }

    return url;
  }

  /// 与 [resolveUrl] 行为等价。
  ///
  /// 历史上用于 CDN 重写，NodeSeek 不需要 CDN 差异化路径，
  /// 为保持调用点不变，保留此方法作为别名。
  static String resolveUrlWithCdn(String url) => resolveUrl(url);

  /// 判断给定 URL 是否属于当前站点。
  ///
  /// NodeSeek 部署在根路径，只要 host 匹配即视为同站点。
  static bool samePrefix(String url) {
    if (url.startsWith('/')) return true;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final appUri = Uri.parse(AppConstants.baseUrl);
    return uri.host == appUri.host;
  }

  static bool _shouldResolve(String url) {
    return url.isNotEmpty && !url.startsWith('upload://');
  }

  static bool _isRelativePath(String url) {
    return url.startsWith('/') && !url.startsWith('//');
  }

  static String get _origin {
    final baseUri = Uri.parse(AppConstants.baseUrl);
    return '${baseUri.scheme}://${baseUri.authority}';
  }
}
