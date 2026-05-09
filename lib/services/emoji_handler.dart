import 'package:flutter/foundation.dart';

import 'preloaded_data_service.dart';
import 'sticker_handler.dart';
import '../utils/url_helper.dart';
import '../utils/emoji_shortcodes.dart';

/// Emoji / 贴图 URL 解析器
///
/// 与网页端逻辑一致，短码解析的优先级：
/// 1. NodeSeek 贴图（`:xhj003:` / `:ac01:` / `:yct015:` / `:emoji00:` 等）：
///    通过 [StickerHandler] 生成 `/static/image/sticker/...` URL
/// 2. 自定义 emoji（如 bili_114）：从预加载数据 `customEmoji` 注册
/// 3. 标准 Twitter emoji：URL 确定性拼接 `/images/emoji/twitter/{name}.png`
class EmojiHandler {
  static final EmojiHandler _instance = EmojiHandler._internal();
  factory EmojiHandler() => _instance;
  EmojiHandler._internal();

  /// 自定义 emoji 名称 -> URL 映射
  Map<String, String>? _customEmojiMap;

  /// 从预加载数据注册自定义 emoji
  ///
  /// 必须在 [PreloadedDataService().ensureLoaded()] 之后调用。
  void init() {
    if (_customEmojiMap != null) return;

    _customEmojiMap = {};

    try {
      final customEmojis = PreloadedDataService().customEmoji;
      if (customEmojis != null) {
        for (final emoji in customEmojis) {
          final name = emoji['name'] as String?;
          final url = emoji['url'] as String?;
          if (name != null && url != null) {
            _customEmojiMap![name] = url;
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to load custom emojis: $e');
    }
  }

  /// 将文本中的 `:shortcode:` 替换为对应 HTML img 标签。
  ///
  /// 优先识别 NodeSeek 贴图（输出 `<img class="sticker">`，由 `HtmlWidgetFactory`
  /// 接管渲染，最大宽度 90dp，与文字同行显示），
  /// 其次按普通 emoji 处理（输出 `<img class="emoji">`）。
  String replaceEmojis(String text) {
    return text.replaceAllMapped(emojiShortcodeRegex, (match) {
      final name = normalizeEmojiShortcodeName(match.group(1)!);

      // 1. 尝试当作 NodeSeek 贴图（尺寸由 HtmlWidgetFactory 统一控制）
      final stickerUrl = StickerHandler.resolveUrl(name);
      if (stickerUrl != null) {
        return '<img src="$stickerUrl" alt=":$name:" '
            'class="sticker" title=":$name:">';
      }

      // 2. 回退到普通 emoji
      final fullUrl = getEmojiUrl(name);
      return '<img src="$fullUrl" alt=":$name:" class="emoji" title=":$name:">';
    });
  }

  /// 获取 emoji 的完整 URL
  ///
  /// 优先查找自定义 emoji（有服务端提供的真实 URL），
  /// 未找到则使用标准 emoji 的确定性路径。
  String getEmojiUrl(String name) {
    final normalized = normalizeEmojiShortcodeName(name);

    // 贴图优先
    final stickerUrl = StickerHandler.resolveUrl(normalized);
    if (stickerUrl != null) return stickerUrl;

    // 自定义 emoji（如 bili_114、tsai 等）
    final customUrl = _customEmojiMap?[normalized];
    if (customUrl != null) {
      return UrlHelper.resolveUrlWithCdn(customUrl);
    }

    final toneMatch = RegExp(r'^([^\s:]+):t([1-6])$').firstMatch(normalized);
    if (toneMatch != null) {
      final base = toneMatch.group(1)!;
      final tone = toneMatch.group(2)!;
      return UrlHelper.resolveUrlWithCdn(
        '/images/emoji/twitter/$base/t$tone.png?v=12',
      );
    }

    // 标准 emoji，URL 确定性拼接
    return UrlHelper.resolveUrlWithCdn(
      '/images/emoji/twitter/$normalized.png?v=12',
    );
  }
}
