import 'package:flutter_test/flutter_test.dart';
import 'package:fluxseek/providers/topic_list/filter_provider.dart';
import 'package:fluxseek/providers/topic_list/sort_provider.dart';

void main() {
  test(
    'NodeSeek topic list only exposes supported filters and sort orders',
    () {
      expect(supportedTopicListFilters, [TopicListFilter.latest]);
      expect(supportedTopicSortOrders, [TopicSortOrder.defaultOrder]);
    },
  );
}
