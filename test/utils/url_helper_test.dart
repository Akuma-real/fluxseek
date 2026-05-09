import 'package:flutter_test/flutter_test.dart';
import 'package:fluxseek/services/nodeseek/node_seek_client.dart';
import 'package:fluxseek/utils/url_helper.dart';

void main() {
  group('UrlHelper.resolveUrl', () {
    test('keeps internal page links on origin host', () {
      expect(
        UrlHelper.resolveUrl('/post-123-1'),
        'https://www.nodeseek.com/post-123-1',
      );
    });

    test('keeps relative upload paths on origin host', () {
      expect(
        UrlHelper.resolveUrl('/uploads/short-url/test.pdf'),
        'https://www.nodeseek.com/uploads/short-url/test.pdf',
      );
      expect(
        UrlHelper.resolveUrl(
          '/uploads/default/optimized/1X/test_2_690x200.png',
        ),
        'https://www.nodeseek.com/uploads/default/optimized/1X/test_2_690x200.png',
      );
    });

    test('prepends https to protocol-relative URL', () {
      expect(
        UrlHelper.resolveUrl('//uploads.example.com/original/1X/test.png'),
        'https://uploads.example.com/original/1X/test.png',
      );
    });

    test('keeps absolute URL untouched', () {
      expect(
        UrlHelper.resolveUrl('https://edge.nodeseek.com/i/xxx.png'),
        'https://edge.nodeseek.com/i/xxx.png',
      );
    });

    test('keeps upload:// short link untouched', () {
      expect(
        UrlHelper.resolveUrl('upload://abcdef1234567890.png'),
        'upload://abcdef1234567890.png',
      );
    });
  });

  group('UrlHelper.resolveUrlWithCdn', () {
    test('aliases resolveUrl (no CDN rewrite on NodeSeek)', () {
      expect(
        UrlHelper.resolveUrlWithCdn('/images/emoji/twitter/smile.png?v=12'),
        'https://www.nodeseek.com/images/emoji/twitter/smile.png?v=12',
      );
    });
  });

  group('UrlHelper.samePrefix', () {
    test('returns true for root-relative URLs', () {
      expect(UrlHelper.samePrefix('/post-1'), isTrue);
    });

    test('returns true for same-host absolute URLs', () {
      expect(
        UrlHelper.samePrefix('https://www.nodeseek.com/post-1'),
        isTrue,
      );
    });

    test('returns false for different-host URLs', () {
      expect(UrlHelper.samePrefix('https://example.com/post-1'), isFalse);
    });
  });

  group('ResolvedUploadUrl', () {
    test('uses short_path for attachment links', () {
      final resolved = ResolvedUploadUrl(
        url: '/uploads/default/original/1X/test.pdf',
        shortPath: '/uploads/short-url/test.pdf',
      );

      expect(
        resolved.linkUrl(secureUploads: false),
        '/uploads/short-url/test.pdf',
      );
    });

    test('uses full secure URL for secure attachment links', () {
      final resolved = ResolvedUploadUrl(
        url: '/secure-uploads/default/original/1X/test.pdf',
        shortPath: '/uploads/short-url/test.pdf',
      );

      expect(
        resolved.linkUrl(secureUploads: true),
        '/secure-uploads/default/original/1X/test.pdf',
      );
    });
  });
}
