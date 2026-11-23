import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter/material.dart';

import 'api/bojian_api.dart';
import 'app_icons.dart';
import 'app_page_bar.dart';
import 'app_store.dart';
import 'design.dart';
import 'photo_source_sheet.dart';
import 'support_attachment.dart';
import 'resume_photo.dart' show validateResumePhoto;

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key, required this.store, this.initialText = ''});

  final AppStore store;
  final String initialText;

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  static const topics = ['功能使用与体验', '闪退、卡顿或界面错位', '账号与隐私', '会员与订单', '其他问题'];
  static const categories = {
    'SUGGESTION': '提建议',
    'INQUIRY': '想咨询',
    'COMPLAINT': '要投诉',
  };
  late final details = TextEditingController(text: widget.initialText);
  final contact = TextEditingController();
  final photos = <XFile, String>{};
  final uploaded = <XFile, int>{};
  late final int epoch;
  String topic = topics.first, category = 'SUGGESTION';
  bool sending = false, picking = false;

  @override
  void initState() {
    super.initState();
    epoch = widget.store.epoch;
  }

  @override
  void dispose() {
    details.dispose();
    contact.dispose();
    super.dispose();
  }

  Future<void> addPhoto() async {
    if (sending || picking || photos.length >= 3) return;
    setState(() => picking = true);
    try {
      final photo = await pickAppPhoto(context);
      if (photo == null || !mounted) return;
      final mime = await validateResumePhoto(photo);
      if (mounted) setState(() => photos[photo] = mime);
    } catch (e) {
      if (mounted) await showRequestFailure(context, e);
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  void checkSession() {
    if (!mounted ||
        !widget.store.isAuthenticated ||
        widget.store.epoch != epoch) {
      throw const ApiFailure('登录状态已变化，请重新打开意见反馈');
    }
  }

  Future<void> submit() async {
    if (sending || picking) return;
    final body = details.text.trim();
    if (body.isEmpty) {
      toast(context, '请描述你的反馈详情');
      return;
    }
    final content = [
      body,
      '问题类型：$topic',
      if (contact.text.trim().isNotEmpty) '联系方式：${contact.text.trim()}',
    ].join('\n');
    String withPhotos(Iterable<String> ids) =>
        supportContentWithPhotos(content, ids);
    if (utf8.encode(withPhotos(List.filled(photos.length, '9' * 19))).length >
        2000) {
      toast(context, '反馈内容过长，请适当缩短');
      return;
    }
    dismissKeyboard();
    setState(() => sending = true);
    final ok = await runRequest(context, () async {
      for (final e in photos.entries) {
        checkSession();
        uploaded[e.key] ??= await uploadSupportPhoto(
          widget.store,
          e.key,
          e.value,
          epoch: epoch,
          checkSession: checkSession,
        );
      }
      checkSession();
      await widget.store.request(
        'PostFeedback',
        expectedEpoch: epoch,
        body: {
          'category': category,
          'content': withPhotos(photos.keys.map((p) => '${uploaded[p]!}')),
          'diagnostic_consent': false,
        },
      );
    });
    if (!mounted) return;
    if (ok) {
      toast(context, '反馈已提交', success: true);
      Navigator.pop(context);
    } else {
      setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final active = !sending && !picking;
    const inset = EdgeInsets.symmetric(horizontal: 16);
    final field = const InputDecoration(
      isCollapsed: true,
      filled: false,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      contentPadding: EdgeInsets.zero,
      counterText: '',
    );
    return Scaffold(
      backgroundColor: c.inset,
      appBar: AppPageBar(
        backgroundColor: c.surface,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: FilledButton(
                onPressed: active ? submit : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(64, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                child: Text(sending ? '提交中…' : '提交'),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                ColoredBox(
                  color: c.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 1),
                      Padding(
                        padding: inset,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: topic,
                            isDense: false,
                            style: TextStyle(fontSize: 13, color: c.ink),
                            items: [
                              for (final t in topics)
                                DropdownMenuItem(
                                  value: t,
                                  child: Text('问题类型：$t'),
                                ),
                            ],
                            onChanged: sending
                                ? null
                                : (t) {
                                    if (t != null) setState(() => topic = t);
                                  },
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 6,
                          children: [
                            for (final e in categories.entries)
                              ChoiceChip(
                                label: Text(e.value),
                                selected: category == e.key,
                                showCheckmark: true,
                                checkmarkColor: Colors.white,
                                selectedColor: c.palette.seed,
                                backgroundColor: c.inset,
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                labelStyle: TextStyle(
                                  color: category == e.key
                                      ? Colors.white
                                      : c.ink,
                                ),
                                onSelected: sending
                                    ? null
                                    : (_) => setState(() => category = e.key),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: TextField(
                          controller: details,
                          readOnly: sending,
                          minLines: 5,
                          maxLines: 10,
                          maxLength: 600,
                          decoration: field.copyWith(hintText: '请描述你的反馈详情…'),
                        ),
                      ),
                      Padding(padding: inset, child: const Divider(height: 1)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '添加图片（选填，最多3张）',
                              style: TextStyle(
                                color: c.ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '如有相关截图，可在这里补充',
                              style: TextStyle(fontSize: 13, color: c.muted),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final photo in photos.keys)
                                  SizedBox.square(
                                    dimension: 76,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                          child: Image.file(
                                            File(photo.path),
                                            fit: BoxFit.cover,
                                            cacheWidth: 200,
                                          ),
                                        ),
                                        Align(
                                          alignment: Alignment.topRight,
                                          child: IconButton(
                                            tooltip: '移除图片',
                                            onPressed: sending
                                                ? null
                                                : () => setState(() {
                                                    photos.remove(photo);
                                                    uploaded.remove(photo);
                                                  }),
                                            style: IconButton.styleFrom(
                                              backgroundColor: Colors.black54,
                                              foregroundColor: Colors.white,
                                              minimumSize: const Size(32, 32),
                                            ),
                                            icon: const AppIcon(
                                              AppIcons.close,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (photos.length < 3)
                                  SizedBox.square(
                                    dimension: 76,
                                    child: IconButton(
                                      tooltip: '添加图片',
                                      onPressed: active ? addPhoto : null,
                                      style: IconButton.styleFrom(
                                        backgroundColor: c.inset,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                        ),
                                      ),
                                      icon: AppIcon(
                                        AppIcons.camera,
                                        size: 25,
                                        color: c.muted,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ColoredBox(
                  color: c.surface,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        const Text('联系方式'),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: contact,
                            readOnly: sending,
                            textAlign: TextAlign.end,
                            maxLength: 100,
                            textInputAction: TextInputAction.done,
                            decoration: field.copyWith(hintText: '手机号或邮箱（选填）'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
