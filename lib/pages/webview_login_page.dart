import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import '../providers/preferences_provider.dart';
import '../services/credential_store_service.dart';
import '../services/auth_session.dart';
import '../services/nodeseek/node_seek_client.dart';
import '../services/preloaded_data_service.dart';
import '../services/network/cookie/boundary_sync_service.dart';
import '../services/network/cookie/cookie_jar_service.dart';
import '../services/network/cookie/csrf_token_service.dart';
import '../services/network/cookie/raw_set_cookie_queue.dart';
import '../services/network/adapters/webview_http_adapter.dart';
import '../services/toast_service.dart';
import '../services/webview_settings.dart';
import '../services/windows_webview_environment_service.dart';
import '../services/log/log_writer.dart';
import '../widgets/common/dismissible_popup_menu.dart';
import '../widgets/auth/manual_cookie_login_dialog.dart';
import '../l10n/s.dart';
import '../utils/dialog_utils.dart';

/// WebView 登录页面（统一使用 flutter_inappwebview）
class WebViewLoginPage extends ConsumerStatefulWidget {
  /// 初始加载的 URL，默认为登录页面
  /// 用于邮箱链接登录等场景，可传入 email-login URL
  final String? initialUrl;

  const WebViewLoginPage({super.key, this.initialUrl});

  @override
  ConsumerState<WebViewLoginPage> createState() => _WebViewLoginPageState();
}

class _WebViewLoginPageState extends ConsumerState<WebViewLoginPage> {
  final _service = NodeSeekClient();
  final _cookieJar = CookieJarService();
  final _credentialStore = CredentialStoreService();
  final Uri _baseUri = Uri.parse(AppConstants.baseUrl);
  InAppWebViewController? _controller;
  bool _isLoading = true;
  bool _loginHandled = false;
  bool _loginInProgress = false;
  bool _isCompletingLogin = false;
  String? _lastHomeResponseUrl;
  String _url = AppConstants.baseUrl;
  double _progress = 0;
  String? _savedUsername;
  Future<int>? _initialCookieFlushFuture;
  Completer<void>? _fingerprintCompleter;
  bool _fingerprintDone = false;

  /// 对话框期间用静态截图盖住 WebView，避免 BackdropFilter 对
  /// hybrid composition 实时回读造成的卡顿。
  Uint8List? _webViewSnapshot;

  @override
  void initState() {
    super.initState();
    _initialCookieFlushFuture = () async {
      await WebViewHttpAdapter().runStartupSessionCookieSelfCheckOnce(
        reason: 'login_page',
      );
      return RawSetCookieQueue.instance.flushToWebView();
    }();
    _loadSavedUsername();
  }

  Future<void> _loadSavedUsername() async {
    final credentials = await _credentialStore.load();
    if (mounted &&
        credentials.username != null &&
        credentials.username!.isNotEmpty) {
      setState(() => _savedUsername = credentials.username);
    }
  }

  Future<void> _clearLoginWebViewCache() async {
    try {
      await InAppWebViewController.clearAllCache(includeDiskFiles: false);
    } catch (e) {
      debugPrint('[WebViewLogin] clear cache failed: $e');
    }
  }

  Future<void> _logWebViewTimeDiagnostics(
    InAppWebViewController controller,
  ) async {
    if (!Platform.isLinux) return;
    try {
      final result = await controller.evaluateJavascript(
        source: '''
          (function() {
            try {
              var now = new Date();
              var timezone = null;
              try {
                timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
              } catch (_) {}
              return JSON.stringify({
                now: now.toString(),
                iso: now.toISOString(),
                offset: now.getTimezoneOffset(),
                timezone: timezone
              });
            } catch (e) {
              return 'error:' + e;
            }
          })();
        ''',
      );
      debugPrint('[WebViewLogin] JS time diagnostics: $result');
    } catch (e) {
      debugPrint('[WebViewLogin] JS time diagnostics failed: $e');
    }
  }

