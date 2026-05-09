import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:markdown/markdown.dart' as md;

import '../../models/category.dart';
import '../../models/search_result.dart';
import '../../models/topic.dart';
import '../emoji_handler.dart';

class NodeSeekSsrData {
  const NodeSeekSsrData({
    required this.config,
    required this.categories,
    required this.categoryIdByKey,
    required this.topicListData,
    required this.topicListResponse,
  });

  final Map<String, dynamic> config;
  final List<Category> categories;
  final Map<String, int> categoryIdByKey;
  final Map<String, dynamic> topicListData;
  final TopicListResponse topicListResponse;
}

class NodeSeekTopicDetailSsrData {
  const NodeSeekTopicDetailSsrData({
    required this.detail,
    required this.page,
    required this.pageCount,
  });

  final TopicDetail detail;
  final int page;
  final int pageCount;
}

class NodeSeekMemberSearchData {
  const NodeSeekMemberSearchData({required this.users});

  final List<SearchUser> users;
}

NodeSeekSsrData? parseNodeSeekSsrHtml(String html) {
  final config = decodeNodeSeekSsrConfig(html);
  if (config == null) return null;

  final categories = <Category>[];
  final categoryIdByKey = <String, int>{};
  final rawCategories = _asList(config['allCategory']);
  for (var i = 0; i < rawCategories.length; i++) {
    final raw = _asMap(rawCategories[i]);
    if (raw == null) continue;
    final key = raw['key']?.toString() ?? '';
    if (key.isEmpty) continue;
    final id = i + 2; // 保留 1 给旧 Discourse 未分类过滤逻辑。
    categoryIdByKey[key] = id;
    categories.add(
      Category(
        id: id,
        name: raw['cn_text']?.toString() ?? key,
        color: _categoryColor(key),
        textColor: 'FFFFFF',
        slug: key,
        icon: raw['icon']?.toString(),
        readRestricted: raw['adminOnly'] == true,
        permission: raw['adminOnly'] == true ? 3 : 0,
      ),
    );
  }

  final topicListData =
      _buildRenderedTopicListData(html, categoryIdByKey) ??
      _buildTopicListData(_asList(config['rotateTopics']), categoryIdByKey);
  return NodeSeekSsrData(
    config: config,
    categories: categories,
    categoryIdByKey: categoryIdByKey,
    topicListData: topicListData,
    topicListResponse: TopicListResponse.fromJson(topicListData),
  );
}

TopicDetail? parseNodeSeekTopicDetailHtml(String html) {
  return parseNodeSeekTopicDetailSsrHtml(html)?.detail;
}

SearchResult parseNodeSeekSearchHtml(String html, {required String term}) {
  final config = decodeNodeSeekSsrConfig(html) ?? const <String, dynamic>{};
  final categoryIdByKey = <String, int>{};
  final rawCategories = _asList(config['allCategory']);
  for (var i = 0; i < rawCategories.length; i++) {
    final raw = _asMap(rawCategories[i]);
    final key = raw?['key']?.toString() ?? '';
    if (key.isNotEmpty) categoryIdByKey[key] = i + 2;
  }

  final topicListData = _buildRenderedTopicListData(html, categoryIdByKey);
  final topicList = _asMap(topicListData?['topic_list']);
  final rawTopics = _asList(topicList?['topics']);
  final rawUsers = _asList(topicListData?['users']);
  final usersById = <int, Map<String, dynamic>>{};
  for (final raw in rawUsers) {
    final user = _asMap(raw);
    final id = _asInt(user?['id']);
    if (user != null && id != null) usersById[id] = user;
  }

  final posts = <Map<String, dynamic>>[];
  final topics = <Map<String, dynamic>>[];
  for (final raw in rawTopics) {
    final topic = _asMap(raw);
    if (topic == null) continue;
    final topicId = _asInt(topic['id']);
    if (topicId == null) continue;
    topics.add(topic);

    Map<String, dynamic>? firstPoster;
    for (final rawPoster in _asList(topic['posters'])) {
      firstPoster = _asMap(rawPoster);
      if (firstPoster != null) break;
    }
    final userId = _asInt(firstPoster?['user_id']);
    final user = userId == null ? null : usersById[userId];
    posts.add({
      'id': topicId,
      'topic_id': topicId,
      'username': user?['username']?.toString() ?? '',
      'avatar_template': user?['avatar_template']?.toString() ?? '',
      'created_at': topic['created_at']?.toString(),
      'like_count': topic['like_count'] ?? 0,
      'blurb': topic['title']?.toString() ?? '',
      'post_number': 1,
      'topic_title_headline': topic['title']?.toString() ?? '',
    });
  }

  return SearchResult.fromJson({
    'posts': posts,
    'topics': topics,
    'users': <Map<String, dynamic>>[],
    'grouped_search_result': {
      'term': term,
      'more_full_page_results': topicList?['more_topics_url'] != null,
      'more_posts': false,
      'more_users': false,
      'more_categories': false,
    },
  });
}

