import 'dart:async';
import 'dart:math' as math;

import 'playful_refresh.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_icons.dart';
import 'app_page_bar.dart';
import 'app_store.dart';
import 'design.dart';
import 'discovery.dart';

Future<String?> pickArticleTopic(BuildContext context, AppStore store) async {
  final epoch = store.epoch;
  final name = await openPage<String>(context, _TopicPicker(store: store));
  return epoch == store.epoch && store.alive ? name : null;
}

Future<void> openArticleTopic(
  BuildContext context,
  AppStore store,
  String name,
) async {
  if (name.trim().isEmpty) return;
  await openPage<void>(context, _TopicFeed(store: store, name: name.trim()));
}

const _tagFontSize = 11.0;
const _tagBaseHeight = 26.0;

/// Room a hang tag takes beside its name: the pointed end with its hole, and
/// the rounded end. Measured on the painter's 30-high drawing, which these and
/// the padding below are scaled from.
const _tagEnds = 34.0;
const _tagRemoveRoom = 18.0;

/// Untinted room above and below a tag in a row, so a small tag is still easy
/// to tap.
const _tagTouchRoom = 3.0;

String _tagLabel(String tag) => '# $tag';

TextStyle _tagStyle(BuildContext context) => TextStyle(
  fontSize: _tagFontSize,
  height: 1.2,
  fontWeight: FontWeight.w500,
  color: Color.lerp(context.colors.accent, context.colors.ink, .35),
);

/// How tall tags are, growing with the reader's text size.
double _tagHeight(BuildContext context) =>
    _tagBaseHeight *
    (MediaQuery.textScalerOf(context).scale(_tagFontSize) / _tagFontSize).clamp(
      1.0,
      3.0,
    );

