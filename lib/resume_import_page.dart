part of 'resume_pages.dart';

enum ResumeImportSource { wechat, local }

class ImportResume extends StatefulWidget {
  const ImportResume({
    super.key,
    required this.store,
    this.initialFile,
    this.initialSource,
    this.pickFile,
    this.importer,
    this.onSaved,
  });
  final AppStore store;
  final XFile? initialFile;
  final ResumeImportSource? initialSource;
  final Future<XFile?> Function()? pickFile;
  final ResumeImporter? importer;
  final VoidCallback? onSaved;
  @override
  State<ImportResume> createState() => _ImportResumeState();
}

class _ImportResumeState extends State<ImportResume> {
  late final int accountEpoch;
  List<Map<String, dynamic>> pendingImports = [];
  String? pendingError;
  bool loadingPending = false;
  bool _sourceOpened = false;

  Future<void> loadPending() async {
    if (loadingPending) return;
    setState(() {
      loadingPending = true;
      pendingError = null;
    });
    try {
      final result = await widget.store.request(
        'GetResumeImportsPending',
        expectedEpoch: accountEpoch,
      );
      if (!mounted || widget.store.epoch != accountEpoch) return;
      setState(() => pendingImports = items(result.data));
    } catch (e) {
      if (mounted && widget.store.epoch == accountEpoch) {
        setState(() => pendingError = '$e');
      }
    } finally {
      if (mounted) setState(() => loadingPending = false);
    }
  }

