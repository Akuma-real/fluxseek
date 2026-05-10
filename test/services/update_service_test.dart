import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxseek/services/update_service.dart';

void main() {
  group('UpdateService.compareVersions', () {
    test('compares semver prerelease versions', () {
      expect(UpdateService.compareVersions('0.1.0-beta.8', '0.1.0-beta.7'), 1);
      expect(UpdateService.compareVersions('0.1.0-beta.10', '0.1.0-beta.9'), 1);
      expect(UpdateService.compareVersions('0.1.0', '0.1.0-beta.9'), 1);
      expect(UpdateService.compareVersions('0.1.1-beta.1', '0.1.0'), 1);
      expect(UpdateService.compareVersions('0.1.0+1', '0.1.0+2'), 0);
    });
  });

  group('UpdateService.checkForUpdate', () {
    test('beta builds can see newer beta prereleases', () async {
      final service = _buildService(
        currentVersion: '0.1.0-beta.7',
        releases: [
          _release('v0.1.0-beta.8', prerelease: true),
          _release('v0.1.0-beta.7', prerelease: true),
          _release('v0.1.0-beta.6', prerelease: true),
        ],
      );

      final update = await service.checkForUpdate();

      expect(update.hasUpdate, isTrue);
      expect(update.remoteVersion, '0.1.0-beta.8');
    });

    test('stable builds ignore beta prereleases', () async {
      final service = _buildService(
        currentVersion: '0.1.0',
        releases: [
          _release('v0.1.1-beta.1', prerelease: true),
          _release('v0.1.0', prerelease: false),
        ],
      );

      final update = await service.checkForUpdate();

      expect(update.hasUpdate, isFalse);
      expect(update.remoteVersion, '0.1.0');
    });

    test('stable builds continue past prerelease-only pages', () async {
      final service = _buildPagedService(
        currentVersion: '0.1.0',
        releasePages: [
          [
            for (var i = 100; i > 0; i--)
              _release('v0.1.1-beta.$i', prerelease: true),
          ],
          [_release('v0.1.1', prerelease: false)],
        ],
      );

      final update = await service.checkForUpdate();

      expect(update.hasUpdate, isTrue);
      expect(update.remoteVersion, '0.1.1');
    });

    test(
      'stable builds stop when no stable release exists on later pages',
      () async {
        final service = _buildPagedService(
          currentVersion: '0.1.0',
          releasePages: [
            [
              for (var i = 100; i > 0; i--)
                _release('v0.1.1-beta.$i', prerelease: true),
            ],
            const [],
          ],
        );

        final update = await service.checkForUpdate();

        expect(update.hasUpdate, isFalse);
        expect(update.remoteVersion, '0.1.0');
      },
    );

    test('beta builds can update to the final stable release', () async {
      final service = _buildService(
        currentVersion: '0.1.0-beta.9',
        releases: [
          _release('v0.1.0', prerelease: false),
          _release('v0.1.0-beta.9', prerelease: true),
        ],
      );

      final update = await service.checkForUpdate();

      expect(update.hasUpdate, isTrue);
      expect(update.remoteVersion, '0.1.0');
    });
  });
}

UpdateService _buildService({
  required String currentVersion,
  required List<Map<String, dynamic>> releases,
}) {
  return _buildPagedService(
    currentVersion: currentVersion,
    releasePages: [releases],
  );
}

UpdateService _buildPagedService({
  required String currentVersion,
  required List<List<Map<String, dynamic>>> releasePages,
}) {
  final dio = Dio()..httpClientAdapter = _JsonAdapter(releasePages);
  return UpdateService(
    dio: dio,
    currentVersionProvider: () async => currentVersion,
  );
}

Map<String, dynamic> _release(String tag, {required bool prerelease}) {
  return {
    'tag_name': tag,
    'html_url': 'https://github.com/Akuma-real/fluxseek/releases/tag/$tag',
    'body': '- test release',
    'draft': false,
    'prerelease': prerelease,
    'assets': [
      {
        'name': 'fluxseek-$tag-arm64-v8a.apk',
        'browser_download_url': 'https://example.com/$tag.apk',
        'size': 123,
      },
    ],
  };
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.pages);

  final List<List<Map<String, dynamic>>> pages;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final page = int.tryParse(options.uri.queryParameters['page'] ?? '1') ?? 1;
    final body = page > 0 && page <= pages.length
        ? pages[page - 1]
        : const <Map<String, dynamic>>[];
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
