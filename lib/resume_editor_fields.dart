part of 'resume_pages.dart';

/// Shared form fields and option, month and date pickers.
extension _ResumeEditorFields on _ResumeEditorState {
  /// Borderless, underlined input style shared by every editor field.
  InputDecoration _underlineDecoration() => InputDecoration(
    filled: false,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(vertical: 8),
    border: UnderlineInputBorder(
      borderSide: BorderSide(color: context.colors.border),
    ),
    enabledBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: context.colors.border),
    ),
    focusedBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: context.colors.accent),
    ),
  );

  Widget _pair(Widget first, Widget second, {bool compact = false}) =>
      LayoutBuilder(
        builder: (context, constraints) =>
            constraints.maxWidth >=
                (compact
                    ? 280 * MediaQuery.textScalerOf(context).scale(14) / 14
                    : 500)
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: first),
                  const SizedBox(width: 16),
                  Expanded(child: second),
                ],
              )
            : Column(children: [first, second]),
      );

  Future<void> _pickOption(
    TextEditingController controller,
    ResumeOptionKind kind,
  ) async {
    if (saving || pickingPhoto) return;
    final session = _sectionSession;
    final value = await showResumeOptionPicker(
      context,
      store: widget.store,
      initialValue: controller.text,
      kind: kind,
    );
    if (!mounted || session != _sectionSession || value == null) return;
    _update(() => controller.text = value);
  }

  Widget _field(
    String key,
    String label, {
    int lines = 1,
    TextInputType? keyboard,
    String? hint,
    int? hintMaxLines,
    TextEditingController? controller,
    bool enabled = true,
    VoidCallback? onTap,
    AppIconData? pickerIcon,
    bool alignInput = false,
    Widget? labelAction,
    String? Function(String?)? validator,
  }) {
    final dateField =
        key == 'birth_date' || key.endsWith('-date') || key.endsWith('_date');
    final fieldController = controller ?? fields[key];
    final pick =
        onTap ?? (dateField ? () => _pickMonth(fieldController!, label) : null);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: ResumeEditorTypography.caption.copyWith(
                      color: context.colors.muted,
                    ),
                  ),
                ),
                if (labelAction != null) ...[
                  const SizedBox(width: 12),
                  labelAction,
                ],
              ],
            ),
          ),
          TextFormField(
            key: ValueKey('resume-$key'),
            validator: validator,
            controller: fieldController,
            enabled: enabled && !saving,
            readOnly: pick != null,
            textAlignVertical: alignInput ? TextAlignVertical.center : null,
            onTap: pick,
            minLines: lines,
            maxLines: lines == 1 ? 1 : null,
            keyboardType: keyboard,
            textInputAction: lines == 1
                ? TextInputAction.next
                : TextInputAction.newline,
            style: ResumeEditorTypography.body.copyWith(
              color: context.colors.ink,
            ),
            decoration: _underlineDecoration().copyWith(
              constraints: alignInput
                  ? const BoxConstraints(
                      minHeight: _ResumeEditorState._fieldActionExtent,
                    )
                  : null,
              hintMaxLines: hintMaxLines,
              hintText: dateField && enabled
                  ? (alignInput ? '选择日期' : '请选择$label')
                  : hint,
              suffixIcon: pick == null
                  ? (alignInput
                        ? const SizedBox(
                            width: 0,
                            height: _ResumeEditorState._fieldActionExtent,
                          )
                        : null)
                  : ValueListenableBuilder<TextEditingValue>(
                      valueListenable: fieldController!,
                      builder: (_, value, _) => value.text.isEmpty
                          ? _fieldTrailingIcon(pickerIcon ?? AppIcons.date)
                          : IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                width: _ResumeEditorState._fieldActionExtent,
                                height: _ResumeEditorState._fieldActionExtent,
                              ),
                              tooltip: '清除$label',
                              onPressed: saving || !enabled
                                  ? null
                                  : () {
                                      dismissKeyboard();
                                      fieldController.clear();
                                    },
                              icon: AppIcon(
                                AppIcons.close,
                                size: 18,
                                color: context.colors.muted,
                              ),
                            ),
                    ),
              suffixIconConstraints: BoxConstraints.tightFor(
                width: alignInput && pick == null
                    ? 0
                    : _ResumeEditorState._fieldActionExtent,
                height: _ResumeEditorState._fieldActionExtent,
              ),
              hintStyle: ResumeEditorTypography.body.copyWith(
                color: context.colors.muted,
              ),
              errorMaxLines: 3,
              errorStyle: ResumeEditorTypography.caption.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickMonth(
    TextEditingController controller,
    String label,
  ) async {
    if (saving) return;
    final session = _sectionSession;
    final now = DateTime.now();
    final parts = controller.text.split(RegExp(r'[-./]'));
    final year = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
    final month = parts.length > 1 ? int.tryParse(parts[1]) : null;
    final selected = await showDateWheelPicker(
      context,
      title: '选择$label',
      initialDate:
          year != null && (month == null || (month >= 1 && month <= 12))
          ? DateTime(year, month ?? 1)
          : DateTime(now.year, now.month),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 20, 12),
      monthOnly: true,
    );
    if (!mounted || session != _sectionSession) return;
    if (selected != null) {
      controller.text =
          '${selected.year}-${selected.month.toString().padLeft(2, '0')}';
    }
  }
}
