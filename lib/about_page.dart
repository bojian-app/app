import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'app_page_bar.dart';
import 'app_store.dart';
import 'app_update.dart';
import 'design.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key, required this.store});
  final AppStore store;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> with WidgetsBindingObserver {
  final updates = AppUpdates.instance;
  final installer = AppUpdateInstaller();
  bool startingInstall = false;
  bool logExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    updates.refresh(widget.store, force: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    installer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && installer.waitingForPermission) {
      _install();
    }
  }

  Future<void> _check() async {
    if (updates.loading) return;
    await updates.refresh(widget.store, force: true);
    if (!mounted) return;
    final pendingDownload = _pendingDownloadMessage(updates);
    if (updates.failed) {
      toast(context, '检查失败，请重试');
    } else if (pendingDownload != null) {
      toast(context, pendingDownload);
    } else if (updates.latest != null && updates.latestComparison == null) {
      toast(context, '版本信息不足，暂时无法判断是否有更新');
    } else if (updates.loaded && !updates.hasUpdate) {
      toast(context, '已是最新版本');
    }
  }

  Future<void> _install() async {
    if (startingInstall || installer.busy) return;
    setState(() => startingInstall = true);
    try {
      await installer.install(widget.store);
    } finally {
      if (mounted) setState(() => startingInstall = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppPageBar(
        title: const Text('关于拾页'),
        backgroundColor: colors.surface,
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([updates, installer]),
        builder: (context, _) {
          final releases = [
            for (final release in updates.releases)
              if (release.notes.isNotEmpty) release,
          ];
          return SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    appPageHorizontalPadding,
                    28,
                    appPageHorizontalPadding,
                    32,
                  ),
                  children: [
                    _Identity(
                      version: updates.installedVersion,
                      buildNumber: updates.installedBuild,
                    ),
                    const SizedBox(height: 36),
                    _UpdateRow(
                      updates: updates,
                      installer: installer,
                      startingInstall: startingInstall,
                      onCheck: _check,
                      onInstall: _install,
                    ),
                    if (releases.isNotEmpty) ...[
                      ExpansionTile(
                        key: const PageStorageKey('about-release-notes'),
                        initiallyExpanded: logExpanded,
                        onExpansionChanged: (value) {
                          setState(() => logExpanded = value);
                        },
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(
                          top: 8,
                          bottom: 8,
                        ),
                        shape: const Border(),
                        collapsedShape: const Border(),
                        iconColor: colors.muted,
                        collapsedIconColor: colors.muted,
                        title: Text(
                          '更新日志',
                          style: TextStyle(fontSize: 15, color: colors.ink),
                        ),
                        children: [
                          for (var i = 0; i < releases.length; i++)
                            _ReleaseEntry(
                              release: releases[i],
                              last: i == releases.length - 1,
                            ),
                        ],
                      ),
                      Divider(height: 1, color: colors.border),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.version, required this.buildNumber});
  final String version;
  final int buildNumber;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Image.asset(
        'assets/branding/app_icon.png',
        width: 88,
        height: 88,
        cacheWidth: 264,
        excludeFromSemantics: true,
      ),
      const SizedBox(height: 16),
      Text(
        '拾页',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: context.colors.ink,
        ),
      ),
      if (version.isNotEmpty || buildNumber > 0) ...[
        const SizedBox(height: 8),
        Text(
          [
            if (version.isNotEmpty) _versionLabel(version),
            if (buildNumber > 0) '构建号 ${_displayBuildNumber(buildNumber)}',
          ].join(' · '),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: context.colors.muted),
        ),
      ],
    ],
  );
}