NodeSeekMemberSearchData parseNodeSeekMemberSearchHtml(String html) {
  final document = html_parser.parse(html);
  final byId = <int, SearchUser>{};
  for (final link in document.querySelectorAll('a[href^="/space/"]')) {
    final href = link.attributes['href'] ?? '';
    final id = _spaceIdFromPath(href);
    if (id == null) continue;
    final img = link.querySelector('img') ?? link.parent?.querySelector('img');
    final alt = _cleanText(img?.attributes['alt']);
    final text = _cleanText(link.text);
    final username = alt ?? text ?? 'user$id';
    byId[id] = SearchUser(
      id: id,
      username: username,
      name: text == username ? null : text,
      avatarTemplate: img?.attributes['src'] ?? '/avatar/$id.png',
    );
  }
  return NodeSeekMemberSearchData(users: byId.values.toList());
}

NodeSeekTopicDetailSsrData? parseNodeSeekTopicDetailSsrHtml(String html) {
  final config = decodeNodeSeekSsrConfig(html);
  if (config == null) return null;

  final postData = _asMap(config['postData']);
  if (postData == null) return null;

  final postId = _asInt(postData['postId']);
  if (postId == null) return null;
  final page = _asInt(postData['postPage']) ?? 1;
  final pageCount = _asInt(postData['postPageCount']) ?? page;

  final categoryIdByKey = <String, int>{};
  final rawCategories = _asList(config['allCategory']);
  for (var i = 0; i < rawCategories.length; i++) {
    final raw = _asMap(rawCategories[i]);
    final key = raw?['key']?.toString() ?? '';
    if (key.isNotEmpty) categoryIdByKey[key] = i + 2;
  }

  final rawComments = _asList(postData['comments']);
  final posts = <Post>[];

  // NodeSeek 数据结构：comments[0] (floorIndex=0) 是主帖，后续是回复
  // postNumber 映射：floorIndex + 1（主帖=1，第一个回复=2）
  for (var i = 0; i < rawComments.length; i++) {
    final raw = _asMap(rawComments[i]);
    if (raw == null) continue;
    final floor = _asInt(raw['floorIndex']) ?? i;
    final poster = _asMap(raw['poster']);
    final posterName = poster?['name']?.toString();
    final posterId = _asInt(poster?['uid']);
    final createdAt = _parseTime(raw['time']) ?? DateTime.now();
    posts.add(
      Post(
        id: _asInt(raw['commentId']) ?? postId * 1000 + floor,
        name: posterName,
        username: (posterName == null || posterName.isEmpty)
            ? 'user${posterId ?? floor}'
            : posterName,
        avatarTemplate: posterId == null ? '' : '/avatar/$posterId.png',
        cooked: _markdownToBasicHtml(raw['markdown']?.toString() ?? ''),
        postNumber: floor + 1,
        postType: 1,
        updatedAt: createdAt,
        createdAt: createdAt,
        likeCount: _asInt(raw['likeCount']) ?? 0,
        replyCount: floor == 0 ? rawComments.length - 1 : 0,
        bookmarked: raw['collected'] == true,
        hidden: raw['blocked'] == true,
        cookedHidden: raw['blocked'] == true,
        userId: posterId,
        liked: raw['liked'] == true,
        disliked: raw['disliked'] == true,
        upvoted: raw['upvoted'] == true,
        dislikeCount: _asInt(raw['dislikeCount']) ?? 0,
        upvoteCount: _asInt(raw['upvoteCount']) ?? 0,
        signatureCooked: _markdownToBasicHtml(
          raw['signature']?.toString() ?? '',
        ),
      ),
    );
  }

  // Fallback：如果没有评论数据，创建空壳主帖
  if (posts.isEmpty) {
    final op = _asMap(postData['op']);
    final opName = op?['name']?.toString();
    final opId = _asInt(op?['uid']);
    posts.add(
      Post(
        id: postId,
        name: opName,
        username: (opName == null || opName.isEmpty)
            ? 'user${opId ?? postId}'
            : opName,
        avatarTemplate: opId == null ? '' : '/avatar/$opId.png',
        cooked: '',
        postNumber: 1,
        postType: 1,
        updatedAt: DateTime.now(),
        createdAt: DateTime.now(),
        likeCount: 0,
        replyCount: 0,
        userId: opId,
      ),
    );
  }

  final op = _asMap(postData['op']);
  final opId = _asInt(op?['uid']) ?? 0;
  final opName = op?['name']?.toString();
  final categoryKey = postData['category']?.toString() ?? '';
  return NodeSeekTopicDetailSsrData(
    page: page < 1 ? 1 : page,
    pageCount: pageCount < 1 ? 1 : pageCount,
    detail: TopicDetail(
      id: postId,
      title: postData['title']?.toString() ?? '',
      slug: 'post-$postId',
      postsCount: posts.length,
      postStream: PostStream(
        posts: posts,
        stream: posts.map((post) => post.id).toList(),
      ),
      categoryId: categoryIdByKey[categoryKey] ?? 0,
      closed: postData['locked'] == true || postData['locked'] == 1,
      archived: false,
      tags: const <Tag>[],
      views: _asInt(postData['views']) ?? 0,
      likeCount: 0,
      createdAt: posts.first.createdAt,
      visible: true,
      createdBy: opId == 0
          ? null
          : TopicUser(
              id: opId,
              username: opName ?? 'user$opId',
              avatarTemplate: '/avatar/$opId.png',
            ),
      bookmarked: postData['collected'] == true,
    ),
  );
}

