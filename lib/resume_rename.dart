import 'package:flutter/material.dart';

import 'app_store.dart';
import 'api/bojian_api.dart';
import 'app_icons.dart';
import 'design.dart';

class ResumeInlineName extends StatefulWidget {
  const ResumeInlineName({
    super.key,
    required this.store,
    required this.resume,
  });
  final AppStore store;
  final ResumeDraft resume;
  @override
  State<ResumeInlineName> createState() => _ResumeInlineNameState();
}

class _ResumeInlineNameState extends State<ResumeInlineName> {
  late final controller = TextEditingController(text: widget.resume.title);
  late String title = widget.resume.title;
  final nameFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    nameFocus.addListener(() {
      if (!nameFocus.hasFocus && editing && !saving) cancel();
    });
  }

  bool editing = false;
  bool saving = false;
  String? error;
  static const titleStyle = TextStyle(
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: ink,
  );

  @override
  void didUpdateWidget(ResumeInlineName oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resume.title != widget.resume.title) {
      title = widget.resume.title;
    }
  }

  @override
  void dispose() {
    nameFocus.dispose();
    controller.dispose();
    super.dispose();
  }

  void cancel() => setState(() {
    editing = false;
    error = null;
  });

  Future<void> save() async {
    if (saving) return;
    final name = controller.text.trim();
    if (name.isEmpty || name.runes.length > 160) {
      setState(() => error = '请输入 1–160 个字的简历名称');
      return;
    }
    if (name == title) {
      cancel();
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.store.renameResume(widget.resume.id, name);
      if (mounted) {
        setState(() {
          title = name;
          editing = false;
          saving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = e is ApiFailure ? e.message : '改名失败，请重试';
        });
      }
    }
  }

  Widget action(String label, AppIconData icon, VoidCallback? onPressed) =>
      IconButton(
        tooltip: label,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          minimumSize: const Size(32, 36),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          overlayColor: Colors.transparent,
        ),
        icon: AppIcon(icon, size: 17, color: label == '保存名称' ? blue : muted),
      );

  @override
  Widget build(BuildContext context) {
    if (!editing) {
      return InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => setState(() {
          controller.text = title;
          controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: title.length,
          );
          editing = true;
        }),
        child: Tooltip(
          message: '简历改名',
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                ),
                const SizedBox(width: 5),
                const AppIcon(AppIcons.edit, size: 13, color: muted),
              ],
            ),
          ),
        ),
      );
    }
    // Consume taps around the controls so the card's preview does not open.
    // Keep the default editable tap group shared with selection handles/menus.
    return TextFieldTapRegion(
      child: GestureDetector(
        onTap: () {},
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('resume-rename-input'),
                    controller: controller,
                    focusNode: nameFocus,
                    onTapOutside: (_) => nameFocus.unfocus(),
                    autofocus: true,
                    readOnly: saving,
                    style: titleStyle,
                    maxLength: 160,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => save(),
                    decoration: const InputDecoration(
                      hintText: '简历名称',
                      counterText: '',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 7),
                      filled: false,
                      border: UnderlineInputBorder(),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFDCE5F6)),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: blue),
                      ),
                    ),
                  ),
                ),
                if (saving)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else ...[
                  action('取消改名', AppIcons.close, cancel),
                  action('保存名称', AppIcons.confirm, save),
                ],
              ],
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Text(
                  error!,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
