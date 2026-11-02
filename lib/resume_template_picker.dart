import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'api/bojian_api.dart';
import 'app_icons.dart';
import 'app_store.dart';
import 'design.dart';
import 'resume_document.dart';
import 'resume_templates.dart';
import 'resume_thumbnail.dart';

class ResumeTemplatePicker extends StatefulWidget {
  const ResumeTemplatePicker({
    super.key,
    required this.store,
    required this.resume,
    this.heightFactor = .88,
  });
  final AppStore store;
  final ResumeDraft resume;
  final double heightFactor;
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
        height: MediaQuery.sizeOf(context).height * widget.heightFactor,
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
                      ? 6
                      : constraints.maxWidth >= 600
                      ? 5
                      : 3;
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
                                childAspectRatio: resumePaperSize.aspectRatio,
                                mainAxisExtent: constraints.maxHeight < 260
                                    ? (constraints.maxHeight - 16).clamp(
                                        120.0,
                                        230.0,
                                      )
                                    : null,
                              ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => tile(choices[index]),
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
                                      style: TextStyle(
                                        color: context.colors.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: load,
                                      child: const Text('重新加载'),
                                    ),
                                  ],
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
              decoration: BoxDecoration(
                color: context.colors.surface,
                border: Border(top: BorderSide(color: context.colors.border)),
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

  Widget tile(Map<String, dynamic> design) {
    final id = integer(design['id']);
    final active = id == selected;
    final current = id == widget.resume.marketTemplateID;
    return Semantics(
      selected: active,
      button: true,
      label: '${design['name']}${current ? '，使用中' : ''}',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: saving
              ? null
              : () => setState(() {
                  selected = id;
                  error = null;
                }),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: active ? blue : context.colors.border,
                width: active ? 1.5 : 1,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: const EdgeInsets.all(2),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: resumePaperSize.aspectRatio,
                      child: id == 0
                          ? StandardResumeThumbnail(resume: widget.resume)
                          : MarketResumeThumbnail(
                              url: design['thumbnail_url'] as String? ?? '',
                            ),
                    ),
                  ),
                ),
                if (current)
                  Positioned(
                    top: 12,
                    right: -23,
                    child: IgnorePointer(
                      child: Transform.rotate(
                        angle: math.pi / 4,
                        child: Container(
                          width: 90,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: blue,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x26000000),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            '使用中',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              height: 1,
                            ),
                          ),
                        ),
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
