import 'package:flutter/material.dart';
import '../../../../l10n/s.dart';
import '../../../../models/topic.dart';

/// 帖子底部操作栏（NodeSeek 四种互动：赞 / 给鸡腿 / 踩 / 回复）
class PostActionBar extends StatelessWidget {
  final Post post;
  final bool isGuest;
  final bool isOwnPost;
  final bool isLiking;
  final bool liked;
  final bool disliked;
  final bool upvoted;
  final int likeCount;
  final int dislikeCount;
  final int upvoteCount;
  final GlobalKey likeButtonKey;
  final List<Post> replies;
  final ValueNotifier<bool> isLoadingRepliesNotifier;
  final ValueNotifier<bool> showRepliesNotifier;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleDislike;
  final VoidCallback onToggleUpvote;
  final VoidCallback? onReply;
  final VoidCallback onShowMoreMenu;
  final VoidCallback onToggleReplies;
  final bool hideRepliesButton;

  const PostActionBar({
    super.key,
    required this.post,
    required this.isGuest,
    required this.isOwnPost,
    required this.isLiking,
    required this.liked,
    required this.disliked,
    required this.upvoted,
    required this.likeCount,
    required this.dislikeCount,
    required this.upvoteCount,
    required this.likeButtonKey,
    required this.replies,
    required this.isLoadingRepliesNotifier,
    required this.showRepliesNotifier,
    required this.onToggleLike,
    required this.onToggleDislike,
    required this.onToggleUpvote,
    this.onReply,
    required this.onShowMoreMenu,
    required this.onToggleReplies,
    this.hideRepliesButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        // 回复数按钮
        if (post.replyCount > 0 && !hideRepliesButton)
          ValueListenableBuilder<bool>(
            valueListenable: isLoadingRepliesNotifier,
            builder: (context, isLoadingReplies, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: showRepliesNotifier,
                builder: (context, showReplies, _) {
                  return GestureDetector(
                    onTap: isLoadingReplies ? null : onToggleReplies,
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: showReplies
                            ? theme.colorScheme.primaryContainer.withValues(
                                alpha: 0.3,
                              )
                            : theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: showReplies
                              ? theme.colorScheme.primary.withValues(alpha: 0.2)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isLoadingReplies && replies.isEmpty)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else ...[
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 15,
                              color: showReplies
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${post.replyCount}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: showReplies
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              showReplies
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              size: 18,
                              color: showReplies
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),

        const Spacer(),
        if (!isGuest) ...[
          // 赞按钮
          _ActionButton(
            key: likeButtonKey,
            icon: liked ? Icons.favorite : Icons.favorite_border,
            count: likeCount,
            active: liked,
            activeColor: theme.colorScheme.error,
            onTap: isOwnPost ? null : (isLiking ? null : onToggleLike),
            tooltip: '赞',
          ),
          const SizedBox(width: 4),
          // 给鸡腿按钮
          _ActionButton(
            icon: upvoted
                ? Icons.thumb_up
                : Icons.thumb_up_outlined,
            count: upvoteCount,
            active: upvoted,
            activeColor: Colors.orange,
            onTap: isOwnPost ? null : onToggleUpvote,
            tooltip: '给鸡腿',
          ),
          const SizedBox(width: 4),
          // 踩按钮
          _ActionButton(
            icon: disliked
                ? Icons.thumb_down
                : Icons.thumb_down_outlined,
            count: dislikeCount,
            active: disliked,
            activeColor: theme.colorScheme.onSurfaceVariant,
            onTap: isOwnPost ? null : onToggleDislike,
            tooltip: '踩',
          ),
          const SizedBox(width: 8),
          // 回复按钮
          Tooltip(
            message: context.l10n.common_reply,
            child: GestureDetector(
              onTap: onReply,
              child: Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.reply,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],

        const SizedBox(width: 8),

        // 更多按钮
        GestureDetector(
          onTap: onShowMoreMenu,
          child: Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.more_horiz,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// 单个操作按钮（图标 + 可选计数）
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final int count;
  final bool active;
  final Color activeColor;
  final VoidCallback? onTap;
  final String? tooltip;

  const _ActionButton({
    super.key,
    required this.icon,
    required this.count,
    required this.active,
    required this.activeColor,
    this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = active ? activeColor : theme.colorScheme.onSurfaceVariant;

    Widget button = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }

    return button;
  }
}
