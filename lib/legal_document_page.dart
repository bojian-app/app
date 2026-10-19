import 'package:flutter/material.dart';

import 'design.dart';
import 'legal_document.dart';

/// A local, read-only document route, separate from the login consent controls.
class LegalDocumentPage extends StatefulWidget {
  const LegalDocumentPage({super.key, required this.kind});

  final LegalDocumentKind kind;

  @override
  State<LegalDocumentPage> createState() => _LegalDocumentPageState();
}

class _LegalDocumentPageState extends State<LegalDocumentPage> {
  final scroll = ScrollController();
  final sectionKeys = <String, GlobalKey>{};

  LegalDocument get document => legalDocumentFor(widget.kind);

  @override
  void didUpdateWidget(covariant LegalDocumentPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind == widget.kind) return;
    sectionKeys.clear();
    final nextKind = widget.kind;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.kind == nextKind && scroll.hasClients) {
        scroll.jumpTo(0);
      }
    });
  }

  Future<void> showDirectory() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.colors.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .62,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  '${document.title}目录',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  itemCount: document.sections.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final section = document.sections[index];
                    return TextButton(
                      key: ValueKey('legal-directory-${section.id}'),
                      onPressed: () => Navigator.of(context).pop(section.id),
                      style: TextButton.styleFrom(
                        foregroundColor: context.colors.ink,
                        alignment: Alignment.centerLeft,
                        minimumSize: const Size.fromHeight(52),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        overlayColor: Colors.transparent,
                      ).withoutHover(),
                      child: Text(
                        section.title,
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    final target = sectionKeys[selected]?.currentContext;
    if (target != null && target.mounted) {
      await Scrollable.ensureVisible(
        target,
        alignment: 0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = document;
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        title: Text(current.title),
        centerTitle: false,
        titleSpacing: 0,
        backgroundColor: context.colors.surface,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              key: const ValueKey('legal-directory'),
              onPressed: showDirectory,
              style: TextButton.styleFrom(
                foregroundColor: context.colors.muted,
                overlayColor: Colors.transparent,
                minimumSize: const Size(44, 44),
              ).withoutHover(),
              child: const Text('目录'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Scrollbar(
          controller: scroll,
          child: SingleChildScrollView(
            key: const ValueKey('legal-document-scroll'),
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: SelectionArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final line in current.metadata)
                        Text(
                          line,
                          style: TextStyle(
                            color: context.colors.muted,
                            fontSize: 11.5,
                            height: 1.8,
                          ),
                        ),
                      const SizedBox(height: 22),
                      Container(
                        key: const ValueKey('legal-important-notice'),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: (context.isDark
                              ? context.colors.accentSoft
                              : const Color(0xFFF5F7FC)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final paragraph in current.introduction)
                              Text(
                                paragraph.text,
                                style: TextStyle(
                                  color: context.colors.ink,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.85,
                                ),
                              ),
                          ],
                        ),
                      ),
                      for (final section in current.sections)
                        KeyedSubtree(
                          key: ValueKey('legal-section-${section.id}'),
                          child: Padding(
                            key: sectionKeys.putIfAbsent(
                              section.id,
                              GlobalKey.new,
                            ),
                            padding: const EdgeInsets.only(top: 30),
                            child: _LegalSectionView(section: section),
                          ),
                        ),
                      const SizedBox(
                        key: ValueKey('legal-document-end'),
                        height: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }
}

class _LegalSectionView extends StatelessWidget {
  const _LegalSectionView({required this.section});

  final LegalSection section;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        section.title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.6,
        ),
      ),
      const SizedBox(height: 14),
      for (var index = 0; index < section.blocks.length; index++)
        Padding(
          padding: EdgeInsets.only(
            bottom: index == section.blocks.length - 1 ? 0 : 12,
          ),
          child: switch (section.blocks[index]) {
            LegalParagraph(:final text, :final emphasized) => Text(
              text,
              style: TextStyle(
                color: context.colors.ink,
                fontSize: 14,
                height: 1.85,
                fontWeight: emphasized ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            LegalSubheading(:final text) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            final LegalTable table => _LegalTableView(
              key: ValueKey('legal-${section.id}-table'),
              table: table,
            ),
          },
        ),
    ],
  );
}

class _LegalTableView extends StatelessWidget {
  const _LegalTableView({super.key, required this.table});

  final LegalTable table;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(14) > 17.5;
      final wide = constraints.maxWidth >= 560 && !largeText;
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          border: Border.all(color: context.colors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: wide ? wideTable(context) : narrowTable(context),
      );
    },
  );

  Widget wideTable(BuildContext context) => Table(
    defaultVerticalAlignment: TableCellVerticalAlignment.top,
    columnWidths: {0: const FlexColumnWidth(.9)},
    border: TableBorder(
      horizontalInside: BorderSide(color: context.colors.border),
      verticalInside: BorderSide(color: context.colors.border),
    ),
    children: [
      TableRow(
        decoration: BoxDecoration(color: context.colors.canvas),
        children: [
          for (final header in table.headers)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                header,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.7,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      for (final row in table.rows)
        TableRow(
          children: [
            for (final value in row)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 13, height: 1.8),
                ),
              ),
          ],
        ),
    ],
  );

  /// On phones each original table row becomes a vertical definition list, so
  /// long provider names and pending disclosures remain readable without zoom.
  Widget narrowTable(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var rowIndex = 0; rowIndex < table.rows.length; rowIndex++) ...[
        if (rowIndex > 0) const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                table.headers.first,
                style: TextStyle(
                  color: context.colors.muted,
                  fontSize: 11.5,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                table.rows[rowIndex].first,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.7,
                ),
              ),
              for (
                var columnIndex = 1;
                columnIndex < table.headers.length;
                columnIndex++
              ) ...[
                const SizedBox(height: 10),
                Text(
                  table.headers[columnIndex],
                  style: TextStyle(
                    color: context.colors.muted,
                    fontSize: 11.5,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  table.rows[rowIndex][columnIndex],
                  style: const TextStyle(fontSize: 13, height: 1.8),
                ),
              ],
            ],
          ),
        ),
      ],
    ],
  );
}
