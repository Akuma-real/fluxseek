import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants.dart';
import '../../services/message_bus_service.dart';
import '../../utils/time_utils.dart';
import 'message_bus_service_provider.dart';
import 'models.dart';
import 'topic_tracking_providers.dart';

bool get _isOfficialNodeSeekHost =>
    Uri.tryParse(AppConstants.baseUrl)?.host == 'www.nodeseek.com';

/// 话题频道监听器
/// 监听新回复和正在输入的用户
class TopicChannelNotifier extends Notifier<TopicChannelState> {
  TopicChannelNotifier(this.topicId);
  final int topicId;

  @override
  TopicChannelState build() {
    // 确保 MessageBus 已 configure（域名配置），避免用主站域名轮询
    ref.watch(messageBusInitProvider);
    if (_isOfficialNodeSeekHost) {
      debugPrint('[TopicChannel] NodeSeek 非旧论坛接口，跳过 MessageBus 订阅');
      return const TopicChannelState();
    }

    final messageBus = ref.watch(messageBusServiceProvider);
    final topicChannel = '/topic/$topicId';
    final reactionsChannel = '/topic/$topicId/reactions';

    void onTopicMessage(MessageBusMessage message) {
      final data = message.data;
      if (data is! Map<String, dynamic>) return;

      // 1. reload_topic 消息（话题状态变更：关闭/打开/固定等）
      final reloadTopic = data['reload_topic'] as bool? ?? false;
      if (reloadTopic) {
        final refreshStream = data['refresh_stream'] as bool? ?? false;
        debugPrint('[TopicChannel] reload_topic, refreshStream=$refreshStream');
        state = state.copyWith(
          reloadRequested: true,
          refreshStreamRequested: refreshStream,
        );
        return;
      }

      // 2. notification_level_change（通知级别变更）
      final notifLevel = data['notification_level_change'] as int?;
      if (notifLevel != null) {
        debugPrint('[TopicChannel] notification_level_change: $notifLevel');
        state = state.copyWith(notificationLevelChange: notifLevel);
        return;
      }

      final type = data['type'] as String?;
      final postId = data['id'] as int?;
      final updatedAtStr = data['updated_at'] as String?;
      final updatedAt = TimeUtils.parseUtcTime(updatedAtStr) ?? DateTime.now();

      debugPrint('[TopicChannel] 收到消息: type=$type, postId=$postId');

      switch (type) {
        case 'created':
          state = state.copyWith(hasNewReplies: true);
          if (postId != null) {
            final createdUserId = data['user_id'] as int?;
            _addPostUpdate(
              postId,
              TopicMessageType.created,
              updatedAt,
              userId: createdUserId,
            );
          }
          break;

        case 'revised':
        case 'rebaked':
          if (postId != null) {
            final msgType = type == 'revised'
                ? TopicMessageType.revised
                : TopicMessageType.rebaked;
            _addPostUpdate(postId, msgType, updatedAt);
          }
          break;

        case 'deleted':
          if (postId != null) {
            _addPostUpdate(postId, TopicMessageType.deleted, updatedAt);
          }
          break;

        case 'destroyed':
          if (postId != null) {
            _addPostUpdate(postId, TopicMessageType.destroyed, updatedAt);
          }
          break;

        case 'recovered':
          if (postId != null) {
            _addPostUpdate(postId, TopicMessageType.recovered, updatedAt);
          }
          break;

        case 'acted':
          if (postId != null) {
            _addPostUpdate(postId, TopicMessageType.acted, updatedAt);
          }
          break;

        case 'liked':
        case 'unliked':
          if (postId != null) {
            final likesCount = data['likes_count'] as int?;
            final userId = data['user_id'] as int?;
            final msgType = type == 'liked'
                ? TopicMessageType.liked
                : TopicMessageType.unliked;
            _addPostUpdate(
              postId,
              msgType,
              updatedAt,
              likesCount: likesCount,
              userId: userId,
            );
          }
          break;

        case 'read':
          if (postId != null) {
            final readersCount = data['readers_count'] as int?;
            _addPostUpdate(
              postId,
              TopicMessageType.read,
              updatedAt,
              readersCount: readersCount,
            );
          }
          break;

        case 'stats':
          final postsCount = data['posts_count'] as int?;
          final likeCount = data['like_count'] as int?;
          final lastPostedAtStr = data['last_posted_at'] as String?;
          final lastPostedAt = TimeUtils.parseUtcTime(lastPostedAtStr);

          state = state.copyWith(
            statsUpdate: TopicStatsUpdate(
              postsCount: postsCount,
              likeCount: likeCount,
              lastPostedAt: lastPostedAt,
            ),
          );
          break;

        case 'move_to_inbox':
          state = state.copyWith(messageArchived: false);
          break;

        case 'archived':
          state = state.copyWith(messageArchived: true);
          break;

        case 'remove_allowed_user':
          debugPrint('[TopicChannel] 用户被移出私信');
          break;

        default:
          debugPrint('[TopicChannel] 未知消息类型: $type');
      }
    }

    void onReactionsMessage(MessageBusMessage message) {
      final data = message.data;
      if (data is! Map<String, dynamic>) return;

      final postId = data['post_id'] as int?;
      if (postId == null) return;

      debugPrint('[TopicChannel] 收到 reactions 消息: postId=$postId');
      _addPostUpdate(postId, TopicMessageType.acted, DateTime.now());
    }

    messageBus.subscribe(topicChannel, onTopicMessage);
    messageBus.subscribe(reactionsChannel, onReactionsMessage);

    ref.onDispose(() {
      messageBus.unsubscribe(topicChannel, onTopicMessage);
      messageBus.unsubscribe(reactionsChannel, onReactionsMessage);
    });

    return const TopicChannelState();
  }

  void clearNewReplies() {
    state = state.copyWith(hasNewReplies: false);
  }

  void clearReloadRequest() {
    state = state.copyWith(
      reloadRequested: false,
      refreshStreamRequested: false,
    );
  }

  void clearNotificationLevelChange() {
    state = state.copyWith(clearNotificationLevelChange: true);
  }

  void _addPostUpdate(
    int postId,
    TopicMessageType type,
    DateTime updatedAt, {
    int? likesCount,
    int? readersCount,
    int? userId,
  }) {
    // 去重：如果最近 2 秒内已有相同 postId + type 的更新，跳过
    final updates = List<PostUpdate>.from(state.postUpdates);
    if (updates.isNotEmpty) {
      final last = updates.last;
      if (last.postId == postId &&
          last.type == type &&
          updatedAt.difference(last.updatedAt).inSeconds.abs() < 2) {
        return;
      }
    }

    final update = PostUpdate(
      postId: postId,
      type: type,
      updatedAt: updatedAt,
      likesCount: likesCount,
      readersCount: readersCount,
      userId: userId,
    );

    updates.add(update);
    if (updates.length > 50) {
      updates.removeAt(0);
    }

    state = state.copyWith(postUpdates: updates);
  }

  void clearPostUpdates() {
    state = state.copyWith(postUpdates: []);
  }

  void clearStatsUpdate() {
    state = state.copyWith(clearStatsUpdate: true);
  }

}

final topicChannelProvider = NotifierProvider.family
    .autoDispose<TopicChannelNotifier, TopicChannelState, int>(
      TopicChannelNotifier.new,
    );
