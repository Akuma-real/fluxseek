part of '../node_seek_client.dart';

/// 话题相关
mixin _TopicsMixin on _NodeSeekClientBase {
  NodeSeekService get _nodeSeekTopics => NodeSeekService(_dio);

  /// 按 topic_ids 获取话题（对齐网页版 loadBefore 请求）
  Future<TopicListResponse> getTopicsByIds(List<int> topicIds) async {
    return TopicListResponse(topics: [], moreTopicsUrl: null);
  }

  Future<TopicListResponse> getLatestTopics({
    int page = 0,
    String? order,
    bool? ascending,
  }) async {
    if (page == 0 && order == null && ascending == null) {
      final preloadedList = await PreloadedDataService().getInitialTopicList();
      if (preloadedList != null) {
        return preloadedList;
      }
    }

    return _nodeSeekTopics.getLatestTopics(
      page: page,
      order: order,
      ascending: ascending,
    );
  }

  /// 获取话题列表（支持分类和标签筛选）
  Future<TopicListResponse> getFilteredTopics({
    required String filter,
    int? categoryId,
    String? categorySlug,
    String? parentCategorySlug,
    List<String>? tags,
    String? period,
    int page = 0,
    String? order,
    bool? ascending,
  }) async {
    return _nodeSeekTopics.getFilteredTopics(
      categoryId: categoryId,
      categorySlug: categorySlug,
      tags: tags,
      period: period,
      page: page,
      order: order,
      ascending: ascending,
    );
  }

  Future<TopicListResponse> getNewTopics({
    int page = 0,
    String? order,
    bool? ascending,
  }) async {
    return TopicListResponse(topics: [], moreTopicsUrl: null);
  }

  Future<TopicListResponse> getUnreadTopics({
    int page = 0,
    String? order,
    bool? ascending,
  }) async {
    return TopicListResponse(topics: [], moreTopicsUrl: null);
  }

  Future<TopicListResponse> getUnseenTopics({
    int page = 0,
    String? order,
    bool? ascending,
  }) async {
    return TopicListResponse(topics: [], moreTopicsUrl: null);
  }

  Future<TopicListResponse> getHotTopics({
    int page = 0,
    String? order,
    bool? ascending,
  }) async {
    return TopicListResponse(topics: [], moreTopicsUrl: null);
  }

  /// 获取话题详情
  Future<TopicDetail> getTopicDetail(
    int id, {
    int? postNumber,
    bool trackVisit = false,
    String? filter,
    String? usernameFilters,
    bool filterTopLevelReplies = false,
  }) async {
    final page = postNumber == null
        ? null
        : _nodeSeekTopics.pageForPostNumber(id, postNumber);
    final detail = await _nodeSeekTopics.getTopicDetail(id, page: page);
    if (detail != null) return detail;
    throw Exception('NodeSeek topic not found: $id');
  }

  /// 通过 slug 获取话题详情（返回真实的 topic ID）
  Future<TopicDetail> getTopicDetailBySlug(
    String slug, {
    int? postNumber,
    bool trackVisit = false,
  }) async {
    return _nodeSeekTopics.getTopicDetailBySlug(slug);
  }

  /// 批量获取帖子内容
  Future<PostStream> getPosts(int topicId, List<int> postIds) async {
    return PostStream(posts: const [], stream: postIds);
  }

  /// 按帖子编号获取帖子
  Future<PostStream> getPostsByNumber(
    int topicId, {
    required int postNumber,
    required bool asc,
  }) async {
    return _nodeSeekTopics.getPostsByNumber(
      topicId,
      postNumber: postNumber,
      asc: asc,
    );
  }

  Future<TopicListResponse> getTopTopics() async {
    return TopicListResponse(topics: [], moreTopicsUrl: null);
  }

  Future<TopicListResponse> getCategoryTopics(String categorySlug) async {
    return _nodeSeekTopics.getFilteredTopics(categorySlug: categorySlug);
  }

  /// 创建话题
  Future<int> createTopic({
    required String title,
    required String raw,
    required int categoryId,
    List<String>? tags,
  }) async {
    final categorySlug = await _nodeSeekTopics.categorySlug(categoryId);
    if (categorySlug == null || categorySlug.isEmpty) {
      throw Exception('NodeSeek category not found: $categoryId');
    }
    final response = await _dio.post(
      '/api/content/new-discussion',
      data: {
        'content': raw,
        'mode': 'new-discussion',
        'title': title,
        'category': categorySlug,
        'rank': 0,
      },
    );
    final data = response.data;
    if (data is Map && data['success'] == false) {
      throw Exception(
        data['message']?.toString() ?? S.current.error_createTopicFailed,
      );
    }
    final redirect = data is Map ? data['redirect']?.toString() : null;
    final match = redirect == null
        ? null
        : RegExp(r'/post-(\d+)').firstMatch(redirect);
    final postId = match == null ? null : int.tryParse(match[1]!);
    if (postId != null) return postId;
    throw Exception(S.current.error_unknownResponseFormat);
  }

  /// 忽略新话题
  Future<void> dismissNewTopics({int? categoryId}) async {
    return;
  }

  /// 忽略未读话题
  Future<void> dismissUnreadTopics({int? categoryId}) async {
    return;
  }

  /// 设置话题订阅级别
  Future<void> setTopicNotificationLevel(
    int topicId,
    TopicNotificationLevel level,
  ) async {
    return;
  }

  /// 更新话题元数据
  Future<void> updateTopic({
    required int topicId,
    String? title,
    int? categoryId,
    List<String>? tags,
  }) async {
    _unsupportedNodeSeekFeature('单独更新话题元数据');
  }

  /// 获取话题 AI 摘要
  Future<TopicSummary?> getTopicSummary(
    int topicId, {
    bool skipAgeCheck = false,
  }) async {
    return null;
  }

  /// 获取话题主贴的 HTML 内容（轻量请求，只解析第一楼）
  Future<String?> getTopicFirstPostCooked(int topicId) async {
    final detail = await _nodeSeekTopics.getTopicDetail(topicId);
    return detail?.postStream.posts.firstOrNull?.cooked;
  }
}