class _UpdateRow extends StatelessWidget {
  const _UpdateRow({
    required this.updates,
    required this.installer,
    required this.startingInstall,
    required this.onCheck,
    required this.onInstall,
  });
  final AppUpdates updates;
  final AppUpdateInstaller installer;
  final bool startingInstall;
  final VoidCallback onCheck, onInstall;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final release = updates.latest;
    final hasUpdate = updates.hasUpdate && release != null;
    final blockReason = updates.installBlockReason;
    final message =
        blockReason ?? _pendingDownloadMessage(updates) ?? installer.message;
    final downloading = installer.busy;
    final installing = installer.stage == AppUpdateStage.installing;
    final waiting = startingInstall || installing || updates.loading;
    final String title;
    if (downloading) {
      title = '正在下载';
    } else if (installing) {
      title = '正在打开安装器';
    } else if (updates.loading && !hasUpdate) {
      title = '检查中…';
    } else if (blockReason != null) {
      title = '重新检查更新';
    } else if (hasUpdate) {
      title = installer.stage == AppUpdateStage.failed ? '重试更新' : '立即更新';
    } else {
      title = updates.failed ? '重新检查更新' : '检查更新';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, color: colors.border),
        Material(
          color: colors.surface,
          child: InkWell(
            onTap: waiting || downloading
                ? null
                : hasUpdate && blockReason == null
                ? onInstall
                : onCheck,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(fontSize: 15, color: colors.ink),
                    ),
                  ),
                  if (hasUpdate)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Badge(
                        smallSize: 8,
                        backgroundColor: Color(0xFFE5322D),
                      ),
                    ),
                  if (downloading)
                    Text(
                      '${(installer.progress * 100).round()}%',
                      style: TextStyle(fontSize: 13, color: colors.muted),
                    )
                  else if (waiting)
                    SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: colors.muted,
                      ),
                    )
                  else ...[
                    if (hasUpdate)
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12, right: 8),
                          child: Text(
                            _versionLabel(release.versionName),
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.accent,
                            ),
                          ),
                        ),
                      ),
                    AppIcon(AppIcons.forward, size: 18, color: colors.muted),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (downloading)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: LinearProgressIndicator(
              value: installer.progress,
              minHeight: 2,
              color: colors.accent,
              backgroundColor: colors.border,
            ),
          ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: installer.stage == AppUpdateStage.failed
                    ? Theme.of(context).colorScheme.error
                    : colors.muted,
              ),
            ),
          ),
        Divider(height: 1, color: colors.border),
      ],
    );
  }
}

class _ReleaseEntry extends StatelessWidget {
  const _ReleaseEntry({required this.release, required this.last});
  final AppRelease release;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _versionLabel(release.versionName),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.ink,
                ),
              ),
              if (release.buildNumber > 0)
                Text(
                  '构建号 ${_displayBuildNumber(release.buildNumber)}',
                  style: TextStyle(fontSize: 12, color: colors.muted),
                ),
              if (release.releasedAt != null)
                Text(
                  _date(release.releasedAt!),
                  style: TextStyle(fontSize: 12, color: colors.muted),
                ),
            ],
          ),
          const SizedBox(height: 10),
          for (final note in release.notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                note,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.7,
                  color: colors.ink.withValues(alpha: .75),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _date(DateTime value) =>
    '${value.year}.${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')}';

String _versionLabel(String version) =>
    version.startsWith('v') || version.startsWith('V') ? version : 'v$version';

String? _pendingDownloadMessage(AppUpdates updates) {
  final release = updates.latest;
  if (release == null ||
      release.downloadURL.isNotEmpty ||
      (updates.latestComparison ?? 0) <= 0) {
    return null;
  }
  final name = release.versionName.trim();
  return name.isEmpty ? '新版本已发布，暂未提供下载' : '已发布 ${_versionLabel(name)}，暂未提供下载';
}

String _displayBuildNumber(int number) {
  final raw = number.toString();
  if (raw.length != 10 || !raw.startsWith('20')) return raw;
  final year = int.parse(raw.substring(0, 4));
  final month = int.parse(raw.substring(4, 6));
  final day = int.parse(raw.substring(6, 8));
  final date = DateTime.utc(year, month, day);
  return date.year == year && date.month == month && date.day == day
      ? raw.substring(2)
      : raw;
}
