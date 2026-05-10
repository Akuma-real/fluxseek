part of '../node_seek_client.dart';

/// 认证相关
mixin _AuthMixin on _NodeSeekClientBase {
  // --- 保守登出复检机制 ---
  // 收到失效信号后，不立即登出，而是累积 strike 并通过 probe 做二次验证，
  // 避免瞬时 cookie 传输问题
  // 或 token rotation 窗口导致的误判。
  static const Duration _strikeWindow = Duration(seconds: 45);
  static const Duration _inconclusiveCooldown = Duration(seconds: 30);
  int _authStrikeCount = 0;
  DateTime? _lastStrikeAt;
  DateTime? _lastInconclusiveAt;
  Future<bool?>? _activeProbe;

  void _resetStrikes() {
    _authStrikeCount = 0;
    _lastStrikeAt = null;
    _lastInconclusiveAt = null;
  }

  bool _isInCooldown() {
    final last = _lastInconclusiveAt;
    if (last == null) return false;
    return DateTime.now().difference(last) <= _inconclusiveCooldown;
  }

  /// 统一的 auth invalid 信号入口。
  /// [isStrong] 强信号：not_logged_in / 4xx + logged-out（1 次即触发 probe）
  ///           弱信号：2xx + logged-out（需 2 次累积）
  Future<void> _reportAuthSignal({
    required bool isStrong,
    required String source,
    required String triggerInfo,
    required RequestOptions requestOptions,
    int? statusCode,
  }) async {
    if (_isLoggingOut) return;

    // 冷却期内抑制
    if (_isInCooldown() && !isStrong) {
      LogWriter.instance.write({
        'timestamp': DateTime.now().toIso8601String(),
        'level': 'info',
        'type': 'auth',
        'event': 'auth_signal_suppressed_cooldown',
        'message': '处于 inconclusive 冷却期，暂时抑制弱 auth 信号',
        'source': source,
        'trigger': triggerInfo,
      });
      return;
    }

    // probe 进行中，不增加 strike（并发折叠）
    if (_activeProbe != null) {
      LogWriter.instance.write({
        'timestamp': DateTime.now().toIso8601String(),
        'level': 'info',
        'type': 'auth',
        'event': 'auth_signal_folded',
        'message': 'probe 进行中，折叠此 auth 信号',
        'source': source,
        'trigger': triggerInfo,
      });
      return;
    }

    // 累加 strike
    final now = DateTime.now();
    if (_lastStrikeAt == null ||
        now.difference(_lastStrikeAt!) > _strikeWindow) {
      _authStrikeCount = 1;
    } else {
      _authStrikeCount += 1;
    }
    _lastStrikeAt = now;

    final threshold = isStrong ? 1 : 2;

    // 记录诊断日志
    final jarTToken = await _cookieJar.getTToken();
    final sentCookieHeader = requestOptions.headers['cookie']?.toString() ?? '';
    // 优先匹配 NodeSeek 的 session cookie，兼容旧 _t
    final sentTMatch =
        RegExp(r'(?:^|;\s*)session=([^;]*)').firstMatch(sentCookieHeader) ??
        RegExp(r'(?:^|;\s*)_t=([^;]*)').firstMatch(sentCookieHeader);

    LogWriter.instance.write({
      'timestamp': now.toIso8601String(),
      'level': _authStrikeCount >= threshold ? 'warning' : 'info',
      'type': 'auth',
      'event': 'auth_signal_reported',
      'message': _authStrikeCount >= threshold
          ? 'auth 信号达到阈值，准备执行 session probe'
          : 'auth 信号已记录，等待后续信号确认',
      'source': source,
      'trigger': triggerInfo,
      'isStrong': isStrong,
      'strike': _authStrikeCount,
      'threshold': threshold,
      'statusCode': statusCode,
      'memHasToken': _tToken != null && _tToken!.isNotEmpty,
      'jarHasToken': jarTToken != null && jarTToken.isNotEmpty,
      'sentHasT': sentTMatch != null,
    });

    if (_authStrikeCount >= threshold) {
      await _probeSession(source: source, triggerInfo: triggerInfo);
    }
  }

  /// 通过 GET /session/current.json 验证会话是否仍然有效。
  /// 返回值：true=有效, false=确认失效, null=无法判断
  Future<bool?> _probeSession({required String source, String? triggerInfo}) {
    final inFlight = _activeProbe;
    if (inFlight != null) return inFlight;

    final future = _probeSessionImpl(source: source, triggerInfo: triggerInfo);
    _activeProbe = future;
    future.whenComplete(() {
      if (identical(_activeProbe, future)) {
        _activeProbe = null;
      }
    });
    return future;
  }

  Future<bool?> _probeSessionImpl({
    required String source,
    String? triggerInfo,
  }) async {
    if (NodeSeekService.isOfficialHost) {
      _lastInconclusiveAt = DateTime.now();
      return null;
    }

    final strikeSnapshot = _authStrikeCount;

    // probe 前只同步 cf_clearance，不同步 _t
    // 避免在半失效态把坏 cookie 回灌到 CookieJar
    try {
      await BoundarySyncService.instance.syncFromWebView(
        cookieNames: {'cf_clearance'},
      );
    } catch (e) {
      debugPrint('[Auth] probe 前 cf_clearance 同步失败: $e');
    }

    try {
      final response = await _dio.get(
        '/session/current.json',
        queryParameters: {'_': DateTime.now().millisecondsSinceEpoch},
        options: Options(
          extra: const {'skipAuthCheck': true, 'skipCsrf': true},
        ),
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        LogWriter.instance.write({
          'timestamp': DateTime.now().toIso8601String(),
          'level': 'warning',
          'type': 'auth',
          'event': 'auth_probe_inconclusive',
          'message': 'probe 返回非预期数据结构，暂不登出',
          'source': source,
          'trigger': ?triggerInfo,
          'statusCode': response.statusCode,
        });
        _lastInconclusiveAt = DateTime.now();
        return null;
      }

      final currentUser = data['current_user'];
      if (currentUser is Map<String, dynamic>) {
        // 会话有效，恢复
        final user = User.fromJson(currentUser);
        currentUserNotifier.value = user;
        if (user.username.isNotEmpty) {
          _username = user.username;
          await _storage.write(
            key: NodeSeekClient._usernameKey,
            value: user.username,
          );
        }
        final liveToken = await _cookieJar.getTToken();
        if (liveToken != null && liveToken.isNotEmpty) {
          _tToken = liveToken;
        }
        LogWriter.instance.write({
          'timestamp': DateTime.now().toIso8601String(),
          'level': 'info',
          'type': 'auth',
          'event': 'auth_probe_success',
          'message': 'session probe 确认会话有效，保持登录',
          'source': source,
          'trigger': ?triggerInfo,
          'username': user.username,
        });
        _resetStrikes();
        return true;
      }

      // 200 但无 current_user → 确认失效
      LogWriter.instance.write({
        'timestamp': DateTime.now().toIso8601String(),
        'level': 'warning',
        'type': 'auth',
        'event': 'auth_probe_failed',
        'message': 'session probe 确认 current_user 不存在，执行登出',
        'source': source,
        'trigger': ?triggerInfo,
      });
      await _handleAuthInvalid(
        S.current.auth_loginExpiredRelogin,
        source: 'probe_confirmed',
        triggerInfo: triggerInfo,
      );
      return false;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      // 404 = 无用户（session_controller.rb:676）
      if (status == 404) {
        LogWriter.instance.write({
          'timestamp': DateTime.now().toIso8601String(),
          'level': 'warning',
          'type': 'auth',
          'event': 'auth_probe_failed',
          'message': 'session probe 返回 404，确认会话失效',
          'source': source,
          'trigger': ?triggerInfo,
        });
        await _handleAuthInvalid(
          S.current.auth_loginExpiredRelogin,
          source: 'probe_confirmed',
          triggerInfo: triggerInfo,
        );
        return false;
      }
      // 网络异常 → inconclusive
      LogWriter.instance.write({
        'timestamp': DateTime.now().toIso8601String(),
        'level': 'warning',
        'type': 'auth',
        'event': 'auth_probe_inconclusive',
        'message': 'session probe 请求失败，暂不登出',
        'source': source,
        'trigger': ?triggerInfo,
        'statusCode': status,
        'errorType': e.type.toString(),
      });
      // 如果累积 strike 较多，升级为登出
      if (strikeSnapshot >= 2) {
        LogWriter.instance.write({
          'timestamp': DateTime.now().toIso8601String(),
          'level': 'warning',
          'type': 'auth',
          'event': 'auth_inconclusive_escalated',
          'message': 'probe 不确定但 strike 已累积 $strikeSnapshot 次，升级为登出',
          'source': source,
          'trigger': ?triggerInfo,
        });
        await _handleAuthInvalid(
          S.current.auth_loginExpiredRelogin,
          source: 'probe_escalated',
          triggerInfo: triggerInfo,
        );
        return false;
      }
      _lastInconclusiveAt = DateTime.now();
      return null;
    } catch (e) {
      debugPrint('[Auth] probe 异常: $e');
      _lastInconclusiveAt = DateTime.now();
      return null;
    }
  }

  /// 初始化拦截器
  void _initInterceptors() {
    // 添加业务特定拦截器
    _dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (!_credentialsLoaded) {
            await _loadStoredCredentials();
            _credentialsLoaded = true;
          }

          final sessionState = await _readSessionCookieState();
          final liveToken = sessionState.tToken;
          if (liveToken != _tToken) {
            if ((liveToken == null || liveToken.isEmpty) &&
                _tToken != null &&
                _tToken!.isNotEmpty) {
              LogWriter.instance.write({
                'timestamp': DateTime.now().toIso8601String(),
                'level': 'warning',
                'type': 'auth',
                'event': 'token_desync_before_request',
                'message': '请求前检测到内存 token 与 CookieJar 不一致，已按 CookieJar 修正',
                'method': options.method,
                'url': options.uri.toString(),
                'memTokenLen': _tToken?.length,
                'jarTokenLen': liveToken?.length,
              });
            }
            _tToken = (liveToken != null && liveToken.isNotEmpty)
                ? liveToken
                : null;
          }

          options.extra['_sessionCookieFingerprint'] = sessionState.fingerprint;

          debugPrint('[DIO] ${options.method} ${options.uri}');
          handler.next(options);
        },
        onResponse: (response, handler) async {
          final sessionState = await _syncSessionStateFromResponse(
            response.requestOptions,
            response: response,
            phase: 'response',
          );
          _syncMemoryTokenFromSessionState(
            sessionState,
            logWhenCleared: true,
            requestOptions: response.requestOptions,
          );

          debugPrint(
            '[DIO] ${response.statusCode} ${response.requestOptions.uri}',
          );
          handler.next(response);
        },
        onError: (error, handler) async {
          final skipAuthCheck =
              error.requestOptions.extra['skipAuthCheck'] == true;
          final data = error.response?.data;
          debugPrint('[DIO] Error: ${error.response?.statusCode}');

          // BAD CSRF / high risk action 处理：
          // NodeSeek 返回 403 + "high risk action" 通常是缺少 x-csrf-challenge header
          // 用 extra 标记防止无限循环，只重试一次
          if (error.response?.statusCode == 403 &&
              (_isBadCsrfResponse(data) || _isHighRiskResponse(data)) &&
              error.requestOptions.extra['_csrfRetried'] != true) {
            debugPrint(
              '[DIO] CSRF/high-risk detected, retrying with x-csrf-challenge header',
            );
            // 用新 header 重试原请求
            final options = error.requestOptions;
            options.extra['_csrfRetried'] = true;
            options.headers.remove('cookie');
            options.headers.remove('Cookie');
            removeHeaderCaseInsensitive(options.headers, 'X-CSRF-Token');
            _cookieSync.clearCsrfToken();
            await _cookieSync.updateCsrfToken();
            final csrfToken = _cookieSync.csrfToken;
            options.headers['x-csrf-challenge'] = 'simple-token';
            if (csrfToken != null && csrfToken.isNotEmpty) {
              options.headers['X-CSRF-Token'] = csrfToken;
            }
            try {
              final response = await _dio.fetch(options);
              return handler.resolve(response);
            } on DioException catch (e) {
              return handler.next(e);
            }
          }

          final sessionState = await _syncSessionStateFromResponse(
            error.requestOptions,
            response: error.response,
            phase: 'error',
          );
          _syncMemoryTokenFromSessionState(
            sessionState,
            requestOptions: error.requestOptions,
          );

          if (!skipAuthCheck &&
              data is Map &&
              data['error_type'] == 'not_logged_in') {
            final jarTToken = sessionState.tToken;
            await AuthLogService().logAuthInvalid(
              source: 'error_response',
              reason: data['error_type']?.toString() ?? 'not_logged_in',
              extra: {
                'method': error.requestOptions.method,
                'url': error.requestOptions.uri.toString(),
                'statusCode': error.response?.statusCode,
                'errors': data['errors'],
                'jarHasToken': jarTToken != null && jarTToken.isNotEmpty,
                'jarTokenLength': jarTToken?.length,
                'memHasToken': _tToken != null && _tToken!.isNotEmpty,
              },
            );
            // 服务端明确返回 not_logged_in 是强信号
            unawaited(
              _reportAuthSignal(
                isStrong: true,
                source: 'error_response_body',
                triggerInfo:
                    '${error.requestOptions.method} ${error.requestOptions.uri} → ${error.response?.statusCode}, error_type=${data['error_type']}',
                requestOptions: error.requestOptions,
                statusCode: error.response?.statusCode,
              ),
            );
          }

          handler.next(error);
        },
      ),
    );
  }

  Future<SessionSnapshot> _readSessionCookieState() async {
    final tToken = await _cookieJar.getTToken();
    final forumSession = await _cookieJar.getCookieValue('_forum_session');

    return SessionSnapshot.fromValues(
      tToken: tToken,
      forumSession: forumSession,
    );
  }

  Future<SessionSnapshot> _syncSessionStateFromResponse(
    RequestOptions requestOptions, {
    Response? response,
    required String phase,
  }) async {
    final sessionState = await _readSessionStateAfterResponse(response);
    final beforeFingerprint =
        requestOptions.extra['_sessionCookieFingerprint'] as String?;
    final afterFingerprint = sessionState.fingerprint;

    if (beforeFingerprint == afterFingerprint) {
      return sessionState;
    }

    final requestGeneration =
        requestOptions.extra['_sessionGeneration'] as int?;
    if (requestGeneration != null &&
        !AuthSession().isValid(requestGeneration)) {
      return sessionState;
    }

    requestOptions.extra['_sessionCookieFingerprint'] = afterFingerprint;

    LogWriter.instance.write({
      'timestamp': DateTime.now().toIso8601String(),
      'level': 'info',
      'type': 'auth',
      'event': 'session_cookie_rotated',
      'message': '检测到会话 Cookie 变化，后续请求将使用新的 _t',
      'phase': phase,
      'method': requestOptions.method,
      'url': requestOptions.uri.toString(),
      'hadSessionBefore':
          beforeFingerprint != null && beforeFingerprint.isNotEmpty,
      'hasSessionAfter':
          afterFingerprint != null && afterFingerprint.isNotEmpty,
      'beforeTLen': beforeFingerprint?.length,
      'afterTLen': afterFingerprint?.length,
      'hasForumSessionAfter': sessionState.hasForumSession,
    });

    return sessionState;
  }

  Future<SessionSnapshot> _readSessionStateAfterResponse(
    Response? response,
  ) async {
    final tTokenFromResponse = _extractTTokenFromSetCookie(response);
    if (tTokenFromResponse != null || _hasExplicitTDeletion(response)) {
      final forumSession = await _cookieJar.getCookieValue('_forum_session');
      return SessionSnapshot.fromValues(
        tToken: tTokenFromResponse,
        forumSession: forumSession,
      );
    }

    return _readSessionCookieState();
  }

  String? _extractTTokenFromSetCookie(Response? response) {
    final headers = _flattenSetCookieHeaders(response);
    String? token;

    for (final header in headers) {
      final lower = header.toLowerCase();
      // NodeSeek 主 session cookie 优先，旧 _t 兼容
      String? prefix;
      if (lower.startsWith('session=')) {
        prefix = 'session=';
      } else if (lower.startsWith('_t=')) {
        prefix = '_t=';
      }
      if (prefix == null) continue;

      final value = header.substring(prefix.length).split(';').first;
      if (value.isEmpty || value == 'del') {
        token = null;
      } else {
        token = value;
      }
    }

    return token;
  }

  bool _hasExplicitTDeletion(Response? response) {
    final headers = _flattenSetCookieHeaders(response);
    for (final header in headers) {
      final lower = header.toLowerCase();
      String? prefix;
      if (lower.startsWith('session=')) {
        prefix = 'session=';
      } else if (lower.startsWith('_t=')) {
        prefix = '_t=';
      }
      if (prefix == null) continue;

      final value = header.substring(prefix.length).split(';').first;
      if (value.isEmpty || value == 'del') {
        return true;
      }
    }
    return false;
  }

  List<String> _flattenSetCookieHeaders(Response? response) {
    final rawHeaders = response?.headers[HttpHeaders.setCookieHeader];
    if (rawHeaders == null || rawHeaders.isEmpty) return const [];

    return rawHeaders
        .map((str) => str.split(RegExp('(?<=)(,)(?=[^;]+?=)')))
        .expand((cookie) => cookie)
        .where((cookie) => cookie.isNotEmpty)
        .toList(growable: false);
  }

  void _syncMemoryTokenFromSessionState(
    SessionSnapshot sessionState, {
    bool logWhenCleared = false,
    RequestOptions? requestOptions,
  }) {
    final tToken = sessionState.tToken;

    if (tToken != null && tToken.isNotEmpty) {
      _tToken = tToken;
      return;
    }

    if (_tToken != null && _tToken!.isNotEmpty) {
      if (logWhenCleared && requestOptions != null) {
        LogWriter.instance.write({
          'timestamp': DateTime.now().toIso8601String(),
          'level': 'warning',
          'type': 'auth',
          'event': 'token_missing_after_response',
          'message': '响应后会话 Cookie 已缺失，仅记录告警，不立即清空内存 token',
          'method': requestOptions.method,
          'url': requestOptions.uri.toString(),
          'memTokenLen': _tToken?.length,
        });
      }
      // 不再立即清空 _tToken，由 probe 确认失效后在 logout() 中统一清除
      // _tToken = null;
    }
  }

  /// 判断响应是否为 BAD CSRF
  /// 服务端返回 403 + '["BAD CSRF"]' 表示 CSRF token 校验失败
  bool _isBadCsrfResponse(dynamic data) {
    if (data is String) return _looksLikeCsrfMessage(data);
    if (data is List) {
      return data.any((item) => _looksLikeCsrfMessage(item?.toString()));
    }
    if (data is Map) {
      return _looksLikeCsrfMessage(data['message']?.toString()) ||
          _looksLikeCsrfMessage(data['error']?.toString()) ||
          _looksLikeCsrfMessage(data['errors']?.toString());
    }
    return false;
  }

  bool _looksLikeCsrfMessage(String? value) {
    if (value == null) return false;
    final normalized = value.toLowerCase();
    return normalized.contains('bad csrf') ||
        normalized.contains('csrf check error') ||
        normalized == '["bad csrf"]';
  }

  /// 判断响应是否为 NodeSeek 的 high risk action（缺少 x-csrf-challenge header）
  bool _isHighRiskResponse(dynamic data) {
    if (data is Map) {
      return data['success'] == false && data['message'] == 'high risk action';
    }
    return false;
  }

  /// 设置导航 context
  void setNavigatorContext(BuildContext context) {
    _cfChallenge.setContext(context);
  }

  Future<void> _handleAuthInvalid(
    String message, {
    String? source,
    String? triggerInfo,
    bool? sentHasT,
    int? sentTLen,
  }) async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    // ===== 第一步：立即切断所有在途请求 =====
    // 先于 logout 执行，防止用户在失效状态下继续操作产生更多 403
    AuthSession().advance();

    // 收集 _t cookie 诊断信息（不含实际值，仅状态）
    final jarTToken = await _cookieJar.getTToken();
    final csrfToken = _cookieSync.csrfToken;
    final jarSessionCookies = await _cookieJar
        .getSessionCookieDiagnosticsForRequest(
          uri: Uri.parse(AppConstants.baseUrl),
        );

    // 记录被动退出日志（含触发来源，方便排查）
    LogWriter.instance.write({
      'timestamp': DateTime.now().toIso8601String(),
      'level': 'warning',
      'type': 'lifecycle',
      'event': 'logout_passive',
      'message': '登录失效被动退出',
      'reason': message,
      'source': source,
      'trigger': triggerInfo,
      // _t cookie 诊断（仅记录有无和长度，不记录实际值）
      'memHasToken': _tToken != null && _tToken!.isNotEmpty,
      'jarHasToken': jarTToken != null && jarTToken.isNotEmpty,
      'jarTokenLen': jarTToken?.length,
      'hasCsrf': csrfToken != null && csrfToken.isNotEmpty,
      'jarSessionCookies': jarSessionCookies,
      'sentHasT': sentHasT,
      'sentTLen': sentTLen,
    });

    await AuthIssueNoticeService.instance.recordPassiveLogout();
    await logout(callApi: false, refreshPreload: true);
    _isLoggingOut = false;
    _authErrorController.add(message);
  }

  /// 检查是否已登录
  ///
  /// 除了检查本地 _t cookie，旧兼容路径还会做服务端验证。
  /// 网络异常时保守返回 true（保留本地状态）。
  Future<bool> isLoggedIn() async {
    String? sessionValue;
    for (final name in CookieJarService.sessionCookieNames) {
      final value = await _cookieJar.getCookieValue(name);
      if (value != null && value.isNotEmpty) {
        sessionValue = value;
        break;
      }
    }
    if (sessionValue == null || sessionValue.isEmpty) return false;

    final username = await _storage.read(key: NodeSeekClient._usernameKey);
    if (username == null || username.isEmpty) return false;

    if (NodeSeekService.isOfficialHost) {
      _tToken = sessionValue;
      _username = username;
      return true;
    }

    // 服务端验证
    try {
      final response = await _dio.get(
        '/session/current.json',
        queryParameters: {'_': DateTime.now().millisecondsSinceEpoch},
        options: Options(
          extra: const {'skipAuthCheck': true, 'skipCsrf': true},
        ),
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['current_user'] is Map) {
        _tToken = sessionValue;
        final liveUsername = (data['current_user'] as Map)['username']
            ?.toString();
        _username = (liveUsername != null && liveUsername.isNotEmpty)
            ? liveUsername
            : username;
        _resetStrikes();
        return true;
      }
      // 200 但无 current_user
      await logout(callApi: false, refreshPreload: false);
      return false;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      // 404 = 无用户 / 401/403 = 明确拒绝
      if (status == 404 || status == 401 || status == 403) {
        await logout(callApi: false, refreshPreload: false);
        return false;
      }
      // 网络异常/CF 验证等 → 保守保留本地状态
      _tToken = sessionValue;
      _username = username;
      return true;
    } catch (_) {
      _tToken = sessionValue;
      _username = username;
      return true;
    }
  }

  /// 仅设置 token，不触发状态广播（登录流程中先设置 token，等数据就绪后再广播）
  void setToken(String tToken) {
    _tToken = tToken;
    _credentialsLoaded = false;
  }

  /// 登录成功后通知监听者（应在预加载数据就绪后调用）
  /// 会话写入由显式边界同步统一处理。
  void onLoginSuccess(String tToken) {
    _tToken = tToken;
    _credentialsLoaded = false;
    AuthIssueNoticeService.instance.clearSessionCookieRepairHint();
    _authStateController.add(null);
  }

  /// 保存用户名
  Future<void> saveUsername(String username) async {
    _username = username;
    await _storage.write(key: NodeSeekClient._usernameKey, value: username);
  }

  /// 从用户在系统浏览器复制的 Cookie 字符串导入 NodeSeek 登录态。
  ///
  /// 仅接受当前站点 Cookie，不处理账号密码。调用方应让用户先在浏览器
  /// 正常完成 NodeSeek/Cloudflare 官方验证，再复制包含 `session=` 的 Cookie。
  Future<User> importBrowserCookieHeader(String rawCookieText) async {
    final cookies = _extractBrowserCookies(rawCookieText);
    final token = _selectImportedSessionCookie(cookies)?.value;
    if (token == null || token.isEmpty) {
      throw const FormatException('未找到 NodeSeek 登录 Cookie（session）');
    }

    final baseUri = Uri.parse(AppConstants.baseUrl);
    for (final entry in cookies.entries) {
      await _cookieJar.setCookie(
        entry.key,
        entry.value,
        url: AppConstants.baseUrl,
        path: '/',
        secure: true,
        httpOnly: entry.key == 'session' || entry.key == '_t',
      );
      await _writeImportedCookieToWebView(
        baseUri,
        entry.key,
        entry.value,
        httpOnly: entry.key == 'session' || entry.key == '_t',
      );
    }

    _tToken = token;
    AuthSession().advance();

    await PreloadedDataService().refresh();
    final currentUser = PreloadedDataService().currentUserSync;
    if (currentUser == null) {
      throw StateError(
        'Cookie 已导入，但首页未返回登录用户，请确认 Cookie 属于 www.nodeseek.com 且仍有效',
      );
    }

    final user = User.fromJson(_normalizeNodeSeekCurrentUser(currentUser));
    if (user.username.isEmpty) {
      throw StateError('Cookie 已导入，但无法识别当前用户名');
    }

    _username = user.username;
    await _storage.write(
      key: NodeSeekClient._usernameKey,
      value: user.username,
    );
    currentUserNotifier.value = user;
    onLoginSuccess(token);
    return user;
  }

  Map<String, String> _extractBrowserCookies(String rawCookieText) {
    final result = <String, String>{};
    final acceptedNames = {
      ...CookieJarService.sessionCookieNames,
      'cf_clearance',
      'colorscheme',
      'sortBy',
    };
    final ignoredNames = {
      'path',
      'domain',
      'expires',
      'max-age',
      'samesite',
      'secure',
      'httponly',
    };

    final lines = rawCookieText
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);

    for (var line in lines) {
      final lower = line.toLowerCase();
      if (lower.startsWith('cookie:')) {
        line = line.substring(line.indexOf(':') + 1).trim();
      } else if (lower.startsWith('set-cookie:')) {
        line = line.substring(line.indexOf(':') + 1).trim();
      }

      for (final part in line.split(';')) {
        final item = part.trim();
        final equals = item.indexOf('=');
        if (equals <= 0) continue;
        final name = item.substring(0, equals).trim();
        final value = item.substring(equals + 1).trim();
        if (name.isEmpty || value.isEmpty) continue;
        final normalized = name.toLowerCase();
        if (ignoredNames.contains(normalized)) continue;
        if (acceptedNames.contains(name)) {
          result[name] = value;
        }
      }
    }

    return result;
  }

  MapEntry<String, String>? _selectImportedSessionCookie(
    Map<String, String> cookies,
  ) {
    for (final name in const ['session', '_t', '_forum_session']) {
      final value = cookies[name];
      if (value != null && value.isNotEmpty) {
        return MapEntry(name, value);
      }
    }
    for (final name in CookieJarService.sessionCookieNames) {
      final value = cookies[name];
      if (value != null && value.isNotEmpty) {
        return MapEntry(name, value);
      }
    }
    return null;
  }

  Future<void> _writeImportedCookieToWebView(
    Uri baseUri,
    String name,
    String value, {
    required bool httpOnly,
  }) async {
    try {
      await _cookieJar.webViewCookieManager.setCookie(
        url: WebUri(baseUri.toString()),
        name: name,
        value: value,
        path: '/',
        isSecure: true,
        isHttpOnly: httpOnly,
      );
    } catch (e) {
      debugPrint('[Login] 导入 Cookie 写入 WebView 失败: $e');
    }
  }

  Map<String, dynamic> _normalizeNodeSeekCurrentUser(Map<String, dynamic> raw) {
    final id = _asInt(raw['id']) ?? _asInt(raw['member_id']) ?? 0;
    final username =
        raw['username']?.toString() ??
        raw['member_name']?.toString() ??
        raw['name']?.toString() ??
        '';

    // 从 SSR __config__.user.unViewedCount 提取未读通知计数
    final unViewedCount = raw['unViewedCount'];
    int allUnread = 0;
    int replyUnread = 0;
    int messageUnread = 0;
    if (unViewedCount is Map) {
      allUnread = _asInt(unViewedCount['all']) ?? 0;
      replyUnread = _asInt(unViewedCount['reply']) ?? 0;
      messageUnread = _asInt(unViewedCount['message']) ?? 0;
    }

    return {
      ...raw,
      'id': id,
      'username': username,
      'name': raw['name']?.toString() ?? username,
      'avatar_template':
          raw['avatar_template']?.toString() ??
          (id > 0 ? '/avatar/$id.png' : null),
      'trust_level': _asInt(raw['trust_level']) ?? _asInt(raw['rank']) ?? 0,
      'gamification_score':
          _asInt(raw['gamification_score']) ?? _asInt(raw['coin']),
      'bio_raw': raw['bio_raw'] ?? raw['bio'],
      'created_at': raw['created_at'],
      'topic_count': _asInt(raw['topic_count']) ?? _asInt(raw['nPost']),
      'post_count': _asInt(raw['post_count']) ?? _asInt(raw['nComment']),
      // 映射 NodeSeek SSR unViewedCount 到标准通知计数字段
      'unread_notifications': replyUnread,
      'unread_high_priority_notifications': messageUnread,
      'all_unread_notifications_count': allUnread,
    };
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  /// 登出
  Future<void> logout({bool callApi = true, bool refreshPreload = true}) async {
    // ===== 第一步：切断所有旧请求 =====
    AuthSession().advance();

    // ===== 第二步：主动停止后台 Service =====
    MessageBusService().stopAll();
    CfClearanceRefreshService().stop();

    // ===== 第三步：调用登出 API（可选，用新的 generation） =====
    if (callApi) {
      try {
        if (NodeSeekService.isOfficialHost) {
          // NodeSeek 使用 POST /api/account/signOut + x-csrf-challenge header
          await _dio.post(
            '/api/account/signOut',
            options: Options(headers: {'x-csrf-challenge': 'simple-token'}),
          );
        } else {
          final usernameForLogout =
              _username ??
              await _storage.read(key: NodeSeekClient._usernameKey);
          if (usernameForLogout != null && usernameForLogout.isNotEmpty) {
            await _dio.delete('/session/$usernameForLogout');
          }
        }
      } catch (e) {
        debugPrint('[NodeSeekClient] Logout API failed: $e');
      }
    }

    // ===== 第四步：清除内存状态 =====
    _tToken = null;
    _username = null;
    _cachedUserSummary = null;
    _cachedUserSummaryUsername = null;
    _userSummaryCacheTime = null;
    await _storage.delete(key: NodeSeekClient._usernameKey);
    _credentialsLoaded = false;

    // ===== 第五步：清除 Cookie（保留 cf_clearance）=====
    await _cookieSync.reset();
    final cfClearanceCookie = await _cookieJar.getCfClearanceCookie();
    await _cookieJar.clearAll();
    if (cfClearanceCookie != null) {
      await _cookieJar.restoreCfClearance(cfClearanceCookie);
    }

    // ===== 第六步：刷新预加载数据（确保新状态就绪后再广播）=====
    PreloadedDataService().reset();
    if (refreshPreload) {
      await PreloadedDataService().refresh();
    }

    // ===== 第七步：广播状态变更（此时一切已就绪）=====
    currentUserNotifier.value = null;
    _authStateController.add(null);

    // ===== 第八步：重置 auth strike 状态 =====
    _resetStrikes();
  }
}
