import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'api/bojian_api.dart';
import 'app_store.dart';
import 'app_icons.dart';
import 'design.dart';
import 'resume_editor_typography.dart';

enum ResumeOptionKind {
  position('GetJobTitles', '职位', '意向职位', 'job-title'),
  industry('GetIndustries', '行业', '期望行业', 'industry'),
  city('GetCities', '城市', '意向城市', 'city');

  const ResumeOptionKind(
    this.method,
    this.label,
    this.fieldLabel,
    this.keyPrefix,
  );
  final String method, label, fieldLabel, keyPrefix;
  String get title => '选择$fieldLabel';
  String get hint => '搜索或输入$fieldLabel';
}

Future<String?> showResumeOptionPicker(
  BuildContext context, {
  required AppStore store,
  String initialValue = '',
  String? title,
  ResumeOptionKind kind = ResumeOptionKind.position,
}) async {
  final epoch = store.epoch;
  final value = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    clipBehavior: Clip.antiAlias,
    backgroundColor: context.colors.surface,
    builder: (_) => ResumeOptionPicker(
      store: store,
      initialValue: initialValue,
      title: title,
      kind: kind,
    ),
  );
  return store.alive && store.epoch == epoch ? value : null;
}

class ResumeOptionPicker extends StatefulWidget {
  const ResumeOptionPicker({
    super.key,
    required this.store,
    this.initialValue = '',
    this.title,
    this.kind = ResumeOptionKind.position,
  });

  final AppStore store;
  final String initialValue;
  final String? title;
  final ResumeOptionKind kind;

  @override
  State<ResumeOptionPicker> createState() => _ResumeOptionPickerState();
}

class _ResumeOptionPickerState extends State<ResumeOptionPicker> {
  late final text = TextEditingController(text: widget.initialValue);
  final headerKey = GlobalKey();
  Timer? debounce;
  int operation = 0;
  bool loading = true;
  String? error;
  List<String> names = [];

  @override
  void initState() {
    super.initState();
    unawaited(load(text.text.trim(), ++operation));
  }

  void search(String value) {
    debounce?.cancel();
    final request = ++operation;
    setState(() {
      loading = true;
      error = null;
      names = [];
    });
    debounce = Timer(
      const Duration(milliseconds: 250),
      () => load(value.trim(), request),
    );
  }

  Future<void> load(String query, int request) async {
    try {
      final result = await widget.store.request(
        widget.kind.method,
        query: {'q': query},
        authenticated: false,
      );
      if (!mounted || operation != request) return;
      final items = result.data['items'];
      if (items is! List) throw ApiFailure('${widget.kind.label}列表暂不可用');
      setState(() {
        names = items
            .whereType<Map>()
            .map((item) => '${item['name'] ?? ''}'.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList();
        loading = false;
      });
    } catch (_) {
      if (!mounted || operation != request) return;
      setState(() {
        loading = false;
        error = '${widget.kind.label}列表加载失败，可以重试或直接使用输入的${widget.kind.label}';
      });
    }
  }

  void useInput() {
    final value = text.text.trim();
    if (value.isEmpty) return;
    final exact = names.where(
      (name) => name.toLowerCase() == value.toLowerCase(),
    );
    Navigator.pop(context, exact.isEmpty ? value : exact.first);
  }

  @override
  void dispose() {
    debounce?.cancel();
    text.dispose();
    super.dispose();
  }

  Widget _header() => Padding(
    key: headerKey,
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
    child: Semantics(
      label: widget.title ?? widget.kind.title,
      child: TextField(
        key: ValueKey('${widget.kind.keyPrefix}-search'),
        controller: text,
        maxLength: 60,
        style: ResumeEditorTypography.body,
        textInputAction: TextInputAction.done,
        onChanged: search,
        onSubmitted: (_) => useInput(),
        decoration: InputDecoration(
          hintText: widget.kind.hint,
          counterText: '',
          prefixIcon: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: SizedBox.square(
              dimension: 18,
              child: AppIcon(
                AppIcons.search,
                size: 18,
                color: context.colors.muted,
              ),
            ),
          ),
          suffixIcon: text.text.isEmpty
              ? null
              : IconButton(
                  tooltip: '清除搜索',
                  icon: AppIcon(
                    AppIcons.close,
                    size: 18,
                    color: context.colors.muted,
                  ),
                  onPressed: () {
                    text.clear();
                    search('');
                  },
                ),
        ),
      ),
    ),
  );

  Widget _choice(String name, {bool custom = false}) {
    final selected = name == widget.initialValue.trim();
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? context.colors.accentSoft : context.colors.inset,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? context.colors.accent : Colors.transparent,
          ),
        ),
        child: InkWell(
          key: custom ? ValueKey('${widget.kind.keyPrefix}-custom') : null,
          borderRadius: BorderRadius.circular(10),
          onTap: custom ? useInput : () => Navigator.pop(context, name),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      name,
                      style: ResumeEditorTypography.body.copyWith(
                        color: selected
                            ? context.colors.accent
                            : context.colors.ink,
                      ),
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 6),
                    AppIcon(
                      AppIcons.confirm,
                      size: 16,
                      color: context.colors.accent,
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

  List<Widget> _results() {
    final query = text.text.trim();
    final hasExact = names.any(
      (name) => name.toLowerCase() == query.toLowerCase(),
    );
    return [
      if (query.isNotEmpty && !hasExact) ...[
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: [_choice(query, custom: true)],
        ),
        const SizedBox(height: 12),
      ],
      if (loading)
        const Padding(
          padding: EdgeInsets.all(28),
          child: Center(
            child: SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        )
      else if (error != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Text(
                error!,
                textAlign: TextAlign.center,
                style: ResumeEditorTypography.caption.copyWith(
                  color: context.colors.muted,
                ),
              ),
              TextButton(
                onPressed: () => search(text.text),
                child: const Text('重试'),
              ),
            ],
          ),
        )
      else if (names.isNotEmpty) ...[
        Text(
          '${query.isEmpty ? '全部${widget.kind.label}' : '搜索结果'}（${names.length}）',
          style: ResumeEditorTypography.caption.copyWith(
            color: context.colors.muted,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 10, children: names.map(_choice).toList()),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final keyboard = MediaQuery.viewInsetsOf(context).bottom;
        final height = math.min(
          MediaQuery.sizeOf(context).height * .75,
          math.max(0.0, constraints.maxHeight - keyboard),
        );
        // Keep all controls reachable on short screens and with large text.
        final compact =
            height < 340 * MediaQuery.textScalerOf(context).scale(14) / 14;
        return Padding(
          padding: EdgeInsets.only(bottom: keyboard),
          child: SizedBox(
            height: height,
            child: compact
                ? ListView(
                    key: ValueKey('${widget.kind.keyPrefix}-results'),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      _header(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _results(),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _header(),
                      Expanded(
                        child: ListView(
                          key: ValueKey('${widget.kind.keyPrefix}-results'),
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          children: _results(),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    ),
  );
}
