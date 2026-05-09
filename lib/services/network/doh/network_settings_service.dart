import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 网络设置（DoH 能力已移除后的精简版本）
///
/// 保留占位字段供各 adapter 读取，避免跨服务调用处处报错。
/// 所有 DoH / Gateway / MITM 相关能力均为禁用状态。
class NetworkSettings {
  const NetworkSettings();

  /// 已永久禁用
  bool get dohEnabled => false;

  /// 无本地代理端口
  int? get proxyPort => null;

  /// 不使用自定义 DNS
  String get selectedServerUrl => '';

  /// 无 IPv6 偏好
  bool get preferIPv6 => false;

  /// 无 serverIp 覆盖
  String? get serverIp => null;

  /// Gateway 禁用
  bool get gatewayEnabled => false;
}

/// 已解析 host 结果（兼容旧调用方）
class ResolvedHostConfig {
  const ResolvedHostConfig({this.dnsOverrides = const [], this.preferredIp});

  const ResolvedHostConfig.empty()
    : dnsOverrides = const [],
      preferredIp = null;

  final List<String> dnsOverrides;
  final String? preferredIp;
}

/// 精简的 DNS 解析器：仅做系统 DNS 查询。
///
/// 保留此类是为了兼容 `cf_challenge_logger.dart` 诊断逻辑，不做任何 DoH。
class DohResolver {
  DohResolver();

  Future<List<InternetAddress>> resolveAll(String host) async {
    try {
      return await InternetAddress.lookup(host);
    } catch (_) {
      return const <InternetAddress>[];
    }
  }
}

/// 网络设置服务（DoH 能力移除后的 stub）。
///
/// 所有 DoH 状态永远返回 false / null，所有 DoH 操作方法为 no-op。
/// 保留公共 API 是为了避免修改所有适配器 / 拦截器 / 日志收集器。
class NetworkSettingsService {
  NetworkSettingsService._internal();

  static final NetworkSettingsService instance =
      NetworkSettingsService._internal();

  final ValueNotifier<NetworkSettings> notifier = ValueNotifier(
    const NetworkSettings(),
  );
  final ValueNotifier<bool> isApplying = ValueNotifier(false);

  final DohResolver _resolver = DohResolver();

  int get version => 0;
  DohResolver get resolver => _resolver;
  NetworkSettings get current => notifier.value;
  List<Object> get servers => const [];
  int get dnsCacheEntryCount => 0;

  /// 始终为 false：无 Gateway 模式
  bool get isGatewayMode => false;

  /// 始终为 false：无本地代理
  bool get shouldRunLocalProxy => false;

  bool get lastStartFailed => false;
  bool get wasRunningBeforeApply => false;
  bool get pendingStart => false;

  Future<void> initialize(SharedPreferences prefs) async {
    // DoH 能力已移除，无需初始化
    // 清理遗留的 SharedPreferences 键，避免堆积
    for (final key in const [
      'doh_enabled',
      'doh_selected',
      'doh_custom',
      'doh_proxy_port',
      'doh_prefer_ipv6',
      'doh_server_ip',
      'doh_ech_server',
      'doh_gateway_enabled',
      'doh_multi_ip',
      'cert_use_per_device',
      'per_device_cert_installed',
      'vpn_auto_toggle_enabled',
      'vpn_auto_toggle_suppressed_doh',
      'vpn_auto_toggle_suppressed_proxy',
    ]) {
      await prefs.remove(key);
    }
  }

  /// 保留解析接口：当前始终返回空（系统 DNS）
  Future<ResolvedHostConfig> resolveHostForRequest(String host) async {
    return const ResolvedHostConfig.empty();
  }

  /// 保留连接成功回报接口：no-op
  void reportHostConnectionFailure(String host, String? ip) {}

  /// 保留连接失败回报接口：no-op
  void reportHostConnectionSuccess(String host, String? ip) {}

  /// 供 main.dart 调用：no-op（DoH 代理已移除，无需保活）
  void ensureProxyAlive() {}

  /// 供 setting 页面调用：no-op
  Future<void> setDohEnabled(bool enabled) async {}
}
