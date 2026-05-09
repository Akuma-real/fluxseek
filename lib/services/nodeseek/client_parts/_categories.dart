part of '../node_seek_client.dart';

/// 分类和标签相关
mixin _CategoriesMixin on _NodeSeekClientBase {
  NodeSeekService get _nodeSeekCategories => NodeSeekService(_dio);

  /// 获取站点信息（包含所有分类）
  Future<List<Category>> getCategories() async {
    final preloadedCategories = await PreloadedDataService().getCategories();
    if (preloadedCategories != null && preloadedCategories.isNotEmpty) {
      return preloadedCategories;
    }
    return _nodeSeekCategories.getCategories();
  }

  /// 获取站点热门标签
  Future<List<String>> getTags() async {
    return await PreloadedDataService().getTopTags() ?? const [];
  }

  /// 检查站点是否支持标签功能
  Future<bool> canTagTopics() async {
    return await PreloadedDataService().canTagTopics() ?? false;
  }

  /// 获取话题标题最小长度
  Future<int> getMinTopicTitleLength() async {
    return PreloadedDataService().getMinTopicTitleLength();
  }

  /// 获取私信标题最小长度
  Future<int> getMinPmTitleLength() async {
    return PreloadedDataService().getMinPmTitleLength();
  }

  /// 获取回复内容最小长度
  Future<int> getMinPostLength() async {
    return PreloadedDataService().getMinPostLength();
  }

  /// 获取首贴内容最小长度
  Future<int> getMinFirstPostLength() async {
    return PreloadedDataService().getMinFirstPostLength();
  }

  /// 获取私信内容最小长度
  Future<int> getMinPmPostLength() async {
    return PreloadedDataService().getMinPmPostLength();
  }

  /// 设置分类通知级别
  Future<void> setCategoryNotificationLevel(int categoryId, int level) async {
    debugPrint('[NodeSeek] 分类通知级别 API 未在文档中提供，跳过');
  }

  /// 获取首页书签 tab
  Future<TopicListResponse> getBookmarks({int page = 0}) async {
    return _nodeSeekCategories.getBookmarks(page: page);
  }
}
