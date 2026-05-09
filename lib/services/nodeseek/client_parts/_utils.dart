part of '../node_seek_client.dart';

/// 工具方法
mixin _UtilsMixin on _NodeSeekClientBase {
  /// 获取所有表情列表
  Future<Map<String, List<Emoji>>> getEmojis() async {
    if (NodeSeekService.isOfficialHost) {
      return const {};
    }

    try {
      final response = await _dio.get('/emojis.json');
      final data = response.data as Map<String, dynamic>;

      final Map<String, List<Emoji>> emojiGroups = {};

      data.forEach((group, emojis) {
        if (emojis is List) {
          emojiGroups[group] = emojis
              .map((e) => Emoji.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      });

      return emojiGroups;
    } catch (e) {
      if (e is DioException) {
        throw _handleDioError(e);
      }
      rethrow;
    }
  }

  /// 创建私信（NodeSeek 使用 /api/notification/message/send）
  Future<int> createPrivateMessage({
    required List<String> targetUsernames,
    required String title,
    required String raw,
  }) async {
    if (NodeSeekService.isOfficialHost) {
      // NodeSeek 私信需要 receiverUid，尝试从用户名解析
      // 由于 NodeSeek 私信不支持多人，取第一个目标用户
      if (targetUsernames.isEmpty) {
        throw Exception(S.current.error_sendPMFailed);
      }
      final targetUsername = targetUsernames.first;
      // 通过搜索获取 uid
      final users = await NodeSeekService(_dio).searchMembers(targetUsername);
      final targetUser = users.where((u) => u.username == targetUsername).firstOrNull;
      if (targetUser == null) {
        throw Exception('无法找到用户: $targetUsername');
      }
      final response = await _dio.post(
        '/api/notification/message/send',
        data: {
          'receiverUid': targetUser.id,
          'content': raw,
          'markdown': true,
        },
      );
      final respData = response.data;
      if (respData is Map && respData['success'] == false) {
        throw Exception(respData['message']?.toString() ?? S.current.error_sendPMFailed);
      }
      // NodeSeek 私信没有 topic_id 概念，返回目标用户 id 作为会话标识
      return targetUser.id;
    }

    final data = <String, dynamic>{
      'title': title,
      'raw': raw,
      'archetype': 'private_message',
      'target_recipients': targetUsernames.join(','),
    };

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
        respData['post']['topic_id'] != null) {
      return respData['post']['topic_id'] as int;
    }

    if (respData is Map && respData['topic_id'] != null) {
      return respData['topic_id'] as int;
    }

    if (respData is Map && respData['success'] == false) {
      final errors = respData['errors'];
      final msg = errors is List ? errors.join('\n') : errors?.toString();
      throw Exception(msg ?? S.current.error_sendPMFailed);
    }

    throw Exception(S.current.error_unknownResponseFormat);
  }

  /// 阅读计时（NodeSeek 无对应接口，返回 null）
  Future<int?> topicsTimings({
    required int topicId,
    required int topicTime,
    required Map<int, int> timings,
    Map<String, dynamic>? logContext,
  }) async {
    return null;
  }

  /// 获取预加载的话题追踪元数据（NodeSeek 无对应接口）
  Future<Map<String, dynamic>?> getPreloadedTopicTrackingMeta() async {
    return null;
  }
}
