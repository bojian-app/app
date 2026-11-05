import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_store.dart';
import 'design.dart';

class InvitationPage extends StatefulWidget {
  const InvitationPage({super.key, required this.store});
  final AppStore store;
  @override
  State<InvitationPage> createState() => _InvitationPageState();
}

class _InvitationPageState extends State<InvitationPage> {
  Map<String, dynamic>? data;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final epoch = widget.store.epoch;
    try {
      final result = await widget.store.request('GetWalletInvitations');
      if (mounted && epoch == widget.store.epoch) {
        setState(() {
          data = result.data;
          error = null;
        });
      }
    } catch (e) {
      if (mounted && epoch == widget.store.epoch) setState(() => error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('邀请新人')),
    body: RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            '每邀请一位新人，得 500 积分',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text('好友注册时填写你的邀请码，并完成手机号验证绑定后，积分自动到账。每位新人只计一次；已有账号不参与。'),
          const SizedBox(height: 32),
          if (error != null) ...[
            Text(error!),
            TextButton(onPressed: load, child: const Text('重试')),
          ] else if (data == null)
            const Center(child: CircularProgressIndicator())
          else ...[
            const Text('我的邀请码'),
            SelectableText(
              '${data!['invite_code'] ?? ''}',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () async {
                final code = '${data!['invite_code'] ?? ''}';
                if (code.isEmpty) return;
                await Clipboard.setData(
                  ClipboardData(
                    text:
                        '邀请你加入博简，注册时填写邀请码 $code，完成手机号绑定。下载：${data!['download_url']}',
                  ),
                );
                if (context.mounted) toast(context, '邀请内容已复制，可以发送给好友');
              },
              child: const Text('复制邀请内容'),
            ),
            const SizedBox(height: 32),
            Text(
              '已完成 ${data!['completed_count'] ?? 0} 人 · 待绑定 ${data!['pending_count'] ?? 0} 人',
            ),
            const SizedBox(height: 8),
            Text('累计获得 ${data!['awarded_points'] ?? 0} 积分'),
          ],
        ],
      ),
    ),
  );
}
