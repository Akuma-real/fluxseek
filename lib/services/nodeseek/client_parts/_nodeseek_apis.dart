part of '../node_seek_client.dart';

/// NodeSeek 专属 API
///
/// 对齐 docs/nodeseek-api.md 中 fluxseek 可能调用的端点：
/// - 签到 / 今日额度
/// - Stardust（鸡腿）流水与转账
/// - 偏好与自定义样式
/// - 黑名单
/// - 置顶评论
/// - 未读通知计数
/// - 鸡腿积分明细
/// - 登录历史 / Telegram 绑定信息
mixin _NodeSeekApisMixin on _NodeSeekClientBase {
  bool get _nodeSeekApiOnly => NodeSeekService.isOfficialHost;

  // ==========================
  // 1. 签到 & 今日额度
  // ==========================

  /// 每日签到。[random]=true 为随机 1-14 鸡腿，false 为固定 5 个。
  /// 返回 `{success, message, current}`。
  Future<Map<String, dynamic>> checkIn({bool random = false}) async {
    _requireNodeSeek('签到');
    final response = await _dio.post(
      '/api/attendance',
      queryParameters: {'random': random ? 'true' : 'false'},
    );
    return _asMap(response.data);
  }

  /// 签到排行榜。
  Future<Map<String, dynamic>> getAttendanceBoard({int page = 1}) async {
    _requireNodeSeek('签到排行榜');
    final response = await _dio.get(
      '/api/attendance/board',
      queryParameters: {'page': page},
    );
    return _asMap(response.data);
  }

  /// 今日额度（回帖奖励、免费点赞等）。
  /// [scope]='freelike' 只校验免费点赞额度。
  Future<Map<String, dynamic>> getTodayProgress({String? scope}) async {
    _requireNodeSeek('今日额度');
    final response = await _dio.get(
      '/api/progress/today',
      queryParameters: scope == null ? null : {'scope': scope},
    );
    return _asMap(response.data);
  }

  // ==========================
  // 2. Stardust（鸡腿）
  // ==========================

  /// Stardust 流水。
  Future<Map<String, dynamic>> getStardustList({
    required int memberId,
    int count = 10,
  }) async {
    _requireNodeSeek('Stardust 流水');
    final response = await _dio.get(
      '/api/stardust/list',
      queryParameters: {'count': count, 'member_id': memberId},
    );
    return _asMap(response.data);
  }

  /// Stardust 转账预检。必须在 [sendStardust] 之前调用。
  Future<Map<String, dynamic>> prepareStardustPayment({
    required int receiverId,
  }) async {
    _requireNodeSeek('Stardust 转账预检');
    final response = await _dio.post(
      '/api/stardust/payment-prepare',
      data: {
        'receiver_id': receiverId,
        'origin': AppConstants.baseUrl,
      },
    );
    return _asMap(response.data);
  }

  /// 发送 Stardust。[refId] 为触发转账的评论 / upvote ID。
  Future<Map<String, dynamic>> sendStardust({
    required int memberId,
    required int diff,
    required int refId,
  }) async {
    _requireNodeSeek('发送 Stardust');
    final response = await _dio.post(
      '/api/stardust/send',
      data: {'member_id': memberId, 'diff': diff, 'ref_id': refId},
    );
    return _asMap(response.data);
  }

  // ==========================
  // 3. 偏好 & 自定义样式
  // ==========================

  /// 读取偏好。使用 POST（绕过 GET CSRF 请求门）。
  Future<Map<String, dynamic>> getPreferences(List<String> keys) async {
    _requireNodeSeek('偏好读取');
    final response = await _dio.post(
      '/api/preference/list',
      data: {'keys': keys},
    );
    return _asMap(response.data);
  }

  /// 写入单条偏好。请求体格式为 `{key: value}`。
  Future<Map<String, dynamic>> setPreference(String key, Object? value) async {
    _requireNodeSeek('偏好写入');
    final response = await _dio.post(
      '/api/preference/set',
      data: {key: value},
    );
    return _asMap(response.data);
  }

  /// 读取自定义 CSS。
  Future<String?> getCustomStyle() async {
    _requireNodeSeek('自定义样式读取');
    final response = await _dio.get('/api/style');
    final data = _asMap(response.data);
    final raw = data['data'];
    return raw?.toString();
  }

  /// 写入自定义 CSS（传空字符串清空）。
  Future<Map<String, dynamic>> setCustomStyle(String css) async {
    _requireNodeSeek('自定义样式写入');
    final response = await _dio.post('/api/style', data: {'style': css});
    return _asMap(response.data);
  }

  // ==========================
  // 4. 黑名单（block-list）
  // ==========================

  /// 黑名单列表。
  Future<List<Map<String, dynamic>>> getBlockList() async {
    _requireNodeSeek('黑名单');
    final response = await _dio.get('/api/block-list/list');
    final data = _asMap(response.data);
    final list = data['data'];
    if (list is List) {
      return [
        for (final item in list)
          if (item is Map) item.cast<String, dynamic>(),
      ];
    }
    return const [];
  }

  /// 拉黑（按用户名）。
  Future<void> addToBlockList(String username) async {
    _requireNodeSeek('拉黑用户');
    await _dio.post(
      '/api/block-list/add',
      data: {'block_member_name': username},
    );
  }

  /// 取消拉黑（按 uid）。
  Future<void> removeFromBlockList(int memberId) async {
    _requireNodeSeek('取消拉黑');
    await _dio.post(
      '/api/block-list/del',
      data: {'block_member_id': memberId},
    );
  }

  // ==========================
  // 5. 内容操作
  // ==========================

  /// 置顶 / 取消置顶评论（消耗 5 鸡腿）。
  Future<Map<String, dynamic>> pinComment(
    int commentId, {
    required bool pin,
  }) async {
    _requireNodeSeek('置顶评论');
    final response = await _dio.post(
      '/api/content/pin-comment',
      data: {'commentId': commentId, 'action': pin ? 'add' : 'remove'},
    );
    return _asMap(response.data);
  }

  /// 楼层快照（抽奖用）。[time] 必须是 Unix 毫秒时间戳。
  Future<List<Map<String, dynamic>>> getFloorData({
    required int postId,
    required int timeMs,
  }) async {
    _requireNodeSeek('楼层快照');
    final response = await _dio.get(
      '/api/content/floor-data',
      queryParameters: {'postId': postId, 'time': timeMs},
    );
    final data = _asMap(response.data);
    final list = data['data'];
    if (list is List) {
      return [
        for (final item in list)
          if (item is Map) item.cast<String, dynamic>(),
      ];
    }
    return const [];
  }

  // ==========================
  // 6. 通知
  // ==========================

  /// 独立的未读通知计数（回退方案，首页 SSR 已内嵌 `unViewedCount`）。
  Future<Map<String, dynamic>> getUnreadNotificationCount() async {
    _requireNodeSeek('未读通知数');
    final response = await _dio.get('/api/notification/unread-count');
    final data = _asMap(response.data);
    final counts = data['unreadCount'];
    if (counts is Map) return counts.cast<String, dynamic>();
    return const {'all': 0, 'reply': 0, 'atMe': 0, 'message': 0};
  }

  /// 标记 @我 通知已读。
  Future<void> markAtMeRead(List<int> ids) async {
    _requireNodeSeek('@我 标记已读');
    if (ids.isEmpty) return;
    await _dio.post(
      '/api/notification/at-me/markViewed',
      data: {'atMe': ids},
    );
  }

  /// 标记私信已读。
  Future<void> markMessagesRead(List<int> messageIds) async {
    _requireNodeSeek('私信标记已读');
    if (messageIds.isEmpty) return;
    await _dio.post(
      '/api/notification/message/markViewed',
      data: {'messages': messageIds},
    );
  }

  /// 私信会话列表。
  Future<List<Map<String, dynamic>>> getMessageConversations() async {
    _requireNodeSeek('私信列表');
    final response = await _dio.get('/api/notification/message/list');
    final data = _asMap(response.data);
    final list = data['msgArray'];
    if (list is List) {
      return [
        for (final item in list)
          if (item is Map) item.cast<String, dynamic>(),
      ];
    }
    return const [];
  }

  /// 与指定用户的会话历史。
  Future<Map<String, dynamic>> getMessagesWithUser(int uid) async {
    _requireNodeSeek('私信会话');
    final response = await _dio.get('/api/notification/message/with/$uid');
    return _asMap(response.data);
  }

  // ==========================
  // 7. 账号
  // ==========================

  /// 鸡腿积分明细（分页）。
  Future<Map<String, dynamic>> getCreditHistory(int page) async {
    _requireNodeSeek('鸡腿积分明细');
    final response = await _dio.get('/api/account/credit/page-$page');
    return _asMap(response.data);
  }

  /// 登录历史。
  Future<List<Map<String, dynamic>>> getSignInHistory() async {
    _requireNodeSeek('登录历史');
    final response = await _dio.get('/api/account/signIn-history');
    final data = _asMap(response.data);
    final list = data['historyIp'];
    if (list is List) {
      return [
        for (final item in list)
          if (item is Map) item.cast<String, dynamic>(),
      ];
    }
    return const [];
  }

  /// Telegram 绑定信息。
  Future<Map<String, dynamic>?> getTelegramBinding() async {
    _requireNodeSeek('Telegram 绑定');
    final response = await _dio.get('/api/account/telegram');
    final data = _asMap(response.data);
    final detail = data['telegramDetail'];
    return detail is Map ? detail.cast<String, dynamic>() : null;
  }

  /// 获取 Telegram Login Widget 需要的 Bot ID。
  Future<String?> getTelegramBotId() async {
    _requireNodeSeek('Telegram Bot ID');
    final response = await _dio.get('/api/telegram/botid');
    final data = _asMap(response.data);
    return data['botId']?.toString();
  }

  /// 更新个人简介 / 签名 / README（各字段可选）。
  Future<Map<String, dynamic>> updateIntroduction({
    String? bio,
    String? signature,
    String? readme,
  }) async {
    _requireNodeSeek('更新简介');
    final payload = <String, dynamic>{
      'bio': ?bio,
      'signature': ?signature,
      'readme': ?readme,
    };
    final response = await _dio.post(
      '/api/account/introduction',
      data: payload,
    );
    return _asMap(response.data);
  }

  // ==========================
  // 8. 邀请
  // ==========================

  /// 注册时是否必须填邀请码。
  Future<bool> isInviteCodeRequired() async {
    final response = await _dio.get(
      '/api/invite/necessary',
      options: Options(extra: const {'skipAuthCheck': true}),
    );
    final data = _asMap(response.data);
    return data['necessary'] == true;
  }

  /// 我的邀请码列表（每页 50 条）。
  Future<Map<String, dynamic>> getMyInvites({int page = 1}) async {
    _requireNodeSeek('邀请码列表');
    final response = await _dio.get(
      '/api/invite/list',
      queryParameters: {'page': page},
    );
    return _asMap(response.data);
  }

  /// 购买邀请码（扣鸡腿）。返回含 `coin` 与 `invite_code`。
  ///
  /// ⚠️⚠️⚠️ **严重警告**：此接口会**立即扣除约 1000 鸡腿**（实际消耗以响应
  /// 返回的 `coin` 差值为准），**一经调用不可撤销**。
  ///
  /// **禁止在无用户明确二次确认的场景下调用**。UI 层必须：
  /// 1. 弹出确认对话框，展示当前余额、扣除数量、扣除后余额；
  /// 2. 明确告知"不可撤销"；
  /// 3. 用户点击"确认购买"后才可调用本方法。
  ///
  /// 响应失败（余额不足等）会返回 `{"success": false, "message": "..."}`，
  /// 调用方应检查 `success` 字段。
  Future<Map<String, dynamic>> buyInviteCode() async {
    _requireNodeSeek('购买邀请码');
    final response = await _dio.post('/api/invite/buyOne');
    return _asMap(response.data);
  }

  // ==========================
  // 9. 推广
  // ==========================

  /// 推广列表（首页侧栏）。
  Future<List<Map<String, dynamic>>> getPromotions() async {
    final response = await _dio.get('/api/promotion/list');
    final data = _asMap(response.data);
    final list = data['data'];
    if (list is List) {
      return [
        for (final item in list)
          if (item is Map) item.cast<String, dynamic>(),
      ];
    }
    return const [];
  }

  // ==========================
  // 辅助方法
  // ==========================

  void _requireNodeSeek(String feature) {
    if (!_nodeSeekApiOnly) {
      throw UnsupportedError('当前站点不支持 NodeSeek 专属功能: $feature');
    }
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map) return data.cast<String, dynamic>();
    return const {};
  }
}
