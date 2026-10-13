import 'user_display_name.dart';

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import 'api/bojian_api.dart';
import 'app_icons.dart';
import 'app_store.dart';
import 'design.dart';
import 'profile_avatar.dart';

class ResumeGuidanceShare extends StatefulWidget {
  const ResumeGuidanceShare({
    super.key,
    required this.store,
    required this.resume,
  });
  final AppStore store;
  final ResumeDraft resume;
  @override
  State<ResumeGuidanceShare> createState() => _ResumeGuidanceShareState();
}

class _ResumeGuidanceShareState extends State<ResumeGuidanceShare> {
  final question = TextEditingController();
  final search = TextEditingController();
  final friends = <Map<String, dynamic>>[];
  final selected = <int>{};
  bool community = true;
  bool loading = false, loaded = false, sending = false;
  String? error, cursor, lastPayload, requestKey;

  Future<void> loadFriends({bool more = false}) async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.store.request(
        'GetFriends',
        query: {
          'limit': '50',
          if (more && cursor != null) 'cursor': cursor!,
          if (search.text.trim().isNotEmpty) 'query': search.text.trim(),
        },
      );
      if (!mounted) return;
      setState(() {
        if (!more) friends.clear();
        final ids = friends.map((u) => integer(u['id'])).toSet();
        friends.addAll(
          items(result.data).where(
            (u) =>
                integer(u['id']) != widget.store.userID &&
                ids.add(integer(u['id'])),
          ),
        );
        cursor = result.data['next_cursor']?.toString();
        if (cursor == '') cursor = null;
        loaded = true;
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> submit() async {
    if (sending) return;
    if (!community && selected.isEmpty) {
      toast(context, '请选择想请教的好友');
      return;
    }
    final ids = selected.toList()..sort();
    final body = <String, dynamic>{
      'version': 2,
      'destination': community ? 'CIRCLE' : 'FRIENDS',
      if (!community) 'friend_ids': ids,
      'question': question.text.trim(),
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
          'mobile-guidance-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    }
    dismissKeyboard();
    setState(() => sending = true);
    final sent = await runRequest(context, () async {
      final result = await widget.store.request(
        'PostResumesIdGuidance',
        path: {'id': '${widget.resume.id}'},
        body: body,
        extra: {'idempotency-key': requestKey!},
      );
      if (integer(result.data['id']) <= 0) {
        throw const ApiFailure('分享结果暂不可用，请重试');
      }
    });
    if (!mounted) return;
    if (sent) {
      Navigator.pop(context);
      toast(context, community ? '已提交审核，通过后展示在社区' : '指点邀请已发送');
    } else {
      setState(() => sending = false);
    }
  }

  @override
  void dispose() {
    question.dispose();
    search.dispose();
    super.dispose();
  }

  Widget destination(String label, String detail, bool value) => Expanded(
    child: Material(
      color: community == value ? const Color(0xFFF0F5FF) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: sending
            ? null
            : () {
                setState(() => community = value);
                if (!value && !loaded && !loading) loadFriends();
              },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: community == value
                  ? blue.withValues(alpha: .4)
                  : borderColor,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIcon(
                value ? AppIcons.discover : AppIcons.guidanceRecipients,
                color: community == value ? blue : muted,
                size: 22,
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: community == value ? blue : ink,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                detail,
                style: const TextStyle(fontSize: 11, color: muted, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !sending,
    child: Scaffold(
      backgroundColor: canvasColor,
      appBar: AppBar(title: const Text('请求指点')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Panel(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const AppIcon(AppIcons.resume, color: blue, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.resume.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  destination('分享到社区', '审核通过后公开', true),
                  const SizedBox(width: 12),
                  destination('指定用户', '向好友私下请教', false),
                ],
              ),
              const SizedBox(height: 20),
              if (!community) ...[
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '选择好友',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '已选 ${selected.length}/20',
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: search,
                  enabled: !sending && !loading,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => loadFriends(),
                  decoration: InputDecoration(
                    hintText: '搜索好友昵称或用户 ID',
                    suffixIcon: IconButton(
                      tooltip: '搜索好友',
                      onPressed: sending || loading
                          ? null
                          : () => loadFriends(),
                      icon: const AppIcon(AppIcons.search, size: 20),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (error != null) ...[
                  Text(error!, style: const TextStyle(color: muted)),
                  TextButton(
                    onPressed: () => loadFriends(),
                    child: const Text('重新加载'),
                  ),
                ],
                if (loaded && friends.isEmpty && error == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      '没有找到可选择的好友。',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ),
                for (final user in friends)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: ProfileAvatar(
                      seed: '${user['id']}',
                      url: user['avatar_url'] as String? ?? '',
                      size: 36,
                    ),
                    title: Text(
                      userDisplayName(
                        '${user['remark'] ?? ''}'.trim().isEmpty
                            ? user['display_name']
                            : user['remark'],
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      '${user['public_id'] ?? ''}',
                      style: const TextStyle(fontSize: 10, color: muted),
                    ),
                    trailing: AppIcon(
                      selected.contains(integer(user['id']))
                          ? AppIcons.confirm
                          : AppIcons.addCircle,
                      color: selected.contains(integer(user['id']))
                          ? blue
                          : muted,
                      size: 20,
                    ),
                    selected: selected.contains(integer(user['id'])),
                    onTap: sending
                        ? null
                        : () {
                            final id = integer(user['id']);
                            if (!selected.contains(id) &&
                                selected.length >= 20) {
                              toast(context, '最多选择 20 位好友');
                              return;
                            }
                            setState(() {
                              if (!selected.remove(id)) selected.add(id);
                            });
                          },
                  ),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                if (cursor != null && !loading)
                  TextButton(
                    onPressed: () => loadFriends(more: true),
                    child: const Text('加载更多好友'),
                  ),
                const SizedBox(height: 20),
              ],
              const Text(
                '想请教什么？',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('guidance-question'),
                controller: question,
                enabled: !sending,
                minLines: 3,
                maxLines: 6,
                maxLength: 1000,
                decoration: const InputDecoration(
                  hintText: '例如：工作经历的重点是否清楚，有哪些可以改进的地方？',
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: FilledButton(
            key: const ValueKey('guidance-submit'),
            onPressed: sending || (!community && selected.isEmpty)
                ? null
                : submit,
            child: Text(
              sending
                  ? '正在发送…'
                  : community
                  ? '提交到社区'
                  : '发送邀请',
            ),
          ),
        ),
      ),
    ),
  );
}
