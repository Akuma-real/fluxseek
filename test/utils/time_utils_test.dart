import 'package:flutter_test/flutter_test.dart';
import 'package:fluxseek/utils/time_utils.dart';

void main() {
  group('TimeUtils.formatRecentRelativeOrDetailTime', () {
    test('uses detail time outside the relative window', () {
      final time = DateTime(2024, 1, 2, 3, 4);

      expect(
        TimeUtils.formatRecentRelativeOrDetailTime(
          time,
          relativeWindow: Duration.zero,
        ),
        '2024-01-02 03:04',
      );
    });
  });
}
