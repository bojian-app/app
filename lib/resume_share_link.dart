import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api/bojian_api.dart';
import 'app_store.dart';
import 'design.dart';

/// A link anyone can open to view the whole resume online and download it as
/// PDF. Unlike the review link it shows contact details and the photo.
class ResumeShareLinkSheet extends StatefulWidget {
  const ResumeShareLinkSheet({
    super.key,
    required this.store,
    required this.resume,
  });
  final AppStore store;
  final ResumeDraft resume;
  @override
  State<ResumeShareLinkSheet> createState() => _ResumeShareLinkSheetState();
}

class _ResumeShareLinkSheetState extends State<ResumeShareLinkSheet> {
  late final int accountEpoch;
  bool loading = true, busy = false;
  String? url, error;
  int views = 0, downloads = 0;

  @override
  void initState() {
    super.initState();
    accountEpoch = widget.store.epoch;
    load();
  }

  static String checkedURL(dynamic value) {
    final parsed = Uri.tryParse('$value');
    if (parsed == null ||
        parsed.scheme != 'https' ||
        parsed.host != 'bojian.kelance.cn' ||
        parsed.hasPort ||
        parsed.userInfo.isNotEmpty ||
        parsed.hasQuery ||
        parsed.hasFragment ||
        !RegExp(r'^/resume/[a-f0-9]{64}$').hasMatch(parsed.path)) {
      throw const ApiFailure('链接生成结果无效，请重试');
    }
    return parsed.toString();
  }

  void apply(Map data) {
    url = data['active'] == true ? checkedURL(data['url']) : null;
    views = integer(data['view_count']);
    downloads = integer(data['download_count']);
  }

  Future<void> run(String operation, {String? done}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.store.request(
        operation,
        path: {'id': '${widget.resume.id}'},
        expectedEpoch: accountEpoch,
      );
      if (!mounted) return;
      setState(() => apply(result.data));
      final link = url;
      if (operation == 'PostResumesIdShareLink' && link != null) {
        await Clipboard.setData(ClipboardData(text: link));
      }
      if (mounted && done != null) toast(context, done);
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> load() async {
    setState(() => loading = true);
    await run('GetResumesIdShareLink');
    if (mounted) setState(() => loading = false);
  }

  Future<void> share() async {
    final link = url;
    if (link == null) return;
    final box = context.findRenderObject() as RenderBox?;
    final name = widget.resume.name.trim();
    await SharePlus.instance.share(
      ShareParams(
        title: name.isEmpty ? '我的简历' : '$name的简历',
        text: '${name.isEmpty ? '我的简历' : '$name的简历'}，可在线查看并下载 PDF：\n$link',
        sharePositionOrigin: box == null
            ? null
            : Rect.fromPoints(
                box.localToGlobal(Offset.zero),
                box.localToGlobal(box.size.bottomRight(Offset.zero)),
              ),
      ),
    );
  }

  Future<void> open() async {
    final link = url;
    if (link == null) return;
    if (!await launchUrl(
      Uri.parse(link),
      mode: LaunchMode.externalApplication,
    )) {
      if (mounted) toast(context, '无法打开浏览器');
    }
  }

  Future<void> revoke() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('停用简历外链？'),
        content: const Text('停用后已发出的链接立即失效，再次生成会得到新链接。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            key: const ValueKey('resume-share-link-revoke-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('停用'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await run('DeleteResumesIdShareLink', done: '链接已停用');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final link = url;
    return PopScope(
      canPop: !busy,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '简历外链',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              Text(
                '对方无需登录，打开链接即可在线查看这份简历，并可下载与当前模板版式一致的 PDF。',
                style: TextStyle(fontSize: 14, height: 1.6, color: colors.ink),
              ),
              const SizedBox(height: 8),
              Text(
                '链接包含联系方式和照片，请只发给信任的人。内容随简历更新，停用后立即失效。',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: colors.muted,
                ),
              ),
              const SizedBox(height: 20),
              if (loading)
                const Center(child: DotMatrixLoader(compact: true))
              else ...[
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (link != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: colors.canvas,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          link,
                          key: const ValueKey('resume-share-link-url'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: colors.ink),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '已查看 $views 次 · 已下载 $downloads 次',
                          style: TextStyle(fontSize: 12, color: colors.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          key: const ValueKey('resume-share-link-copy'),
                          onPressed: busy
                              ? null
                              : () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: link),
                                  );
                                  if (context.mounted) toast(context, '链接已复制');
                                },
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: const Text('复制链接'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          key: const ValueKey('resume-share-link-share'),
                          onPressed: busy ? null : share,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: const Text('分享'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        key: const ValueKey('resume-share-link-open'),
                        onPressed: busy ? null : open,
                        child: const Text('在浏览器中预览'),
                      ),
                      TextButton(
                        key: const ValueKey('resume-share-link-revoke'),
                        onPressed: busy ? null : revoke,
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                        child: const Text('停用链接'),
                      ),
                    ],
                  ),
                ] else
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('resume-share-link-create'),
                      onPressed: busy
                          ? null
                          : () =>
                                run('PostResumesIdShareLink', done: '链接已生成并复制'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(busy ? '处理中…' : '生成并复制链接'),
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
}
