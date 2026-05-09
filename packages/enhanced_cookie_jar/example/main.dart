import 'dart:io';

import 'package:enhanced_cookie_jar/enhanced_cookie_jar.dart';

Future<void> main() async {
  final jar = EnhancedPersistCookieJar(
    store: FileCookieStore('.dart_tool/example_enhanced_cookie_jar'),
  );

  final uri = Uri.parse('https://www.nodeseek.com/latest');
  await jar.saveFromResponse(uri, [
    Cookie('session', 'token')
      ..domain = '.nodeseek.com'
      ..path = '/'
      ..secure = true
      ..httpOnly = true,
  ]);

  final cookies = await jar.loadForRequest(uri);
  stdout.writeln('cookies=${cookies.map((e) => e.name).join(',')}');
}
