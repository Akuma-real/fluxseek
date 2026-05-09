import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/connect_stats.dart';
import '../constants.dart';

/// 站点扩展统计 Provider。
final connectStatsProvider = FutureProvider<ConnectStats?>((ref) async {
  if (!AppConstants.siteFeatures.connectStats) return null;
  return null;
});
