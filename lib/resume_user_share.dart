import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_icons.dart';
import 'app_page_bar.dart';
import 'app_store.dart';
import 'design.dart';
import 'profile_avatar.dart';
import 'user_display_name.dart';

class ResumeUserShare extends StatefulWidget {
  const ResumeUserShare({super.key, required this.store, required this.resume});

  static const defaultRemark = '你好，这是我的简历，请查收。';

  final AppStore store;
  final ResumeDraft resume;

  @override
  State<ResumeUserShare> createState() => _ResumeUserShareState();
}

class _ResumeUserShareState extends State<ResumeUserShare> {
  final userID = TextEditingController();
  final remark = TextEditingController();
  Timer? searchTimer;
  TextEditingValue lastSearchInput = TextEditingValue.empty;
  bool settingRecipient = false;
  int searchVersion = 0;
  late final int accountEpoch;
  List<Map<String, dynamic>> results = [];
  Map<String, dynamic>? selected;
  bool loading = false, searched = false, sending = false;
  String? searchError, sendError, lastPayload, requestKey;

  @override
  void initState() {
    super.initState();
    accountEpoch = widget.store.epoch;
    userID.addListener(queryEdited);
  }

  void queryEdited() {
    final value = userID.value;
    final changed =
        value.text != lastSearchInput.text ||
        value.composing != lastSearchInput.composing;
    lastSearchInput = value;
    if (!settingRecipient && changed) queryChanged(value.text);
  }

  void queryChanged(String value) {
    searchTimer?.cancel();
    final version = ++searchVersion;
    final query = value.trim();
    final composing = userID.value.composing;
    final ready =
        query.isNotEmpty && !(composing.isValid && !composing.isCollapsed);
    setState(() {
      selected = null;
      results = [];
      loading = ready;
      searched = false;
      searchError = null;
      sendError = null;
    });
    if (ready) {
      searchTimer = Timer(
        const Duration(milliseconds: 350),
        () => searchUsers(query, version),
      );
    }
  }

  Future<void> searchUsers(String query, int version) async {
    try {
      final response = await widget.store.request(
        'GetUsersSearch',
        query: {'query': query, 'mode': 'recipient'},
        expectedEpoch: accountEpoch,
      );
      if (!mounted || version != searchVersion) return;
      setState(() {
        results = items(response.data)
            .where((user) => integer(user['id']) != widget.store.userID)
            .toList();
        searched = true;
        loading = false;
      });
    } catch (error) {
      if (!mounted || version != searchVersion) return;
      setState(() {
        loading = false;
        searchError = '$error';
      });
    }
  }

