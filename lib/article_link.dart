import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_icons.dart';
import 'design.dart';

Uri? articleWebLink(String text) {
  final value = text.trim();
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !{'http', 'https'}.contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      value.contains(RegExp(r'\s'))) {
    return null;
  }
  return uri;
}

Future<void> openArticleLink(BuildContext context, Uri url) async {
  try {
    if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    // The current device may not have an application for web links.
  }
  if (context.mounted) toast(context, '无法打开链接');
}

Future<Uri?> editArticleLink(BuildContext context, {String initial = ''}) =>
    showModalBottomSheet<Uri>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _LinkSheet(initial: initial),
    );

class _LinkSheet extends StatefulWidget {
  const _LinkSheet({required this.initial});
  final String initial;
  @override
  State<_LinkSheet> createState() => _LinkSheetState();
}

class _LinkSheetState extends State<_LinkSheet> {
  late final text = TextEditingController(text: widget.initial);
  bool invalid = false;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  void accept() {
    final uri = articleWebLink(text.text);
    if (uri == null) {
      setState(() => invalid = true);
      return;
    }
    Navigator.pop(context, uri);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '添加链接',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: '关闭',
                onPressed: () => Navigator.pop(context),
                icon: const AppIcon(AppIcons.close),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            autofocus: true,
            controller: text,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => accept(),
            onChanged: (_) {
              if (invalid) setState(() => invalid = false);
            },
            decoration: InputDecoration(
              hintText: '输入链接',
              errorText: invalid ? '请输入完整的 http 或 https 链接' : null,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: accept, child: const Text('添加')),
        ],
      ),
    ),
  );
}

class ArticleLinkCard extends StatelessWidget {
  const ArticleLinkCard({super.key, required this.url});
  final Uri url;
  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.inset,
    borderRadius: BorderRadius.circular(10),
    child: ListTile(
      leading: const AppIcon(AppIcons.link),
      title: Text(url.host),
      subtitle: Text(
        url.toString(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const AppIcon(AppIcons.forward, size: 16),
      onTap: () => openArticleLink(context, url),
    ),
  );
}
