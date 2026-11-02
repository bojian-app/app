import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api/bojian_api.dart';
import 'app_store.dart';
import 'design.dart';

class ResumeLinkShare extends StatefulWidget {
  const ResumeLinkShare({super.key, required this.store, required this.resume});
  final AppStore store;
  final ResumeDraft resume;
  @override
  State<ResumeLinkShare> createState() => _ResumeLinkShareState();
}

class _ResumeLinkShareState extends State<ResumeLinkShare> {
  late final int accountEpoch;
  bool loading = true, busy = false;
  String? url, error;

  @override
  void initState() {
    super.initState();
    accountEpoch = widget.store.epoch;
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = await widget.store.request(
        'GetResumesIdExternalLink',
        path: {'id': '${widget.resume.id}'},
        expectedEpoch: accountEpoch,
      );
      if (!mounted) return;
      setState(
        () => url = value.data['active'] == true
            ? checkedURL(value.data['url'])
            : null,
      );
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String checkedURL(dynamic value) {
    final parsed = Uri.tryParse('$value');
    if (parsed == null ||
        parsed.scheme != 'https' ||
        parsed.host != 'bojian.kelance.cn' ||
        parsed.hasPort ||
        parsed.userInfo.isNotEmpty ||
        parsed.hasQuery ||
        parsed.hasFragment ||
        !RegExp(r'^/resume-review/[a-f0-9]{64}$').hasMatch(parsed.path)) {
      throw const ApiFailure('链接生成结果无效，请重试');
    }
    return parsed.toString();
  }

  Future<void> copy() async {
    if (busy || loading) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.store.request(
        'PostResumesIdExternalLink',
        path: {'id': '${widget.resume.id}'},
        expectedEpoch: accountEpoch,
      );
      final link = checkedURL(result.data['url']);
      if (!mounted) return;
      setState(() => url = link);
      await Clipboard.setData(ClipboardData(text: link));
      if (mounted) toast(context, '链接已复制');
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> revoke() async {
    if (busy || url == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.request(
        'DeleteResumesIdExternalLink',
        path: {'id': '${widget.resume.id}'},
        expectedEpoch: accountEpoch,
      );
      if (!mounted) return;
      setState(() => url = null);
      toast(context, '链接已停用');
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '链接分享',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Text(
              '对方无需登录，可在网页上评论和改写，由你确认采用。',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: context.colors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '链接长期有效，停用后不可访问。',
              style: TextStyle(fontSize: 12, color: context.colors.muted),
            ),
            const SizedBox(height: 24),
            if (loading)
              const Center(child: CircularProgressIndicator(strokeWidth: 2))
            else ...[
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('resume-link-copy'),
                  onPressed: busy ? null : copy,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(
                    busy
                        ? '处理中…'
                        : url == null
                        ? '生成并复制链接'
                        : '复制链接',
                  ),
                ),
              ),
              if (url != null)
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    key: const ValueKey('resume-link-revoke'),
                    onPressed: busy ? null : revoke,
                    child: const Text('停用链接'),
                  ),
                ),
              if (error != null)
                Center(
                  child: TextButton(
                    onPressed: busy ? null : load,
                    child: const Text('刷新状态'),
                  ),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}
