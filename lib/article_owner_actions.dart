import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'app_action_sheet.dart';
import 'app_store.dart';
import 'design.dart';

class ArticleOwnerActions extends StatefulWidget {
  const ArticleOwnerActions({
    super.key,
    required this.store,
    required this.articleID,
  });
  final AppStore store;
  final int articleID;
  @override
  State<ArticleOwnerActions> createState() => _ArticleOwnerActionsState();
}

class _ArticleOwnerActionsState extends State<ArticleOwnerActions> {
  bool busy = false;
  Future<void> unpublish() async {
    if (busy) return;
    final epoch = widget.store.epoch;
    setState(() => busy = true);
    String? status;
    final saved = await runRequest(context, () async {
      status = await widget.store.unpublishArticle(widget.articleID);
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (saved && widget.store.epoch == epoch) {
      toast(context, status == 'WITHDRAWN' ? '求助已下架' : '已下架并退回草稿箱，可修改后重新发布');
      Navigator.maybePop(context);
    }
  }

  Future<void> showActions() async {
    if (busy) return;
    final epoch = widget.store.epoch;
    final selected = await showAppActionSheet(
      context,
      builder: (_) => const AppActionSheet(
        title: '文章操作',
        subtitle: '管理当前内容',
        cancelKey: ValueKey('article-owner-menu-cancel'),
        actions: [
          AppSheetAction(
            value: 'unpublish',
            label: '下架',
            materialIcon: Icons.visibility_off_outlined,
            destructive: true,
            key: ValueKey('article-action-unpublish'),
          ),
        ],
      ),
    );
    if (!mounted || selected != 'unpublish' || widget.store.epoch != epoch) {
      return;
    }
    await unpublish();
  }

  @override
  Widget build(BuildContext context) => IconButton(
    key: ValueKey('article-owner-actions-${widget.articleID}'),
    tooltip: '更多操作',
    onPressed: busy ? null : showActions,
    icon: busy
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const AppIcon(AppIcons.more, size: 20),
  );
}
