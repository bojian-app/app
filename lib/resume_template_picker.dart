import 'package:flutter/material.dart';

import 'api/bojian_api.dart';
import 'app_icons.dart';
import 'app_store.dart';
import 'design.dart';
import 'resume_document.dart';
import 'resume_templates.dart';

class ResumeTemplatePicker extends StatefulWidget {
  const ResumeTemplatePicker({
    super.key,
    required this.store,
    required this.resume,
  });
  final AppStore store;
  final ResumeDraft resume;
  @override
  State<ResumeTemplatePicker> createState() => _ResumeTemplatePickerState();
}

class _ResumeTemplatePickerState extends State<ResumeTemplatePicker> {
  late int selected = widget.resume.marketTemplateID;
  List<Map<String, dynamic>> purchased = [];
  bool loading = true, saving = false;
  String? loadError, error;
  int operation = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final request = ++operation;
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final result = await widget.store.purchasedResumeTemplates();
      if (!mounted || request != operation) return;
      setState(() => purchased = result);
    } catch (e) {
      if (mounted && request == operation) {
        setState(() => loadError = e is ApiFailure ? e.message : '已购买模板加载失败');
      }
    } finally {
      if (mounted && request == operation) setState(() => loading = false);
    }
  }

  Future<void> apply() async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      if (selected == 0) {
        await widget.store.changeResumeLayout(
          widget.resume.id,
          ResumeLayout.standard,
        );
      } else {
        await widget.store.changeResumeMarketTemplate(
          widget.resume.id,
          selected,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ApiFailure ? e.message : '模板切换失败，请重试');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final choices = <Map<String, dynamic>>[
      {'id': 0, 'name': ResumeLayout.standard.title},
      ...purchased,
    ];
    final available = choices.any((row) => integer(row['id']) == selected);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .88,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '切换模板',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: saving ? null : () => Navigator.pop(context),
                    icon: const AppIcon(AppIcons.close, size: 20),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 900
                      ? 4
                      : constraints.maxWidth >= 600
                      ? 3
                      : 2;
                  return CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 16,
                                childAspectRatio: .62,
                                mainAxisExtent: constraints.maxHeight < 260
                                    ? (constraints.maxHeight - 16).clamp(
                                        120.0,
                                        230.0,
                                      )
                                    : null,
                              ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => tile(
                              choices[index],
                              compact: constraints.maxHeight < 260,
                            ),
                            childCount: choices.length,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: loading
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : loadError != null
                              ? Column(
                                  children: [
                                    Text(
                                      loadError!,
                                      style: const TextStyle(
                                        color: muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: load,
                                      child: const Text('重新加载'),
                                    ),
                                  ],
                                )
                              : purchased.isEmpty
                              ? const Text(
                                  '暂无已购买模板',
                                  style: TextStyle(color: muted, fontSize: 12),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        error!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: saving || !available ? null : apply,
                      child: Text(saving ? '正在切换…' : '使用选中模板'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget tile(Map<String, dynamic> design, {bool compact = false}) {
    final id = integer(design['id']);
    final active = id == selected;
    final current = id == widget.resume.marketTemplateID;
    final artwork = Center(
      child: AspectRatio(
        aspectRatio: resumePaperSize.aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: ColoredBox(
            color: Colors.white,
            child: id == 0
                ? _StandardThumbnail(resume: widget.resume)
                : _MarketThumbnail(
                    url: design['thumbnail_url'] as String? ?? '',
                  ),
          ),
        ),
      ),
    );
    final details = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${design['name']}',
          maxLines: compact ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                current
                    ? '当前使用'
                    : id == 0
                    ? '系统模板'
                    : '已购买',
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? blue : Colors.transparent,
                border: Border.all(color: active ? blue : borderColor),
              ),
              child: active
                  ? const Center(
                      child: AppIcon(
                        AppIcons.confirm,
                        size: 12,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ],
    );
    return Semantics(
      selected: active,
      button: true,
      label: '${design['name']}',
      child: Material(
        color: active ? const Color(0xFFF0F5FF) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: active ? blue : borderColor,
            width: active ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: saving
              ? null
              : () => setState(() {
                  selected = id;
                  error = null;
                }),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: compact
                ? Row(
                    children: [
                      Expanded(flex: 4, child: artwork),
                      const SizedBox(width: 10),
                      Expanded(flex: 5, child: details),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: artwork),
                      const SizedBox(height: 10),
                      details,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _MarketThumbnail extends StatelessWidget {
  const _MarketThumbnail({required this.url});
  final String url;
  @override
  Widget build(BuildContext context) {
    final placeholder = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppIcon(AppIcons.templates, size: 28, color: muted),
          const SizedBox(height: 8),
          const Text('预览暂不可用', style: TextStyle(color: muted, fontSize: 10)),
        ],
      ),
    );
    return url.isEmpty
        ? placeholder
        : Image.network(
            url,
            cacheWidth: 720,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => placeholder,
          );
  }
}

class _StandardThumbnail extends StatefulWidget {
  const _StandardThumbnail({required this.resume});
  final ResumeDraft resume;
  @override
  State<_StandardThumbnail> createState() => _StandardThumbnailState();
}

class _StandardThumbnailState extends State<_StandardThumbnail> {
  late final document = ResumeDocument(widget.resume);
  @override
  void dispose() {
    document.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final rect = document.pages.first.photo;
      final scale = constraints.maxWidth / resumePaperSize.width;
      return Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _ThumbnailPainter(document)),
          ),
          if (rect != null && widget.resume.photoURL.isNotEmpty)
            Positioned(
              left: rect.left * scale,
              top: rect.top * scale,
              width: rect.width * scale,
              height: rect.height * scale,
              child: Image.network(
                widget.resume.photoURL,
                cacheWidth: 240,
                fit: BoxFit.cover,
                alignment: const Alignment(0, -.35),
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
        ],
      );
    },
  );
}

class _ThumbnailPainter extends CustomPainter {
  const _ThumbnailPainter(this.document);
  final ResumeDocument document;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / resumePaperSize.width);
    paintResumeSheet(canvas, document, 0);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ThumbnailPainter oldDelegate) =>
      oldDelegate.document != document;
}
