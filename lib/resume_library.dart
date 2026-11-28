part of 'resume_pages.dart';

class ResumeLibrary extends StatelessWidget {
  const ResumeLibrary({super.key, required this.store, this.embedded = false});
  final AppStore store;
  final bool embedded;
  @override
  Widget build(BuildContext context) => AutoPaginate.section(
    store: store,
    section: 'resumes',
    child: PlayfulRefresh(
      hasError: () => store.errors['resumes'] != null,
      onRefresh: () => store.load('resumes'),
      child: embedded
          ? _profileGrid(context)
          : ListView(
              key: const PageStorageKey('resume-library'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (!embedded) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(
                      appPageHorizontalPadding,
                      18,
                      appPageHorizontalPadding,
                      16,
                    ),
                    child: Text(
                      '我的简历',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.5,
                      ),
                    ),
                  ),
                ],
                if (!embedded)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: appPageHorizontalPadding,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _actionCard(
                            context,
                            label: '创建简历',
                            icon: AppIcons.add,
                            onTap: () => _create(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _actionCard(
                            context,
                            label: '导入简历',
                            icon: AppIcons.importResume,
                            onTap: () => _import(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!embedded) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      appPageHorizontalPadding,
                      0,
                      appPageHorizontalPadding,
                      12,
                    ),
                    child: Row(
                      children: [
                        const Text(
                          '简历库',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${store.resumes.length} 份',
                          style: TextStyle(
                            color: context.colors.muted,
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '最近更新',
                          style: TextStyle(
                            color: context.colors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                DataStatus(
                  store: store,
                  section: 'resumes',
                  art: EmptyArt.resume,
                  empty: store.resumes.isEmpty,
                  title: embedded ? '这里还没有内容' : '创建你的第一份简历',
                  subtitle: embedded ? '下拉刷新，查看最新内容。' : '从一份空白简历开始，逐步整理你的经历。',
                ),
                for (final resume in store.resumes)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      appPageHorizontalPadding,
                      0,
                      appPageHorizontalPadding,
                      12,
                    ),
                    child: _resumeCard(context, resume),
                  ),
                PageLoadingFooter(
                  visible: store.loadingMore.contains('resumes'),
                ),
              ],
            ),
    ),
  );
  Widget _profileGrid(BuildContext context) => CustomScrollView(
    key: const PageStorageKey('profile-resumes'),
    physics: const AlwaysScrollableScrollPhysics(),
    slivers: [
      SliverToBoxAdapter(
        child: DataStatus(
          store: store,
          section: 'resumes',
          art: EmptyArt.resume,
          empty: store.resumes.isEmpty,
          title: '这里还没有内容',
          subtitle: '下拉刷新，查看最新内容。',
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          appPageHorizontalPadding,
          8,
          appPageHorizontalPadding,
          24,
        ),
        sliver: SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 12,
            childAspectRatio: resumePaperSize.aspectRatio,
          ),
          itemCount: store.resumes.length,
          itemBuilder: (context, index) {
            final resume = store.resumes[index];
            return Material(
              key: ValueKey('resume-card-${resume.id}'),
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              elevation: 1,
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () => openPage(
                  context,
                  ResumePreview(store: store, resumeId: resume.id),
                ),
                child: ResumeCardThumbnail(store: store, resume: resume),
              ),
            );
          },
        ),
      ),
      SliverToBoxAdapter(
        child: PageLoadingFooter(
          visible: store.loadingMore.contains('resumes'),
        ),
      ),
      // Clears the home shell's floating tab bar.
      SliverToBoxAdapter(
        child: SizedBox(height: MediaQuery.paddingOf(context).bottom),
      ),
    ],
  );

  Widget _actionCard(
    BuildContext context, {
    required String label,
    required AppIconData icon,
    required VoidCallback onTap,
  }) => Material(
    color: context.colors.surface,
    clipBehavior: Clip.antiAlias,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (context.isDark
                    ? context.colors.accentSoft
                    : const Color(0xFFEEF4FF)),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Center(
                child: AppIcon(icon, size: 20, color: context.colors.accent),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.colors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _resumeCard(BuildContext context, ResumeDraft resume) {
    final progress = resume.progress.clamp(0.0, 1.0);
    final progressColor = progress == 1
        ? const Color(0xFF449581)
        : context.colors.accent;
    return Material(
      color: context.colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.colors.border),
      ),
      child: InkWell(
        key: ValueKey('resume-card-${resume.id}'),
        onTap: () =>
            openPage(context, ResumePreview(store: store, resumeId: resume.id)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final thumbnailWidth = (constraints.maxWidth * .32).clamp(
                72.0,
                110.0,
              );
              final thumbnailHeight =
                  (thumbnailWidth - 2) / resumePaperSize.aspectRatio + 2;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: thumbnailWidth,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: context.colors.border),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(1),
                        child: ResumeCardThumbnail(
                          key: ValueKey(
                            'resume-thumbnail-${identityHashCode(store)}-${store.epoch}-${resume.id}-${resume.marketTemplateID}',
                          ),
                          store: store,
                          resume: resume,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: thumbnailHeight),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                resume.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: ResumeEditorTypography.entryTitle
                                    .copyWith(color: context.colors.ink),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                resume.updatedAt == null
                                    ? '尚未记录更新时间'
                                    : '${resumeUpdatedLabel(resume.updatedAt!)} 更新',
                                style: ResumeEditorTypography.caption.copyWith(
                                  color: context.colors.muted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _resumeDetail(
                                context,
                                AppIcons.work,
                                resume.position.trim().isEmpty
                                    ? '求职岗位待填写'
                                    : resume.position.trim(),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: double.infinity,
                                child: Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Text(
                                      '完善度',
                                      style: ResumeEditorTypography.caption
                                          .copyWith(
                                            color: context.colors.muted,
                                          ),
                                    ),
                                    Text(
                                      '${(progress * 100).round()}%',
                                      style: ResumeEditorTypography.entryTitle
                                          .copyWith(color: progressColor),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 3),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 4,
                                  color: progressColor,
                                  backgroundColor: context.colors.accentSoft,
                                ),
                              ),
                            ],
                          ),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    '查看简历',
                                    style: ResumeEditorTypography.caption
                                        .copyWith(
                                          color: context.colors.accent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                AppIcon(
                                  AppIcons.forward,
                                  size: 14,
                                  color: context.colors.accent,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _resumeDetail(BuildContext context, AppIconData icon, String text) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: 14, color: context.colors.muted),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ResumeEditorTypography.caption.copyWith(
                color: context.colors.ink,
              ),
            ),
          ),
        ],
      );

  Future<void> showAddOptions(BuildContext context) async {
    final epoch = store.epoch;
    final source = await showResumeAddSheet(context);
    if (!context.mounted ||
        source == null ||
        !store.isAuthenticated ||
        epoch != store.epoch) {
      return;
    }
    switch (source) {
      case ResumeAddSource.assistance:
        openPage(context, ResumeAssistancePage(store: store));
      case ResumeAddSource.manual:
        _create(context);
      case ResumeAddSource.wechat:
        openPage(
          context,
          ImportResume(store: store, initialSource: ResumeImportSource.wechat),
        );
      case ResumeAddSource.local:
        openPage(
          context,
          ImportResume(store: store, initialSource: ResumeImportSource.local),
        );
    }
  }

  void _create(BuildContext context) {
    if (!store.isAuthenticated) {
      store.endSession();
      return;
    }
    final draft = store.createResume();
    openPage(context, ResumeEditor(store: store, draft: draft));
  }

  void _import(BuildContext context) =>
      openPage(context, ImportResume(store: store));
}
