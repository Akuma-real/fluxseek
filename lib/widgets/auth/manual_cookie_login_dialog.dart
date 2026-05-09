import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/nodeseek/node_seek_client.dart';
import '../../services/toast_service.dart';

class ManualCookieLoginDialog extends StatefulWidget {
  const ManualCookieLoginDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    if (!Platform.isLinux) return false;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const ManualCookieLoginDialog(),
    );
    return result == true;
  }

  @override
  State<ManualCookieLoginDialog> createState() =>
      _ManualCookieLoginDialogState();
}

class _ManualCookieLoginDialogState extends State<ManualCookieLoginDialog> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      ToastService.showError('剪贴板里没有 Cookie');
      return;
    }
    setState(() => _controller.text = text);
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ToastService.showError('请先粘贴 Cookie');
      return;
    }

    setState(() => _submitting = true);
    try {
      final user = await NodeSeekClient().importBrowserCookieHeader(text);
      if (!mounted) return;
      ToastService.showSuccess('已登录 @${user.username}');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ToastService.showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('导入浏览器 Cookie'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '先在系统浏览器正常登录 NodeSeek，然后复制 www.nodeseek.com 请求里的 Cookie header。这里只会读取 session、smac、hmti_、fog、cf_clearance 等 Cookie，不要粘贴密码。',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              minLines: 5,
              maxLines: 8,
              enabled: !_submitting,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Cookie: session=...; smac=...; cf_clearance=...',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : _pasteFromClipboard,
          child: const Text('粘贴'),
        ),
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('导入'),
        ),
      ],
    );
  }
}