  Future<void> submit() async {
    final recipient = selected;
    if (sending || recipient == null) return;
    final body = <String, dynamic>{
      'version': 2,
      'destination': 'USERS',
      'user_ids': [integer(recipient['id'])],
      'question': remark.text.trim().isEmpty
          ? ResumeUserShare.defaultRemark
          : remark.text.trim(),
      'hidden_fields': [
        'personal_info',
        'photo',
        'projects.url',
        'educations.institution',
        'work_experiences.company',
        'projects.name',
        'certifications.issuer',
      ],
    };
    final encoded = jsonEncode(body);
    if (encoded != lastPayload) {
      lastPayload = encoded;
      requestKey =
          'mobile-user-share-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    }
    dismissKeyboard();
    setState(() {
      sending = true;
      sendError = null;
    });
    try {
      await widget.store.request(
        'PostResumesIdGuidance',
        path: {'id': '${widget.resume.id}'},
        body: body,
        extra: {'idempotency-key': requestKey!},
        expectedEpoch: accountEpoch,
      );
      if (!mounted) return;
      Navigator.pop(context);
      toast(context, '简历已分享');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        sending = false;
        sendError = '$error';
      });
    }
  }

  @override
  void dispose() {
    searchTimer?.cancel();
    userID.removeListener(queryEdited);
    userID.dispose();
    remark.dispose();
    super.dispose();
  }

  void clearSearchInput() {
    settingRecipient = true;
    try {
      userID.clear();
    } finally {
      settingRecipient = false;
    }
  }

  void clearRecipient() {
    clearSearchInput();
    queryChanged('');
  }

  Widget fieldLabel(String title) => Text(
    title,
    style: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: context.colors.ink,
    ),
  );

  Widget recipientRow(Map<String, dynamic> user, {bool chosen = false}) =>
      Material(
        key: chosen
            ? const ValueKey('resume-share-selected-user')
            : ValueKey('resume-share-user-${user['id']}'),
        color: chosen ? context.colors.accentSoft : context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: sending || chosen
              ? null
              : () {
                  searchTimer?.cancel();
                  searchVersion++;
                  clearSearchInput();
                  setState(() {
                    selected = user;
                    sendError = null;
                    results = [];
                    searched = false;
                    loading = false;
                    searchError = null;
                  });
                  dismissKeyboard();
                },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
            child: Row(
              children: [
                ProfileAvatar(
                  seed: '${user['id']}',
                  url: '${user['avatar_url'] ?? ''}',
                  size: 36,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userDisplayName(user['display_name']),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: context.colors.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'ID：${user['public_id']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (chosen)
                  IconButton(
                    tooltip: '取消选择',
                    onPressed: sending ? null : clearRecipient,
                    icon: AppIcon(
                      AppIcons.close,
                      size: 16,
                      color: context.colors.muted,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: AppIcon(
                      AppIcons.addCircle,
                      size: 18,
                      color: context.colors.accent,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

  Widget searchFeedback() {
    if (selected != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: recipientRow(selected!, chosen: true),
      );
    }
    if (searchError != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                searchError!,
                style: TextStyle(fontSize: 12, color: context.colors.muted),
              ),
            ),
            TextButton(
              onPressed: () => queryChanged(userID.text),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (results.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.border),
          ),
          constraints: const BoxConstraints(maxHeight: 240),
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: results.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, indent: 60, color: context.colors.border),
            itemBuilder: (_, index) => recipientRow(results[index]),
          ),
        ),
      );
    }
    if (!loading && !searched) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        loading ? '正在查找用户…' : '没有找到匹配用户',
        style: TextStyle(fontSize: 12, color: context.colors.muted),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !sending,
    child: Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppPageBar(title: const Text('分享给指定用户')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      fieldLabel('接收人'),
                      const SizedBox(height: 12),
                      TextField(
                        key: const ValueKey('resume-share-user-id'),
                        controller: userID,
                        enabled: !sending,
                        maxLength: 80,
                        maxLengthEnforcement:
                            MaxLengthEnforcement.truncateAfterCompositionEnds,
                        keyboardType: TextInputType.text,
                        autocorrect: true,
                        enableSuggestions: true,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(fontSize: 14, height: 1.4),
                        decoration: InputDecoration(
                          hintText: '选择接收人',
                          counterText: '',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          prefixIconConstraints: const BoxConstraints.tightFor(
                            width: 44,
                            height: 48,
                          ),
                          prefixIcon: Center(
                            child: AppIcon(
                              AppIcons.search,
                              size: 18,
                              color: context.colors.muted,
                            ),
                          ),
                          suffixIcon: loading
                              ? const SizedBox(
                                  width: 44,
                                  child: Center(
                                    widthFactor: 1,
                                    heightFactor: 1,
                                    child: SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                      ),
                                    ),
                                  ),
                                )
                              : userID.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: '清空搜索',
                                  onPressed: sending ? null : clearRecipient,
                                  icon: AppIcon(
                                    AppIcons.close,
                                    size: 16,
                                    color: context.colors.muted,
                                  ),
                                ),
                        ),
                      ),
                      searchFeedback(),
                      const SizedBox(height: 32),
                      fieldLabel('备注'),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: context.colors.inset,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            TextField(
                              key: const ValueKey('resume-share-remark'),
                              controller: remark,
                              enabled: !sending,
                              minLines: 3,
                              maxLines: 6,
                              maxLength: 1000,
                              style: const TextStyle(fontSize: 14, height: 1.6),
                              decoration: const InputDecoration(
                                hintText: ResumeUserShare.defaultRemark,
                                counterText: '',
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                contentPadding: EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  16,
                                  8,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: remark,
                                  builder: (_, value, _) => Text(
                                    '${value.text.characters.length}/1000',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: context.colors.muted,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (sendError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            sendError!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('resume-user-share-submit'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: context.colors.accentSoft,
                        disabledForegroundColor: context.colors.accent
                            .withValues(alpha: .5),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: sending || selected == null ? null : submit,
                      child: Text(sending ? '正在分享…' : '分享简历'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
