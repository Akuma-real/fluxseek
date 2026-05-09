import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/topic.dart';
import '../models/category.dart';
import 'network/node_seek_dio.dart';
import 'network/cookie/cookie_jar_service.dart';
import 'network/cookie/csrf_token_service.dart';
import 'cf_challenge_service.dart';
import 'cf_clearance_refresh_service.dart';
import 'nodeseek/ssr_parser.dart';

/// 预加载数据服务
///
/// 从 NodeSeek 首页 HTML 的 Vue SSR 注入数据中提取当前用户、分类、话题列表等，
/// 避免额外 API 请求。
class PreloadedDataService {
  static final PreloadedDataService _instance =
      PreloadedDataService._internal();
  factory PreloadedDataService() => _instance;

  final Dio _dio;
  final CsrfTokenService _cookieSync = CsrfTokenService();
  final CfChallengeService _cfChallenge = CfChallengeService();

  // 缓存的预加载数据
  Map<String, dynamic>? _currentUser;
  Map<String, dynamic>? _siteSettings;
  Map<String, dynamic>? _site; // 站点信息（包含 categories）
  Map<String, dynamic>? _topicTrackingStateMeta;
  Map<String, dynamic>? _topicListData; // 首页话题列表原始数据
  TopicListResponse? _cachedTopicListResponse; // 缓存的已解析话题列表
  Completer<TopicListResponse?>? _topicListResponseCompleter;
  List<Map<String, dynamic>>? _customEmoji; // 自定义 emoji
  List<Map<String, dynamic>>? _topicTrackingStates; // 话题追踪状态
  String? _sharedSessionKey; // MessageBus 跨域认证 key（当前未使用，留给 MessageBus 清理任务）
  String? _longPollingBaseUrl; // MessageBus 独立域名（当前未使用，留给 MessageBus 清理任务）
  bool _hasNodeSeekSsrBootstrap = false; // 是否提取到 NodeSeek Vue SSR 引导数据
  bool _loaded = false;
  bool _loading = false;

  bool get _isOfficialNodeSeekHost {
    final host = Uri.tryParse(AppConstants.baseUrl)?.host;
    return host == 'www.nodeseek.com';
  }

  PreloadedDataService._internal()
    : _dio = NodeSeekDio.create(
        defaultHeaders: {
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        },
      );

  /// 是否已加载数据
  bool get isLoaded => _loaded;
  Map<String, dynamic>? get currentUserSync => _currentUser;
  Map<String, dynamic>? get siteSettingsSync => _siteSettings;

  List<Map<String, dynamic>>? get topicTrackingStatesSync =>
      _topicTrackingStates;

  /// 设置导航 context（用于弹出 CF 验证页面）
  void setNavigatorContext(BuildContext context) {
    _cfChallenge.setContext(context);
  }

  /// 确保预加载数据已准备好
  Future<void> ensureLoaded() async {
    await _ensureLoaded();
  }

  /// 获取 currentUser 数据（包含通知计数等）
  Future<Map<String, dynamic>?> getCurrentUser() async {
    await _ensureLoaded();
    return _currentUser;
  }

  /// 获取站点设置
  Future<Map<String, dynamic>?> getSiteSettings() async {
    await _ensureLoaded();
    return _siteSettings;
  }

  /// 获取站点信息（包含 categories、top_tags 等）
  Future<Map<String, dynamic>?> getSite() async {
    await _ensureLoaded();
    return _site;
  }

  /// 获取系统用户头像模板
  /// 用于通知列表中没有 acting_user 时的默认头像
  Future<String?> getSystemUserAvatarTemplate() async {
    await _ensureLoaded();
    return _site?['system_user_avatar_template'] as String?;
  }