Map<String, dynamic>? decodeNodeSeekSsrConfig(String html) {
  final script = _extractTempScript(html);
  if (script == null || script.trim().isEmpty) return null;

  final candidates = <String>[
    ...RegExp(
      r'''atob\(\s*["']([^"']+)["']\s*\)''',
      dotAll: true,
    ).allMatches(script).map((m) => m.group(1)!),
    ...RegExp(
      r'''["']([A-Za-z0-9+/=_-]{40,})["']''',
      dotAll: true,
    ).allMatches(script).map((m) => m.group(1)!),
    script.trim(),
  ];

  for (final candidate in candidates) {
    final decoded = _tryDecodeConfigCandidate(candidate);
    if (decoded != null) return decoded;
  }
  return _tryExtractObjectAssignment(script);
}

String? _extractTempScript(String html) {
  final match = RegExp(
    r'''<script\b[^>]*id=["']temp-script["'][^>]*>([\s\S]*?)</script>''',
    caseSensitive: false,
  ).firstMatch(html);
  return match?.group(1);
}

Map<String, dynamic>? _tryDecodeConfigCandidate(String raw) {
  final candidates = <String>[raw.trim()];
  try {
    candidates.add(utf8.decode(base64.decode(base64.normalize(raw.trim()))));
  } catch (_) {}

  for (final candidate in candidates) {
    for (final text in [candidate, _tryUriDecode(candidate)]) {
      if (text == null || text.isEmpty) continue;
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return decoded.cast<String, dynamic>();
      } catch (_) {}
    }
  }
  return null;
}

String? _tryUriDecode(String value) {
  try {
    return Uri.decodeComponent(value);
  } catch (_) {
    return null;
  }
}

