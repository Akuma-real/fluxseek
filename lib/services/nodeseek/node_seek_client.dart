import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart' hide Badge;
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../models/topic.dart';
import '../../models/nested_topic.dart';
import '../../models/user.dart';
import '../../models/user_action.dart';
import '../../models/notification.dart';
import '../../models/category.dart';
import '../../models/search_result.dart';
import '../../models/emoji.dart';
import '../../models/badge.dart';
import '../../models/tag_search_result.dart';
import '../../models/mention_user.dart';
import '../../models/draft.dart';
import '../../models/invite_link.dart';

import '../../constants.dart';
import '../auth_session.dart';
import '../auth_issue_notice_service.dart';
import '../cf_clearance_refresh_service.dart';
import '../network/cookie/csrf_token_service.dart';
import '../network/cookie/cookie_jar_service.dart';
import '../network/cookie/boundary_sync_service.dart';
import '../network/cookie/session_snapshot.dart';
import '../cf_challenge_service.dart';
import '../message_bus_service.dart';
import '../network/node_seek_dio.dart';
import '../network/header_utils.dart';
import 'node_seek_service.dart';
import '../preloaded_data_service.dart';
import '../auth_log_service.dart';
import '../log/log_writer.dart';
import '../network/exceptions/api_exception.dart';
import '../storage/resilient_secure_storage.dart';
import '../../l10n/s.dart';
import '../../utils/url_helper.dart';

part 'client_parts/_auth.dart';
part 'client_parts/_topics.dart';
part 'client_parts/_posts.dart';
part 'client_parts/_users.dart';
part 'client_parts/_search.dart';
part 'client_parts/_notifications.dart';
part 'client_parts/_uploads.dart';
part 'client_parts/_categories.dart';
part 'client_parts/_utils.dart';
part 'client_parts/_drafts.dart';
part 'client_parts/_nested.dart';
part 'client_parts/_nodeseek_apis.dart';

/// 基类，包含所有共享字段
abstract class _NodeSeekClientBase {
  Dio get _dio;
  ResilientSecureStorage get _storage;
  CsrfTokenService get _cookieSync;
  CookieJarService get _cookieJar;
  CfChallengeService get _cfChallenge;

  String? get _tToken;
  set _tToken(String? value);
  String? get _username;
  set _username(String? value);
  bool get _credentialsLoaded;
  set _credentialsLoaded(bool value);
  bool get _isLoggingOut;
  set _isLoggingOut(bool value);

  UserSummary? get _cachedUserSummary;
  set _cachedUserSummary(UserSummary? value);
  String? get _cachedUserSummaryUsername;
  set _cachedUserSummaryUsername(String? value);
  DateTime? get _userSummaryCacheTime;
  set _userSummaryCacheTime(DateTime? value);
  Map<String, Future<User>> get _activeUserRequests;
  Map<String, Future<UserSummary>> get _activeUserSummaryRequests;

  ValueNotifier<User?> get currentUserNotifier;
  StreamController<String> get _authErrorController;
  StreamController<void> get _authStateController;
  // ignore: unused_element
  StreamController<void> get _cfChallengeController;
  Map<String, ResolvedUploadUrl> get _urlCache;

  bool get isAuthenticated;

  // 共享工具方法
  Exception _handleDioError(DioException error);
  Never _throwApiError(DioException e);
  Never _unsupportedNodeSeekFeature(String feature);
  Future<void> _loadStoredCredentials();
}

/// NodeSeek 客户端门面。
///
/// 这里保留旧 UI 调用面需要的方法，底层逐步迁到 NodeSeek 专用实现。
class NodeSeekClient extends _NodeSeekClientBase
    with
        _AuthMixin,
        _TopicsMixin,
        _PostsMixin,
        _UsersMixin,
        _SearchMixin,
        _NotificationsMixin,
        _UploadsMixin,
        _CategoriesMixin,
        _UtilsMixin,
        _DraftsMixin,
        _NestedMixin,
        _NodeSeekApisMixin {
  static const String baseUrl = AppConstants.baseUrl;
  static const String _usernameKey = 'linux_do_username';
  static const _summaryCacheDuration = Duration(minutes: 5);

  @override
  final Dio _dio;
  @override
  final ResilientSecureStorage _storage;
  @override
  final CsrfTokenService _cookieSync = CsrfTokenService();
  @override
  final CookieJarService _cookieJar = CookieJarService();
  @override
  final CfChallengeService _cfChallenge = CfChallengeService();

  @override
  String? _tToken;
  @override
  String? _username;
  @override
  bool _credentialsLoaded = false;
  @override
  bool _isLoggingOut = false;

  @override
  UserSummary? _cachedUserSummary;
  @override
  String? _cachedUserSummaryUsername;
  @override
  DateTime? _userSummaryCacheTime;
  @override
  final Map<String, Future<User>> _activeUserRequests = {};
  @override
  final Map<String, Future<UserSummary>> _activeUserSummaryRequests = {};

  @override
  final ValueNotifier<User?> currentUserNotifier = ValueNotifier<User?>(null);

  @override
  final _authErrorController = StreamController<String>.broadcast();
  Stream<String> get authErrorStream => _authErrorController.stream;

  @override
  final _authStateController = StreamController<void>.broadcast();
  Stream<void> get authStateStream => _authStateController.stream;

  @override
  final _cfChallengeController = StreamController<void>.broadcast();
  Stream<void> get cfChallengeStream => _cfChallengeController.stream;

  @override
  final Map<String, ResolvedUploadUrl> _urlCache = {};

  static final NodeSeekClient _instance = NodeSeekClient._internal();
  factory NodeSeekClient() => _instance;

  CsrfTokenService get cookieSync => _cookieSync;

  Dio get dio => _dio;

  @override
  bool get isAuthenticated => _tToken != null && _tToken!.isNotEmpty;

  NodeSeekClient._internal()
    : _dio = NodeSeekDio.create(
        defaultHeaders: {
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'X-Requested-With': 'XMLHttpRequest',
        },
      ),
      _storage = ResilientSecureStorage() {
    _initInterceptors();
  }

  // ========== 共享工具方法 ==========

  /// 处理 Dio 错误
  @override
  Exception _handleDioError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return TimeoutException(error.message);
    }
    if (error.response != null) {
      final statusCode = error.response!.statusCode;
      final errorMessage = error.response!.data.toString();
      return Exception('HTTP $statusCode: $errorMessage');
    }
    return Exception(error.message ?? 'Unknown Dio error');
  }

  /// 从 DioException 中提取 API 错误消息并抛出
  @override
  Never _throwApiError(DioException e) {
    if (e.response?.data is Map) {
      final data = e.response!.data as Map;
      if (data['errors'] != null && data['errors'] is List) {
        throw Exception((data['errors'] as List).join('\n'));
      }
    }
    throw e;
  }

  @override
  Never _unsupportedNodeSeekFeature(String feature) {
    throw UnsupportedError('NodeSeek 暂不支持$feature');
  }

  /// 加载存储的凭证
  @override
  Future<void> _loadStoredCredentials() async {
    for (final name in CookieJarService.sessionCookieNames) {
      final value = await _cookieJar.getCookieValue(name);
      if (value != null && value.isNotEmpty) {
        _tToken = value;
        break;
      }
    }
    _username = await _storage.read(key: _usernameKey);
  }
}
