part of '../node_seek_client.dart';

/// 旧嵌套视图插件能力。
///
/// NodeSeek 详情页是普通分页楼层，没有 `/n/topic` 树形回复接口。
mixin _NestedMixin on _NodeSeekClientBase {
  Future<NestedRootsResponse> getNestedRoots(
    int topicId, {
    String sort = 'old',
    int page = 0,
    bool trackVisit = false,
  }) async {
    return NestedRootsResponse(
      roots: const [],
      hasMoreRoots: false,
      page: page,
      sort: sort,
    );
  }

  Future<NestedChildrenResponse> getNestedChildren(
    int topicId,
    int postNumber, {
    String sort = 'old',
    int page = 0,
    int depth = 1,
  }) async {
    return NestedChildrenResponse(children: const [], hasMore: false, page: page);
  }
}