Map<String, dynamic>? _tryExtractObjectAssignment(String script) {
  final marker = 'window.__config__';
  final start = script.indexOf(marker);
  if (start < 0) return null;
  final braceStart = script.indexOf('{', start);
  if (braceStart < 0) return null;

  var depth = 0;
  var inString = false;
  var quote = '';
  var escaped = false;
  for (var i = braceStart; i < script.length; i++) {
    final ch = script[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (ch == r'\') {
        escaped = true;
      } else if (ch == quote) {
        inString = false;
      }
      continue;
    }
    if (ch == '"' || ch == "'") {
      inString = true;
      quote = ch;
      continue;
    }
    if (ch == '{') depth++;
    if (ch == '}') depth--;
    if (depth == 0) {
      final objectLiteral = script.substring(braceStart, i + 1);
      try {
        final decoded = jsonDecode(objectLiteral);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return decoded.cast<String, dynamic>();
      } catch (_) {
        return null;
      }
    }
  }
  return null;
}

Map<String, dynamic> _buildTopicListData(
  List<dynamic> rawTopics,
  Map<String, int> categoryIdByKey,
) {
  final users = <int, Map<String, dynamic>>{};
  final topics = <Map<String, dynamic>>[];

  for (final item in rawTopics) {
    final raw = _asMap(item);
    if (raw == null) continue;
    final postId = _asInt(raw['postId']);
    if (postId == null) continue;

    final op = _asMap(raw['op']);
    final lastCommenter = _asMap(raw['lastCommenter']);
    final opId = _asInt(op?['uid']) ?? 0;
    final lastId = _asInt(lastCommenter?['uid']);
    if (opId != 0) {
      users[opId] = _buildUser(
        opId,
        op?['name']?.toString(),
        avatarTemplate: _nodeSeekAvatarTemplate(opId),
      );
    }
    if (lastId != null && lastId != 0) {
      users[lastId] = _buildUser(
        lastId,
        lastCommenter?['name']?.toString(),
        avatarTemplate: _nodeSeekAvatarTemplate(lastId),
      );
    }

    final comments = _asInt(raw['comments']) ?? 0;
    final categoryKey = raw['category']?.toString() ?? '';
    final lastPostedAt =
        raw['lastCommentDate']?.toString() ??
        raw['lastCommentDateFormated']?.toString();
    topics.add({
      'id': postId,
      'title': raw['titleText']?.toString() ?? '',
      'slug': 'post-$postId',
      'posts_count': comments + 1,
      'reply_count': comments,
      'views': _asInt(raw['views']) ?? 0,
      'like_count': 0,
      'created_at': lastPostedAt,
      'last_posted_at': lastPostedAt,
      'last_poster_username': lastCommenter?['name']?.toString(),
      'category_id': categoryIdByKey[categoryKey] ?? 0,
      'pinned': raw['pined'] == true || raw['isAnnouncement'] == true,
      'visible': raw['blocked'] != true,
      'closed': raw['locked'] == true,
      'archived': false,
      'tags': <String>[],
      'posters': [
        if (opId != 0)
          {'user_id': opId, 'description': 'Original Poster', 'extras': ''},
        if (lastId != null && lastId != 0 && lastId != opId)
          {
            'user_id': lastId,
            'description': 'Most Recent Poster',
            'extras': 'latest',
          },
      ],
      '_nodeseek_title_link': raw['titleLink']?.toString(),
      '_nodeseek_category_key': categoryKey,
      '_nodeseek_category_word': raw['categoryWord']?.toString(),
    });
  }

  return {
    'users': users.values.toList(),
    'topic_list': {
      'topics': topics,
      'more_topics_url': topics.isEmpty ? null : '/page-2',
    },
  };
}

