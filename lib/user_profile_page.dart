import 'user_display_name.dart';

import 'package:flutter/material.dart';

import 'api/bojian_api.dart';
import 'app_icons.dart';
import 'app_store.dart';
import 'design.dart';
import 'discovery.dart';
import 'playful_refresh.dart';
import 'profile_avatar.dart';
import 'resume_updated_label.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key, required this.store, required this.userID});
  final AppStore store;
  final int userID;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  Map<String, dynamic>? profile;
  List<Map<String, dynamic>> articles = [];
  bool loading = true;
  String? profileError, articleError;
  int? opening;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final request = ++generation;
    setState(() {
      loading = true;
      profileError = null;
      articleError = null;
    });
    try {
      final result = await widget.store.request(
        'GetUsersFirstSecond',
        path: {'first': '${widget.userID}', 'second': 'profile'},
      );
      if (!mounted || request != generation) return;
      if (integer(result.data['id']) != widget.userID) {
        throw const ApiFailure('该用户主页暂不可见', code: 'USER_NOT_FOUND');
      }
      setState(() => profile = result.data);
    } catch (error) {
      if (!mounted || request != generation) return;
      setState(() {
        if (error is ApiFailure && error.code == 'USER_NOT_FOUND') {
          profile = null;
          articles = [];
          profileError = '该用户主页暂不可见';
        } else {
          profileError = '主页加载失败，请稍后重试';
        }
        loading = false;
      });
      return;
    }
    try {
      final result = await widget.store.request(
        'GetUsersFirstSecond',
        path: {'first': '${widget.userID}', 'second': 'articles'},
      );
      if (!mounted || request != generation) return;
      setState(() => articles = items(result.data));
    } catch (_) {
      if (mounted && request == generation) {
        setState(() => articleError = '文章加载失败，请稍后重试');
      }
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  Future<void> openArticle(Map<String, dynamic> row) async {
    if (opening != null) return;
    final id = integer(row['id']);
    if (id <= 0) return;
    setState(() => opening = id);
    try {
      final result = await widget.store.request(
        'GetArticlesId',
        path: {'id': '$id'},
      );
      if (!mounted) return;
      await openPage(
        context,
        StoryDetail(story: decodeStory(result.data), store: widget.store),
      );
    } catch (_) {
      if (mounted) toast(context, '文章暂时无法打开，请稍后重试');
    } finally {
      if (mounted) setState(() => opening = null);
    }
  }

  Widget identity() {
    final data = profile!;
    final nickname = '${data['nickname'] ?? ''}'.trim();
    final publicID = '${data['public_id'] ?? ''}'.trim();
    final bio = '${data['bio'] ?? ''}'.trim();
    final city = '${data['city'] ?? ''}'.trim();
    return Container(
      key: const ValueKey('public-user-identity'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 116,
            child: Stack(
              children: [
                Positioned.fill(
                  bottom: 30,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFE9F0FF),
                          Color(0xFFF3F6FF),
                          Color(0xFFEEF7F6),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -18,
                  top: -50,
                  child: Container(
                    width: 158,
                    height: 158,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .55),
                        width: 22,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 24,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(29),
                    ),
                    child: ProfileAvatar(
                      seed: '${widget.userID}',
                      url: '${data['avatar_url'] ?? ''}',
                      size: 72,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userDisplayName(nickname),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                if (publicID.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '用户 ID：$publicID',
                    style: const TextStyle(fontSize: 11, color: muted),
                  ),
                ],
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    bio,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.65,
                      color: Color(0xFF606C80),
                    ),
                  ),
                ],
                if (city.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: canvasColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      city,
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget status(String message, {bool retry = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
    child: Column(
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, height: 1.6, color: muted),
        ),
        if (retry) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: loading ? null : load,
            child: const Text('重新加载'),
          ),
        ],
      ],
    ),
  );

  Widget articleRow(Map<String, dynamic> row) {
    final date = DateTime.tryParse('${row['published_at'] ?? ''}');
    return InkWell(
      key: ValueKey('public-article-${row['id']}'),
      onTap: opening == null ? () => openArticle(row) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (date != null) ...[
                    Text(
                      resumeUpdatedLabel(date),
                      style: const TextStyle(fontSize: 10, color: muted),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    '${row['title'] ?? ''}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            if (opening == integer(row['id']))
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const AppIcon(AppIcons.forward, size: 17, color: muted),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('个人主页')),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: PlayfulRefresh(
            onRefresh: load,
            hasError: () => profileError != null || articleError != null,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                if (profile != null) identity(),
                if (profileError != null) status(profileError!, retry: true),
                if (profile == null && loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Center(
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                if (profile != null) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 28, 4, 14),
                    child: Text(
                      '公开文章',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.white,
                    clipBehavior: Clip.antiAlias,
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      children: [
                        for (var i = 0; i < articles.length; i++) ...[
                          if (i > 0)
                            const Divider(height: 1, indent: 20, endIndent: 20),
                          articleRow(articles[i]),
                        ],
                        if (articleError != null)
                          status(articleError!, retry: true),
                        if (articles.isEmpty && articleError == null)
                          status(loading ? '正在加载文章…' : '暂时没有公开文章'),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
