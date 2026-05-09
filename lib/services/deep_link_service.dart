import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import '../pages/topic_detail_page/topic_detail_page.dart';
import '../pages/user_profile_page.dart';
import '../pages/webview_login_page.dart';
import '../pages/webview_page.dart';
import '../constants.dart';
import '../utils/node_seek_url_parser.dart';
import 'nodeseek/node_seek_client.dart';

/// Deep Link 服务
/// 处理从外部链接打开应用的场景
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService _instance = DeepLinkService._();
  static DeepLinkService get instance => _instance;

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  BuildContext? _navigatorContext;
  bool _initialized = false;

  /// 防重复：记录最近处理的链接和时间
  Uri? _lastHandledUri;
  DateTime? _lastHandledTime;

  /// 邮箱登录成功回调（用于 Onboarding 页面完成引导）
  VoidCallback? onEmailLoginSuccess;

  /// 初始化服务
  /// 在主页面初始化后调用
  void initialize(BuildContext context) {
    _navigatorContext = context;

    if (_initialized) return;
    _initialized = true;

    // 处理应用冷启动时的链接
    _handleInitialLink();

    // 监听后续链接
    _linkSubscription = _appLinks.uriLinkStream.listen(_handleLink);
  }

  /// 更新导航 context
  void updateContext(BuildContext context) {
    _navigatorContext = context;
  }

  /// 处理初始链接（冷启动）
  Future<void> _handleInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        // 延迟处理，确保导航 context 已就绪
        await Future.delayed(const Duration(milliseconds: 500));
        _handleLink(uri);
      }
    } catch (e) {
      debugPrint('DeepLinkService: 获取初始链接失败: $e');
    }
  }

  /// 处理链接
  void _handleLink(Uri uri) {
    if (_navigatorContext == null) {
      debugPrint('DeepLinkService: 导航 context 未就绪');
      return;
    }

    // 防重复：1秒内相同链接不重复处理
    final now = DateTime.now();
    if (_lastHandledUri == uri &&
        _lastHandledTime != null &&
        now.difference(_lastHandledTime!).inSeconds < 1) {
      debugPrint('DeepLinkService: 忽略重复链接 $uri');
      return;
    }
    _lastHandledUri = uri;
    _lastHandledTime = now;

    final context = _navigatorContext!;
    final url = uri.toString();

    debugPrint('DeepLinkService: 收到链接 $url');

    // 尝试匹配用户链接 /u/username
    final userInfo = NodeSeekUrlParser.parseUser(uri.path);
    if (userInfo != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              UserProfilePage(username: userInfo.username, uid: userInfo.uid),
        ),
      );
      return;
    }

    // 尝试匹配 NodeSeek /post-{id}-{page} 和旧话题链接。
    final topicInfo = NodeSeekUrlParser.parseTopic(uri.path);
    if (topicInfo != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TopicDetailPage(
            topicId: topicInfo.topicId,
            scrollToPostNumber: topicInfo.postNumber,
          ),
        ),
      );
      return;
    }

    // 尝试兼容旧的纯 slug 话题链接。
    final topicSlug = NodeSeekUrlParser.parseTopicSlug(uri.path);
    if (topicSlug != null) {
      _handleTopicBySlug(context, topicSlug);
      return;
    }

    final baseHost = Uri.parse(AppConstants.baseUrl).host;
    final isCurrentSiteHost =
        uri.host == baseHost || uri.host.endsWith('.$baseHost');

    // 邮箱链接登录：/session/email-login/{token}
    if (isCurrentSiteHost && uri.path.startsWith('/session/email-login/')) {
      _handleEmailLogin(context, url);
      return;
    }

    // 其他 NodeSeek 链接：使用内置浏览器
    if (isCurrentSiteHost) {
      WebViewPage.open(context, url);
      return;
    }

    // 自定义 scheme (fluxseek://... 或 nodeseek://...)
    if (uri.scheme == AppConstants.primaryScheme || uri.scheme == 'nodeseek') {
      _handleCustomScheme(context, uri);
      return;
    }

    debugPrint('DeepLinkService: 未知链接类型 $url');
  }

  /// 处理自定义 scheme
  /// 支持格式：
  /// - fluxseek://topic/123
  /// - fluxseek://topic/123/5 (指定楼层)
  /// - fluxseek://user/username
  void _handleCustomScheme(BuildContext context, Uri uri) {
    final pathSegments = [
      if (uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments,
    ];

    if (pathSegments.isEmpty) return;

    switch (pathSegments[0]) {
      case 'topic':
        if (pathSegments.length >= 2) {
          final topicId = int.tryParse(pathSegments[1]);
          final postNumber = pathSegments.length >= 3
              ? int.tryParse(pathSegments[2])
              : null;

          if (topicId != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TopicDetailPage(
                  topicId: topicId,
                  scrollToPostNumber: postNumber,
                ),
              ),
            );
          }
        }
        break;

      case 'user':
      case 'u':
      case 'space':
        if (pathSegments.length >= 2) {
          final uid = int.tryParse(pathSegments[1]);
          final username = uid == null ? pathSegments[1] : 'user$uid';
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => UserProfilePage(username: username, uid: uid),
            ),
          );
        }
        break;

      default:
        // 未知路径，打开网页版
        final webUrl = '${AppConstants.baseUrl}/${pathSegments.join('/')}';
        WebViewPage.open(context, webUrl);
    }
  }

  /// 处理邮箱链接登录
  Future<void> _handleEmailLogin(BuildContext context, String url) async {
    debugPrint('DeepLinkService: 处理邮箱链接登录: $url');
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => WebViewLoginPage(initialUrl: url)),
    );
    if (result == true) {
      onEmailLoginSuccess?.call();
    }
  }

  /// 通过 slug 获取话题并打开
  Future<void> _handleTopicBySlug(BuildContext context, String slug) async {
    try {
      debugPrint('DeepLinkService: 通过 slug 获取话题: $slug');
      final service = NodeSeekClient();
      final detail = await service.getTopicDetailBySlug(slug);

      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                TopicDetailPage(topicId: detail.id, initialTitle: detail.title),
          ),
        );
      }
    } catch (e) {
      debugPrint('DeepLinkService: 通过 slug 获取话题失败: $e');
      // 失败时使用 WebView 打开
      if (context.mounted) {
        final searchUrl =
            '${AppConstants.baseUrl}/search?q=${Uri.encodeComponent(slug)}';
        WebViewPage.open(context, searchUrl);
      }
    }
  }

  /// 释放资源
  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
    _navigatorContext = null;
    _initialized = false;
    _lastHandledUri = null;
    _lastHandledTime = null;
  }
}
