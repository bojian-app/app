part of 'resume_pages.dart';

class ResumePreview extends StatefulWidget {
  const ResumePreview({super.key, required this.store, required this.resumeId});
  final AppStore store;
  final int resumeId;
  @override
  State<ResumePreview> createState() => _ResumePreviewState();
}

class _ResumePreviewState extends State<ResumePreview> {
  late final ResumePreviewTrace previewTrace;
  @override
  void initState() {
    super.initState();
    previewTrace = ResumePreviewTrace(widget.resumeId);
  }

  @override
  void dispose() {
    previewTrace.dispose();
    super.dispose();
  }

  final documentKey = GlobalKey<ResumeDocumentViewState>();
  final marketDocumentKey = GlobalKey<ResumeMarketDocumentViewState>();
  AppStore get store => widget.store;
  int get resumeId => widget.resumeId;

  bool openingActions = false;
  bool monochrome = false;
  Future<void> showActions() async {
    if (openingActions) return;
    openingActions = true;
    final epoch = store.epoch;
    try {
      final current = store.resumes.where((r) => r.id == resumeId).firstOrNull;
      if (current == null) return;
      final action = await showAppActionSheet(
        context,
        builder: (_) =>
            ResumeActionsSheet(title: current.title, monochrome: monochrome),
      );
      if (!mounted ||
          action == null ||
          store.epoch != epoch ||
          !store.isAuthenticated) {
        return;
      }
      final resume = store.resumes.where((r) => r.id == resumeId).firstOrNull;
      if (resume == null) return;
      if (action == 'share-to-user') {
        openPage(context, ResumeUserShare(store: store, resume: resume));
      } else if (action == 'share-post') {
        openPage(context, ResumePostComposer(store: store, resume: resume));
      } else if (action == 'monochrome-preview') {
        setState(() => monochrome = !monochrome);
      } else if (action == 'request-help') {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => ResumeLinkShare(store: store, resume: resume),
        );
      } else if (action == 'share-link') {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => ResumeShareLinkSheet(store: store, resume: resume),
        );
      } else if (action == 'rename') {
        await showResumeRenameDialog(context, store: store, resume: resume);
      } else if (action == 'ai-optimize') {
        await openPage(
          context,
          ResumeAIOptimizationPage(store: store, resume: resume),
        );
      } else if (action == 'download') {
        export(resume);
      } else if (action == 'delete') {
        await confirmResumeDeletion(context, store: store, resume: resume);
        if (mounted &&
            store.epoch == epoch &&
            !store.resumes.any((r) => r.id == resumeId) &&
            ModalRoute.of(context)?.isCurrent == true) {
          await Navigator.maybePop(context);
        }
      }
    } finally {
      openingActions = false;
    }
  }

  bool switchingResume = false;

  Future<void> switchResume() async {
    if (switchingResume || !store.isAuthenticated) return;
    switchingResume = true;
    final epoch = store.epoch;
    try {
      final selected = await showPanelSheet<int>(
        context,
        useRootNavigator: true,
        builder: (_) => _ResumeSwitchSheet(store: store, currentId: resumeId),
      );
      if (!mounted ||
          selected == null ||
          selected == resumeId ||
          store.epoch != epoch ||
          !store.isAuthenticated ||
          !store.resumes.any((r) => r.id == selected)) {
        return;
      }
      if (ModalRoute.of(context)?.isCurrent != true) return;
      Navigator.of(context).pushReplacement(
        AppPageRoute<void>(
          builder: (_) => ResumePreview(store: store, resumeId: selected),
        ),
      );
    } finally {
      switchingResume = false;
    }
  }

  Future<void> createCopy(ResumeDraft resume) async {
    if (store.copyingResume || !store.isAuthenticated) return;
    final epoch = store.epoch;
    toast(context, '正在创建副本…');
    try {
      final copied = await store.copyResume(resume.id);
      if (!mounted ||
          store.epoch != epoch ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      toast(context, '副本已创建，原简历已保留');
      Navigator.of(context).pushReplacement(
        AppPageRoute<void>(
          builder: (_) => ResumePreview(store: store, resumeId: copied.id),
        ),
      );
    } catch (error) {
      if (mounted && store.epoch == epoch) {
        await showRequestFailure(context, error);
      }
    }
  }

  String documentIdentity(ResumeDraft resume) =>
      '${resume.id}:${resume.revision}:${resume.marketTemplateID}';

  void chooseTemplate(ResumeDraft resume) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) =>
        ResumeTemplatePicker(store: store, resume: resume, heightFactor: .6),
  );

  void export(ResumeDraft resume) => showPanelSheet<void>(
    context,
    useRootNavigator: true,
    builder: (_) => ResumeExportSheet(
      store: store,
      resume: resume,
      captureLayout: ({required isCancelled, required onProgress}) async {
        final current = store.resumes
            .where((r) => r.id == resumeId)
            .firstOrNull;
        if (current == null ||
            documentIdentity(current) != documentIdentity(resume)) {
          throw const ApiFailure('简历已更新，请重新下载');
        }
        if (resume.usesMarketTemplate) {
          final view = marketDocumentKey.currentState;
          if (view == null) throw const ApiFailure('请等待预览加载完成');
          return view.captureLayout(
            isCancelled: isCancelled,
            onProgress: onProgress,
          );
        }
        final view = documentKey.currentState;
        if (view == null) throw const ApiFailure('请等待预览加载完成');
        return view.captureLayout(
          isCancelled: isCancelled,
          onProgress: onProgress,
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final matches = store.resumes.where((r) => r.id == resumeId);
      if (matches.isEmpty) {
        return Scaffold(
          appBar: _toolbar(context),
          body: const EmptyState(
            '简历暂不可用',
            '请返回列表刷新后重试。',
            art: EmptyArt.contentGone,
          ),
        );
      }
      final resume = matches.first;
      return RouteTransitionSnapshot(
        child: Scaffold(
          appBar: _toolbar(context, resume: resume),
          body: resume.usesMarketTemplate
              ? ResumeMarketDocumentView(
                  key: marketDocumentKey,
                  store: store,
                  resume: resume,
                  monochrome: monochrome,
                )
              : ResumePreviewColor(
                  monochrome: monochrome,
                  child: ResumeDocumentView(
                    key: documentKey,
                    resume: resume,
                    store: store,
                  ),
                ),
          bottomNavigationBar: ResumePreviewTools(
            onEdit: () =>
                openPage(context, ResumeEditor(store: store, draft: resume)),
            onTemplate: () => chooseTemplate(resume),
            onSwitchResume: switchResume,
            onCopy: store.copyingResume ? null : () => createCopy(resume),
          ),
        ),
      );
    },
  );

  PreferredSizeWidget _toolbar(BuildContext context, {ResumeDraft? resume}) =>
      AppPageBar(
        title: Text(
          resume?.title ?? '简历预览',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          ResumePreviewActions(
            onMore: resume == null || store.copyingResume ? null : showActions,
            onClose: () => Navigator.maybePop(context),
          ),
        ],
      );
}

class _ResumeSwitchSheet extends StatelessWidget {
  const _ResumeSwitchSheet({required this.store, required this.currentId});
  final AppStore store;
  final int currentId;

  @override
  Widget build(BuildContext context) => PanelSheet(
    key: const ValueKey('resume-switch-sheet'),
    title: '切换简历',
    closeKey: const ValueKey('resume-switch-close'),
    horizontalPadding: appPageHorizontalPadding,
    child: AnimatedBuilder(
      animation: store,
      builder: (context, _) => SingleChildScrollView(
        child: PanelGroup(
          children: [
            for (final resume in store.resumes) resumeRow(context, resume),
          ],
        ),
      ),
    ),
  );

  Widget resumeRow(BuildContext context, ResumeDraft resume) {
    final selected = resume.id == currentId;
    return ListTile(
      key: ValueKey('resume-switch-${resume.id}'),
      selected: selected,
      selectedColor: context.colors.ink,
      selectedTileColor: context.colors.accentSoft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      minLeadingWidth: 22,
      horizontalTitleGap: 16,
      leading: AppIcon(AppIcons.resume, size: 22, color: context.colors.ink),
      title: Text(
        resume.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: ResumeEditorTypography.action,
      ),
      subtitle: Text(
        selected
            ? '当前简历'
            : resume.updatedAt == null
            ? '尚未记录更新时间'
            : '${resumeUpdatedLabel(resume.updatedAt!)} 更新',
        style: ResumeEditorTypography.caption.copyWith(
          color: context.colors.muted,
        ),
      ),
      trailing: AppIcon(
        selected ? AppIcons.confirm : AppIcons.forward,
        size: 18,
        color: selected ? context.colors.accent : context.colors.muted,
      ),
      onTap: () => Navigator.pop(context, resume.id),
    );
  }
}
