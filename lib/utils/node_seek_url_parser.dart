/// 话题链接解析结果
class TopicLinkInfo {
  final int topicId;
  final String? slug;
  final int? postNumber;

  const TopicLinkInfo({required this.topicId, this.slug, this.postNumber});
}

/// 用户链接解析结果
class UserLinkInfo {
  final String username;
  final int? uid;

  const UserLinkInfo({required this.username, this.uid});
}

class NodeSeekUrlParser {
  NodeSeekUrlParser._();

  /// 兼容旧话题格式：/t/12345 或 /t/12345/1
  static final _topicIdOnlyRegex = RegExp(
    r'/t/(\d+)(?:/(\d+))?(?:[/?#]|$)',
    caseSensitive: false,
  );

  /// 兼容旧 slug 格式。
  static final _topicWithSlugRegex = RegExp(
    r'/t/([^/]+)/(\d+)(?:/(\d+))?',
    caseSensitive: false,
  );

  /// NodeSeek 话题格式：/post-12345 或 /post-12345-2
  static final _nodeSeekPostRegex = RegExp(
    r'/post-(\d+)(?:-(\d+))?(?:[/?#]|$)',
    caseSensitive: false,
  );

  /// 兼容仅含 slug 的旧格式：/t/some-slug（slug 不能以数字开头）
  static final _topicSlugOnlyRegex = RegExp(
    r'/t/([^/\d][^/?#]*)$',
    caseSensitive: false,
  );

  /// 用户链接格式：/u/username、/space/123
  static final _userRegex = RegExp(
    r'/(?:u|user)/([^/?#]+)|/space/(\d+)',
    caseSensitive: false,
  );

  /// 解析话题链接，返回 [TopicLinkInfo] 或 null
  ///
  /// 支持格式：
  /// - `/post-12345-2` → topicId=12345, postNumber=11
  /// - legacy `/t/12345/1` → topicId=12345, postNumber=1
  static TopicLinkInfo? parseTopic(String url) {
    // 优先匹配纯数字 ID 格式
    final idOnlyMatch = _topicIdOnlyRegex.firstMatch(url);
    if (idOnlyMatch != null) {
      return TopicLinkInfo(
        topicId: int.parse(idOnlyMatch.group(1)!),
        postNumber: int.tryParse(idOnlyMatch.group(2) ?? ''),
      );
    }

    final nodeSeekPostMatch = _nodeSeekPostRegex.firstMatch(url);
    if (nodeSeekPostMatch != null) {
      final page = int.tryParse(nodeSeekPostMatch.group(2) ?? '');
      return TopicLinkInfo(
        topicId: int.parse(nodeSeekPostMatch.group(1)!),
        postNumber: page == null ? null : ((page - 1) * 10) + 1,
      );
    }

    // 兼容旧 slug 格式。
    final withSlugMatch = _topicWithSlugRegex.firstMatch(url);
    if (withSlugMatch != null) {
      final slugStr = withSlugMatch.group(1)!;
      return TopicLinkInfo(
        topicId: int.parse(withSlugMatch.group(2)!),
        slug: slugStr != 'topic' ? slugStr : null,
        postNumber: int.tryParse(withSlugMatch.group(3) ?? ''),
      );
    }

    return null;
  }

  /// 解析仅含 slug 的旧话题链接（/t/some-slug），返回 slug 或 null
  ///
  /// 注意：此方法仅匹配没有数字 ID 的 slug 链接，
  /// 带 ID 的链接应使用 [parseTopic]。
  static String? parseTopicSlug(String url) {
    final match = _topicSlugOnlyRegex.firstMatch(url);
    return match?.group(1);
  }

  /// 解析用户链接，返回 [UserLinkInfo] 或 null
  static UserLinkInfo? parseUser(String url) {
    final match = _userRegex.firstMatch(url);
    if (match != null) {
      final uid = int.tryParse(match.group(2) ?? '');
      return UserLinkInfo(username: match.group(1) ?? 'user$uid', uid: uid);
    }
    return null;
  }

  /// 是否是用户链接（用于快速判断）
  static bool isUserLink(String url) {
    return _userRegex.hasMatch(url);
  }
}
