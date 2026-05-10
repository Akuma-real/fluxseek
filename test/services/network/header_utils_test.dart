import 'package:flutter_test/flutter_test.dart';
import 'package:fluxseek/services/network/header_utils.dart';

void main() {
  test('removeHeaderCaseInsensitive removes all case variants', () {
    final headers = <String, dynamic>{
      'X-CSRF-Token': 'old-token',
      'x-csrf-token': 'older-token',
      'Accept': 'application/json',
    };

    removeHeaderCaseInsensitive(headers, 'X-CSRF-Token');

    expect(headers, isNot(contains('X-CSRF-Token')));
    expect(headers, isNot(contains('x-csrf-token')));
    expect(headers['Accept'], 'application/json');
  });
}
