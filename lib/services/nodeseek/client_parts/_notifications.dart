part of '../node_seek_client.dart';

/// 通知相关
mixin _NotificationsMixin on _NodeSeekClientBase {
  NodeSeekService get _nodeSeekNotifications => NodeSeekService(_dio);

  bool get _isOfficialNodeSeekHost {
    return NodeSeekService.isOfficialHost;
  }

  /// 获取最近通知（recent 模式，非分页，用于快捷面板）
  /// 会触发服务端 bump_last_seen_notification，重置未读计数
  Future<NotificationListResponse> getRecentNotifications() async {
    if (_isOfficialNodeSeekHost) {
      return _nodeSeekNotifications.getRecentNotifications();
    }

    final response = await _dio.get(
      '/notifications',
      queryParameters: {
        'recent': true,
        'limit': 30,
        'bump_last_seen_reviewable': true,
      },
    );
    return NotificationListResponse.fromJson(response.data);
  }

  /// 获取通知列表（默认模式，支持完整分页）
  Future<NotificationListResponse> getNotifications({int? offset}) async {
    if (_isOfficialNodeSeekHost) {
      return _nodeSeekNotifications.getNotifications(offset: offset);
    }

    final queryParams = <String, dynamic>{'limit': 60};
    if (offset != null) {
      queryParams['offset'] = offset;
    }

    final response = await _dio.get(
      '/notifications',
      queryParameters: queryParams,
    );
    return NotificationListResponse.fromJson(response.data);
  }

  /// 标记所有通知为已读
  Future<void> markAllNotificationsRead() async {
    if (_isOfficialNodeSeekHost) {
      await _nodeSeekNotifications.markAllNotificationsRead();
      return;
    }

    await _dio.put('/notifications/mark-read');
  }

  /// 标记单条通知为已读
  Future<void> markNotificationRead(int id) async {
    if (_isOfficialNodeSeekHost) {
      await _nodeSeekNotifications.markNotificationRead(id);
      return;
    }

    await _dio.put('/notifications/mark-read', data: {'id': id});
  }
}