  void openReview(ResumeDraft draft) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResumeEditor(
          store: widget.store,
          draft: draft,
          onSaved: widget.onSaved,
        ),
      ),
    );
  }

  Future<void> resumePending(int id) async {
    if (busy || picking || widget.store.epoch != accountEpoch) return;
    final token = ++operation;
    setState(() {
      busy = true;
      stage = '正在恢复解析结果…';
      phase = ResumeImportPhase.ready;
      error = null;
    });
    try {
      final draft =
          await (widget.importer ?? ResumeImporter(store: widget.store))
              .resumeImport(id);
      if (!mounted ||
          token != operation ||
          widget.store.epoch != accountEpoch) {
        return;
      }
      openReview(draft);
    } catch (e) {
      if (mounted && token == operation) setState(() => error = '$e');
    } finally {
      if (mounted && token == operation) {
        setState(() {
          busy = false;
          stage = null;
        });
      }
    }
  }

  final files = ResumeFiles.instance;
  XFile? selected;
  bool picking = false;
  bool busy = false;
  int operation = 0;
  String? stage, error;
  ResumeImportPhase phase = ResumeImportPhase.reading;

  @override
  void initState() {
    super.initState();
    accountEpoch = widget.store.epoch;
    selected = widget.initialFile;
    files.activeImports++;
    files.incoming.addListener(receiveShared);
    if (selected != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && operation == 0) upload();
      });
    }
    if (selected == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await loadPending();
        if (!mounted ||
            operation != 0 ||
            selected != null ||
            pendingImports.isNotEmpty ||
            _sourceOpened) {
          return;
        }
        switch (widget.initialSource) {
          case ResumeImportSource.wechat:
            fromWeChat();
          case ResumeImportSource.local:
            chooseLocal();
          case null:
            break;
        }
      });
    }
  }

  void receiveShared() {
    final file = files.incoming.value;
    if (file == null) return;
    files.incoming.value = null;
    if (selected?.path == file.path) return;
    operation++;
    setState(() {
      selected = file;
      busy = false;
      stage = null;
      error = null;
    });
    upload();
  }

  Future<void> chooseLocal() async {
    if (picking || busy) return;
    _sourceOpened = true;
    setState(() {
      picking = true;
      error = null;
    });
    try {
      final file = await (widget.pickFile ?? files.pickLocal)();
      if (mounted && file != null) setState(() => selected = file);
    } catch (_) {
      if (mounted) setState(() => error = '无法读取文件，请重新选择');
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  void cancel() {
    operation++;
    setState(() {
      busy = false;
      stage = null;
    });
  }

  Future<void> upload() async {
    final file = selected;
    if (file == null || busy || picking) return;
    if (!await AiConsent.ensure(context, widget.store) || !mounted) return;
    final token = ++operation;
    setState(() {
      busy = true;
      stage = '正在读取文件…';
      phase = ResumeImportPhase.reading;
      error = null;
    });
    try {
      final draft =
          await (widget.importer ?? ResumeImporter(store: widget.store))
              .importFile(
                file,
                isCancelled: () => !mounted || token != operation,
                onPhase: (value) {
                  if (mounted && token == operation) {
                    setState(() => phase = value);
                  }
                },
                onProgress: (text) {
                  if (mounted && token == operation) {
                    setState(() => stage = text);
                  }
                },
              );
      if (!mounted || token != operation) return;
      toast(context, '文件已解析，请检查内容后保存');
      openReview(draft);
    } on ImportCancelled {
      // Leaving or cancelling the page must not continue creating an import.
    } catch (e) {
      if (mounted && token == operation) setState(() => error = '$e');
    } finally {
      if (mounted && token == operation) {
        setState(() {
          busy = false;
          stage = null;
        });
      }
    }
  }

  Future<void> fromWeChat() {
    _sourceOpened = true;
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            appPageHorizontalPadding,
            8,
            appPageHorizontalPadding,
            24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '从微信文件上传',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              Text(
                Platform.isAndroid
                    ? '在微信打开简历文件 → 点击右上角“…” → 用其他应用打开 → 选择“最优简”。返回后会自动上传并解析，无需再次选择文件。'
                    : '先将微信中的简历保存到“文件”，再选择已保存的文件上传。',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  color: context.colors.muted,
                ),
              ),
              const SizedBox(height: 22),
              if (Platform.isAndroid) ...[
                FilledButton(
                  onPressed: () async {
                    try {
                      await files.openWeChat();
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    } catch (_) {
                      if (mounted) toast(context, '无法打开微信，请确认已安装微信');
                    }
                  },
                  child: const Text('前往微信'),
                ),
                const SizedBox(height: 8),
              ],
              TextButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  chooseLocal();
                },
                child: const Text('选择已保存的微信文件'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget source(
    String title,
    String subtitle,
    AppIconData icon,
    Color color,
    VoidCallback onTap,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Panel(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: AppIcon(icon, color: color, size: 28),
        title: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: context.colors.muted),
          ),
        ),
        trailing: AppIcon(
          AppIcons.forward,
          size: 16,
          color: context.colors.muted,
        ),
        onTap: busy || picking ? null : onTap,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppPageBar(title: const Text('导入简历')),
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text(
          busy ? '正在导入简历' : '选择简历文件',
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          '支持 PDF、DOC、DOCX，文件不超过 20 MB。',
          style: TextStyle(
            fontSize: 13,
            color: context.colors.muted,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 24),
        if (!busy && pendingImports.isNotEmpty) ...[
          const Text(
            '待保存的导入简历',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text('之前解析的内容还在，可继续校对并保存。'),
          const SizedBox(height: 12),
          for (final record in pendingImports)
            source(
              '${record['name'] ?? '导入的简历'}',
              '继续校对并保存',
              AppIcons.edit,
              context.colors.accent,
              () => resumePending(integer(record['id'])),
            ),
          const SizedBox(height: 16),
        ],
        if (!busy && pendingError != null)
          TextButton(
            onPressed: loadingPending ? null : loadPending,
            child: const Text('待保存记录加载失败，点击重试'),
          ),
        if (!busy)
          source(
            '从微信文件上传',
            '导入聊天中收到的简历',
            AppIcons.wechat,
            const Color(0xFF509B87),
            fromWeChat,
          ),
        if (!busy)
          source(
            '从本机文件上传',
            '选择手机或文件应用中的简历',
            AppIcons.folder,
            context.colors.accent,
            chooseLocal,
          ),
        if (picking)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (selected != null) ...[
          const SizedBox(height: 12),
          Panel(
            child: Row(
              children: [
                AppIcon(
                  AppIcons.attachment,
                  color: context.colors.accent,
                  size: 30,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected!.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      FutureBuilder<int>(
                        future: selected!.length(),
                        builder: (context, snapshot) => Text(
                          snapshot.hasData
                              ? '${(snapshot.data! / 1024 / 1024).toStringAsFixed(2)} MB'
                              : '已选择文件',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const ValueKey('resume-upload'),
            onPressed: busy || picking ? null : upload,
            child: Text(busy ? stage ?? '正在处理…' : '上传并解析'),
          ),
          if (busy) ...[
            const SizedBox(height: 16),
            Panel(
              key: const ValueKey('resume-import-progress'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                  Semantics(liveRegion: true, child: Text(stage ?? '正在处理…')),
                  const SizedBox(height: 12),
                  for (final step in ResumeImportPhase.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            step.index < phase.index
                                ? Icons.check_circle
                                : step == phase
                                ? Icons.pending
                                : Icons.radio_button_unchecked,
                            size: 18,
                            color: step.index <= phase.index
                                ? context.colors.accent
                                : context.colors.muted,
                          ),
                          const SizedBox(width: 8),
                          Text(switch (step) {
                            ResumeImportPhase.reading => '读取文件',
                            ResumeImportPhase.uploading => '上传文件',
                            ResumeImportPhase.parsing => 'AI 识别与整理',
                            ResumeImportPhase.ready => '进入内容校对',
                          }),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    '解析时间取决于文件大小和内容复杂度，请稍候。',
                    style: TextStyle(fontSize: 12, color: context.colors.muted),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: cancel, child: const Text('取消导入')),
          ],
        ],
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              error!,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
      ],
    ),
  );

  @override
  void dispose() {
    operation++;
    files.activeImports--;
    files.incoming.removeListener(receiveShared);
    super.dispose();
  }
}
