// 用户操作记录
import '../utils/time_utils.dart';

/// 用户操作类型
class UserActionType {
  static const int like = 1; // 点赞
  static const int wasLiked = 2; // 被点赞
  static const int newTopic = 4; // 创建话题
  static const int reply = 5; // 回复
}

class UserAction {
  final int? actionType;
  final int topicId;
  final String title;
  final String? slug;
  final int? postNumber;
  final String? username;
  final String? avatarTemplate;
  final DateTime? actingAt;
  final int? categoryId;
  final String? excerpt;

  const UserAction({
    this.actionType,
    required this.topicId,
    required this.title,
    this.slug,
    this.postNumber,
    this.username,
    this.avatarTemplate,
    this.actingAt,
    this.categoryId,
    this.excerpt,
  });

  factory UserAction.fromJson(Map<String, dynamic> json) {
    return UserAction(
      actionType: json['action_type'] as int?,
      topicId: json['topic_id'] as int,
      title: json['title'] as String? ?? '',
      slug: json['slug'] as String?,
      postNumber: json['post_number'] as int?,
      username:
          json['acting_username'] as String? ?? json['username'] as String?,
      avatarTemplate:
          json['acting_avatar_template'] as String? ??
          json['avatar_template'] as String?,
      actingAt: TimeUtils.parseUtcTime(
        json['acting_at'] as String? ?? json['created_at'] as String?,
      ),
      categoryId: json['category_id'] as int?,
      excerpt: json['excerpt'] as String?,
    );
  }

  String getAvatarUrl({int size = 120}) {
    if (avatarTemplate == null) return '';
    return avatarTemplate!.replaceAll('{size}', '$size');
  }
}

class UserActionResponse {
  final List<UserAction> actions;

  const UserActionResponse({required this.actions});

  factory UserActionResponse.fromJson(Map<String, dynamic> json) {
    final actionsJson = json['user_actions'] as List<dynamic>? ?? [];
    return UserActionResponse(
      actions: actionsJson
          .map((e) => UserAction.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
