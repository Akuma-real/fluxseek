import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' hide Category;

import '../../constants.dart';
import '../../models/category.dart';
import '../../models/notification.dart';
import '../../models/search_result.dart';
import '../../models/topic.dart';
import '../../models/user.dart';
import '../../models/user_action.dart';
import '../network/cookie/cookie_jar_service.dart';
import '../preloaded_data_service.dart';
import 'ssr_parser.dart';

class NodeSeekTopicPaging {
  const NodeSeekTopicPaging({
    required this.pageSize,
    required this.pageCount,
    required this.totalPosts,
  });

  final int pageSize;
  final int pageCount;
  final int totalPosts;
}

class NodeSeekService {
  factory NodeSeekService(Dio dio) {
    return _instances[dio] ??= NodeSeekService._(dio);
  }

  NodeSeekService._(this._dio);

  final Dio _dio;
  final Map<int, NodeSeekTopicPaging> _topicPaging = {};

  static final Expando<NodeSeekService> _instances = Expando<NodeSeekService>();
  static bool _nativeSsrBlocked = false;

  static const staticCategoryData = <Map<String, dynamic>>[
    {'key': 'daily', 'cn_text': '日常', 'icon': 'tea'},
    {'key': 'tech', 'cn_text': '技术', 'icon': 'formula'},
    {'key': 'info', 'cn_text': '情报', 'icon': 'receiver'},
    {'key': 'review', 'cn_text': '测评', 'icon': 'dashboard-one'},
    {'key': 'trade', 'cn_text': '交易', 'icon': 'dollar'},
    {'key': 'carpool', 'cn_text': '拼车', 'icon': 'car'},
    {'key': 'promotion', 'cn_text': '推广', 'icon': 'hold-interface'},
    {'key': 'life', 'cn_text': '生活', 'icon': 'oval-love-two'},
    {'key': 'dev', 'cn_text': 'Dev', 'icon': 'terminal'},
    {'key': 'photo-share', 'cn_text': '贴图', 'icon': 'pic-one'},
    {'key': 'expose', 'cn_text': '曝光', 'icon': 'face-recognition'},
    {'key': 'inside', 'cn_text': '内版', 'icon': 'open-one'},
    {'key': 'meaningless', 'cn_text': '无意义', 'icon': 'texture'},
    {'key': 'sandbox', 'cn_text': '沙盒', 'icon': 'experiment'},
  ];

  static bool get isOfficialHost {
    final host = Uri.tryParse(AppConstants.baseUrl)?.host;
    return host == 'www.nodeseek.com';
  }

  static Category categoryFromJson(Map<String, dynamic> json, int index) {
    final key = json['key']?.toString() ?? '';
    return Category(
      id: index + 2,
      name: json['cn_text']?.toString() ?? key,
      color: '64748B',
      textColor: 'FFFFFF',
      slug: key,
      description: json['description']?.toString(),
      icon: json['icon']?.toString(),
      readRestricted: json['adminOnly'] == true,
      permission: json['adminOnly'] == true ? 3 : 0,
    );
  }

  static List<Category> staticCategories() {
    return [
      for (var i = 0; i < staticCategoryData.length; i++)
        categoryFromJson(staticCategoryData[i], i),
    ];
  }

  Future<Response<dynamic>> _getSsrResponse(
    String path, {
    bool acceptNotFound = false,
    bool forceWebView = false,
  }) {
    return _dio.get(
      path,
      options: Options(
        responseType: ResponseType.plain,
        validateStatus: (status) {
          if (status == null) return false;
          if (status >= 200 && status < 400) return true;
          if (acceptNotFound && status == 404) return true;
          if (!forceWebView && status == 403) return true;
          return false;
        },
        headers: {
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'X-Requested-With': null,
        },
        extra: {
          if (AppConstants.skipCsrfForHomeRequest) 'skipCsrf': true,
          'skipCfChallenge': true,
          if (forceWebView)
            'forceWebViewAdapter': true
          else
            'skipWebViewAdapter': true,
        },
      ),
    );
  }

