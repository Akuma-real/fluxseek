import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../constants.dart';
import '../models/user.dart';
import '../providers/nodeseek_providers.dart';
import '../services/toast_service.dart';
import '../utils/time_utils.dart';
import '../l10n/s.dart';

/// 邀请码页面（NodeSeek）
///
/// 对齐 docs/nodeseek-api.md §3.4 / §3.5：
/// - `GET /api/invite/list?page={n}` 列出已购邀请码（每页 50 条）
/// - `POST /api/invite/buyOne` 花费鸡腿生成邀请码（按当前文档说明约 1000 鸡腿）
///
/// ⚠️ 购买邀请码会**立即扣除鸡腿且不可撤销**，必须通过二次确认。
class InviteLinksPage extends ConsumerStatefulWidget {
  const InviteLinksPage({super.key});

  @override
  ConsumerState<InviteLinksPage> createState() => _InviteLinksPageState();
}

class _InviteLinksPageState extends ConsumerState<InviteLinksPage> {
  /// 购买邀请码的约定鸡腿成本（文档未写死，以返回值为准）。
  /// 此处仅用于确认对话框的预估显示。
  static const int _inviteCost = 1000;

  bool _isBuying = false;
  bool _isLoadingList = false;
  List<Map<String, dynamic>> _invites = const [];
  int _totalInvites = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInvites());
  }

  Future<void> _loadInvites() async {
    if (_isLoadingList) return;
    setState(() => _isLoadingList = true);
    try {
      final data = await ref.read(nodeSeekClientProvider).getMyInvites(page: 1);
      final list = data['data'];
      final total = data['total'];
      if (!mounted) return;
      setState(() {
        _invites = list is List
            ? [
                for (final item in list)
                  if (item is Map) item.cast<String, dynamic>(),
              ]
            : const [];
        _totalInvites = total is int
            ? total
            : int.tryParse(total?.toString() ?? '') ?? _invites.length;
      });
    } catch (e) {
      if (!mounted) return;
      // 首次加载失败静默处理（可能是未登录或风控），用户看到空列表即可
      debugPrintFetchFailure(e);
    } finally {
      if (mounted) setState(() => _isLoadingList = false);
    }
  }

  void debugPrintFetchFailure(Object e) {
    // 保留调试日志但不弹 Toast
    // ignore: avoid_print
    print('[InvitePage] fetch list failed: $e');
  }

  /// 处理购买按钮：**必须**先走确认对话框。
  Future<void> _onBuyPressed() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) {
      ToastService.showError(S.current.common_pleaseLogin);
      return;
    }

    final coin = user.gamificationScore ?? 0;
    if (coin < _inviteCost) {
      ToastService.showError(
        S.current.invite_insufficientCoin(_inviteCost, coin),
      );
      return;
    }

    final confirmed = await _showPurchaseConfirmDialog(user);
    if (confirmed != true) return;

    await _performBuy();
  }

  Future<bool?> _showPurchaseConfirmDialog(User user) async {
    final theme = Theme.of(context);
    final coin = user.gamificationScore ?? 0;
    final remaining = coin - _inviteCost;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: theme.colorScheme.error,
          size: 36,
        ),
        title: Text(S.current.invite_buyConfirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 醒目警告栏
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 20,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      S.current.invite_buyConfirmWarning,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
              theme,
              label: S.current.invite_buyConfirmCurrent,
              value: '$coin',
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              theme,
              label: S.current.invite_buyConfirmCost,
              value: '-$_inviteCost',
              valueColor: theme.colorScheme.error,
              valueBold: true,
            ),
            const Divider(height: 20),
            _buildDetailRow(
              theme,
              label: S.current.invite_buyConfirmRemaining,
              value: '$remaining',
              valueBold: true,
            ),
            const SizedBox(height: 12),
            Text(
              S.current.invite_buyConfirmNotice,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.current.common_cancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.errorContainer,
              foregroundColor: theme.colorScheme.onErrorContainer,
            ),
            child: Text(S.current.invite_buyConfirmAction),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    ThemeData theme, {
    required String label,
    required String value,
    Color? valueColor,
    bool valueBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: valueColor ?? theme.colorScheme.onSurface,
            fontWeight: valueBold ? FontWeight.bold : FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Future<void> _performBuy() async {
    setState(() => _isBuying = true);
    try {
      final result = await ref.read(nodeSeekClientProvider).buyInviteCode();
      if (!mounted) return;

      if (result['success'] == false) {
        ToastService.showError(
          result['message']?.toString() ?? S.current.invite_createFailed,
        );
        return;
      }

      final newCoin = result['coin'];
      final code = result['invite_code']?.toString();

      // 同步余额到 currentUserProvider（立即刷新个人卡片的鸡腿数）
      if (newCoin is int) {
        final current = ref.read(currentUserProvider).value;
        if (current != null) {
          final updated = current.copyWith(gamificationScore: newCoin);
          ref.read(nodeSeekClientProvider).currentUserNotifier.value = updated;
        }
      }

      if (code != null && code.isNotEmpty) {
        ToastService.showSuccess(S.current.invite_buySuccess);
        await _showNewInviteSheet(code);
      } else {
        ToastService.showSuccess(S.current.invite_buySuccess);
      }

      // 拉最新列表
      await _loadInvites();
    } on DioException catch (e) {
      if (!mounted) return;
      ToastService.showError(_extractError(e));
    } catch (e) {
      if (!mounted) return;
      ToastService.showError(e.toString());
    } finally {
      if (mounted) setState(() => _isBuying = false);
    }
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return e.message ?? S.current.invite_createFailed;
  }

  Future<void> _showNewInviteSheet(String code) async {
    final theme = Theme.of(context);
    final link = _buildInviteLink(code);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    S.current.invite_buySuccessTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _InviteCodeBlock(code: code, link: link),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ToastService.showSuccess(S.current.invite_codeCopied);
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: Text(S.current.invite_copyCode),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        SharePlus.instance.share(
                          ShareParams(
                            text: link,
                            subject: S.current.invite_shareSubject,
                          ),
                        );
                      },
                      icon: const Icon(Icons.share_rounded),
                      label: Text(S.current.common_share),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildInviteLink(String code) {
    return '${AppConstants.baseUrl}/register?invite_code=$code';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider).value;
    final coin = user?.gamificationScore ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.invite_title)),
      body: RefreshIndicator(
        onRefresh: _loadInvites,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildBuyCard(theme, coin),
            const SizedBox(height: 16),
            _buildHistoryHeader(theme),
            const SizedBox(height: 8),
            if (_isLoadingList && _invites.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_invites.isEmpty)
              _buildEmptyState(theme)
            else
              ..._invites.map((item) => _buildInviteCard(theme, item)),
          ],
        ),
      ),
    );
  }

  Widget _buildBuyCard(ThemeData theme, int coin) {
    final affordable = coin >= _inviteCost;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.confirmation_number_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.invite_buyTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.invite_buyDescription(_inviteCost),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.45,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.restaurant_menu_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.invite_balanceLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$coin',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: affordable
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (_isBuying || !affordable) ? null : _onBuyPressed,
                icon: _isBuying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.shopping_cart_rounded),
                label: Text(
                  _isBuying
                      ? context.l10n.invite_buying
                      : context.l10n.invite_buyAction(_inviteCost),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryHeader(ThemeData theme) {
    return Row(
      children: [
        Text(
          context.l10n.invite_historyTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        if (_totalInvites > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$_totalInvites',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInviteCard(ThemeData theme, Map<String, dynamic> item) {
    final code = item['invite_code']?.toString() ?? '';
    final link = code.isNotEmpty ? _buildInviteLink(code) : '';
    final usedBy = item['used_by'];
    final isUsed = usedBy is Map && usedBy['member_id'] != null;
    final createdAt = item['created_at']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    code,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _StatusChip(
                  label: isUsed
                      ? context.l10n.invite_statusUsed
                      : context.l10n.invite_statusUnused,
                  color: isUsed
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (createdAt != null) ...[
                  Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    TimeUtils.formatDetailTime(
                      DateTime.tryParse(createdAt)?.toLocal(),
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (isUsed) ...[
                  const SizedBox(width: 12),
                  Icon(
                    Icons.person_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      usedBy['member_name']?.toString() ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (!isUsed && link.isNotEmpty) ...[
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: context.l10n.invite_copyCode,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ToastService.showSuccess(S.current.invite_codeCopied);
                    },
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: S.current.common_share,
                    icon: const Icon(Icons.share_rounded, size: 18),
                    onPressed: () {
                      SharePlus.instance.share(
                        ShareParams(
                          text: link,
                          subject: S.current.invite_shareSubject,
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            context.l10n.invite_noLinks,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _InviteCodeBlock extends StatelessWidget {
  final String code;
  final String link;

  const _InviteCodeBlock({required this.code, required this.link});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.current.invite_codeLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            code,
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            S.current.invite_linkLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            link,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