Map<String, dynamic>? _buildRenderedTopicListData(
  String html,
  Map<String, int> categoryIdByKey,
) {
  final document = html_parser.parse(html);
  final items = document.querySelectorAll('ul.post-list > li.post-list-item');
  if (items.isEmpty) return null;

  final users = <int, Map<String, dynamic>>{};
  final topics = <Map<String, dynamic>>[];

  for (final item in items) {
    final titleLink = item.querySelector('.post-title a[href^="/post-"]');
    final href = titleLink?.attributes['href'] ?? '';
    final postId = _postIdFromNodeSeekPath(href);
    if (postId == null) continue;

    final authorLink = item.querySelector('.info-author a[href^="/space/"]');
    final authorName = _cleanText(authorLink?.text) ?? 'user$postId';
    final avatar = item.querySelector('img.avatar-normal');
    final avatarUid = _asInt(avatar?.attributes['data-uid']);
    final authorSpaceId = _spaceIdFromPath(authorLink?.attributes['href']);
    final authorId = avatarUid ?? authorSpaceId ?? postId;
    users[authorId] = _buildUser(
      authorId,
      authorName,
      avatarTemplate:
          _nonEmpty(avatar?.attributes['src']) ??
          (avatarUid != null || authorSpaceId != null
              ? _nodeSeekAvatarTemplate(authorId)
              : null),
    );

    final lastCommenterLink = item.querySelector(
      '.info-last-commenter a[href^="/space/"]',
    );
    final lastCommenterId = _spaceIdFromPath(
      lastCommenterLink?.attributes['href'],
    );
    final lastCommenterName = _cleanText(lastCommenterLink?.text);
    if (lastCommenterId != null) {
      users[lastCommenterId] = _buildUser(
        lastCommenterId,
        lastCommenterName,
        avatarTemplate: _nodeSeekAvatarTemplate(lastCommenterId),
      );
    }

    final categoryLink = item.querySelector(
      'a.post-category[href^="/categories/"]',
    );
    final categoryHref = categoryLink?.attributes['href'] ?? '';
    final categoryKey = categoryHref.startsWith('/categories/')
        ? categoryHref.substring('/categories/'.length)
        : '';
    final categoryWord = _cleanText(categoryLink?.text);

    final lastTime = item.querySelector('.info-last-comment-time time');
    final lastPostedAt =
        lastTime?.attributes['datetime'] ?? lastTime?.attributes['title'];
    final replyCount = _firstInt(
      item.querySelector('.info-comments-count')?.text,
      fallback: _firstInt(
        item.querySelector('.info-comments-count')?.attributes['title'],
      ),
    );
    final views = _firstInt(item.querySelector('.info-views')?.text);

    topics.add({
      'id': postId,
      'title': _cleanText(titleLink?.text) ?? '',
      'slug': 'post-$postId',
      'posts_count': replyCount + 1,
      'reply_count': replyCount,
      'views': views,
      'like_count': 0,
      'created_at': lastPostedAt,
      'last_posted_at': lastPostedAt,
      'last_poster_username': lastCommenterName,
      'category_id': categoryIdByKey[categoryKey] ?? 0,
      'pinned': false,
      'visible': true,
      'closed': false,
      'archived': false,
      'tags': <String>[],
      'posters': [
        {'user_id': authorId, 'description': 'Original Poster', 'extras': ''},
        if (lastCommenterId != null && lastCommenterId != authorId)
          {
            'user_id': lastCommenterId,
            'description': 'Most Recent Poster',
            'extras': 'latest',
          },
      ],
      '_nodeseek_title_link': href,
      '_nodeseek_category_key': categoryKey,
      '_nodeseek_category_word': categoryWord,
    });
  }

  if (topics.isEmpty) return null;
  final nextUrl = document
      .querySelector('.nsk-pager a.pager-next[href*="/page-"]')
      ?.attributes['href'];

  return {
    'users': users.values.toList(),
    'topic_list': {'topics': topics, 'more_topics_url': nextUrl},
  };
}

String _nodeSeekAvatarTemplate(int uid) => '/avatar/$uid.png';

Map<String, dynamic> _buildUser(
  int id,
  String? name, {
  String? avatarTemplate,
}) {
  final username = (name == null || name.isEmpty) ? 'user$id' : name;
  return {
    'id': id,
    'username': username,
    'avatar_template': avatarTemplate ?? '',
  };
}

String? _nonEmpty(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? null : text;
}