  Future<void> _reloadCurrentPage() async {
    final controller = _controller;
    if (controller == null) return;
    await _clearLoginWebViewCache();
    final current = _url.isNotEmpty
        ? _url
        : (widget.initialUrl ?? '${AppConstants.baseUrl}/signIn.html');
    await controller.loadUrl(urlRequest: URLRequest(url: WebUri(current)));
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final windowsWebViewEnvironment =
        WindowsWebViewEnvironmentService.instance.environment;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.webviewLogin_title),
        actions: [
          if (Platform.isLinux)
            IconButton(
              icon: const Icon(Icons.cookie_outlined),
              tooltip: '导入浏览器 Cookie',
              onPressed: _importBrowserCookie,
            ),
          if (_savedUsername != null)
            SwipeDismissiblePopupMenuButton<String>(
              icon: const Icon(Icons.key_rounded),
              tooltip: context.l10n.webviewLogin_savedPassword,
              onSelected: (value) {
                if (value == 'clear') {
                  _clearCredentials();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    context.l10n.webviewLogin_lastLogin(_savedUsername!),
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(context.l10n.webviewLogin_clearSaved),
                    ],
                  ),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reloadCurrentPage,
            tooltip: context.l10n.common_refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading || _isCompletingLogin)
            LinearProgressIndicator(
              value: _isCompletingLogin ? null : _progress,
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Icon(
                  Icons.lock,
                  size: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _url,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Offstage(
                  offstage: _webViewSnapshot != null,
                  child: WebViewSettings.wrapWithScrollFix(
                    InAppWebView(
                      webViewEnvironment: windowsWebViewEnvironment,
                      initialSettings: WebViewSettings.visible,
                      initialUserScripts: UnmodifiableListView([
                        ...WebViewSettings.ios15PolyfillScripts,
                      ]),
                      onReceivedServerTrustAuthRequest: (_, challenge) =>
                          WebViewSettings.handleServerTrustAuthRequest(
                            challenge,
                          ),
                      onWebViewCreated: (controller) async {
                        _controller = controller;
                        // 注册 JS Handler，用于在登录按钮点击时接收凭证
                        controller.addJavaScriptHandler(
                          handlerName: 'onLoginCredentials',
                          callback: (args) {
                            if (args.isNotEmpty &&
                                ref.read(preferencesProvider).autoFillLogin) {
                              try {
                                final data = args[0] as Map<String, dynamic>;
                                final username = data['username'] as String?;
                                final password = data['password'] as String?;
                                if (username != null &&
                                    username.isNotEmpty &&
                                    password != null &&
                                    password.isNotEmpty) {
                                  _credentialStore.save(username, password);
                                  if (mounted) {
                                    setState(() => _savedUsername = username);
                                  }
                                }
                              } catch (_) {}
                            }
                          },
                        );
                        controller.addJavaScriptHandler(
                          handlerName: 'onFingerprintDone',
                          callback: (_) {
                            _fingerprintDone = true;
                            final c = _fingerprintCompleter;
                            if (c != null && !c.isCompleted) c.complete();
                            return null;
                          },
                        );
                        controller.addJavaScriptHandler(
                          handlerName: 'onNodeSeekLoginResponse',
                          callback: (_) {
                            _handleNodeSeekLoginResponse(controller);
                            return null;
                          },
                        );
                        // 等待 cookie flush 完成再加载 URL，
                        // 确保 WebView 引擎初始化后 cookie 已就位
                        await _awaitInitialCookieFlush();
                        await _clearLoginWebViewCache();
                        await controller.loadUrl(
                          urlRequest: URLRequest(
                            url: WebUri(
                              widget.initialUrl ??
                                  '${AppConstants.baseUrl}/signIn.html',
                            ),
                          ),
                        );
                        // Android: 启用 WebAuthn/PassKey 支持
                        if (Platform.isAndroid) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            const MethodChannel(
                              'com.akuma.fluxseek/webauthn',
                            ).invokeMethod('enableWebAuthentication');
                          });
                        }
                      },
                      onLoadStart: (controller, url) => setState(() {
                        _isLoading = true;
                        _url = url?.toString() ?? '';
                        _lastHomeResponseUrl = null;
                      }),
                      onProgressChanged: (controller, progress) =>
                          setState(() => _progress = progress / 100),
                      onLoadResource: (controller, resource) {
                        _handleLoadedResource(controller, resource);
                      },
                      onLoadStop: (controller, url) async {
                        setState(() {
                          _isLoading = false;
                          _url = url?.toString() ?? '';
                        });
                        _recheckCount = 0;
                        await WebViewSettings.injectScrollFix(controller);
                        await _logWebViewTimeDiagnostics(controller);
                        _injectNodeSeekLoginHook(controller);
                        _injectFingerprintHook(controller);
                        // 自动填充登录表单
                        await _autoFillLoginForm(controller, url);
                        // 自动检测登录状态
                        await _checkLoginStatus(
                          controller,
                          currentUrl: url?.toString(),
                        );
                      },
                      onUpdateVisitedHistory: (controller, url, isReload) {
                        if (!_loginHandled && isReload != true) {
                          // SPA 路由变化时也尝试检测登录状态
                          _recheckCount = 0;
                          _checkLoginStatus(
                            controller,
                            currentUrl: url?.toString(),
                          );
                        }
                      },
                    ),
                    getController: () => _controller,
                  ),
                ),
                if (_webViewSnapshot != null)
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: Image.memory(
                        _webViewSnapshot!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                if (_isCompletingLogin)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.88),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(context.l10n.webviewLogin_loginSuccess),
                            const SizedBox(height: 8),
                            Text(
                              '正在同步登录状态...',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCredentials() async {
    final snapshot = await _controller?.takeScreenshot();
    if (!mounted) return;
    if (snapshot != null) {
      setState(() => _webViewSnapshot = snapshot);
    }
    final bool? confirmed;
    try {
      confirmed = await showAppDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.webviewLogin_clearSavedTitle),
          content: Text(context.l10n.webviewLogin_clearSavedContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.common_cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.common_delete),
            ),
          ],
        ),
      );
    } finally {
      if (mounted && _webViewSnapshot != null) {
        setState(() => _webViewSnapshot = null);
      }
    }
    if (confirmed == true) {
      await _credentialStore.clear();
      if (mounted) setState(() => _savedUsername = null);
    }
  }

  Future<void> _handleNodeSeekLoginResponse(
    InAppWebViewController controller,
  ) async {
    if (_loginHandled) return;
    debugPrint('[Login] 检测到 NodeSeek signIn API 成功响应，准备跳转首页同步登录态');
    await _awaitInitialCookieFlush();
    try {
      await BoundarySyncService.instance.syncFromWebView(
        currentUrl: AppConstants.baseUrl,
        controller: controller,
        cookieNames: CookieJarService.sessionCookieNames,
        allowLowConfidenceSessionCookies: true,
      );
    } catch (e) {
      debugPrint('[Login] signIn 响应后同步 Cookie 失败: $e');
    }

    if (!mounted || _loginHandled) return;
    await controller.loadUrl(
      urlRequest: URLRequest(url: WebUri(AppConstants.baseUrl)),
    );
    _recheckCount = 0;
    _scheduleLoginRecheck(controller);
  }

  Future<void> _importBrowserCookie() async {
    final result = await ManualCookieLoginDialog.show(context);
    if (result == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _injectNodeSeekLoginHook(InAppWebViewController controller) {
    controller.evaluateJavascript(
      source: '''
      (function() {
        if (window.__nodeSeekLoginHooked) return;
        window.__nodeSeekLoginHooked = true;

        function isSignInUrl(input) {
          try {
            var raw = typeof input === 'string' ? input : (input && input.url) || '';
            return raw.indexOf('/api/account/signIn') !== -1 || raw.indexOf('/api/account/emailSignIn') !== -1;
          } catch (_) {
            return false;
          }
        }

        function notifyIfSuccess(text) {
          try {
            var data = JSON.parse(text);
            var detail = data && data.detail;
            if (data && (data.success === true || (detail && (detail.member_id || detail.member_name)))) {
              window.flutter_inappwebview.callHandler('onNodeSeekLoginResponse', data);
            }
          } catch (_) {}
        }

        var originalFetch = window.fetch;
        if (typeof originalFetch === 'function') {
          window.fetch = function(input, init) {
            var promise = originalFetch.apply(this, arguments);
            if (isSignInUrl(input)) {
              promise.then(function(response) {
                try {
                  response.clone().text().then(notifyIfSuccess);
                } catch (_) {}
              }, function() {});
            }
            return promise;
          };
        }

        var originalOpen = XMLHttpRequest.prototype.open;
        var originalSend = XMLHttpRequest.prototype.send;
        XMLHttpRequest.prototype.open = function(method, url) {
          this.__nodeSeekLoginRequest = isSignInUrl(url);
          return originalOpen.apply(this, arguments);
        };
        XMLHttpRequest.prototype.send = function(body) {
          if (this.__nodeSeekLoginRequest) {
            this.addEventListener('loadend', function() {
              notifyIfSuccess(this.responseText || '');
            });
          }
          return originalSend.apply(this, arguments);
        };
      })();
    ''',
    );
  }

  /// 自动填充登录表单 + 注入凭证捕获脚本
  Future<void> _autoFillLoginForm(
    InAppWebViewController controller,
    WebUri? url,
  ) async {
    final autoFill = ref.read(preferencesProvider).autoFillLogin;
    if (!autoFill) return;

    final urlStr = url?.toString() ?? '';
    final host = Uri.tryParse(urlStr)?.host;
    if (host == null || host != Uri.parse(AppConstants.baseUrl).host) return;
    // 邮箱链接登录页无需自动填充
    if (urlStr.contains('/session/email-login/')) return;

    final credentials = await _credentialStore.load();
    final hasCredentials =
        credentials.username != null &&
        credentials.username!.isNotEmpty &&
        credentials.password != null &&
        credentials.password!.isNotEmpty;

    // 转义特殊字符防止 JS 注入
    final escapedUsername = hasCredentials
        ? jsonEncode(credentials.username!)
        : 'null';
    final escapedPassword = hasCredentials
        ? jsonEncode(credentials.password!)
        : 'null';

    await controller.evaluateJavascript(
      source:
          '''
      (function() {
        var savedUser = $escapedUsername;
        var savedPass = $escapedPassword;
        var filled = false;
        var hooked = false;
        var attempts = 0;
        var timer = setInterval(function() {
          var userInput = document.getElementById('login-account-name') ||
            document.querySelector('input[name="username"], input[name="account"], input[type="email"], input[type="text"]');
          var passInput = document.getElementById('login-account-password') ||
            document.querySelector('input[name="password"], input[type="password"]');
          if (userInput && passInput) {
            // 自动填充（仅一次）
            if (!filled && savedUser && savedPass) {
              filled = true;
              userInput.value = savedUser;
              passInput.value = savedPass;
              userInput.dispatchEvent(new Event('input', {bubbles: true}));
              passInput.dispatchEvent(new Event('input', {bubbles: true}));
            }
            // 监听登录按钮点击，在提交前捕获凭证
            if (!hooked) {
              hooked = true;
              var loginBtn = document.getElementById('login-button') ||
                document.querySelector('button[type="submit"], input[type="submit"], button');
              if (loginBtn) {
                loginBtn.addEventListener('click', function() {
                  var u = document.getElementById('login-account-name');
                  var p = document.getElementById('login-account-password');
                  if (u && p && u.value && p.value) {
                    window.flutter_inappwebview.callHandler('onLoginCredentials', {
                      username: u.value,
                      password: p.value
                    });
                  }
                }, true);
              }
            }
            clearInterval(timer);
          }
          if (++attempts > 30) clearInterval(timer);
        }, 300);
      })();
    ''',
    );
  }

  /// 检测登录状态，登录成功自动关闭
  Future<void> _checkLoginStatus(
    InAppWebViewController controller, {
    String? currentUrl,
  }) async {
    if (_loginHandled || _loginInProgress) return;
    _loginInProgress = true;

    try {
      final username = await _readCurrentUsername(controller);
      if (username == null || username.isEmpty) {
        if (_lastHomeResponseUrl != null &&
            _isHomePageUrl(_lastHomeResponseUrl)) {
          _scheduleLoginRecheck(controller);
        }
        return;
      }

      currentUrl ??= (await controller.getUrl())?.toString();
      await _awaitInitialCookieFlush();
      if (mounted && !_isCompletingLogin) {
        setState(() {
          _isCompletingLogin = true;
          _isLoading = true;
        });
      }

      await BoundarySyncService.instance.syncFromWebView(
        currentUrl: currentUrl,
        controller: controller,
        allowLowConfidenceSessionCookies: true,
      );
      final sessionCookie = await _readSessionCookieFromWebView(
        controller,
        currentUrl: currentUrl,
      );
      if (sessionCookie == null && !_isOfficialNodeSeekHost) {
        if (mounted && _isCompletingLogin) {
          setState(() {
            _isCompletingLogin = false;
            _isLoading = false;
          });
        }
        debugPrint('[Login] 已检测到 currentUser=$username，但尚未读到 _t，等待后续同步');
        _scheduleLoginRecheck(controller);
        return;
      }
      if (sessionCookie == null) {
        debugPrint(
          '[Login] 已检测到 NodeSeek currentUser=$username，但 Android WebView 未暴露会话 Cookie，继续以页面登录态完成收口',
        );
      }

      _loginHandled = true;
      final fingerprintFuture = _waitForFingerprintPostIfNeeded();
      final finalToken = await _finalizeLoginBeforeExit(
        controller,
        username: username,
        currentUrl: currentUrl,
        webViewSessionCookieName: sessionCookie?.name,
        webViewSessionCookieValue: sessionCookie?.value,
      );
      await fingerprintFuture;

      String? pageHtml;
      try {
        pageHtml =
            await controller.evaluateJavascript(
                  source:
                      'document.documentElement ? document.documentElement.outerHTML : null',
                )
                as String?;
      } catch (_) {}

      if (pageHtml != null && pageHtml.isNotEmpty) {
        await PreloadedDataService().hydrateFromHtml(pageHtml);
      }

      if (mounted) {
        ToastService.showSuccess(S.current.webviewLogin_loginSuccess);
        Navigator.of(context).pop(true);
      }

      unawaited(
        _finalizeLoginAfterExit(
          currentUrl: currentUrl,
          token: finalToken,
          pageHtml: pageHtml,
        ),
      );
    } finally {
      _loginInProgress = false;
    }
  }

  Future<String> _finalizeLoginBeforeExit(
    InAppWebViewController controller, {
    required String username,
    required String? currentUrl,
    required String? webViewSessionCookieName,
    required String? webViewSessionCookieValue,
  }) async {
    await _service.saveUsername(username);
    await _syncCsrfFromPage(controller);

    // 先切断旧请求，防止登录收口期间旧响应的 Set-Cookie 写入竞争
    AuthSession().advance();

    await BoundarySyncService.instance.syncFromWebView(
      currentUrl: currentUrl,
      controller: controller,
      cookieNames: CookieJarService.sessionCookieNames,
      allowLowConfidenceSessionCookies: true,
    );

    final jarToken = await _cookieJar.getTToken();
    final jarSessionCookie = await _readStoredSessionCookie();
    final finalToken =
        (jarToken != null && jarToken.isNotEmpty ? jarToken : null) ??
        (webViewSessionCookieName == '_t' &&
                webViewSessionCookieValue != null &&
                webViewSessionCookieValue.isNotEmpty
            ? webViewSessionCookieValue
            : null) ??
        (jarSessionCookie?.value != null && jarSessionCookie!.value.isNotEmpty
            ? jarSessionCookie.value
            : null) ??
        webViewSessionCookieValue;
    final tokenMatch =
        webViewSessionCookieName == '_t' &&
        webViewSessionCookieValue != null &&
        jarToken == webViewSessionCookieValue;
    final jarSessionCookies = await _cookieJar
        .getSessionCookieDiagnosticsForRequest(
          uri: Uri.parse(AppConstants.baseUrl),
        );
    LogWriter.instance.write({
      'timestamp': DateTime.now().toIso8601String(),
      'level': tokenMatch ? 'info' : 'warning',
      'type': 'auth',
      'event': 'login_cookie_finalize',
      'message': tokenMatch ? '登录收口 Cookie 对齐' : '登录收口 Cookie 不一致',
      'currentUrl': currentUrl,
      'username': username,
      'webViewSessionCookieName': webViewSessionCookieName,
      'webViewSessionCookieLen': webViewSessionCookieValue?.length,
      'jarTokenLen': jarToken?.length,
      'jarSessionCookieName': jarSessionCookie?.name,
      'jarSessionCookieLen': jarSessionCookie?.value.length,
      'finalTokenLen': finalToken?.length,
      'tokenMatch': tokenMatch,
      'jarTokenMissing': jarToken == null || jarToken.isEmpty,
      'jarSessionCookies': jarSessionCookies,
    });
    if (webViewSessionCookieName == '_t' && !tokenMatch) {
      debugPrint(
        '[Login] _t 不一致! WebView=${webViewSessionCookieValue?.length}chars, Jar=${jarToken?.length}chars',
      );
    }

    if (finalToken != null && finalToken.isNotEmpty) {
      _service.setToken(finalToken);
      _service.onLoginSuccess(finalToken);
    }
    return finalToken ?? '';
  }

  Future<void> _finalizeLoginAfterExit({
    required String? currentUrl,
    required String token,
    String? pageHtml,
  }) async {
    try {
      var reusedPreloaded = false;
      if (pageHtml != null && pageHtml.isNotEmpty) {
        reusedPreloaded = await PreloadedDataService().hydrateFromHtml(
          pageHtml,
        );
      }
      if (!reusedPreloaded) {
        debugPrint('[Login] 当前页面无可复用首页数据，回退到 HTTP refresh');
        await PreloadedDataService().refresh();
      }

      final jarToken = await _cookieJar.getTToken();
      final tokenMatch = jarToken == token;
      final jarSessionCookies = await _cookieJar
          .getSessionCookieDiagnosticsForRequest(
            uri: Uri.parse(AppConstants.baseUrl),
          );
      LogWriter.instance.write({
        'timestamp': DateTime.now().toIso8601String(),
        'level': 'info',
        'type': 'lifecycle',
        'event': 'login',
        'message': '用户登录成功',
        'jarTokenLen': jarToken?.length,
        'webViewTokenLen': token.length,
        'tokenMatch': tokenMatch,
        'currentUrl': currentUrl,
        'jarSessionCookies': jarSessionCookies,
      });
    } catch (e) {
      debugPrint('[Login] 登录态后台收尾失败: $e');
    }
  }

  Future<String?> _readCurrentUsername(
    InAppWebViewController controller,
  ) async {
    try {
      final result = await controller.evaluateJavascript(
        source: '''
        (function() {
          try {
            var cfgUser = window.__config__ && window.__config__.user;
            if (cfgUser) {
              return cfgUser.name || cfgUser.username || cfgUser.member_name || null;
            }
            var meta = document.querySelector('meta[name="current-username"]');
            if (meta && meta.content) return meta.content;
            return null;
          } catch(e) { return null; }
        })();
      ''',
      );

      if (result == null) {
        return null;
      }

      final username = result.toString();
      if (username.isEmpty || username == 'null') {
        return null;
      }
      return username;
    } catch (_) {
      return null;
    }
  }

  Future<void> _syncCsrfFromPage(InAppWebViewController controller) async {
    try {
      final csrf = await controller.evaluateJavascript(
        source: '''
        (function() {
          var meta = document.querySelector('meta[name="csrf-token"]');
          return meta && meta.content ? meta.content : null;
        })();
      ''',
      );
      if (csrf != null &&
          csrf.toString().isNotEmpty &&
          csrf.toString() != 'null') {
        CsrfTokenService().setCsrfToken(csrf.toString());
      }
    } catch (_) {}
  }

  void _injectFingerprintHook(InAppWebViewController controller) {
    controller.evaluateJavascript(
      source: '''
      (function() {
        if (window.__fpHooked) return;
        window.__fpHooked = true;
        function notify() {
          try { window.flutter_inappwebview.callHandler('onFingerprintDone'); } catch(e) {}
        }
        var _f = window.fetch;
        window.fetch = function(input, init) {
          var result = _f.apply(this, arguments);
          if (init && init.method && init.method.toUpperCase() === 'POST' &&
              typeof init.body === 'string' && init.body.indexOf('visitor_id=') !== -1) {
            result.then(notify, notify);
          }
          return result;
        };
        var _o = XMLHttpRequest.prototype.open, _s = XMLHttpRequest.prototype.send;
        XMLHttpRequest.prototype.open = function(m, u) { this._m = m; return _o.apply(this, arguments); };
        XMLHttpRequest.prototype.send = function(body) {
          if (this._m === 'POST' && typeof body === 'string' && body.indexOf('visitor_id=') !== -1) {
            this.addEventListener('loadend', notify);
          }
          return _s.apply(this, arguments);
        };
      })();
    ''',
    );
  }

  Future<void> _waitForFingerprintPost() async {
    if (_fingerprintDone) return;
    final completer = Completer<void>();
    _fingerprintCompleter = completer;
    try {
      await completer.future.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      debugPrint('[Login] 等待指纹上报超时，继续登录流程');
    }
  }

  Future<void> _waitForFingerprintPostIfNeeded() {
    if (Uri.tryParse(AppConstants.baseUrl)?.host == 'www.nodeseek.com') {
      return Future.value();
    }
    return _waitForFingerprintPost();
  }

  Future<void> _handleLoadedResource(
    InAppWebViewController controller,
    LoadedResource resource,
  ) async {
    final resourceUrl = resource.url?.toString();
    if (!_isHomePageUrl(resourceUrl)) {
      return;
    }

    _lastHomeResponseUrl = resourceUrl;
    debugPrint(
      '[Login] 检测到首页响应: url=$resourceUrl, initiatorType=${resource.initiatorType}',
    );
    await _checkLoginStatus(controller, currentUrl: resourceUrl);
  }

  Future<void> _awaitInitialCookieFlush() async {
    final future = _initialCookieFlushFuture;
    if (future == null) return;
    try {
      await future.timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('[Login] 等待初始 Cookie 回放完成失败: $e');
    }
  }

  Future<_LoginSessionCookie?> _readSessionCookieFromWebView(
    InAppWebViewController controller, {
    String? currentUrl,
  }) async {
    final cookieManager =
        WindowsWebViewEnvironmentService.instance.cookieManager;
    final candidates = <String>{
      AppConstants.baseUrl,
      '${AppConstants.baseUrl}/',
      if (currentUrl != null && currentUrl.isNotEmpty) currentUrl,
    };

    for (final url in candidates) {
      final cookies = await cookieManager.getCookies(url: WebUri(url));

      for (final name in CookieJarService.sessionCookieNames) {
        for (final cookie in cookies) {
          if (cookie.name == name && cookie.value.isNotEmpty) {
            return _LoginSessionCookie(cookie.name, cookie.value);
          }
        }
      }
    }

    for (final name in CookieJarService.sessionCookieNames) {
      final value = await _cookieJar.readCookieValueFromController(
        controller,
        name,
        currentUrl: currentUrl,
      );
      if (value != null && value.isNotEmpty) {
        return _LoginSessionCookie(name, value);
      }
    }

    return null;
  }

  Future<_LoginSessionCookie?> _readStoredSessionCookie() async {
    for (final name in CookieJarService.sessionCookieNames) {
      final value = await _cookieJar.getCookieValue(name);
      if (value != null && value.isNotEmpty) {
        return _LoginSessionCookie(name, value);
      }
    }
    return null;
  }

  int _recheckCount = 0;
  static const _maxRechecks = 15;
  static const _recheckInterval = Duration(milliseconds: 500);

  void _scheduleLoginRecheck(InAppWebViewController controller) {
    if (_recheckCount >= _maxRechecks) {
      debugPrint('[Login] 已达最大重试次数($_maxRechecks)，停止重试');
      return;
    }
    _recheckCount++;
    Future.delayed(_recheckInterval, () {
      if (!mounted || _loginHandled || _controller != controller) {
        return;
      }
      _checkLoginStatus(controller);
    });
  }

  bool _isHomePageUrl(String? rawUrl) {
    final uri = Uri.tryParse(rawUrl ?? '');
    if (uri == null) {
      return false;
    }
    if (uri.scheme != _baseUri.scheme || uri.host != _baseUri.host) {
      return false;
    }
    if (uri.hasPort != _baseUri.hasPort) {
      return false;
    }
    if (uri.hasPort && uri.port != _baseUri.port) {
      return false;
    }

    final currentPath = _normalizePath(uri.path);
    final homePath = _normalizePath(_baseUri.path);
    return currentPath == homePath;
  }

  String _normalizePath(String path) {
    if (path.isEmpty || path == '/') {
      return '/';
    }
    return path.endsWith('/') && path.length > 1
        ? path.substring(0, path.length - 1)
        : path;
  }

  bool get _isOfficialNodeSeekHost =>
      Uri.tryParse(AppConstants.baseUrl)?.host == 'www.nodeseek.com';
}

class _LoginSessionCookie {
  const _LoginSessionCookie(this.name, this.value);

  final String name;
  final String value;
}