double _tagWidth(BuildContext context, String tag) {
  final painter = TextPainter(
    text: TextSpan(
      text: _tagLabel(tag),
      style: DefaultTextStyle.of(context).style.merge(_tagStyle(context)),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width.ceilToDouble() + 1;
  painter.dispose();
  return width + _tagEnds * _tagHeight(context) / 30;
}

/// One topic as a hang tag: pointed on the left, with a hole for its string.
class ArticleHangTag extends StatelessWidget {
  const ArticleHangTag(
    this.tag, {
    super.key,
    this.shade = false,
    this.covered = false,
    this.onRemove,
  });
  final String tag;

  /// Lying under another: only the end that sticks out is to be seen, so the
  /// name, which would show in pieces, fades away.
  final bool covered;

  /// The deeper of two tints, so tags lying over each other stay apart.
  final bool shade;

  /// Adds a cross to the tag that drops it.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final height = _tagHeight(context);
    final scale = height / 30;
    return CustomPaint(
      painter: _HangTagPainter(
        fill: shade
            ? Color.alphaBlend(
                colors.accent.withValues(alpha: .08),
                colors.accentSoft,
              )
            : colors.accentSoft,
        edge: colors.accent.withValues(alpha: .38),
        gap: colors.surface,
        hole: colors.accent,
      ),
      child: SizedBox(
        height: height,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 22 * scale),
            Flexible(
              child: AnimatedOpacity(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                opacity: covered ? 0 : 1,
                child: Text(
                  _tagLabel(tag),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: _tagStyle(context),
                ),
              ),
            ),
            if (onRemove case final remove?)
              Semantics(
                button: true,
                child: Tooltip(
                  message: '移除话题',
                  child: InkResponse(
                    onTap: remove,
                    radius: 18,
                    child: SizedBox(
                      width: _tagRemoveRoom + 8 * scale,
                      height: height,
                      child: Center(
                        child: AppIcon(
                          AppIcons.close,
                          size: 10,
                          color: colors.muted,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              SizedBox(width: 12 * scale),
          ],
        ),
      ),
    );
  }
}

class _HangTagPainter extends CustomPainter {
  const _HangTagPainter({
    required this.fill,
    required this.edge,
    required this.gap,
    required this.hole,
  });
  final Color fill, edge, gap, hole;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.height / 30;
    final right = size.width - 1, corner = 7 * k;
    final outline = Path()
      ..moveTo(13 * k, 2 * k)
      ..lineTo(right - corner, 2 * k)
      ..quadraticBezierTo(right, 2 * k, right, 2 * k + corner)
      ..lineTo(right, 28 * k - corner)
      ..quadraticBezierTo(right, 28 * k, right - corner, 28 * k)
      ..lineTo(13 * k, 28 * k)
      ..lineTo(2 * k, 17 * k)
      ..quadraticBezierTo(.5 * k, 15 * k, 2 * k, 13 * k)
      ..close();
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    // A rim of the page's own colour parts one tag from the one beneath it.
    canvas
      ..drawPath(
        outline,
        line
          ..color = gap
          ..strokeWidth = 3,
      )
      ..drawPath(outline, Paint()..color = fill)
      ..drawPath(
        outline,
        line
          ..color = edge
          ..strokeWidth = 1,
      );
    final centre = Offset(11 * k, 15 * k);
    canvas
      ..drawCircle(centre, 3 * k, Paint()..color = gap)
      ..drawCircle(
        centre,
        3 * k,
        line
          ..color = hole
          ..strokeWidth = 1,
      );
  }

  @override
  bool shouldRepaint(_HangTagPainter old) =>
      old.fill != fill ||
      old.edge != edge ||
      old.gap != gap ||
      old.hole != hole;
}

/// A post's tags on their own; each opens its topic. A [collapsible] row starts
/// as one stack, which a tap fans out and "收起" puts back.
class ArticleTagRow extends StatefulWidget {
  const ArticleTagRow({
    super.key,
    required this.tags,
    required this.store,
    this.collapsible = false,
  });
  final List<String> tags;
  final AppStore? store;
  final bool collapsible;

  @override
  State<ArticleTagRow> createState() => _ArticleTagRowState();
}

class _ArticleTagRowState extends State<ArticleTagRow> {
  bool open = false;

  /// How far each tag of the stack shows past the one above it, and how many
  /// of them show at all.
  static const peek = 12.0;
  static const peeks = 4;
  static const spacing = 4.0;

  @override
  void didUpdateWidget(ArticleTagRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.tags, widget.tags)) open = false;
  }

  void toggle() => setState(() => open = !open);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final tags = widget.tags;
      final tagHeight = _tagHeight(context);
      final height = tagHeight + _tagTouchRoom * 2;
      final width = constraints.maxWidth;
      final stacks = widget.collapsible && tags.length > 1;
      final stacked = stacks && !open;
      final labelStyle = TextStyle(fontSize: 11, color: context.colors.muted);

      final places = <Rect>[];
      var labelAt = Offset.zero;
      double total;
      if (stacked) {
        final shown = math.min(tags.length - 1, peeks);
        // The narrowest a tag can be cut: both ends and a letter or two.
        final least = tagHeight * 1.6;
        final front = math.max(least, width - shown * peek);
        var edge = 0.0;
        for (var i = 0; i < tags.length; i++) {
          // Past the last step the rest hide beneath it.
          if (i > peeks) {
            places.add(places[peeks]);
            continue;
          }
          final own = math.max(
            least,
            math.min(_tagWidth(context, tags[i]), front),
          );
          // Each one ends a step further right than the one above it.
          edge = i == 0 ? own : edge + peek;
          final fit = math.min(own, edge);
          places.add(Rect.fromLTWH(edge - fit, 0, fit, height));
        }
        // "收起" grows out of the end of the stack.
        labelAt = Offset(edge, 0);
        total = height;
      } else {
        var x = 0.0, y = 0.0;
        for (final tag in tags) {
          final own = math.min(_tagWidth(context, tag), width);
          if (x > 0 && x + own > width) {
            x = 0;
            y += height;
          }
          places.add(Rect.fromLTWH(x, y, own, height));
          x += own + spacing;
        }
        if (stacks) {
          final painter = TextPainter(
            text: TextSpan(
              text: '收起',
              style: DefaultTextStyle.of(context).style.merge(labelStyle),
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          // With the padding around the word.
          if (x + painter.width.ceilToDouble() + 8 > width) {
            x = 0;
            y += height;
          }
          painter.dispose();
          labelAt = Offset(x, y);
        }
        total = y + height;
      }

      final reduced = MediaQuery.disableAnimationsOf(context);
      // Overshoots a little, like cards flicked apart.
      const spring = Cubic(.3, 1.35, .5, 1);
      Duration time(int index) => reduced
          ? Duration.zero
          : Duration(milliseconds: 380 + 35 * math.min(index, 6));

      return AnimatedContainer(
        duration: reduced ? Duration.zero : const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        width: width,
        height: total,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Painted from the last, so the first lies on top of the stack.
            for (var i = tags.length - 1; i >= 0; i--)
              AnimatedPositioned.fromRect(
                key: ValueKey('article-tag-place-${tags[i]}'),
                duration: time(i),
                curve: spring,
                rect: places[i],
                child: GestureDetector(
                  key: ValueKey('article-tag-${tags[i]}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: stacked
                      ? toggle
                      : widget.store == null
                      ? null
                      : () => openArticleTopic(context, widget.store!, tags[i]),
                  child: Semantics(
                    button: true,
                    label: stacked ? '展开话题标签' : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: _tagTouchRoom,
                      ),
                      child: ArticleHangTag(
                        tags[i],
                        shade: i.isOdd,
                        covered: stacked && i > 0,
                      ),
                    ),
                  ),
                ),
              ),
            if (stacks)
              AnimatedPositioned(
                duration: time(tags.length),
                curve: Curves.easeOutCubic,
                left: labelAt.dx,
                top: labelAt.dy,
                height: height,
                child: GestureDetector(
                  key: const ValueKey('article-tags-toggle'),
                  behavior: HitTestBehavior.opaque,
                  onTap: stacked ? null : toggle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Center(
                      widthFactor: 1,
                      child: stacked
                          ? null
                          : Text('收起', maxLines: 1, style: labelStyle),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _TopicPicker extends StatefulWidget {
  const _TopicPicker({required this.store});
  final AppStore store;

  @override
  State<_TopicPicker> createState() => _TopicPickerState();
}

class _TopicPickerState extends State<_TopicPicker> {
  late final account = widget.store.epoch;
  final input = TextEditingController();
  final focus = FocusNode();
  Timer? pending;
  String get name => input.text.trim();
  bool get valid => name.isNotEmpty && name.runes.length <= 120;
  int generation = 0;
  bool loading = false, failed = false;
  List<Map<String, dynamic>> options = [];

  void changed(String value) {
    pending?.cancel();
    final request = ++generation;
    final query = value.trim();
    setState(() {
      options = [];
      loading = query.isNotEmpty;
      failed = false;
    });
    if (query.isNotEmpty) {
      pending = Timer(
        const Duration(milliseconds: 220),
        () => search(query, request),
      );
    }
  }

  Future<void> search(String value, int request) async {
    try {
      final result = await widget.store.request(
        'GetArticleTopics',
        query: {'query': value},
        expectedEpoch: account,
      );
      if (!mounted || request != generation || account != widget.store.epoch) {
        return;
      }
      setState(() {
        options = items(result.data);
        loading = false;
        failed = false;
      });
    } catch (_) {
      if (mounted && request == generation) {
        setState(() {
          loading = false;
          failed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    pending?.cancel();
    focus.dispose();
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: const AppPageBar(leading: CloseButton()),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: appPageHorizontalPadding,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => focus.requestFocus(),
                child: Row(
                  children: [
                    const Text('#'),
                    Flexible(
                      child: IntrinsicWidth(
                        child: TextField(
                          controller: input,
                          autofocus: true,
                          focusNode: focus,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                            isDense: true,
                            constraints: BoxConstraints(minWidth: 3),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.deny(
                              RegExp(r'[#\x00-\x1f\x7f-\x9f]'),
                            ),
                            LengthLimitingTextInputFormatter(120),
                          ],
                          onChanged: changed,
                          onSubmitted: (_) {
                            if (valid) Navigator.pop(context, name);
                          },
                        ),
                      ),
                    ),
                    const Text('#'),
                  ],
                ),
              ),
            ),
            const Divider(
              height: 1,
              indent: appPageHorizontalPadding,
              endIndent: appPageHorizontalPadding,
            ),
            Expanded(
              child: LoadingGate(
                loading: loading,
                builder: (_) => loading
                    ? const DotMatrixLoader()
                    : failed
                    ? Center(
                        child: EmptyState.failed(
                          '加载失败',
                          onRetry: () => changed(name),
                          compact: true,
                        ),
                      )
                    : ListView.builder(
                        itemCount: options.length,
                        itemBuilder: (context, i) {
                          final item = options[i];
                          final topic = item['name'] as String;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: appPageHorizontalPadding,
                            ),
                            title: Text('#$topic#'),
                            trailing: Text(
                              '${integer(item['article_count'])} 条动态',
                              style: TextStyle(color: colors.muted),
                            ),
                            onTap: () => Navigator.pop(context, topic),
                          );
                        },
                      ),
              ),
            ),
            const Divider(
              height: 1,
              indent: appPageHorizontalPadding,
              endIndent: appPageHorizontalPadding,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: appPageHorizontalPadding),
                child: TextButton(
                  onPressed: valid ? () => Navigator.pop(context, name) : null,
                  child: const Text('完成'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicFeed extends StatefulWidget {
  const _TopicFeed({required this.store, required this.name});
  final AppStore store;
  final String name;
  @override
  State<_TopicFeed> createState() => _TopicFeedState();
}

class _TopicFeedState extends State<_TopicFeed> {
  late final account = widget.store.epoch;
  List<Story> stories = [];
  bool loading = false, failed = false;
  String cursor = '';
  int generation = 0;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(accountChanged);
    load();
  }

  void accountChanged() {
    if (account != widget.store.epoch && (stories.isNotEmpty || loading)) {
      generation++;
      setState(() {
        stories = [];
        cursor = '';
        loading = false;
        failed = true;
      });
    }
  }

  Future<void> load({bool more = false}) async {
    if (account != widget.store.epoch || more && (loading || cursor.isEmpty)) {
      return;
    }
    final request = ++generation;
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      final result = await widget.store.request(
        'GetFeed',
        query: {
          'topic': widget.name,
          'limit': '20',
          if (more) 'cursor': cursor,
        },
        expectedEpoch: account,
      );
      if (!mounted || generation != request || account != widget.store.epoch) {
        return;
      }
      final page = items(result.data).map(decodeStory);
      setState(() {
        if (!more) stories = [];
        final seen = stories.map((s) => s.id).toSet();
        stories.addAll(page.where((s) => seen.add(s.id)));
        cursor = result.nextCursor;
      });
    } catch (_) {
      if (mounted && generation == request) setState(() => failed = true);
    } finally {
      if (mounted && generation == request) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(accountChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppPageBar(
      title: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.maybePop(context),
        child: const Text('返回'),
      ),
    ),
    body: SafeArea(
      top: false,
      child: PlayfulRefresh(
        onRefresh: load,
        child: AutoPaginate(
          canLoad: !loading && !failed && cursor.isNotEmpty,
          onLoadMore: () => load(more: true),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: stories.length + 1,
            itemBuilder: (context, index) {
              if (index < stories.length) {
                return FeedRow(
                  child: StoryCard(
                    store: widget.store,
                    story: stories[index],
                    flat: true,
                    compactTypography: true,
                  ),
                );
              }
              if (loading) return const PageLoadingFooter(visible: true);
              if (failed && stories.isEmpty) {
                return EmptyState.failed('加载失败', onRetry: load);
              }
              if (failed) {
                return Center(
                  child: TextButton(
                    onPressed: () =>
                        load(more: stories.isNotEmpty && cursor.isNotEmpty),
                    child: const Text('加载失败，点击重试'),
                  ),
                );
              }
              if (stories.isEmpty) {
                return const EmptyState('暂无公开动态', '', art: EmptyArt.post);
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    ),
  );
}