  Future<Response<dynamic>> getSsrResponse(
    String path, {
    bool acceptNotFound = false,
  }) async {
    if (_nativeSsrBlocked || isOfficialHost) {
      return _getSsrResponse(
        path,
        acceptNotFound: acceptNotFound,
        forceWebView: true,
      );
    }

    final response = await _getSsrResponse(
      path,
      acceptNotFound: acceptNotFound,
    );
    if (response.statusCode != 403) return response;

    _nativeSsrBlocked = true;
    debugPrint('[NodeSeek] Native SSR returned 403, falling back to WebView');
    return _getSsrResponse(
      path,
      acceptNotFound: acceptNotFound,
      forceWebView: true,
    );
  }

  Future<TopicListResponse?> getSsrTopics(String path) async {
    // 确保每次拉取列表前 sortBy cookie 为 postTime（按发帖时间排序，从新到旧）
    await _ensureSortByPostTime();
    final response = await getSsrResponse(path);
    final data = response.data;
    final html = data is String ? data : data?.toString() ?? '';
    final ssr = parseNodeSeekSsrHtml(html);
    return ssr?.topicListResponse;
  }

  /// 确保 sortBy cookie 为 postTime。NodeSeek SSR 读取该 cookie 决定返回顺序：
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
      debugPrint('[NodeSeek] set sortBy cookie failed: $e');
    }
  }

  Future<TopicListResponse> getLatestTopics({
    int page = 0,
    String? order,
    bool? ascending,
  }) async {
    if (page == 0 && order == null && ascending == null) {
      final preloadedList = PreloadedDataService().getInitialTopicListSync();
      if (preloadedList != null) return preloadedList;
    }

    final ssrList = await getSsrTopics(page > 0 ? '/page-${page + 1}' : '/');
    return ssrList ?? TopicListResponse(topics: [], moreTopicsUrl: null);
  }

  Future<TopicListResponse> getFilteredTopics({
    int? categoryId,
    String? categorySlug,
    List<String>? tags,
    String? period,
    int page = 0,
    String? order,
    bool? ascending,
  }) async {
    if (categorySlug != null &&
        tags == null &&
        period == null &&
        order == null &&
        ascending == null) {
      final path = page > 0
          ? '/categories/$categorySlug/page-${page + 1}'
          : '/categories/$categorySlug';
      final ssrList = await getSsrTopics(path);
      return ssrList ?? TopicListResponse(topics: [], moreTopicsUrl: null);
    }

    if (categoryId == null &&
        categorySlug == null &&
        tags == null &&
        period == null) {
      return getLatestTopics(page: page, order: order, ascending: ascending);
    }

    return TopicListResponse(topics: [], moreTopicsUrl: null);
  }

  Future<TopicDetail?> getTopicDetail(int id, {int? page}) async {
    final firstPage = await _getTopicDetailPage(id, page: page);
    if (firstPage == null) return null;

    final posts = firstPage.detail.postStream.posts;
    final pageCount = firstPage.pageCount < 1 ? 1 : firstPage.pageCount;
    final pageSize = posts.isEmpty ? 1 : posts.length;
    var totalPosts = _maxPostNumber(posts);

    if (pageCount > 1 && firstPage.page != pageCount) {
      try {
        final lastPage = await _getTopicDetailPage(id, page: pageCount);
        if (lastPage != null) {
          totalPosts = _maxPostNumber(lastPage.detail.postStream.posts);
        }
      } catch (e) {
        debugPrint('[NodeSeek] 加载话题 $id 最后一页失败: $e');
      }
    }

    if (totalPosts < posts.length) {
      totalPosts = posts.length;
    }
    if (totalPosts == 0) {
      totalPosts = pageCount * pageSize;
    }

    _topicPaging[id] = NodeSeekTopicPaging(
      pageSize: pageSize,
      pageCount: pageCount,
      totalPosts: totalPosts,
    );

    return firstPage.detail.copyWith(
      postsCount: totalPosts,
      postStream: PostStream(
        posts: posts,
        stream: _buildStream(id, posts, totalPosts),
      ),
    );
  }

  Future<TopicDetail> getTopicDetailBySlug(String slug) async {
    final match = RegExp(r'post-(\d+)').firstMatch(slug);
    final id = match == null ? int.tryParse(slug) : int.tryParse(match[1]!);
    if (id != null) {
      final pageMatch = RegExp(r'post-\d+-(\d+)').firstMatch(slug);
      final page = pageMatch == null ? null : int.tryParse(pageMatch[1]!);
      final detail = await getTopicDetail(id, page: page);
      if (detail != null) return detail;
    }
    throw Exception('NodeSeek topic not found: $slug');
  }

  int pageForPostNumber(int topicId, int postNumber) {
    final paging = _topicPaging[topicId];
    final pageSize = paging?.pageSize ?? 10;
    final safePostNumber = postNumber < 1 ? 1 : postNumber;
    return ((safePostNumber - 1) ~/ pageSize) + 1;
  }

  Future<PostStream> getPostsByNumber(
    int topicId, {
    required int postNumber,
    required bool asc,
  }) async {
    final paging = _topicPaging[topicId];
    final pageSize = paging?.pageSize ?? 10;
    final pageCount = paging?.pageCount ?? 1;
    final currentPage = ((postNumber - 1) ~/ pageSize) + 1;
    final targetPage = asc ? currentPage + 1 : currentPage - 1;
    if (targetPage < 1 || targetPage > pageCount) {
      return PostStream(posts: const [], stream: const []);
    }

    final ssrPage = await _getTopicDetailPage(topicId, page: targetPage);
    final posts = ssrPage?.detail.postStream.posts ?? const <Post>[];
    final totalPosts = [
      paging?.totalPosts ?? 0,
      _maxPostNumber(posts),
    ].reduce((a, b) => a > b ? a : b);

    if (ssrPage != null && totalPosts > 0) {
      _topicPaging[topicId] = NodeSeekTopicPaging(
        pageSize: pageSize,
        pageCount: ssrPage.pageCount,
        totalPosts: totalPosts,
      );
    }

    return PostStream(
      posts: posts,
      stream: _buildStream(topicId, posts, totalPosts),
    );
  }

  Future<List<Category>> getCategories() async {
    final preloaded = PreloadedDataService();
    if (!preloaded.isLoaded) return staticCategories();

    final preloadedCategories = await preloaded.getCategories();
    if (preloadedCategories != null && preloadedCategories.isNotEmpty) {
      return preloadedCategories;
    }

    final response = await _dio.post('/api/content/list-categories');
    final data = response.data;
    final categories = data is Map ? data['data'] : null;
    if (categories is! List) return const [];

    return [
      for (var i = 0; i < categories.length; i++)
        if (categories[i] is Map)
          categoryFromJson((categories[i] as Map).cast<String, dynamic>(), i),
    ];
  }

  Future<String?> categorySlug(int categoryId) async {
    final categories = await getCategories();
    for (final category in categories) {
      if (category.id == categoryId) return category.slug;
    }
    return null;
  }

  Future<TopicListResponse> getBookmarks({int page = 0}) async {
    final response = await _dio.get(
      '/api/statistics/list-collection',
      queryParameters: {'page': page + 1},
    );
    final data = response.data;
    final collections = data is Map ? data['collections'] : null;
    final topics = <Map<String, dynamic>>[];
    final users = <Map<String, dynamic>>[];
    final seenUserIds = <int>{};
    if (collections is List) {
      for (final item in collections) {
        if (item is! Map) continue;
        final raw = item.cast<String, dynamic>();
        final postId = int.tryParse(item['post_id']?.toString() ?? '');
        if (postId == null) continue;
        final userId =
            _asInt(raw['member_id']) ??
            _asInt(raw['uid']) ??
            _asInt(raw['user_id']) ??
            _asInt(raw['author_id']);
        final username =
            raw['member_name']?.toString() ??
            raw['username']?.toString() ??
            raw['user_name']?.toString() ??
            raw['author_name']?.toString();
        if (userId != null && userId > 0 && seenUserIds.add(userId)) {
          users.add({
            'id': userId,
            'username': username ?? 'user$userId',
            'avatar_template':
                raw['avatar_template']?.toString() ?? '/avatar/$userId.png',
          });
        }
        topics.add({
          'id': postId,
          'title': item['title']?.toString() ?? '',
          'slug': 'post-$postId',
          'posts_count': 1,
          'reply_count': 0,
          'views': 0,
          'like_count': 0,
          'category_id': 0,
          'pinned': false,
          'visible': item['rank'] != 255,
          'closed': false,
          'archived': false,
          'tags': <String>[],
          'posters': userId != null && userId > 0
              ? <Map<String, dynamic>>[
                  {
                    'user_id': userId,
                    'description': 'Original Poster',
                    'extras': 'latest',
                  },
                ]
              : <Map<String, dynamic>>[],
          'last_poster_username': username,
        });
      }
    }
    return TopicListResponse.fromJson({
      'users': users,
      'topic_list': {'topics': topics, 'more_topics_url': null},
    });
  }

  Future<TopicListResponse> getUserCreatedTopicsByUid(
    int uid, {
    int page = 0,
    User? author,
  }) async {
    final effectiveAuthor = author ?? await getUserByUid(uid);
    final actions = await _getUserDiscussions(uid, page: page + 1);
    final topics = actions
        .map((action) {
          final topicId = _asInt(action['topic_id']) ?? 0;
          final createdAt = action['created_at']?.toString();
          return {
            'id': topicId,
            'title': action['title']?.toString() ?? '',
            'slug': 'post-$topicId',
            'posts_count': 1,
            'reply_count': 0,
            'views': 0,
            'like_count': 0,
            'category_id': action['category_id'] ?? 0,
            'pinned': false,
            'visible': true,
            'closed': false,
            'archived': false,
            'tags': <String>[],
            'created_at': createdAt,
            'last_posted_at': createdAt,
            'last_poster_username': effectiveAuthor.username,
            'posters': [
              {
                'user_id': effectiveAuthor.id,
                'description': 'Original Poster',
                'extras': 'latest',
              },
            ],
          };
        })
        .where((topic) => (topic['id'] as int) > 0)
        .toList();

    final moreUrl = topics.length >= 30
        ? '/api/content/list-discussions?uid=$uid&page=${page + 2}'
        : null;
    return TopicListResponse.fromJson({
      'users': [
        {
          'id': effectiveAuthor.id,
          'username': effectiveAuthor.username,
          'avatar_template':
              effectiveAuthor.avatarTemplate ??
              '/avatar/${effectiveAuthor.id}.png',
        },
      ],
      'topic_list': {'topics': topics, 'more_topics_url': moreUrl},
    });
  }

  Future<SearchResult> search({required String query, int page = 1}) async {
    final parsed = _parseSearchQuery(query);
    if (parsed.term.isEmpty) {
      return _emptySearchResult(query);
    }

    final path = Uri(
      path: '/search',
      queryParameters: {
        'q': parsed.term,
        if (parsed.categorySlug != null) 'category': parsed.categorySlug!,
        if (page > 1) 'page': '$page',
      },
    ).toString();
    final response = await getSsrResponse(path);
    final html = response.data is String
        ? response.data as String
        : response.data?.toString() ?? '';

    final postResults = _isExternalSearchRedirect(response)
        ? _emptySearchResult(parsed.term)
        : parseNodeSeekSearchHtml(html, term: parsed.term);
    if (_isExternalSearchRedirect(response)) {
      debugPrint('[NodeSeek] search redirected to external engine: $path');
    }
    if (page > 1) return postResults;

    final memberResults = await searchMembers(parsed.term);
    return SearchResult.fromJson({
      'posts': postResults.posts
          .map((post) => _searchPostToJson(post))
          .toList(),
      'topics': postResults.posts
          .map((post) => post.topic)
          .whereType<SearchTopic>()
          .map(_searchTopicToJson)
          .toList(),
      'users': memberResults.map(_searchUserToJson).toList(),
      'grouped_search_result': {
        'term': parsed.term,
        'more_full_page_results': postResults.hasMorePosts,
        'more_posts': false,
        'more_users': false,
        'more_categories': false,
      },
    });
  }

  Future<List<SearchUser>> searchMembers(String query) async {
    final term = query.trim();
    if (term.isEmpty) return const [];

    final uid = int.tryParse(term);
    if (uid != null) {
      try {
        final user = await getUserByUid(uid);
        return [
          SearchUser(
            id: user.id,
            username: user.username,
            name: user.name,
            avatarTemplate: user.avatarTemplate ?? '/avatar/${user.id}.png',
          ),
        ];
      } catch (e) {
        debugPrint('[NodeSeek] uid search failed: $e');
        return const [];
      }
    }

    final path = Uri(path: '/member', queryParameters: {'q': term}).toString();
    final response = await getSsrResponse(path);
    if (_isExternalSearchRedirect(response)) return const [];

    final html = response.data is String
        ? response.data as String
        : response.data?.toString() ?? '';
    return parseNodeSeekMemberSearchHtml(html).users;
  }

  Future<User> getUserByUid(int uid) async {
    final detail = await _getUserDetail(uid);
    final resolvedUid = _asInt(detail['member_id']) ?? uid;
    final username = detail['member_name']?.toString() ?? 'user$resolvedUid';
    final bio = detail['bio']?.toString();
    return User(
      id: resolvedUid,
      username: username,
      name: username,
      avatarTemplate: '/avatar/$resolvedUid.png',
      trustLevel: _asInt(detail['rank']) ?? 0,
      bio: bio,
      bioRaw: bio,
      createdAt: DateTime.tryParse(detail['created_at']?.toString() ?? ''),
      canFollow: false,
      isFollowed: detail['followed'] == true || detail['followed'] == 1,
      totalFollowers: _asInt(detail['fans']),
      totalFollowing: _asInt(detail['follows']),
      canSendPrivateMessages: false,
      canSendPrivateMessageToUser: false,
      gamificationScore: _asInt(detail['coin']),
    );
  }

  Future<UserSummary> getUserSummaryByUid(int uid) async {
    final detail = await _getUserDetail(uid);
    final createdAt = DateTime.tryParse(detail['created_at']?.toString() ?? '');
    final joinDays = createdAt == null
        ? 0
        : DateTime.now()
              .difference(createdAt.toLocal())
              .inDays
              .clamp(0, 1 << 31)
              .toInt();
    return UserSummary(
      daysVisited: joinDays,
      postsReadCount: 0,
      likesReceived: _asInt(detail['coin']) ?? 0,
      likesGiven: 0,
      topicCount: _asInt(detail['nPost']) ?? 0,
      postCount: _asInt(detail['nComment']) ?? 0,
      timeRead: 0,
      bookmarkCount: _asInt(detail['collectionCount']) ?? 0,
    );
  }

  Future<UserActionResponse> getUserActionsByUid(
    int uid, {
    String? filter,
    int offset = 0,
  }) async {
    final page = offset ~/ 30 + 1;
    final actions = <Map<String, dynamic>>[];
    final wantsTopics = filter == null || filter.contains('4');
    final wantsComments = filter == null || filter.contains('5');

    if (wantsTopics) {
      actions.addAll(await _getUserDiscussions(uid, page: page));
    }
    if (wantsComments) {
      actions.addAll(await _getUserComments(uid, page: page));
    }

    return UserActionResponse.fromJson({'user_actions': actions});
  }

  Future<List<Map<String, dynamic>>> _getUserDiscussions(
    int uid, {
    required int page,
  }) async {
    final data = await _getNodeSeekJson(
      '/api/content/list-discussions',
      queryParameters: {'uid': uid, 'page': page},
    );
    if (data['success'] == false) {
      debugPrint('[NodeSeek] list-discussions failed: ${data['message']}');
      return const [];
    }

    return _asMapList(data['discussions'])
        .map((raw) {
          final topicId = _asInt(raw['post_id']) ?? _asInt(raw['id']) ?? 0;
          return {
            'action_type': UserActionType.newTopic,
            'topic_id': topicId,
            'title': raw['title']?.toString() ?? '',
            'slug': 'post-$topicId',
            'post_number': 1,
            'created_at':
                raw['created_at']?.toString() ?? raw['time']?.toString(),
            'excerpt': raw['summary']?.toString() ?? raw['text']?.toString(),
          };
        })
        .where((item) => (item['topic_id'] as int) > 0)
        .toList();
  }

  Future<List<Map<String, dynamic>>> _getUserComments(
    int uid, {
    required int page,
  }) async {
    final data = await _getNodeSeekJson(
      '/api/content/list-comments',
      queryParameters: {'uid': uid, 'page': page},
    );
    if (data['success'] == false) {
      debugPrint('[NodeSeek] list-comments failed: ${data['message']}');
      return const [];
    }

    return _asMapList(data['comments'])
        .map((raw) {
          final topicId = _asInt(raw['post_id']) ?? _asInt(raw['id']) ?? 0;
          final floor = _asInt(raw['floor_id']) ?? _asInt(raw['floor']);
          return {
            'action_type': UserActionType.reply,
            'topic_id': topicId,
            'title': raw['title']?.toString() ?? '',
            'slug': 'post-$topicId',
            'post_number': floor,
            'created_at':
                raw['created_at']?.toString() ?? raw['time']?.toString(),
            'excerpt':
                raw['text']?.toString() ??
                raw['content']?.toString() ??
                raw['markdown']?.toString(),
          };
        })
        .where((item) => (item['topic_id'] as int) > 0)
        .toList();
  }

  Future<Map<String, dynamic>> _getNodeSeekJson(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dio.get(
      path,
      queryParameters: queryParameters,
      options: Options(
        headers: {
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'X-Requested-With': 'XMLHttpRequest',
        },
        extra: {
          'forceWebViewAdapter': true,
          'skipCfChallenge': true,
          'isSilent': true,
        },
      ),
    );
    final rawData = response.data;
    final data = rawData is String ? jsonDecode(rawData) : rawData;
    if (data is Map) return data.cast<String, dynamic>();
    return const <String, dynamic>{};
  }

  Future<NotificationListResponse> getRecentNotifications() async {
    // 并行获取 reply-to-me 和 at-me 两个频道
    final results = await Future.wait([
      _dio.get(
        '/api/notification/reply-to-me/list',
        options: Options(
          headers: {
            'Accept': 'application/json, text/javascript, */*; q=0.01',
            'X-Requested-With': 'XMLHttpRequest',
          },
          extra: {
            'forceWebViewAdapter': true,
            'skipCfChallenge': true,
            'isSilent': true,
          },
        ),
      ).catchError((e) {
        debugPrint('[NodeSeek] reply-to-me/list failed: $e');
        return Response(
          requestOptions: RequestOptions(),
          data: <String, dynamic>{'success': false, 'data': <dynamic>[]},
        );
      }),
      _dio.get(
        '/api/notification/at-me/list',
        options: Options(
          headers: {
            'Accept': 'application/json, text/javascript, */*; q=0.01',
            'X-Requested-With': 'XMLHttpRequest',
          },
          extra: {
            'forceWebViewAdapter': true,
            'skipCfChallenge': true,
            'isSilent': true,
          },
        ),
      ).catchError((e) {
        debugPrint('[NodeSeek] at-me/list failed: $e');
        return Response(
          requestOptions: RequestOptions(),
          data: <String, dynamic>{'success': false, 'data': <dynamic>[]},
        );
      }),
    ]);

    final replyData = results[0].data is Map
        ? (results[0].data as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final atMeData = results[1].data is Map
        ? (results[1].data as Map).cast<String, dynamic>()
        : <String, dynamic>{};

    // 合并两个频道的原始通知 JSON
    final replyItems = _buildNotificationJsonList(
      replyData,
      notificationType: NotificationType.replied,
    );
    final atMeItems = _buildNotificationJsonList(
      atMeData,
      notificationType: NotificationType.mentioned,
    );

    final allItems = [...replyItems, ...atMeItems];
    // 按 created_at 降序排序
    allItems.sort((a, b) {
      final aTime = a['created_at']?.toString() ?? '';
      final bTime = b['created_at']?.toString() ?? '';
      return bTime.compareTo(aTime);
    });

    return NotificationListResponse.fromJson({
      'notifications': allItems,
      'total_rows_notifications': allItems.length,
      'seen_notification_id': 0,
    });
  }

  Future<Map<String, dynamic>> _getUserDetail(int uid) async {
    final data = await _getNodeSeekJson('/api/account/getInfo/$uid');
    final detail = data['detail'];
    if (detail is Map) return detail.cast<String, dynamic>();
    throw Exception('NodeSeek user not found: $uid');
  }

  _ParsedSearchQuery _parseSearchQuery(String query) {
    var term = query.replaceAll(
      RegExp(r'\border:(relevance|latest|likes|views|latest_topic)\b'),
      ' ',
    );
    String? categorySlug;
    final categoryMatch = RegExp(
      r'(?:^|\s)#([a-z0-9-]+)(?=\s|$)',
    ).firstMatch(term);
    if (categoryMatch != null) {
      categorySlug = categoryMatch.group(1);
    }
    term = term
        .replaceAll(RegExp(r'(?:^|\s)#[a-z0-9:-]+(?=\s|$)'), ' ')
        .replaceAll(RegExp(r'\b(tags|status|before|after|in):\S+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return _ParsedSearchQuery(term: term, categorySlug: categorySlug);
  }

  SearchResult _emptySearchResult(String term) => SearchResult.fromJson({
    'posts': <Map<String, dynamic>>[],
    'topics': <Map<String, dynamic>>[],
    'users': <Map<String, dynamic>>[],
    'grouped_search_result': {'term': term},
  });

  bool _isExternalSearchRedirect(Response<dynamic> response) {
    final status = response.statusCode ?? 0;
    final location = response.headers.value('location') ?? '';
    final realHost = response.realUri.host.toLowerCase();
    final realPath = response.realUri.path.toLowerCase();
    final redirected = status >= 300 && status < 400;
    return (redirected && location.contains('google.')) ||
        realHost.contains('google.') ||
        (realHost.contains('google') && realPath.contains('/search'));
  }

  Map<String, dynamic> _searchPostToJson(SearchPost post) => {
    'id': post.id,
    'topic_id': post.topic?.id,
    'username': post.username,
    'avatar_template': post.avatarTemplate,
    'created_at': post.createdAt.toIso8601String(),
    'like_count': post.likeCount,
    'blurb': post.blurb,
    'post_number': post.postNumber,
    'topic_title_headline': post.topicTitleHeadline,
  };

  Map<String, dynamic> _searchTopicToJson(SearchTopic topic) => {
    'id': topic.id,
    'title': topic.title,
    'slug': topic.slug,
    'category_id': topic.categoryId,
    'tags': topic.tags.map((tag) => tag.name).toList(),
    'posts_count': topic.postsCount,
    'views': topic.views,
    'closed': topic.closed,
    'archived': topic.archived,
  };

  Map<String, dynamic> _searchUserToJson(SearchUser user) => {
    'id': user.id,
    'username': user.username,
    'name': user.name,
    'avatar_template': user.avatarTemplate,
  };

  Future<NotificationListResponse> getNotifications({int? offset}) async {
    if (offset != null && offset > 0) {
      return NotificationListResponse.fromJson({
        'notifications': <Map<String, dynamic>>[],
        'total_rows_notifications': 0,
        'seen_notification_id': 0,
      });
    }
    return getRecentNotifications();
  }

  Future<void> markAllNotificationsRead() async {
    // 使用新版 API：三个频道全部标记已读
    await Future.wait([
      _dio.post(
        '/api/notification/reply-to-me/markViewed',
        queryParameters: {'all': 'true'},
      ),
      _dio.post(
        '/api/notification/at-me/markViewed',
        queryParameters: {'all': 'true'},
      ),
      _dio.post(
        '/api/notification/message/markViewed',
        queryParameters: {'all': 'true'},
      ),
    ].map((f) => f.catchError((e) {
      debugPrint('[NodeSeek] markAllNotificationsRead partial failure: $e');
      return Response(requestOptions: RequestOptions());
    })));
  }

  Future<void> markNotificationRead(int id) async {
    // id 在 fluxseek 中对应 comment_id，使用新版 replys 接口
    await _dio.post(
      '/api/notification/reply-to-me/markViewed',
      data: {
        'replys': [id],
      },
    );
  }

  Future<NodeSeekTopicDetailSsrData?> _getTopicDetailPage(
    int id, {
    int? page,
  }) async {
    final effectivePage = page == null || page < 1 ? 1 : page;
    final response = await getSsrResponse(
      '/post-$id-$effectivePage',
      acceptNotFound: true,
    );
    final data = response.data;
    final html = data is String ? data : data?.toString() ?? '';
    final parsed = parseNodeSeekTopicDetailSsrHtml(html);
    if (parsed != null) return parsed;

    if (response.statusCode == 404 && html.contains('本帖需要注册用户才能查看')) {
      throw Exception('本帖需要注册用户才能查看，请先登录 NodeSeek 后再访问。');
    }
    if (response.statusCode == 404) {
      throw Exception('内容不存在或已被删除。');
    }
    return null;
  }

  int _syntheticPostId(int topicId, int postNumber) {
    return -((topicId * 1000000) + postNumber);
  }

  int _maxPostNumber(List<Post> posts) {
    var maxPostNumber = 0;
    for (final post in posts) {
      if (post.postNumber > maxPostNumber) {
        maxPostNumber = post.postNumber;
      }
    }
    return maxPostNumber;
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  List<Map<String, dynamic>> _asMapList(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is Map) item.cast<String, dynamic>(),
    ];
  }

  List<int> _buildStream(int topicId, List<Post> loadedPosts, int totalPosts) {
    final postIdByNumber = <int, int>{
      for (final post in loadedPosts) post.postNumber: post.id,
    };
    return [
      for (var postNumber = 1; postNumber <= totalPosts; postNumber++)
        postIdByNumber[postNumber] ?? _syntheticPostId(topicId, postNumber),
    ];
  }

  List<Map<String, dynamic>> _buildNotificationJsonList(
    Map<String, dynamic> json, {
    NotificationType notificationType = NotificationType.mentioned,
  }) {
    final rawItems = json['data'];
    final notifications = <Map<String, dynamic>>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is! Map) continue;
        final map = item.cast<String, dynamic>();
        final notificationId = int.tryParse(map['id']?.toString() ?? '');
        final commentId = int.tryParse(map['comment_id']?.toString() ?? '');
        final topicId = int.tryParse(map['post_id']?.toString() ?? '');
        final commenterId = int.tryParse(map['commenter_id']?.toString() ?? '');
        notifications.add({
          'id': notificationId ?? commentId ?? 0,
          'user_id': commenterId ?? 0,
          'notification_type': notificationType.id,
          'read': map['viewed'] == 1 || map['viewed'] == true,
          'high_priority': false,
          'created_at': map['created_at']?.toString(),
          'post_number': int.tryParse(map['floor_id']?.toString() ?? ''),
          'topic_id': topicId,
          'slug': topicId == null ? null : 'post-$topicId',
          'fancy_title': map['title']?.toString(),
          'data': {
            'display_username': map['commenter_name']?.toString(),
            'topic_title': map['title']?.toString(),
          },
        });
      }
    }
    return notifications;
  }
}

class _ParsedSearchQuery {
  const _ParsedSearchQuery({required this.term, required this.categorySlug});

  final String term;
  final String? categorySlug;
}
