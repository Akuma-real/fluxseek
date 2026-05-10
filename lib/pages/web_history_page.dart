import 'package:ai_model_manager/ai_model_manager.dart'
    show SwipeAction, SwipeActionCell, SwipeActionScope;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/s.dart';
import '../models/web_history_item.dart';
import '../navigation/nav_action_bus.dart';
import '../providers/web_history_provider.dart';
import '../utils/dialog_utils.dart';
import '../utils/time_utils.dart';
import 'webview_page.dart';

/// 本地内置浏览器历史页。
class WebHistoryPage extends ConsumerStatefulWidget {
  const WebHistoryPage({super.key, this.isActive = true});

  /// 嵌入底栏时用于决定是否响应 NavActionBus。
  final bool isActive;

  @override
  ConsumerState<WebHistoryPage> createState() => _WebHistoryPageState();
}

class _WebHistoryPageState extends ConsumerState<WebHistoryPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_publishScrollProgress);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _publishScrollProgress() {
    if (!_scrollController.hasClients) return;
    final raw = _scrollController.offset;
    final progress = raw < 0 ? 0.0 : raw;
    final current = ref.read(navScrollProgressProvider(NavEntryIds.history));
    final atZero = progress == 0 && current != 0;
    final crossed =
        (progress >= navScrollIconThreshold) !=
        (current >= navScrollIconThreshold);
    if (!atZero && !crossed && (progress - current).abs() < 4.0) return;
    ref.read(navScrollProgressProvider(NavEntryIds.history).notifier).state =
        progress;
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(webHistoryProvider);
    final theme = Theme.of(context);

    ref.listen(navActionBusProvider, (_, event) {
      if (event == null || event.targetId != NavEntryIds.history) return;
      if (!widget.isActive) return;
      if (event.action == NavAction.scrollToTop ||
          event.action == NavAction.refresh) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
        ref.resetNavScrollProgress(NavEntryIds.history);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.myBrowser_history),
        actions: [
          if (history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: context.l10n.myBrowser_clearHistory,
              onPressed: () => _confirmClear(context),
            ),
        ],
      ),
      body: history.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.myBrowser_historyEmpty,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : SwipeActionScope(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final item = history[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index < history.length - 1 ? 12 : 0,
                    ),
                    child: SwipeActionCell(
                      key: ValueKey(
                        '${item.url}_${item.visitedAt.millisecondsSinceEpoch}',
                      ),
                      trailingActions: [
                        SwipeAction(
                          icon: Icons.delete_outline,
                          color: Colors.red,
                          label: S.current.myBrowser_delete,
                          onPressed: () => ref
                              .read(webHistoryProvider.notifier)
                              .removeByUrl(item.url),
                        ),
                      ],
                      child: _HistoryCard(
                        item: item,
                        onTap: () => WebViewPage.open(
                          context,
                          item.url,
                          title: item.title,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  void _confirmClear(BuildContext context) {
    showAppDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.current.myBrowser_clearHistory),
        content: Text(S.current.myBrowser_clearHistoryConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.current.common_cancel),
          ),
          FilledButton(
            onPressed: () {
              ref.read(webHistoryProvider.notifier).clearAll();
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(S.current.myBrowser_clearHistory),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item, required this.onTap});

  final WebHistoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uri = Uri.tryParse(item.url);
    final host = uri?.host ?? '';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.history_rounded,
                color: Colors.purple,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title.isNotEmpty ? item.title : item.url,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          host.isNotEmpty ? host : item.url,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        TimeUtils.formatRelativeTime(item.visitedAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.outline.withValues(alpha: 0.4),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
