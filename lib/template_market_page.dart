part of 'resume_pages.dart';

class TemplateMarket extends StatelessWidget {
  const TemplateMarket({super.key, required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) => TemplateMarketView(
    store: store,
    onUseTemplate: (context, template) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _MarketResumeChooser(
          store: store,
          template: template,
          onSelected: (resume) {
            openPage(context, ResumePreview(store: store, resumeId: resume.id));
          },
          onCreate: () {
            openPage(
              context,
              ResumeEditor(
                store: store,
                draft: ResumeDraft(
                  id: 0,
                  title: '我的简历',
                  marketTemplateID: integer(template['id']),
                  source: {
                    'app_layout': 'market',
                    'app_template_name': template['name'],
                  },
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

class _MarketResumeChooser extends StatefulWidget {
  const _MarketResumeChooser({
    required this.store,
    required this.template,
    required this.onSelected,
    required this.onCreate,
  });
  final AppStore store;
  final Map<String, dynamic> template;
  final ValueChanged<ResumeDraft> onSelected;
  final VoidCallback onCreate;
  @override
  State<_MarketResumeChooser> createState() => _MarketResumeChooserState();
}

class _MarketResumeChooserState extends State<_MarketResumeChooser> {
  bool loading = true, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    await widget.store.load('resumes');
    if (mounted) {
      setState(() {
        loading = false;
        error = widget.store.errors['resumes'];
      });
    }
  }

  Future<void> use(ResumeDraft resume) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.changeResumeMarketTemplate(
        resume.id,
        integer(widget.template['id']),
      );
      if (!mounted) return;
      final matching = widget.store.resumes.where((row) => row.id == resume.id);
      if (matching.isEmpty) throw const ApiFailure('简历暂不可用，请刷新');
      final updated = matching.first;
      Navigator.pop(context);
      widget.onSelected(updated);
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ApiFailure ? e.message : '模板应用失败，请重试');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .65,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              appPageHorizontalPadding,
              0,
              appPageHorizontalPadding,
              16,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '选择要使用的简历',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: appPageHorizontalPadding,
              ),
              child: Text(
                error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : ListenableBuilder(
                    listenable: widget.store,
                    builder: (context, _) => AutoPaginate.section(
                      store: widget.store,
                      section: 'resumes',
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: appPageHorizontalPadding,
                        ),
                        children: [
                          if (widget.store.errors.containsKey('resumes'))
                            TextButton(
                              onPressed: load,
                              child: const Text('重新加载'),
                            )
                          else
                            for (final resume in widget.store.resumes)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  resume.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  resume.templateTitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.colors.muted,
                                  ),
                                ),
                                trailing: busy
                                    ? null
                                    : const AppIcon(AppIcons.forward, size: 18),
                                onTap: busy ? null : () => use(resume),
                              ),
                          if (!widget.store.errors.containsKey('resumes') &&
                              widget.store.resumes.isEmpty)
                            const EmptyState(
                              '你还没有简历',
                              '可以用这套模板创建一份。',
                              compact: true,
                            ),
                          PageLoadingFooter(
                            visible: widget.store.loadingMore.contains(
                              'resumes',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              appPageHorizontalPadding,
              12,
              appPageHorizontalPadding,
              16,
            ),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: busy || loading
                    ? null
                    : () {
                        Navigator.pop(context);
                        widget.onCreate();
                      },
                child: const Text('创建新简历'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
