import 'package:flutter/material.dart';

class NodeSeekTabData {
  const NodeSeekTabData({required this.title, required this.bodyHtml});

  final String title;
  final String bodyHtml;
}

Widget? buildNodeSeekTabs({
  required BuildContext context,
  required dynamic element,
  required Widget Function(String html, TextStyle? textStyle) htmlBuilder,
  required TextStyle? textStyle,
}) {
  final tabs = _extractTabs(element);
  if (tabs.isEmpty) return null;
  return _NodeSeekTabs(
    tabs: tabs,
    htmlBuilder: htmlBuilder,
    textStyle: textStyle,
  );
}

List<NodeSeekTabData> _extractTabs(dynamic element) {
  final children = element.children as List<dynamic>;
  final tabs = <NodeSeekTabData>[];

  for (var i = 0; i < children.length; i++) {
    final titleElement = children[i];
    if (titleElement.localName != 'div' ||
        !titleElement.classes.contains('nsk-magic-tab-title')) {
      continue;
    }

    dynamic bodyElement;
    for (var j = i + 1; j < children.length; j++) {
      final candidate = children[j];
      if (candidate.localName == 'div' &&
          candidate.classes.contains('nsk-magic-tab-body')) {
        bodyElement = candidate;
        i = j;
        break;
      }
      if (candidate.localName == 'div' &&
          candidate.classes.contains('nsk-magic-tab-title')) {
        break;
      }
    }

    if (bodyElement == null) continue;
    final title = titleElement.text.trim();
    if (title.isEmpty) continue;
    tabs.add(
      NodeSeekTabData(
        title: title,
        bodyHtml: (bodyElement.innerHtml as String).trim(),
      ),
    );
  }

  return tabs;
}

class _NodeSeekTabs extends StatefulWidget {
  const _NodeSeekTabs({
    required this.tabs,
    required this.htmlBuilder,
    required this.textStyle,
  });

  final List<NodeSeekTabData> tabs;
  final Widget Function(String html, TextStyle? textStyle) htmlBuilder;
  final TextStyle? textStyle;

  @override
  State<_NodeSeekTabs> createState() => _NodeSeekTabsState();
}

class _NodeSeekTabsState extends State<_NodeSeekTabs> {
  int _selectedIndex = 0;

  @override
  void didUpdateWidget(covariant _NodeSeekTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedIndex >= widget.tabs.length) {
      _selectedIndex = widget.tabs.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _selectedIndex.clamp(0, widget.tabs.length - 1);
    final borderColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.7);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < widget.tabs.length; i++)
                    _NodeSeekTabButton(
                      title: widget.tabs[i].title,
                      selected: i == selected,
                      isFirst: i == 0,
                      onTap: () => setState(() => _selectedIndex = i),
                    ),
                ],
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: borderColor),
          Padding(
            padding: const EdgeInsets.all(10),
            child: KeyedSubtree(
              key: ValueKey(selected),
              child: widget.htmlBuilder(
                widget.tabs[selected].bodyHtml,
                widget.textStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeSeekTabButton extends StatelessWidget {
  const _NodeSeekTabButton({
    required this.title,
    required this.selected,
    required this.isFirst,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final bool isFirst;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.primary;
    final textColor = selected
        ? selectedColor
        : theme.colorScheme.onSurface.withValues(alpha: 0.72);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(isFirst ? 7 : 0),
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44, maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? selectedColor : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelLarge?.copyWith(
            color: textColor,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
