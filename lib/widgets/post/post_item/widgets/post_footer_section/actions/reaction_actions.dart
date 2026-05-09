// ignore_for_file: invalid_use_of_protected_member

part of '../post_footer_section.dart';

extension _PostFooterReactionActions on _PostFooterSectionState {
  Future<void> _toggleLike() async {
    if (_isLiking) return;

    HapticFeedback.lightImpact();
    setState(() => _isLiking = true);

    try {
      final wasLiked = _liked;
      if (wasLiked) {
        await _service.unlikePost(widget.post.id);
      } else {
        await _service.likePost(widget.post.id);
      }
      if (!mounted) return;

      setState(() {
        _liked = !wasLiked;
        _likeCount += wasLiked ? -1 : 1;
      });

      final params = TopicDetailParams(widget.topicId);
      ref
          .read(topicDetailProvider(params).notifier)
          .applyLikeToggle(
            widget.post.id,
            liked: _liked,
            likeCount: _likeCount,
          );
    } on DioException catch (_) {
      // 网络错误已由 ErrorInterceptor 处理
    } catch (e, s) {
      AppErrorHandler.handleUnexpected(e, s);
    } finally {
      if (mounted) {
        setState(() => _isLiking = false);
      }
    }
  }

  Future<void> _toggleDislike() async {
    HapticFeedback.lightImpact();

    try {
      final wasDisliked = _disliked;
      if (wasDisliked) {
        await _service.toggleDislike(widget.post.id, add: false);
      } else {
        await _service.toggleDislike(widget.post.id, add: true);
      }
      if (!mounted) return;

      setState(() {
        _disliked = !wasDisliked;
        _dislikeCount += wasDisliked ? -1 : 1;
      });

      final params = TopicDetailParams(widget.topicId);
      ref
          .read(topicDetailProvider(params).notifier)
          .applyDislikeToggle(
            widget.post.id,
            disliked: _disliked,
            dislikeCount: _dislikeCount,
          );
    } on DioException catch (_) {
      // 网络错误已由 ErrorInterceptor 处理
    } catch (e, s) {
      AppErrorHandler.handleUnexpected(e, s);
    }
  }

  Future<void> _toggleUpvote() async {
    HapticFeedback.lightImpact();

    try {
      final wasUpvoted = _upvoted;
      if (wasUpvoted) {
        await _service.toggleUpvote(widget.post.id, add: false);
      } else {
        await _service.toggleUpvote(widget.post.id, add: true);
      }
      if (!mounted) return;

      setState(() {
        _upvoted = !wasUpvoted;
        _upvoteCount += wasUpvoted ? -1 : 1;
      });

      final params = TopicDetailParams(widget.topicId);
      ref
          .read(topicDetailProvider(params).notifier)
          .applyUpvoteToggle(
            widget.post.id,
            upvoted: _upvoted,
            upvoteCount: _upvoteCount,
          );
    } on DioException catch (_) {
      // 网络错误已由 ErrorInterceptor 处理
    } catch (e, s) {
      AppErrorHandler.handleUnexpected(e, s);
    }
  }
}
