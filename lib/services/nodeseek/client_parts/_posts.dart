part of '../node_seek_client.dart';

/// 帖子相关
mixin _PostsMixin on _NodeSeekClientBase {
  NodeSeekService get _nodeSeekPosts => NodeSeekService(_dio);
  bool get _isOfficialNodeSeekHost => NodeSeekService.isOfficialHost;

  /// 创建回复
  Future<Post> createReply({
    required int topicId,
    required String raw,
    int? replyToPostNumber,
  }) async {
    if (_isOfficialNodeSeekHost) {
      final response = await _dio.post(
        '/api/content/new-comment',
        data: {'content': raw, 'mode': 'new-comment', 'postId': topicId},
        options: Options(
          contentType: Headers.jsonContentType,
          headers: {
            'Accept': '*/*',
            'X-Requested-With': null,
            'Referer': '${AppConstants.baseUrl}/post-$topicId-1',
            'Origin': AppConstants.baseUrl,
            'Sec-Fetch-Dest': 'empty',
            'Sec-Fetch-Mode': 'cors',
            'Sec-Fetch-Site': 'same-origin',
            'csrf-token': _newNodeSeekContentCsrfToken(),
          },
          extra: {'skipCsrf': true, 'skipWebViewAdapter': true},
        ),
      );
      final respData = response.data;
      if (respData is Map && respData['success'] == false) {
        throw Exception(
          respData['message']?.toString() ?? S.current.error_replyFailed,
        );
      }

      final hash = respData is Map
          ? respData['redirectHash']?.toString()
          : null;
      final postNumber = hash == null
          ? null
          : int.tryParse(hash.replaceFirst('#', ''));
      if (postNumber != null) {
        final stream = await _nodeSeekPosts.getPostsByNumber(
          topicId,
          postNumber: postNumber,
          asc: true,
        );
        final matched = stream.posts
            .where((post) => post.postNumber == postNumber)
            .firstOrNull;
        if (matched != null) return matched;
      }

      final detail = await _nodeSeekPosts.getTopicDetail(topicId);
      final posts = detail?.postStream.posts ?? const <Post>[];
      if (posts.isNotEmpty) return posts.last;
      throw Exception(S.current.error_unknownResponseFormat);
    }

    final data = <String, dynamic>{'topic_id': topicId, 'raw': raw};

    if (replyToPostNumber != null) {
      data['reply_to_post_number'] = replyToPostNumber;
    }

    try {
      final response = await _dio.post(
        '/posts.json',
        data: data,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final respData = response.data;

      // 帖子进入审核队列
      if (respData is Map && respData['action'] == 'enqueued') {
        throw PostEnqueuedException(
          pendingCount: respData['pending_count'] as int? ?? 0,
        );
      }

      if (respData is Map &&
          respData.containsKey('post') &&
          respData['post'] != null) {
        return Post.fromJson(respData['post'] as Map<String, dynamic>);
      }

      if (respData is Map && respData['id'] != null) {
        return Post.fromJson(respData as Map<String, dynamic>);
      }

      if (respData is Map && respData['success'] == false) {
        final errors = respData['errors'];
        final msg = errors is List ? errors.join('\n') : errors?.toString();
        throw Exception(msg ?? S.current.error_replyFailed);
      }

      throw Exception(S.current.error_unknownResponseFormat);
    } on DioException catch (e) {
      _throwApiError(e);
    }
  }

  String _newNodeSeekContentCsrfToken() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return String.fromCharCodes(
      List<int>.generate(
        16,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
        growable: false,
      ),
    );
  }

  /// 点赞帖子
  Future<void> likePost(int postId) async {
    if (_isOfficialNodeSeekHost) {
      await _dio.post(
        '/api/statistics/like',
        data: {'commentId': postId, 'action': 'add'},
      );
      return;
    }

    try {
      await _dio.post(
        '/post_actions',
        data: {'id': postId, 'post_action_type_id': 2},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
    } on DioException catch (e) {
      _throwApiError(e);
    }
  }

  /// 取消点赞
  Future<void> unlikePost(int postId) async {
    if (_isOfficialNodeSeekHost) {
      await _dio.post(
        '/api/statistics/like',
        data: {'commentId': postId, 'action': 'remove'},
      );
      return;
    }

    try {
      await _dio.delete(
        '/post_actions/$postId',
        queryParameters: {'post_action_type_id': 2},
      );
    } on DioException catch (e) {
      _throwApiError(e);
    }
  }

  /// 切换踩
  Future<void> toggleDislike(int postId, {required bool add}) async {
    await _dio.post(
      '/api/statistics/dislike',
      data: {'commentId': postId, 'action': add ? 'add' : 'remove'},
    );
  }

  /// 切换给鸡腿（upvote）
  Future<void> toggleUpvote(int postId, {required bool add}) async {
    await _dio.post(
      '/api/statistics/upvote',
      data: {'commentId': postId, 'action': add ? 'add' : 'remove'},
    );
  }

  /// 获取帖子的回复历史
  Future<List<Post>> getPostReplyHistory(int postId) async {
    if (_isOfficialNodeSeekHost) {
      return [];
    }

    final response = await _dio.get('/posts/$postId/reply-history');
    final data = response.data as List<dynamic>;
    return data.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 获取帖子的回复列表
  Future<List<Post>> getPostReplies(int postId, {int after = 1}) async {
    if (_isOfficialNodeSeekHost) {
      return [];
    }

    final response = await _dio.get(
      '/posts/$postId/replies',
      queryParameters: {'after': after},
    );
    final data = response.data as List<dynamic>;
    return data.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 通过话题 ID 和楼层编号获取单个帖子
  Future<Post> getPostByNumber(int topicId, int postNumber) async {
    if (_isOfficialNodeSeekHost) {
      final stream = await _nodeSeekPosts.getPostsByNumber(
        topicId,
        postNumber: postNumber,
        asc: true,
      );
      final matched = stream.posts
          .where((post) => post.postNumber == postNumber)
          .firstOrNull;
      if (matched != null) return matched;
      _unsupportedNodeSeekFeature('按楼层获取未加载评论');
    }

    final response = await _dio.get('/posts/by_number/$topicId/$postNumber');
    final data = response.data as Map<String, dynamic>;
    return Post.fromJson(data);
  }

  /// 获取帖子所有层级回复的 ID 列表（递归查询）
  Future<List<int>> getPostReplyIds(int postId) async {
    if (_isOfficialNodeSeekHost) {
      return [];
    }

    final response = await _dio.get('/posts/$postId/reply-ids.json');
    final data = response.data as List<dynamic>;
    return data.map((e) => (e as Map<String, dynamic>)['id'] as int).toList();
  }

  /// 获取单个帖子完整数据（用于 MessageBus 刷新）
  Future<Post> getPost(int postId) async {
    if (_isOfficialNodeSeekHost) {
      _unsupportedNodeSeekFeature('按评论 ID 获取评论');
    }

    final response = await _dio.get('/posts/$postId.json');
    final data = response.data as Map<String, dynamic>;
    return Post.fromJson(data);
  }

  /// 获取帖子原始内容
  Future<String?> getPostRaw(int postId) async {
    if (_isOfficialNodeSeekHost) {
      return null;
    }

    try {
      final response = await _dio.get('/posts/$postId.json');
      final data = response.data as Map<String, dynamic>?;
      return data?['raw'] as String?;
    } catch (e) {
      debugPrint('[NodeSeekClient] getPostRaw failed: $e');
      return null;
    }
  }

  /// 更新帖子内容
  /// 更新帖子内容
  ///
  /// NodeSeek 区分楼主帖（`edit-discussion`，可带 title/rank）和普通评论
  /// （`edit-comment`，仅带 content）。通过 [isTopic] / [topicId] 区分：
  /// - [isTopic] = true 时走 `edit-discussion`，需要 [title]（或保持不变）。
  /// - 默认走 `edit-comment`。
  Future<Post> updatePost({
    required int postId,
    required String raw,
    String? editReason,
    bool isTopic = false,
    String? title,
    int? rank,
  }) async {
    if (_isOfficialNodeSeekHost) {
      final Map<String, dynamic> payload;
      if (isTopic) {
        payload = <String, dynamic>{
          'content': raw,
          'mode': 'edit-discussion',
          'postId': postId,
          'title': ?title,
          'rank': ?rank,
        };
      } else {
        payload = <String, dynamic>{
          'content': raw,
          'mode': 'edit-comment',
          'commentId': postId,
        };
      }
      final response = await _dio.post(
        isTopic ? '/api/content/edit-discussion' : '/api/content/edit-comment',
        data: payload,
      );
      final respData = response.data;
      if (respData is Map && respData['success'] == false) {
        throw Exception(
          respData['message']?.toString() ?? S.current.error_updatePostFailed,
        );
      }
      // NodeSeek 编辑接口不返回完整评论对象，用 SSR 详情刷新
      // （先按 postId 拉流，再筛出对应 id）
      try {
        final detail = await _nodeSeekPosts.getTopicDetail(
          isTopic ? postId : 0,
        );
        final matched = detail?.postStream.posts
            .where((p) => p.id == postId)
            .firstOrNull;
        if (matched != null) return matched;
      } catch (_) {
        // 忽略刷新失败，直接抛出最通用的成功占位
      }
      // 占位返回，调用方如需最新内容应重新拉列表
      return Post.fromJson({
        'id': postId,
        'post_number': isTopic ? 1 : 0,
        'raw': raw,
        'cooked': raw,
      });
    }

    try {
      final data = <String, dynamic>{'post[raw]': raw};
      if (editReason != null && editReason.isNotEmpty) {
        data['post[edit_reason]'] = editReason;
      }

      final response = await _dio.put(
        '/posts/$postId.json',
        data: data,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final respData = response.data;
      if (respData is Map && respData['post'] != null) {
        return Post.fromJson(respData['post'] as Map<String, dynamic>);
      }
      throw Exception(S.current.error_updatePostFailed);
    } on DioException catch (e) {
      _throwApiError(e);
    }
  }

  /// 添加话题书签
  Future<int> bookmarkTopic(
    int topicId, {
    String? name,
    DateTime? reminderAt,
    int? autoDeletePreference,
  }) async {
    if (_isOfficialNodeSeekHost) {
      await _dio.post(
        '/api/statistics/collection',
        data: {'postId': topicId, 'action': 'add'},
      );
      return topicId;
    }

    try {
      final data = <String, dynamic>{
        'bookmarkable_id': topicId,
        'bookmarkable_type': 'Topic',
      };
      if (name != null && name.isNotEmpty) {
        data['name'] = name;
      }
      if (reminderAt != null) {
        data['reminder_at'] = reminderAt.toUtc().toIso8601String();
      }
      if (autoDeletePreference != null) {
        data['auto_delete_preference'] = autoDeletePreference;
      }

      final response = await _dio.post(
        '/bookmarks.json',
        data: data,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final respData = response.data;
      if (respData is Map && respData['id'] != null) {
        return respData['id'] as int;
      }
      throw Exception(S.current.error_unrecognizedDataFormat);
    } on DioException catch (e) {
      _throwApiError(e);
    }
  }

  /// 添加帖子书签
  Future<int> bookmarkPost(
    int postId, {
    String? name,
    DateTime? reminderAt,
    int? autoDeletePreference,
  }) async {
    if (_isOfficialNodeSeekHost) {
      await _dio.post(
        '/api/statistics/collection',
        data: {'postId': postId, 'action': 'add'},
      );
      return postId;
    }

    try {
      final data = <String, dynamic>{
        'bookmarkable_id': postId,
        'bookmarkable_type': 'Post',
      };
      if (name != null && name.isNotEmpty) {
        data['name'] = name;
      }
      if (reminderAt != null) {
        data['reminder_at'] = reminderAt.toUtc().toIso8601String();
      }
      if (autoDeletePreference != null) {
        data['auto_delete_preference'] = autoDeletePreference;
      }

      final response = await _dio.post(
        '/bookmarks.json',
        data: data,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final respData = response.data;
      if (respData is Map && respData['id'] != null) {
        return respData['id'] as int;
      }
      throw Exception(S.current.error_unrecognizedDataFormat);
    } on DioException catch (e) {
      _throwApiError(e);
    }
  }

  /// 更新书签
  Future<void> updateBookmark(
    int bookmarkId, {
    String? name,
    DateTime? reminderAt,
    int? autoDeletePreference,
  }) async {
    if (_isOfficialNodeSeekHost) {
      return;
    }

    try {
      final data = <String, dynamic>{};
      // name 传空字符串表示清除
      if (name != null) {
        data['name'] = name;
      }
      if (reminderAt != null) {
        data['reminder_at'] = reminderAt.toUtc().toIso8601String();
      }
      if (autoDeletePreference != null) {
        data['auto_delete_preference'] = autoDeletePreference;
      }

      await _dio.put(
        '/bookmarks/$bookmarkId.json',
        data: data,
        options: Options(contentType: Headers.jsonContentType),
      );
    } on DioException catch (e) {
      _throwApiError(e);
    }
  }

  /// 清除书签提醒
  Future<void> clearBookmarkReminder(int bookmarkId) async {
    if (_isOfficialNodeSeekHost) {
      return;
    }

    try {
      await _dio.put(
        '/bookmarks/bulk.json',
        data: {
          'bookmark_ids': [bookmarkId],
          'operation': {'type': 'clear_reminder'},
        },
        options: Options(contentType: Headers.jsonContentType),
      );
    } on DioException catch (e) {
      _throwApiError(e);
    }
  }

  /// 删除书签
  Future<void> deleteBookmark(int bookmarkId) async {
    if (_isOfficialNodeSeekHost) {
      await _dio.post(
        '/api/statistics/collection',
        data: {'postId': bookmarkId, 'action': 'remove'},
      );
      return;
    }

    try {
      await _dio.delete('/bookmarks/$bookmarkId.json');
    } on DioException catch (e) {
      _throwApiError(e);
    }
  }

  /// 举报帖子
  Future<void> flagPost(int postId, int flagTypeId, {String? message}) async {
    if (_isOfficialNodeSeekHost) {
      _unsupportedNodeSeekFeature('举报评论');
    }

    try {
      final data = <String, dynamic>{
        'id': postId,
        'post_action_type_id': flagTypeId,
      };
      if (message != null && message.isNotEmpty) {
        data['message'] = message;
      }

      await _dio.post(
        '/post_actions',
        data: data,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
    } on DioException catch (e) {
      _throwApiError(e);
    }
  }

  /// 获取可用的举报类型
  Future<List<FlagType>> getFlagTypes() async {
    if (_isOfficialNodeSeekHost) {
      return FlagType.defaultTypes;
    }

    try {
      final response = await _dio.get('/post_action_types.json');
      final data = response.data;
      if (data is Map && data['post_action_types'] != null) {
        return (data['post_action_types'] as List)
            .map((e) => FlagType.fromJson(e as Map<String, dynamic>))
            .where((f) => f.isFlag)
            .toList();
      }
      return FlagType.defaultTypes;
    } catch (e) {
      debugPrint('[NodeSeekClient] getFlagTypes failed: $e');
      return FlagType.defaultTypes;
    }
  }

  /// 接受答案
  Future<Map<String, dynamic>> acceptAnswer(int postId) async {
    if (_isOfficialNodeSeekHost) {
      _unsupportedNodeSeekFeature('接受答案');
    }

    try {
      final response = await _dio.post(
        '/solution/accept',
        data: {'id': postId},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _throwApiError(e);
    }
  }

  /// 取消接受答案
  Future<void> unacceptAnswer(int postId) async {
    if (_isOfficialNodeSeekHost) {
      _unsupportedNodeSeekFeature('取消接受答案');
    }

    try {
      await _dio.post(
        '/solution/unaccept',
        data: {'id': postId},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
    } on DioException catch (e) {
      _throwApiError(e);
    }
  }

  /// 删除帖子
  ///
  /// [isTopic] 为 true 时删除整个话题（NodeSeek 使用 delete-discussion），
  /// 否则只删除评论/回复（delete-comment）。
  Future<void> deletePost(int postId, {bool isTopic = false}) async {
    if (_isOfficialNodeSeekHost) {
      if (isTopic) {
        await _dio.post(
          '/api/content/delete-discussion',
          data: {'mode': 'delete-discussion', 'postId': postId},
        );
      } else {
        await _dio.post(
          '/api/content/delete-comment',
          data: {'mode': 'delete-comment', 'commentId': postId},
        );
      }
      return;
    }

    try {
      await _dio.delete('/posts/$postId.json');
    } on DioException catch (e) {
      _throwApiError(e);
    }
  }

  /// 恢复已删除的帖子
  Future<void> recoverPost(int postId) async {
    if (_isOfficialNodeSeekHost) {
      _unsupportedNodeSeekFeature('恢复已删除评论');
    }

    try {
      await _dio.put('/posts/$postId/recover.json');
    } on DioException catch (e) {
      _throwApiError(e);
    }
  }

  /// 获取帖子回应人列表
  /// 获取隐藏帖子的原始 cooked 内容
  Future<String> getPostCooked(int postId) async {
    if (_isOfficialNodeSeekHost) {
      _unsupportedNodeSeekFeature('获取隐藏评论内容');
    }

    final response = await _dio.get('/posts/$postId/cooked.json');
    return (response.data as Map<String, dynamic>)['cooked'] as String;
  }

  /// 追踪链接点击
  void trackClick({
    required String url,
    required int postId,
    required int topicId,
  }) {
    if (_isOfficialNodeSeekHost) {
      return;
    }

    _dio
        .post(
          '/clicks/track',
          data: {'url': url, 'post_id': postId, 'topic_id': topicId},
          options: Options(contentType: Headers.formUrlEncodedContentType),
        )
        .catchError((e) {
          debugPrint('[NodeSeekClient] trackClick failed: $e');
          return Response(requestOptions: RequestOptions());
        });
  }
}
