import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxseek/services/network/cookie/csrf_token_service.dart';
import 'package:fluxseek/services/network/interceptors/request_header_interceptor.dart';

void main() {
  group('RequestHeaderInterceptor CSRF headers', () {
    test('content writes refresh missing CSRF token before request', () async {
      String? token;
      var refreshCount = 0;
      final adapter = _CapturingAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://www.nodeseek.com'))
        ..httpClientAdapter = adapter
        ..interceptors.add(
          RequestHeaderInterceptor(
            CsrfTokenService(),
            readCsrfToken: () => token,
            updateCsrfToken: () async {
              refreshCount++;
              token = 'dynamic-token';
            },
          ),
        );

      await dio.post('/api/content/new-comment', data: const {});

      expect(refreshCount, 1);
      expect(adapter.options?.headers['x-csrf-challenge'], 'simple-token');
      expect(adapter.options?.headers['X-CSRF-Token'], 'dynamic-token');
    });

    test('non-content writes keep static challenge without refresh', () async {
      var refreshCount = 0;
      final adapter = _CapturingAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://www.nodeseek.com'))
        ..httpClientAdapter = adapter
        ..interceptors.add(
          RequestHeaderInterceptor(
            CsrfTokenService(),
            readCsrfToken: () => null,
            updateCsrfToken: () async => refreshCount++,
          ),
        );

      await dio.post('/api/statistics/like', data: const {});

      expect(refreshCount, 0);
      expect(adapter.options?.headers['x-csrf-challenge'], 'simple-token');
      expect(adapter.options?.headers, isNot(contains('X-CSRF-Token')));
    });

    test('skipCsrf suppresses CSRF headers', () async {
      final adapter = _CapturingAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://www.nodeseek.com'))
        ..httpClientAdapter = adapter
        ..interceptors.add(
          RequestHeaderInterceptor(
            CsrfTokenService(),
            readCsrfToken: () => 'dynamic-token',
          ),
        );

      await dio.post(
        '/api/content/new-comment',
        data: const {},
        options: Options(extra: {'skipCsrf': true}),
      );

      expect(adapter.options?.headers, isNot(contains('x-csrf-challenge')));
      expect(adapter.options?.headers, isNot(contains('X-CSRF-Token')));
    });
  });
}

class _CapturingAdapter implements HttpClientAdapter {
  RequestOptions? options;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    this.options = options;
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
