import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxseek/services/nodeseek/node_seek_service.dart';
import 'package:fluxseek/utils/font_awesome_helper.dart';

void main() {
  group('FontAwesomeHelper', () {
    test('maps NodeSeek category icon aliases to visible icons', () {
      expect(FontAwesomeHelper.getIcon('tea'), Icons.local_cafe_rounded);
      expect(FontAwesomeHelper.getIcon('formula'), Icons.functions_rounded);
      expect(FontAwesomeHelper.getIcon('receiver'), isNotNull);
      expect(FontAwesomeHelper.getIcon('texture'), Icons.texture_rounded);
    });

    test('resolves every static NodeSeek category icon', () {
      for (final item in NodeSeekService.staticCategoryData) {
        final iconName = item['icon']?.toString();
        expect(
          FontAwesomeHelper.getIcon(iconName),
          isNotNull,
          reason: 'static category icon "$iconName" should be visible',
        );
      }
    });
  });
}