  /// 同步获取分类 ID 集合（预加载数据已加载后可用，用于 Tab 过滤）
  Set<int>? get categoryIdsSync {
    if (_site == null) return null;
    try {
      final categoriesJson = _site!['categories'] as List?;
      if (categoriesJson != null) {
        return categoriesJson
            .map(
              (c) =>
                  int.tryParse(
                    (c as Map<String, dynamic>)['id']?.toString() ?? '0',
                  ) ??
                  0,
            )
            .where((id) => id != 0)
            .toSet();
      }
    } catch (_) {}
    return null;
  }

  /// 获取分类列表（从预加载的 site 数据中提取）
  Future<List<Category>?> getCategories() async {
    await _ensureLoaded();
    if (_site == null) return null;

    try {
      final categoriesJson = _site!['categories'] as List?;
      if (categoriesJson != null) {
        return categoriesJson
            .map((c) => Category.fromJson(c as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('[PreloadedData] 解析 categories 失败: $e');
    }
    return null;
  }

  /// 获取热门标签（从预加载的 site 数据中提取）
  Future<List<String>?> getTopTags() async {
    await _ensureLoaded();
    if (_site == null) return null;

    final topTags = _site!['top_tags'] as List?;
    if (topTags != null) {
      // 兼容新旧格式：如果是对象则取 name 字段，如果是字符串则直接用
      return topTags
          .map((t) {
            if (t is Map<String, dynamic>) {
              return t['name'] as String? ?? '';
            }
            return t.toString();
          })
          .where((name) => name.isNotEmpty)
          .toList();
    }
    return null;
  }

  /// 获取帖子操作类型（举报类型等）
  Future<List<Map<String, dynamic>>?> getPostActionTypes() async {
    await _ensureLoaded();
    if (_site == null) return null;

    final types = _site!['post_action_types'] as List?;
    if (types != null) {
      return types.cast<Map<String, dynamic>>();
    }
    return null;
  }

  /// 检查站点是否支持标签功能
  Future<bool?> canTagTopics() async {
    await _ensureLoaded();
    if (_site == null) return null;
    return _site!['can_tag_topics'] as bool?;
  }

  /// 获取默认发帖分类 ID
  /// 从 siteSettings 的 default_composer_category 获取
  Future<int?> getDefaultComposerCategoryId() async {
    await _ensureLoaded();
    if (_siteSettings == null) return null;
    final value = _siteSettings!['default_composer_category'];
    if (value == null) return null;
    if (value is int) {
      // 忽略无效值（-1 或 0 表示未设置）
      if (value <= 0) return null;
      return value;
    }
    if (value is String && value.isNotEmpty) {
      final parsed = int.tryParse(value);
      if (parsed != null && parsed > 0) return parsed;
    }
    return null;
  }

  /// 获取话题标题最小长度
  Future<int> getMinTopicTitleLength() async => 1;

  /// 获取私信标题最小长度
  Future<int> getMinPmTitleLength() async => 1;

  /// 获取回复内容最小长度
  Future<int> getMinPostLength() async => 1;

  /// 获取首贴内容最小长度
  Future<int> getMinFirstPostLength() async => 1;

  /// 获取私信内容最小长度
  Future<int> getMinPmPostLength() async => 1;

  /// 获取 MessageBus 跨域认证 key（当前未使用，留给 MessageBus 清理任务）
  String? get sharedSessionKey => _sharedSessionKey;

  /// 获取 MessageBus 长轮询 base URL（当前未使用，留给 MessageBus 清理任务）
  String? get longPollingBaseUrl => _longPollingBaseUrl;

  /// 站点子路径前缀（NodeSeek 部署在根路径，固定返回空字符串）
  String get baseUri => '';

  /// CDN URL（NodeSeek 通过图片绝对路径分发，UrlHelper 不做额外 CDN 改写）
  String? get cdnUrl => null;

  /// S3 CDN URL（同上）
  String? get s3CdnUrl => null;

  /// S3 基础 URL（同上）
  String? get s3BaseUrl => null;

  /// 获取 MessageBus 频道的初始 message ID
  /// 返回格式: {'/latest': 6855147, '/new': 104155, ...}
  Future<Map<String, dynamic>?> getTopicTrackingStateMeta() async {
    await _ensureLoaded();
    return _topicTrackingStateMeta;
  }

  /// 获取话题追踪状态列表（未读、新话题等）
  /// 用于初始化侧边栏的未读计数
  Future<List<Map<String, dynamic>>?> getTopicTrackingStates() async {
    await _ensureLoaded();
    return _topicTrackingStates;
  }

  /// 获取自定义 emoji 列表（同步访问，需确保已调用 ensureLoaded）
  /// 返回格式: [{name: "emoji_name", url: "emoji_url"}, ...]
  List<Map<String, dynamic>>? get customEmoji => _customEmoji;

  /// 获取自定义 emoji 列表（异步版本，自动确保数据已加载）
  /// 返回格式: [{name: "emoji_name", url: "emoji_url"}, ...]
  Future<List<Map<String, dynamic>>?> getCustomEmoji() async {
    await _ensureLoaded();
    return _customEmoji;
  }

  /// 获取预加载的首页话题列表（仅首次加载时有效）
  /// 返回 TopicListResponse 或 null
  Future<TopicListResponse?> getInitialTopicList() async {
    await _ensureLoaded();
    if (_cachedTopicListResponse != null) {
      final response = _cachedTopicListResponse;
      _cachedTopicListResponse = null;
      _topicListData = null;
      _topicListResponseCompleter = null;
      return response;
    }
    if (_topicListData == null && _topicListResponseCompleter == null) {
      return null;
    }

    try {
      if (_cachedTopicListResponse == null &&
          _topicListResponseCompleter != null) {
        await _topicListResponseCompleter!.future;
      }
      if (_cachedTopicListResponse == null) return null;
      final response = _cachedTopicListResponse;
      _cachedTopicListResponse = null;
      _topicListData = null;
      _topicListResponseCompleter = null;
      return response;
    } catch (e) {
      debugPrint('[PreloadedData] 解析 topic_list 失败: $e');
      _topicListData = null;
      _topicListResponseCompleter = null;
      return null;
    }
  }

  /// 检查是否有预加载的话题列表可用
  bool get hasInitialTopicList =>
      _cachedTopicListResponse != null ||
      _topicListData != null ||
      _topicListResponseCompleter != null;

  /// 同步获取预加载的话题列表（如果已加载）
  /// 返回 TopicListResponse 或 null
  /// 注意：此方法会消费数据，只能调用一次
  TopicListResponse? getInitialTopicListSync() {
    if (_cachedTopicListResponse == null) return null;
    final response = _cachedTopicListResponse;
    _cachedTopicListResponse = null; // 消费后清除
    _topicListData = null;
    _topicListResponseCompleter = null;
    return response;
  }

  /// 强制刷新预加载数据
  Future<void> refresh() async {
    _clearCachedData();
    await _loadPreloadedData();
  }

  /// 直接从已有 HTML 快照恢复预加载数据。
  ///
  /// 适用于登录 WebView 已经拿到完整页面的场景，避免重复请求首页。
  /// 返回是否成功解析到 SSR 引导数据。
  Future<bool> hydrateFromHtml(String html) async {
    _clearCachedData();
    final parsed = await _parsePreloadedDataFromHtml(html);
    if (!parsed) {
      debugPrint('[PreloadedData] HTML 快照不包含可用的 NodeSeek SSR 引导数据');
      return false;
    }

    if (!_hasReusableBootstrapData()) {
      debugPrint(
        '[PreloadedData] HTML 快照缺少完整引导数据: '
        'hasCurrentUser=${_currentUser != null}, '
        'hasSiteSettings=${_siteSettings != null}, '
        'hasSite=${_site != null}',
      );
      _clearCachedData();
      return false;
    }

    _loaded = true;
    if (_currentUser != null) {
      CfClearanceRefreshService().start();
    }
    debugPrint('[PreloadedData] 已从 HTML 快照恢复数据');
    return true;
  }

  void _clearCachedData() {
    _loaded = false;
    _currentUser = null;
    _siteSettings = null;
    _site = null;
    _topicListData = null;
    _cachedTopicListResponse = null;
    _topicListResponseCompleter = null;
    _customEmoji = null;
    _topicTrackingStates = null;
    _topicTrackingStateMeta = null;
    _hasNodeSeekSsrBootstrap = false;
    // _longPollingBaseUrl 和 _sharedSessionKey 是站点级基础设施数据，
    // 不随用户登录状态变化，refresh 窗口期内保留可避免 MessageBus 连接中断。
  }

  /// 重置缓存（登出时调用）
  void reset() {
    _clearCachedData();
    _sharedSessionKey = null;
    _longPollingBaseUrl = null;
  }

  /// 确保数据已加载
  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    if (_loading) {
      // 等待正在进行的加载完成
      while (_loading) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      if (_loaded) return; // 上次成功了才跳过
    }
    await _loadPreloadedData();
  }

  /// 加载预加载数据
  Future<void> _loadPreloadedData() async {
    if (_loading) return;
    _loading = true;

    try {
      // 设置 sortBy=postTime cookie，让 SSR 首页按发帖时间从新到旧排序
      await _ensureSortByPostTime();

      // 发起 HTTP 请求获取数据
      debugPrint('[PreloadedData] 发起 HTTP 请求');
      final response = await _dio.get(
        AppConstants.baseUrl,
        options: Options(
          headers: {'Accept': 'text/html'},
          extra: {
            if (AppConstants.skipCsrfForHomeRequest) 'skipCsrf': true,
            if (_isOfficialNodeSeekHost) ...{
              'forceWebViewAdapter': true,
              'isSilent': true,
            },
          },
        ),
      );

      final html = response.data as String;
      await _parsePreloadedDataFromHtml(html);
      debugPrint('[PreloadedData] 数据加载成功');
      _loaded = true;
      // 预热完成，sitekey 已提取；仅在已登录时启动 cf_clearance 自动续期，
      // 避免未登录状态下的 CF 刷新请求干扰 auth 判断
      if (_currentUser != null) {
        CfClearanceRefreshService().start();
      }
    } catch (e) {
      debugPrint('[PreloadedData] 加载失败: $e');
      rethrow;
    } finally {
      _loading = false;
    }
  }

  /// 确保 sortBy cookie 为 postTime，用于 NodeSeek SSR 排序：
  /// - replyTime：按最后回复时间（默认）
  /// - postTime：按发帖时间（新帖优先）
  Future<void> _ensureSortByPostTime() async {
    final jar = CookieJarService();
    if (!jar.isInitialized) return;
    try {
      final current = await jar.getCookieValue('sortBy');
      if (current == 'postTime') return;
      await jar.setCookie(
        'sortBy',
        'postTime',
        url: AppConstants.baseUrl,
        path: '/',
        secure: true,
      );
    } catch (e) {
      debugPrint('[PreloadedData] 设置 sortBy cookie 失败: $e');
    }
  }

  /// 从 HTML 中解析 NodeSeek SSR 引导数据
  Future<bool> _parsePreloadedDataFromHtml(String html) async {
    _extractCsrfTokenFromHtml(html);
    _extractTurnstileSitekeyFromHtml(html);
    return _parseNodeSeekSsrDataFromHtml(html);
  }

  bool _parseNodeSeekSsrDataFromHtml(String html) {
    final ssr = parseNodeSeekSsrHtml(html);
    if (ssr == null) return false;
    _hasNodeSeekSsrBootstrap = true;

    final user = ssr.config['user'];
    if (user is Map<String, dynamic>) {
      _currentUser = _normalizeNodeSeekCurrentUser(user);
    } else if (user is Map) {
      _currentUser = _normalizeNodeSeekCurrentUser(
        user.cast<String, dynamic>(),
      );
    }

    _siteSettings = {
      'min_topic_title_length': 1,
      'min_personal_message_title_length': 1,
      'min_post_length': 1,
      'min_first_post_length': 1,
      'min_personal_message_post_length': 1,
    };
    _site = {
      'categories': ssr.categories
          .map(
            (category) => {
              'id': category.id,
              'name': category.name,
              'color': category.color,
              'text_color': category.textColor,
              'slug': category.slug,
              'icon': category.icon,
              'read_restricted': category.readRestricted,
              'permission': category.permission,
            },
          )
          .toList(),
      'top_tags': <String>[],
      'can_tag_topics': false,
    };
    _topicListData = ssr.topicListData;
    _cachedTopicListResponse = ssr.topicListResponse;
    _topicListResponseCompleter = null;
    debugPrint(
      '[PreloadedData] NodeSeek SSR 解析成功, '
      'categories=${ssr.categories.length}, '
      'topics=${ssr.topicListResponse.topics.length}',
    );
    return true;
  }

  Map<String, dynamic> _normalizeNodeSeekCurrentUser(Map<String, dynamic> raw) {
    final id = _asInt(raw['id']) ?? _asInt(raw['member_id']) ?? 0;
    final username =
        raw['username']?.toString() ??
        raw['member_name']?.toString() ??
        raw['name']?.toString() ??
        '';

    // 从 SSR __config__.user.unViewedCount 提取未读通知计数
    final unViewedCount = raw['unViewedCount'];
    int allUnread = 0;
    int replyUnread = 0;
    int messageUnread = 0;
    if (unViewedCount is Map) {
      allUnread = _asInt(unViewedCount['all']) ?? 0;
      replyUnread = _asInt(unViewedCount['reply']) ?? 0;
      messageUnread = _asInt(unViewedCount['message']) ?? 0;
    }

    return {
      ...raw,
      'id': id,
      'username': username,
      'name': raw['name']?.toString() ?? username,
      'avatar_template':
          raw['avatar_template']?.toString() ??
          (id > 0 ? '/avatar/$id.png' : null),
      'trust_level': _asInt(raw['trust_level']) ?? _asInt(raw['rank']) ?? 0,
      'gamification_score':
          _asInt(raw['gamification_score']) ?? _asInt(raw['coin']),
      'bio_raw': raw['bio_raw'] ?? raw['bio'],
      'created_at': raw['created_at'],
      'topic_count': _asInt(raw['topic_count']) ?? _asInt(raw['nPost']),
      'post_count': _asInt(raw['post_count']) ?? _asInt(raw['nComment']),
      // 映射 NodeSeek SSR unViewedCount 到标准通知计数字段
      'unread_notifications': replyUnread,
      'unread_high_priority_notifications': messageUnread,
      'all_unread_notifications_count': allUnread,
    };
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  void _extractCsrfTokenFromHtml(String html) {
    final match = RegExp(
      "<meta[^>]+name=[\"']csrf-token[\"'][^>]+content=[\"']([^\"']+)[\"']",
      caseSensitive: false,
    ).firstMatch(html);
    if (match == null) return;
    final raw = match.group(1);
    if (raw == null || raw.isEmpty) return;
    final decoded = raw
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#39;', "'");
    _cookieSync.setCsrfToken(decoded);
  }

  /// 从 HTML 中提取 Turnstile sitekey（cf_clearance 自动续期用）
  void _extractTurnstileSitekeyFromHtml(String html) {
    final match = RegExp(r'data-sitekey="([0-9a-zA-Zx_-]+)"').firstMatch(html);
    if (match == null) return;
    final sitekey = match.group(1);
    if (sitekey != null && sitekey.isNotEmpty) {
      CfClearanceRefreshService().updateSitekey(sitekey);
    }
  }

  bool _hasReusableBootstrapData() {
    return _hasNodeSeekSsrBootstrap &&
        _currentUser != null &&
        _siteSettings != null &&
        _site != null;
  }
}
