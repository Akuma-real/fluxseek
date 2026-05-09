import 'package:flutter_test/flutter_test.dart';
import 'package:fluxseek/services/sticker_handler.dart';

void main() {
  group('StickerHandler', () {
    test('identifies NodeSeek stickers by shortcode', () {
      expect(StickerHandler.isSticker('xhj003'), isTrue);
      expect(StickerHandler.isSticker('ac01'), isTrue);
      expect(StickerHandler.isSticker('yct015'), isTrue);
      expect(StickerHandler.isSticker('emoji00'), isTrue);
    });

    test('rejects unknown groups and out-of-range numbers', () {
      expect(StickerHandler.isSticker('smile'), isFalse);
      expect(StickerHandler.isSticker('heart'), isFalse);
      expect(StickerHandler.isSticker('xhj999'), isFalse);
      expect(StickerHandler.isSticker('xyz001'), isFalse);
      // 无数字
      expect(StickerHandler.isSticker('xhj'), isFalse);
    });

    test('resolves xhj stickers to correct extension by files table', () {
      // xhj/003 是 png
      expect(
        StickerHandler.resolveUrl('xhj003'),
        endsWith('/static/image/sticker/xhj/003.png'),
      );
      // xhj/004 是 gif
      expect(
        StickerHandler.resolveUrl('xhj004'),
        endsWith('/static/image/sticker/xhj/004.gif'),
      );
    });

    test('resolves ac/yct stickers with zero-padded numbers', () {
      expect(
        StickerHandler.resolveUrl('ac01'),
        endsWith('/static/image/sticker/ac/01.png'),
      );
      expect(
        StickerHandler.resolveUrl('ac1001'),
        endsWith('/static/image/sticker/ac/1001.png'),
      );
      expect(
        StickerHandler.resolveUrl('yct015'),
        endsWith('/static/image/sticker/yct/015.gif'),
      );
    });

    test('resolves emoji video group to .png cover', () {
      expect(
        StickerHandler.resolveUrl('emoji00'),
        endsWith('/static/image/sticker/emoji/00.png'),
      );
      expect(
        StickerHandler.resolveUrl('emoji48'),
        endsWith('/static/image/sticker/emoji/48.png'),
      );
    });

    test('returns null for invalid shortcodes', () {
      expect(StickerHandler.resolveUrl('xhj'), isNull);
      expect(StickerHandler.resolveUrl('003'), isNull);
      expect(StickerHandler.resolveUrl('foo'), isNull);
    });

    test('exposes shortcodes list per group', () {
      final xhjCodes = StickerHandler.shortcodesOf('xhj');
      expect(xhjCodes, hasLength(32));
      expect(xhjCodes.first, 'xhj001');
      expect(xhjCodes.last, 'xhj032');

      final emojiCodes = StickerHandler.shortcodesOf('emoji');
      expect(emojiCodes, hasLength(49));
      expect(emojiCodes.first, 'emoji00');
      expect(emojiCodes.last, 'emoji48');
    });

    test('parses shortcode into group+number', () {
      final parsed = StickerHandler.parseShortcode('xhj003');
      expect(parsed?.group, 'xhj');
      expect(parsed?.number, '003');
      expect(StickerHandler.parseShortcode('foo'), isNull);
    });
  });
}
