part of '../node_seek_client.dart';

/// 用户相关
mixin _UsersMixin on _NodeSeekClientBase {
  bool get _isOfficialNodeSeekHost {
    return NodeSeekService.isOfficialHost;
  }

  /// 获取缓存的用户名
  Future<String?> getUsername() async {
    if (_username != null && _username!.isNotEmpty) return _username;

    final preloadedSync = PreloadedDataService().currentUserSync;
    final preloadedUsername = preloadedSync?['username']?.toString();
    if (preloadedUsername != null && preloadedUsername.isNotEmpty) {
      _username = preloadedUsername;
      await _storage.write(key: NodeSeekClient._usernameKey, value: _username!);
      return _username;
    }

    _username = await _storage.read(key: NodeSeekClient._usernameKey);
    if (_username != null && _username!.isNotEmpty) return _username;

    try {
      final preloaded = PreloadedDataService();
      final currentUser = await preloaded.getCurrentUser();
      if (currentUser != null && currentUser['username'] != null) {
        _username = currentUser['username'] as String;
        await _storage.write(
          key: NodeSeekClient._usernameKey,
          value: _username!,
        );
        return _username;
      }
    } catch (e) {
      debugPrint('[DIO] Failed to get username from preloaded: $e');
    }

    return null;
  }

  /// 获取用户信息
  Future<User> getUser(String username) async {
    final activeRequest = _activeUserRequests[username];
    if (activeRequest != null) return activeRequest;

    late final Future<User> request;
    request = _fetchUser(username).whenComplete(() {
      if (identical(_activeUserRequests[username], request)) {
        _activeUserRequests.remove(username);
      }
    });
    _activeUserRequests[username] = request;
    return request;
  }

  Future<User> getUserByUid(int uid) {
    return NodeSeekService(_dio).getUserByUid(uid);
  }

  Future<UserSummary> getUserSummaryByUid(int uid) {
    return NodeSeekService(_dio).getUserSummaryByUid(uid);
  }

  Future<UserActionResponse> getUserActionsByUid(
    int uid, {
    String? filter,
    int offset = 0,
  }) {
    return NodeSeekService(
      _dio,
    ).getUserActionsByUid(uid, filter: filter, offset: offset);
  }

  Future<User> _fetchUser(String username) async {
    if (_isOfficialNodeSeekHost) {
      final preloaded = PreloadedDataService().currentUserSync;
      final preloadedUsername = preloaded?['username']?.toString();
      final preloadedId = _asInt(preloaded?['id']);
      if (preloadedUsername == username &&
          preloadedId != null &&
          preloadedId > 0) {
        return getUserByUid(preloadedId);
      }

      final notifierUser = currentUserNotifier.value;
      if (notifierUser?.username == username && notifierUser!.id > 0) {
        return getUserByUid(notifierUser.id);
      }

      throw StateError(
        'NodeSeek user lookup by username requires uid: $username',
      );
    }

    final response = await _dio.get('/u/$username.json');
    final data = response.data as Map<String, dynamic>;
    return User.fromJson(data['user'] ?? data);
  }

  /// 从预加载数据获取当前用户
  Future<User?> getPreloadedCurrentUser() async {
    try {
      final preloaded = PreloadedDataService();
      final currentUserData = await preloaded.getCurrentUser();
      if (currentUserData != null) {
        final user = User.fromJson(currentUserData);
        currentUserNotifier.value = user;
        if (user.username.isNotEmpty) {
          _username = user.username;
          await _storage.write(
            key: NodeSeekClient._usernameKey,
            value: _username!,
          );
        }
        return user;
      }
    } catch (e) {
      debugPrint('[NodeSeekClient] getPreloadedCurrentUser failed: $e');
    }
    return null;
  }

  /// 获取当前用户信息
  /// 网络错误时会抛出异常，由调用方决定如何处理
  Future<User?> getCurrentUser() async {
    final preloadedUser = await getPreloadedCurrentUser();
    if (_isOfficialNodeSeekHost && preloadedUser != null) {
      if (preloadedUser.id > 0) {
        try {
          final fullUser = await getUserByUid(preloadedUser.id);
          currentUserNotifier.value = fullUser;
          return fullUser;
        } catch (e) {
          debugPrint(
            '[NodeSeekClient] getCurrentUser detail refresh failed: $e',
          );
        }
      }
      currentUserNotifier.value = preloadedUser;
      return preloadedUser;
    }

    final username = await getUsername();
    if (username == null) return null;
    final user = await getUser(username);
    currentUserNotifier.value = user;
    return user;
  }

  /// 获取用户统计数据（带缓存，按用户名区分）
  Future<UserSummary> getUserSummary(
    String username, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _cachedUserSummary != null &&
        _cachedUserSummaryUsername == username &&
        _userSummaryCacheTime != null &&
        DateTime.now().difference(_userSummaryCacheTime!) <
            NodeSeekClient._summaryCacheDuration) {
      return _cachedUserSummary!;
    }

    final activeRequest = _activeUserSummaryRequests[username];
    if (activeRequest != null) return activeRequest;

    late final Future<UserSummary> request;
    request = _fetchUserSummary(username).whenComplete(() {
      if (identical(_activeUserSummaryRequests[username], request)) {
        _activeUserSummaryRequests.remove(username);
      }
    });
    _activeUserSummaryRequests[username] = request;
    return request;
  }

  Future<UserSummary> _fetchUserSummary(String username) async {
    if (_isOfficialNodeSeekHost) {
      final uid = _uidForUsername(username);
      final summary = uid == null
          ? UserSummary(
              daysVisited: 0,
              postsReadCount: 0,
              likesReceived: 0,
              likesGiven: 0,
              topicCount: 0,
              postCount: 0,
              timeRead: 0,
              bookmarkCount: 0,
            )
          : await getUserSummaryByUid(uid);
      _cachedUserSummary = summary;
      _cachedUserSummaryUsername = username;
      _userSummaryCacheTime = DateTime.now();
      return summary;
    }

    final response = await _dio.get('/u/$username/summary.json');
    final summary = UserSummary.fromJson(response.data);

    _cachedUserSummary = summary;
    _cachedUserSummaryUsername = username;
    _userSummaryCacheTime = DateTime.now();

    return summary;
  }

  /// 获取用户动态
  Future<UserActionResponse> getUserActions(
    String username, {
    String? filter,
    int offset = 0,
  }) async {
    if (_isOfficialNodeSeekHost) {
      final uid = _uidForUsername(username);
      if (uid == null) {
        return UserActionResponse.fromJson({
          'user_actions': <Map<String, dynamic>>[],
        });
      }
      return getUserActionsByUid(uid, filter: filter, offset: offset);
    }

    final queryParams = <String, dynamic>{
      'username': username,
      'offset': offset,
    };
    if (filter != null) {
      queryParams['filter'] = filter;
    }
    final response = await _dio.get(
      '/user_actions.json',
      queryParameters: queryParams,
    );
    return UserActionResponse.fromJson(response.data);
  }

  int? _uidForUsername(String username) {
    final notifierUser = currentUserNotifier.value;
    if (notifierUser?.username == username && notifierUser!.id > 0) {
      return notifierUser.id;
    }
    final preloaded = PreloadedDataService().currentUserSync;
    if (preloaded?['username']?.toString() == username) {
      final uid = _asInt(preloaded?['id']);
      if (uid != null && uid > 0) return uid;
    }
    return null;
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  /// 获取用户关注列表
  Future<List<FollowUser>> getFollowing(String username) async {
    if (_isOfficialNodeSeekHost) {
      final response = await _dio.get('/api/fans/follow');
      final data = response.data;
      if (data is Map && data['success'] == true && data['memberList'] is List) {
        return (data['memberList'] as List)
            .whereType<Map>()
            .map((item) => FollowUser(
                  id: _asInt(item['member_id']) ?? 0,
                  username: item['member_name']?.toString() ?? '',
                  name: item['member_name']?.toString() ?? '',
                  avatarTemplate: '/avatar/${item['member_id']}.png',
                ))
            .toList();
      }
      return [];
    }

    final response = await _dio.get('/u/$username/follow/following');
    return (response.data as List)
        .map((json) => FollowUser.fromJson(json))
        .toList();
  }

  /// 获取用户粉丝列表
  Future<List<FollowUser>> getFollowers(String username) async {
    if (_isOfficialNodeSeekHost) {
      final response = await _dio.get('/api/fans/fans');
      final data = response.data;
      if (data is Map && data['success'] == true && data['memberList'] is List) {
        return (data['memberList'] as List)
            .whereType<Map>()
            .map((item) => FollowUser(
                  id: _asInt(item['member_id']) ?? 0,
                  username: item['member_name']?.toString() ?? '',
                  name: item['member_name']?.toString() ?? '',
                  avatarTemplate: '/avatar/${item['member_id']}.png',
                ))
            .toList();
      }
      return [];
    }

    final response = await _dio.get('/u/$username/follow/followers');
    return (response.data as List)
        .map((json) => FollowUser.fromJson(json))
        .toList();
  }

  /// 关注用户（NodeSeek 使用 uid）
  Future<void> followUser(String username) async {
    if (_isOfficialNodeSeekHost) {
      final uid = _uidForUsername(username);
      if (uid == null) {
        throw StateError('NodeSeek follow requires uid, cannot resolve: $username');
      }
      await _dio.post(
        '/api/fans/add',
        data: {'followed_member_id': uid},
      );
      return;
    }

    try {
      await _dio.put('/follow/$username');
    } on DioException catch (e) {
      _throwApiError(e);
    }
  }

  /// 取消关注用户（NodeSeek 使用 uid）
  Future<void> unfollowUser(String username) async {
    if (_isOfficialNodeSeekHost) {
      final uid = _uidForUsername(username);
      if (uid == null) {
        throw StateError('NodeSeek unfollow requires uid, cannot resolve: $username');
      }
      await _dio.post(
        '/api/fans/del',
        data: {'followed_member_id': uid},
      );
      return;
    }

    try {
      await _dio.delete('/follow/$username');
    } on DioException catch (e) {
      _throwApiError(e);
    }
  }

  /// 设置用户订阅级别（normal/mute/ignore）
  Future<void> updateUserNotificationLevel(
    String username, {
    required String level,
    String? expiringAt,
  }) async {
    if (_isOfficialNodeSeekHost) {
      return;
    }

    await _dio.put(
      '/u/$username/notification_level.json',
      data: {'notification_level': level, 'expiring_at': ?expiringAt},
    );
  }

  /// 获取用户浏览历史
  Future<TopicListResponse> getBrowsingHistory({int page = 0}) async {
    if (_isOfficialNodeSeekHost) {
      return TopicListResponse(topics: [], moreTopicsUrl: null);
    }

    final response = await _dio.get(
      '/read.json',
      queryParameters: page > 0 ? {'page': page} : null,
    );
    return TopicListResponse.fromJson(response.data);
  }

  /// 获取用户个人书签
  Future<TopicListResponse> getUserBookmarks({int page = 0}) async {
    if (_isOfficialNodeSeekHost) {
      return NodeSeekService(_dio).getBookmarks(page: page);
    }

    final username = await getUsername();
    if (username == null) {
      throw Exception(S.current.error_notLoggedInNoUsername);
    }
    final response = await _dio.get(
      '/u/$username/bookmarks.json',
      queryParameters: page > 0 ? {'page': page} : null,
    );
    return TopicListResponse.fromJson(response.data);
  }

  /// 获取用户创建的话题
  Future<TopicListResponse> getUserCreatedTopics({int page = 0}) async {
    if (_isOfficialNodeSeekHost) {
      var user = currentUserNotifier.value;
      if (user == null || user.id <= 0) {
        user = await getCurrentUser();
      }
      if (user == null || user.id <= 0) {
        throw Exception(S.current.error_notLoggedInNoUsername);
      }
      return NodeSeekService(
        _dio,
      ).getUserCreatedTopicsByUid(user.id, page: page, author: user);
    }

    final username = await getUsername();
    if (username == null) {
      throw Exception(S.current.error_notLoggedInNoUsername);
    }
    final response = await _dio.get(
      '/topics/created-by/$username.json',
      queryParameters: page > 0 ? {'page': page} : null,
    );
    return TopicListResponse.fromJson(response.data);
  }

  /// 获取用户徽章列表
  Future<BadgeDetailResponse> getUserBadges({required String username}) async {
    if (_isOfficialNodeSeekHost) {
      _unsupportedNodeSeekFeature('徽章');
    }

    final response = await _dio.get(
      '/user-badges/${username.toLowerCase()}.json',
      queryParameters: {'grouped': 'true'},
    );
    return BadgeDetailResponse.fromJson(response.data);
  }

  /// 获取徽章信息
  Future<Badge> getBadge({required int badgeId}) async {
    if (_isOfficialNodeSeekHost) {
      _unsupportedNodeSeekFeature('徽章');
    }

    final response = await _dio.get('/badges/$badgeId.json');
    final badgeData = response.data['badge'] as Map<String, dynamic>;
    return Badge.fromJson(badgeData);
  }

  /// 获取徽章的所有获得者
  Future<BadgeDetailResponse> getBadgeUsers({
    required int badgeId,
    String? username,
  }) async {
    if (_isOfficialNodeSeekHost) {
      _unsupportedNodeSeekFeature('徽章');
    }

    final queryParams = <String, dynamic>{'badge_id': badgeId};
    if (username != null) {
      queryParams['username'] = username;
    }

    final response = await _dio.get(
      '/user_badges.json',
      queryParameters: queryParams,
    );

    return BadgeDetailResponse.fromJson(response.data);
  }

  /// 获取待使用的邀请链接
  Future<List<InviteLinkResponse>> getPendingInvites(String username) async {
    if (_isOfficialNodeSeekHost) {
      return [];
    }

    try {
      final response = await _dio.get('/u/$username/invited/pending');
      return _parsePendingInvites(response.data);
    } on DioException catch (e) {
      _throwApiError(e);
    }
  }

  List<InviteLinkResponse> _parsePendingInvites(dynamic data) {
    final items = <dynamic>[];
    if (data is List) {
      items.addAll(data);
    } else if (data is Map) {
      final invites =
          data['invites'] ??
          data['pending_invites'] ??
          data['invited'] ??
          data['pending'];
      if (invites is List) {
        items.addAll(invites);
      } else if (data['invite'] is Map ||
          data['invite_link'] is String ||
          data['invite_key'] is String) {
        items.add(data);
      }
    }

    final results = <InviteLinkResponse>[];
    for (final item in items) {
      if (item is Map) {
        results.add(
          _inviteResponseFromPendingItem(Map<String, dynamic>.from(item)),
        );
      }
    }
    return results;
  }

  InviteLinkResponse _inviteResponseFromPendingItem(Map<String, dynamic> item) {
    final payload = Map<String, dynamic>.from(item);
    if (!payload.containsKey('invite_link')) {
      final url = payload['invite_url'] ?? payload['url'] ?? payload['link'];
      if (url is String) {
        payload['invite_link'] = url;
      }
    }
    if (payload.containsKey('invite') || payload.containsKey('invite_link')) {
      return InviteLinkResponse.fromJson(payload);
    }
    return InviteLinkResponse.fromJson({
      'invite_link': payload['invite_link'],
      'invite': payload,
    });
  }

  /// 生成邀请链接
  Future<InviteLinkResponse> createInviteLink({
    required int maxRedemptionsAllowed,
    DateTime? expiresAt,
    String? description,
    String? email,
  }) async {
    if (_isOfficialNodeSeekHost) {
      _unsupportedNodeSeekFeature('邀请链接生成');
    }

    final response = await _dio.post(
      '/invites',
      data: {
        'max_redemptions_allowed': maxRedemptionsAllowed,
        if (expiresAt != null)
          'expires_at': expiresAt.toUtc().toIso8601String(),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      },
    );
    return InviteLinkResponse.fromJson(response.data as Map<String, dynamic>);
  }
}
