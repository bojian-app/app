import 'app_icons.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_store.dart';
import 'app_theme.dart';

export 'app_theme.dart';

const blue = Color(0xFF2867EE);
const ink = Color(0xFF202C41);
const muted = Color(0xFF8A94A5);
const canvasColor = Color(0xFFF7F8FA);
const borderColor = Color(0xFFEEF0F4);

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

void dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

Future<bool> runRequest(
  BuildContext context,
  Future<void> Function() request, {
  String? success,
}) async {
  try {
    await request();
    if (success != null && context.mounted) toast(context, success);
    return true;
  } catch (e) {
    if (context.mounted) toast(context, '$e');
    return false;
  }
}

class DataStatus extends StatelessWidget {
  const DataStatus({
    super.key,
    required this.store,
    required this.section,
    required this.empty,
    this.title = '这里还没有内容',
    this.subtitle = '下拉刷新，查看最新内容。',
    this.illustration,
  });
  final AppStore store;
  final String section, title, subtitle;
  final bool empty;
  final Widget? illustration;
  @override
  Widget build(BuildContext context) {
    if (store.loading.contains(section)) {
      if (!empty) return const SizedBox.shrink();
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final error = store.errors[section];
    if (!store.isAuthenticated || error != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Panel(
          child: Column(
            children: [
              Text(
                !store.isAuthenticated ? '登录后即可查看' : error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: context.colors.muted,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => runRequest(
                  context,
                  () => !store.isAuthenticated
                      ? store.endSession()
                      : store.load(section),
                ),
                child: Text(!store.isAuthenticated ? '登录 / 注册' : '重新加载'),
              ),
            ],
          ),
        ),
      );
    }
    return empty
        ? EmptyState(title, subtitle, illustration: illustration)
        : const SizedBox.shrink();
  }
}

class MoreButton extends StatelessWidget {
  const MoreButton({super.key, required this.store, required this.section});
  final AppStore store;
  final String section;
  @override
  Widget build(BuildContext context) => (store.cursors[section] ?? '').isEmpty
      ? const SizedBox.shrink()
      : TextButton(
          onPressed: store.loading.contains(section)
              ? null
              : () => store.load(section, more: true),
          child: const Text('加载更多'),
        );
}

Future<T?> openPage<T>(BuildContext context, Widget page) {
  dismissKeyboard();
  return Navigator.of(context)
      .push<T>(CupertinoPageRoute(builder: (_) => page));
}

class DismissKeyboardButton extends StatelessWidget {
  const DismissKeyboardButton({super.key});

  @override
  Widget build(BuildContext context) =>
      MediaQuery.viewInsetsOf(context).bottom > 0
      ? IconButton(
          tooltip: '收起键盘',
          onPressed: dismissKeyboard,
          icon: const AppIcon(AppIcons.hideKeyboard),
        )
      : const SizedBox.shrink();
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  @override
  Widget build(BuildContext context) => Material(
    color: color ?? context.colors.surface,
    borderRadius: BorderRadius.circular(20),
    child: Padding(padding: padding, child: child),
  );
}

class Avatar extends StatelessWidget {
  const Avatar(this.name, {super.key, this.size = 36, this.color});
  final String name;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: (color ?? context.colors.accent).withValues(alpha: .09),
      borderRadius: BorderRadius.circular(size * .36),
    ),
    alignment: Alignment.center,
    child: Text(
      name.isEmpty ? '简' : name.substring(0, 1),
      style: TextStyle(
        color: color ?? context.colors.accent,
        fontSize: size * .42,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: (color ?? context.colors.accent).withValues(alpha: .07),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: color ?? context.colors.accent,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class PageHeading extends StatelessWidget {
  const PageHeading(this.title, this.subtitle, {super.key, this.action});
  final String title, subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 18, 14, 20),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.5,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: context.colors.muted, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        ?action,
      ],
    ),
  );
}

class DocumentArt extends StatelessWidget {
  const DocumentArt({
    super.key,
    this.variant = 0,
    this.width = 110,
    this.height = 145,
  });
  final int variant;
  final double width, height;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: CustomPaint(painter: _DocumentPainter(variant)),
  );
}

class _DocumentPainter extends CustomPainter {
  _DocumentPainter(this.variant);
  final int variant;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 110, size.height / 145);
    final p = Paint();
    final accent = [
      blue,
      const Color(0xFF509B87),
      const Color(0xFFD2A064),
    ][variant % 3];
    p.color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(7, 4, 96, 137),
        const Radius.circular(3),
      ),
      p,
    );
    if (variant % 3 == 1) {
      p.color = accent.withValues(alpha: .10);
      canvas.drawRect(const Rect.fromLTWH(7, 4, 28, 137), p);
    }
    p.color = accent;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(17, 16, 32, 5),
        const Radius.circular(1),
      ),
      p,
    );
    p.color = accent.withValues(alpha: .18);
    canvas.drawCircle(const Offset(84, 23), 8, p);
    for (var section = 0; section < 3; section++) {
      final y = 39.0 + section * 32;
      p.color = accent.withValues(alpha: .4);
      canvas.drawRect(Rect.fromLTWH(17, y, 20, 2.5), p);
      p.color = const Color(0xFFE6EAF0);
      for (var line = 0; line < 3; line++) {
        canvas.drawRect(
          Rect.fromLTWH(17, y + 8 + line * 5, line == 2 ? 45 : 74, 1.7),
          p,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DocumentPainter oldDelegate) =>
      variant != oldDelegate.variant;
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.title, this.detail, {super.key, this.illustration});
  final String title, detail;
  final Widget? illustration;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 54, horizontal: 24),
    child: Column(
      children: [
        illustration ?? Image.asset('assets/branding/app_icon.png', width: 80),
        const SizedBox(height: 18),
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        if (detail.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.muted, fontSize: 13),
          ),
        ],
      ],
    ),
  );
}
