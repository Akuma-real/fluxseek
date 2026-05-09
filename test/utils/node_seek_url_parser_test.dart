import 'package:flutter_test/flutter_test.dart';
import 'package:fluxseek/utils/node_seek_url_parser.dart';

void main() {
  group('NodeSeekUrlParser NodeSeek routes', () {
    test('parses NodeSeek post links', () {
      final topic = NodeSeekUrlParser.parseTopic('/post-12345');

      expect(topic?.topicId, 12345);
      expect(topic?.postNumber, isNull);
    });

    test('parses NodeSeek post links with page number', () {
      final topic = NodeSeekUrlParser.parseTopic('/post-12345-2');

      expect(topic?.topicId, 12345);
      expect(topic?.postNumber, 11);
    });

    test('parses /user links as profile links', () {
      final user = NodeSeekUrlParser.parseUser('/user/example');

      expect(user?.username, 'example');
    });

    test('parses /space links as uid profile links', () {
      final user = NodeSeekUrlParser.parseUser('/space/6380');

      expect(user?.username, 'user6380');
      expect(user?.uid, 6380);
    });
  });
}
