import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'design.dart';

/// Search box with a leading search icon and a clear button once non-empty.
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    this.fieldKey,
    this.controller,
    required this.hintText,
    required this.onChanged,
    this.fillColor,
    this.autofocus = false,
    this.clearable = true,
    this.contentPadding,
    this.plainIcons = false,
  });

  final Key? fieldKey;
  final TextEditingController? controller;
  final String hintText;

  /// Receives the trimmed query, including '' after clearing.
  final ValueChanged<String> onChanged;
  final Color? fillColor;
  final bool autofocus;

  /// Shows a clear button once the field has text.
  final bool clearable;
  final EdgeInsets? contentPadding;

  /// Uses theme-default icons without padding or muted colour, and keeps the
  /// keyboard open after clearing.
  final bool plainIcons;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  TextEditingController? _own;
  TextEditingController get _controller =>
      widget.controller ?? (_own ??= TextEditingController());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: _controller,
    builder: (context, value, _) => TextField(
      key: widget.fieldKey,
      controller: _controller,
      autofocus: widget.autofocus,
      onChanged: (value) => widget.onChanged(value.trim()),
      onSubmitted: (_) => dismissKeyboard(),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hintText,
        fillColor: widget.fillColor,
        contentPadding: widget.contentPadding,
        prefixIcon: widget.plainIcons
            ? const AppIcon(AppIcons.search)
            : Padding(
                padding: const EdgeInsets.all(14),
                child: AppIcon(
                  AppIcons.search,
                  size: 20,
                  color: context.colors.muted,
                ),
              ),
        suffixIcon: !widget.clearable || value.text.isEmpty
            ? null
            : IconButton(
                tooltip: '清空搜索',
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                  if (!widget.plainIcons) dismissKeyboard();
                },
                icon: AppIcon(
                  AppIcons.clear,
                  size: 18,
                  color: widget.plainIcons ? null : context.colors.muted,
                ),
              ),
      ),
    ),
  );
}
