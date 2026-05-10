import 'package:flutter_test/flutter_test.dart';
import 'package:fluxseek/services/nodeseek/ssr_parser.dart';

void main() {
  test('parses rendered NodeSeek post list before rotateTopics', () {
    const html = '''
<html>
  <body>
    <ul class="post-list">
      <li class="post-list-item">
        <a href="/space/33924">
          <img src="/avatar/33924.png" data-uid="33924" class="avatar-normal">
        </a>
        <div class="post-list-content">
          <div class="post-title"><a href="/post-717547-1">狐狸维权群</a></div>
          <div class="post-info">
            <span class="info-author"><a href="/space/33924">菜狗图图</a></span>
            <span class="info-views"><span title="826 views">826</span></span>
            <span class="info-comments-count"><span>12</span></span>
            <span class="info-last-commenter"><a href="/space/153">pansir029</a></span>
            <a href="/post-717547-2#12" class="info-last-comment-time">
              <time datetime="2026-05-07T00:06:23.000Z">12s ago</time>
            </a>
            <a href="/categories/info" class="post-category">情报</a>
          </div>
        </div>
      </li>
      <li class="post-list-item">
        <a href="/space/18421">
          <img src="/avatar/18421.png" data-uid="18421" class="avatar-normal">
        </a>
        <div class="post-list-content">
          <div class="post-title">
            <a href="/post-717681-1">ChatGPT plus 新加坡区 信用卡 新开</a>
          </div>
          <div class="post-info">
            <span class="info-author"><a href="/space/18421">szx</a></span>
            <span class="info-views"><span>55</span></span>
            <span class="info-comments-count"><span>7</span></span>
            <span class="info-last-commenter"><a href="/space/18421">szx</a></span>
            <a href="/post-717681-1#7" class="info-last-comment-time">
              <time datetime="2026-05-07T00:06:04.000Z">31s ago</time>
            </a>
            <a href="/categories/carpool" class="post-category">拼车</a>
          </div>
        </div>
      </li>
    </ul>
    <div class="nsk-pager">
      <a href="/page-2" rel="next" class="pager-next">next</a>
    </div>
    <script id="temp-script" type="application/json">
      {
        "allCategory": [
          {"key": "info", "cn_text": "情报", "icon": "receiver"},
          {"key": "carpool", "cn_text": "拼车", "icon": "car"}
        ],
        "rotateTopics": [
          {"postId": 1, "titleText": "置顶兜底", "comments": 1}
        ]
      }
    </script>
  </body>
</html>
''';

    final parsed = parseNodeSeekSsrHtml(html);

    expect(parsed, isNotNull);
    expect(parsed!.topicListResponse.topics, hasLength(2));
    expect(parsed.topicListResponse.topics.first.id, 717547);
    expect(parsed.topicListResponse.topics.first.title, '狐狸维权群');
    expect(parsed.topicListResponse.topics.first.replyCount, 12);
    expect(parsed.topicListResponse.topics.first.pinned, isFalse);
    expect(parsed.topicListResponse.moreTopicsUrl, '/page-2');
  });

  test(
    'falls back to NodeSeek avatar endpoint when list avatar src is empty',
    () {
      const html = '''
<html>
  <body>
    <ul class="post-list">
      <li class="post-list-item">
        <a href="/space/42">
          <img data-uid="42" class="avatar-normal">
        </a>
        <div class="post-list-content">
          <div class="post-title"><a href="/post-718001-1">没有设置头像</a></div>
          <div class="post-info">
            <span class="info-author"><a href="/space/42">Na</a></span>
            <span class="info-views"><span>1</span></span>
            <span class="info-comments-count"><span>0</span></span>
            <a href="/categories/daily" class="post-category">日常</a>
          </div>
        </div>
      </li>
    </ul>
    <script id="temp-script" type="application/json">
      {
        "allCategory": [
          {"key": "daily", "cn_text": "日常", "icon": "tea"}
        ]
      }
    </script>
  </body>
</html>
''';

      final parsed = parseNodeSeekSsrHtml(html);

      expect(parsed, isNotNull);
      final poster = parsed!.topicListResponse.topics.single.posters.single;
      expect(poster.user?.id, 42);
      expect(poster.user?.avatarTemplate, '/avatar/42.png');
    },
  );

  test('renders NodeSeek topic markdown and avatar templates', () {
    const html = '''
<script id="temp-script" type="application/json">
{
  "allCategory": [
    {"key": "tech", "cn_text": "技术", "icon": "formula"}
  ],
  "postData": {
    "postId": 717123,
    "postPage": 1,
    "postPageCount": 1,
    "title": "一款超轻量的面板",
    "views": "42",
    "category": "tech",
    "locked": 0,
    "collected": false,
    "op": {"uid": 100, "name": "Na"},
    "comments": [
      {
        "commentId": 9001,
        "floorIndex": 1,
        "poster": {"uid": 100, "name": "Na"},
        "time": "2026-05-07T00:06:23.000Z",
        "markdown": "效果图\\n![image](https://example.com/a.png)\\n\\nhttps://github.com/termdev-labs/aeromonitor",
        "signature": "**签名**",
        "likeCount": 3
      }
    ]
  }
}
</script>
''';

    final parsed = parseNodeSeekTopicDetailSsrHtml(html);

    expect(parsed, isNotNull);
    final detail = parsed!.detail;
    expect(detail.createdBy?.avatarTemplate, '/avatar/100.png');
    expect(detail.postStream.posts, hasLength(1));
    final post = detail.postStream.posts.first;
    expect(post.avatarTemplate, '/avatar/100.png');
    expect(post.cooked, contains('<img'));
    expect(post.cooked, contains('https://example.com/a.png'));
    expect(post.cooked, contains('<a href='));
    expect(post.signatureCooked, contains('<strong>签名</strong>'));
  });

  test('renders NodeSeek magic tabs and ansi code fences', () {
    const html = '''
<script id="temp-script" type="application/json">
{
  "allCategory": [
    {"key": "review", "cn_text": "测评", "icon": "dashboard-one"}
  ],
  "postData": {
    "postId": 723267,
    "postPage": 1,
    "postPageCount": 1,
    "title": "NQ 测试留档",
    "views": "10",
    "category": "review",
    "locked": 0,
    "collected": false,
    "op": {"uid": 45750, "name": "xiaov"},
    "comments": [
      {
        "commentId": 9975263,
        "floorIndex": 0,
        "poster": {"uid": 45750, "name": "xiaov"},
        "time": "2026-05-10T06:20:08.000Z",
        "markdown": ":::: tabs\\n::: tab-item 💻基本信息\\n```ansi\\n\\u001b[36mCPU\\u001b[0m OK\\n```\\n:::\\n::: tab-item 🌐网络质量\\n![image](https://example.com/net.webp)\\n:::\\n::::",
        "signature": "",
        "likeCount": 0
      }
    ]
  }
}
</script>
''';

    final parsed = parseNodeSeekTopicDetailSsrHtml(html);

    expect(parsed, isNotNull);
    final cooked = parsed!.detail.postStream.posts.single.cooked;
    expect(cooked, contains('class="nsk-magic-tabs enabled"'));
    expect(cooked, contains('class="nsk-magic-tab-title is-active"'));
    expect(cooked, contains('💻基本信息'));
    expect(cooked, contains('🌐网络质量'));
    expect(cooked, contains('language-ansi'));
    expect(cooked, contains('\u001b[36mCPU\u001b[0m OK'));
    expect(cooked, contains('https://example.com/net.webp'));
  });

  test('keeps NodeSeek tabs syntax literal inside fenced code blocks', () {
    const html = '''
<script id="temp-script" type="application/json">
{
  "allCategory": [
    {"key": "review", "cn_text": "测评", "icon": "dashboard-one"}
  ],
  "postData": {
    "postId": 723268,
    "postPage": 1,
    "postPageCount": 1,
    "title": "tabs 语法示例",
    "views": "10",
    "category": "review",
    "locked": 0,
    "collected": false,
    "op": {"uid": 45750, "name": "xiaov"},
    "comments": [
      {
        "commentId": 9975264,
        "floorIndex": 0,
        "poster": {"uid": 45750, "name": "xiaov"},
        "time": "2026-05-10T06:20:08.000Z",
        "markdown": "```markdown\\n:::: tabs\\n::: tab-item 示例\\ncontent\\n:::\\n::::\\n```",
        "signature": "",
        "likeCount": 0
      }
    ]
  }
}
</script>
''';

    final parsed = parseNodeSeekTopicDetailSsrHtml(html);

    expect(parsed, isNotNull);
    final cooked = parsed!.detail.postStream.posts.single.cooked;
    expect(cooked, isNot(contains('class="nsk-magic-tabs enabled"')));
    expect(cooked, contains(':::: tabs'));
    expect(cooked, contains('::: tab-item 示例'));
  });

  test('maps rendered post list into search results', () {
    const html = '''
<html>
  <body>
    <ul class="post-list">
      <li class="post-list-item">
        <a href="/space/42">
          <img src="/avatar/42.png" data-uid="42" class="avatar-normal">
        </a>
        <div class="post-title"><a href="/post-718001-1">面板搜索结果</a></div>
        <span class="info-author"><a href="/space/42">Na</a></span>
        <span class="info-views">123</span>
        <span class="info-comments-count">2</span>
        <a href="/categories/tech" class="post-category">技术</a>
      </li>
    </ul>
    <script id="temp-script" type="application/json">
    {"allCategory":[{"key":"tech","cn_text":"技术","icon":"formula"}]}
    </script>
  </body>
</html>
''';

    final result = parseNodeSeekSearchHtml(html, term: '面板');

    expect(result.posts, hasLength(1));
    expect(result.posts.first.topic?.id, 718001);
    expect(result.posts.first.topic?.title, '面板搜索结果');
    expect(result.posts.first.username, 'Na');
  });

  test('parses member search links', () {
    const html = '''
<html>
  <body>
    <a href="/space/6380" class="member-item">
      <img src="/avatar/6380.png" alt="adminlaowang">
      <span>adminlaowang</span>
    </a>
  </body>
</html>
''';

    final result = parseNodeSeekMemberSearchHtml(html);

    expect(result.users, hasLength(1));
    expect(result.users.first.id, 6380);
    expect(result.users.first.username, 'adminlaowang');
    expect(result.users.first.avatarTemplate, '/avatar/6380.png');
  });
}