int? _postIdFromNodeSeekPath(String path) {
  final match = RegExp(r'/post-(\d+)').firstMatch(path);
  return match == null ? null : int.tryParse(match[1]!);
}

int? _spaceIdFromPath(String? path) {
  if (path == null) return null;
  final match = RegExp(r'/space/(\d+)').firstMatch(path);
  return match == null ? null : int.tryParse(match[1]!);
}

int _firstInt(String? value, {int fallback = 0}) {
  if (value == null) return fallback;
  final match = RegExp(r'\d+').firstMatch(value.replaceAll(',', ''));
  return match == null ? fallback : int.tryParse(match[0]!) ?? fallback;
}

String? _cleanText(String? value) {
  final text = value?.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text == null || text.isEmpty ? null : text;
}

List<dynamic> _asList(Object? value) => value is List ? value : const [];

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return null;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

/// 解析时间字段：支持 ISO 8601 字符串、Unix 毫秒时间戳、NodeSeek 时间对象
DateTime? _parseTime(Object? value) {
  if (value == null) return null;
  // NodeSeek 时间对象：{createdDate: "2025-04-13T05:12:53.000Z", ...}
  if (value is Map) {
    final createdDate = value['createdDate']?.toString();
    if (createdDate != null && createdDate.isNotEmpty) {
      final parsed = DateTime.tryParse(createdDate);
      if (parsed != null) return parsed.toLocal();
    }
    final formatted = value['createdDateFormated']?.toString();
    if (formatted != null && formatted.isNotEmpty) {
      final parsed = DateTime.tryParse(formatted);
      if (parsed != null) return parsed.toLocal();
    }
    return null;
  }
  if (value is int) {
    // Unix 毫秒时间戳
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true).toLocal();
  }
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true)
        .toLocal();
  }
  final str = value.toString();
  if (str.isEmpty) return null;
  // 尝试解析为 ISO 8601
  final parsed = DateTime.tryParse(str);
  if (parsed != null) return parsed.toLocal();
  // 尝试解析为纯数字时间戳
  final ms = int.tryParse(str);
  if (ms != null) {
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  }
  return null;
}

String _categoryColor(String key) {
  const colors = {
    'daily': '4F46E5',
    'tech': '0EA5E9',
    'info': '16A34A',
    'review': '9333EA',
    'trade': 'EA580C',
    'carpool': '0891B2',
    'promotion': 'DC2626',
    'life': '65A30D',
    'dev': '2563EB',
    'photo-share': 'DB2777',
    'expose': 'B91C1C',
    'meaningless': '64748B',
    'sandbox': '6B7280',
  };
  return colors[key] ?? '64748B';
}

String _markdownToBasicHtml(String markdown) {
  if (markdown.isEmpty) return '';
  // 先把 NodeSeek 贴图 / emoji 短码替换成 <img>，再交给 markdown 解析
  final withEmoji = EmojiHandler().replaceEmojis(markdown);
  final normalized = withEmoji
      .replaceAllMapped(
        RegExp(r'(?<!\n\n)(!\[[^\]]*\]\([^)]+\))'),
        (match) => '\n\n${match.group(1)!}',
      )
      .replaceAllMapped(
        RegExp(r'(!\[[^\]]*\]\([^)]+\))(?!\n\n)'),
        (match) => '${match.group(1)!}\n\n',
      )
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  return md.markdownToHtml(
    _convertSoftBreaks(normalized),
    extensionSet: md.ExtensionSet.gitHubFlavored,
  );
}

String _convertSoftBreaks(String text) {
  final lines = text.split('\n');
  final result = StringBuffer();
  var inCodeBlock = false;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trimLeft().startsWith('```')) {
      inCodeBlock = !inCodeBlock;
    }

    if (!inCodeBlock &&
        i < lines.length - 1 &&
        line.isNotEmpty &&
        lines[i + 1].isNotEmpty &&
        !line.endsWith('  ')) {
      result.write('$line  ');
    } else {
      result.write(line);
    }
    if (i < lines.length - 1) {
      result.write('\n');
    }
  }

  return result.toString();
}
