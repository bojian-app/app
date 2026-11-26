import 'app_icons.dart';
import 'moderation_rejection_dialog.dart';

import 'package:flutter/material.dart';

import 'app_store.dart';
import 'api/bojian_api.dart';
import 'app_theme.dart';
import 'app_page_transitions.dart';

export 'app_theme.dart';
export 'app_page_transitions.dart';
export 'empty_state.dart';
export 'skeleton.dart';

import 'empty_state.dart';
import 'skeleton.dart';

/// Side gutter of every page, in line with the status bar's own inset.
const appPageHorizontalPadding = 24.0;
const feedOuterPadding = 12.0;
const feedContentPadding = appPageHorizontalPadding - feedOuterPadding;
const feedTitleWeight = FontWeight.bold;

const blue = Color(0xFF2867EE);
const ink = Color(0xFF202C41);
const muted = Color(0xFF8A94A5);
const canvasColor = Colors.white;
const borderColor = Color(0xFFEEF0F4);

SnackBar appFeedbackBar(
  BuildContext context,
  String message, {
  bool success = false,
  SnackBarAction? action,
}) {
  final colors = context.colors;
  final style = Theme.of(context).textTheme.bodyMedium!.copyWith(
    color: colors.ink,
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w500,
  );
  final text = TextPainter(
    text: TextSpan(text: message, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  const markSize = 26.0, gap = 6.0;
  final left = success ? 8.0 : 16.0;
  const right = 16.0;
  final width =
      text.width.ceilToDouble() +
      left +
      right +
      (success ? markSize + gap : 0) +
      2;
  text.dispose();
  final maxWidth = (MediaQuery.sizeOf(context).width - 32).clamp(1.0, 380.0);
  return SnackBar(
    behavior: SnackBarBehavior.floating,
    width: action == null ? width.clamp(1.0, maxWidth) : maxWidth,
    backgroundColor: colors.accentSoft,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    duration: Duration(seconds: success && action == null ? 2 : 4),
    padding: EdgeInsets.fromLTRB(left, 7, right, 7),
    content: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: markSize),
      child: Row(
        children: [
          if (success) ...[
            Image.asset(
              'assets/branding/app_icon.png',
              width: markSize,
              height: markSize,
              cacheWidth: 104,
              excludeFromSemantics: true,
            ),
            const SizedBox(width: gap),
          ],
          Flexible(child: Text(message, style: style)),
        ],
      ),
    ),
    action: action,
  );
}

void toast(
  BuildContext context,
  String message, {
  bool success = false,
  SnackBarAction? action,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      appFeedbackBar(context, message, success: success, action: action),
    );
}

void dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

Future<bool> runRequest(
  BuildContext context,
  Future<void> Function() request, {
  String? success,
}) async {
  try {
    await request();
    if (success != null && context.mounted) {
      toast(context, success, success: true);
    }
    return true;
  } catch (e) {
    if (context.mounted) await showRequestFailure(context, e);
    return false;
  }
}

Future<ModerationExcerpt?> showRequestFailure(
  BuildContext context,
  Object error, {
  bool Function(ModerationExcerpt)? canLocate,
}) async {
  if (error is ApiFailure && error.code == 'CONTENT_REJECTED') {
    return showDialog<ModerationExcerpt>(
      context: context,
      builder: (_) =>
          ModerationRejectionDialog(failure: error, canLocate: canLocate),
    );
  }
  toast(context, '$error');
  return null;
}

class DataStatus extends StatelessWidget {
  const DataStatus({
    super.key,
    required this.store,
    required this.section,
    required this.empty,
    this.title = '这里还没有内容',
    this.subtitle = '下拉刷新，查看最新内容。',
  });
  final AppStore store;
  final String section, title, subtitle;
  final bool empty;
  @override
  Widget build(BuildContext context) {
    if (store.loading.contains(section)) {
      return empty ? const ListSkeleton() : const SizedBox.shrink();
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
    return empty ? EmptyState(title, subtitle) : const SizedBox.shrink();
  }
}

/// Fetches the next page as the reader nears the end of [child]'s
/// scroll view, and when the loaded rows are too few to scroll at all.
class AutoPaginate extends StatefulWidget {
  const AutoPaginate({
    super.key,
    required this.canLoad,
    required this.onLoadMore,
    required this.child,
  });

  /// Another page exists and no request or unresolved failure is pending.
  final bool canLoad;
  final VoidCallback onLoadMore;
  final Widget child;

  /// Paging through an [AppStore] section.
  factory AutoPaginate.section({
    Key? key,
    required AppStore store,
    required String section,
    required Widget child,
  }) => AutoPaginate(
    key: key,
    canLoad:
        (store.cursors[section] ?? '').isNotEmpty &&
        !store.loading.contains(section) &&
        store.errors[section] == null,
    onLoadMore: () => store.load(section, more: true),
    child: child,
  );

  @override
  State<AutoPaginate> createState() => _AutoPaginateState();
}

class _AutoPaginateState extends State<AutoPaginate> {
  bool _scheduled = false;

  bool _near(ScrollMetrics metrics) =>
      metrics.axis == Axis.vertical &&
      metrics.hasContentDimensions &&
      metrics.extentAfter < 800;

  /// One request per frame, issued after it so the owner's rebuild already
  /// reports loading when the next notification arrives.
  void _schedule() {
    if (_scheduled || !widget.canLoad) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted && widget.canLoad) widget.onLoadMore();
    });
  }

  bool _check(ScrollMetrics metrics, int depth) {
    if (depth == 0 && _near(metrics)) _schedule();
    return false;
  }

  /// The scroll view this widget wraps; the first one below it.
  ScrollPosition? _position() {
    ScrollPosition? found;
    void visit(Element element) {
      if (found != null) return;
      if (element is StatefulElement && element.state is ScrollableState) {
        found = (element.state as ScrollableState).position;
        return;
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
    return found;
  }

  @override
  Widget build(BuildContext context) {
    // A first page shorter than the screen never scrolls, and the first
    // layout sends no metrics notification, so look once it is laid out.
    if (widget.canLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final position = mounted ? _position() : null;
        if (position != null && _near(position)) _schedule();
      });
    }
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => _check(n.metrics, n.depth),
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: (n) => _check(n.metrics, n.depth),
        child: widget.child,
      ),
    );
  }
}

/// Spinner shown under a list while its next page loads.
class PageLoadingFooter extends StatelessWidget {
  const PageLoadingFooter({super.key, required this.visible});
  final bool visible;

  @override
  Widget build(BuildContext context) => visible
      ? const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        )
      : const SizedBox.shrink();
}

Future<T?> openPage<T>(BuildContext context, Widget page) {
  dismissKeyboard();
  return Navigator.of(context).push<T>(AppPageRoute<T>(builder: (_) => page));
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
      shape: BoxShape.circle,
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
    padding: const EdgeInsets.fromLTRB(
      appPageHorizontalPadding,
      18,
      appPageHorizontalPadding,
      20,
    ),
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
