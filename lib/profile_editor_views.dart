import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_icons.dart';
import 'design.dart';

class ProfileAvatarEditorView extends StatelessWidget {
  const ProfileAvatarEditorView({
    super.key,
    required this.preview,
    required this.saving,
    required this.choosing,
    required this.hasChanges,
    required this.onGallery,
    required this.onSystemAvatar,
    required this.onSave,
  });

  final Widget Function(double size) preview;
  final bool saving, choosing, hasChanges;
  final VoidCallback onGallery, onSystemAvatar, onSave;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
    child: Scaffold(
      key: const ValueKey('profile-avatar-editor'),
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (hasChanges || saving)
            _ProfileSaveAction(
              saving: saving,
              onSave: saving || choosing ? null : onSave,
              inverted: true,
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: preview(
              math.min(constraints.maxWidth, constraints.maxHeight),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '更改头像',
                style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 13),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  Widget choice(
                    String label,
                    String key,
                    AppIconData icon,
                    VoidCallback action,
                  ) => FilledButton.icon(
                    key: ValueKey(key),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF303030),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF202020),
                      disabledForegroundColor: const Color(0xFF999999),
                      minimumSize: const Size.fromHeight(50),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
                    ).withoutHover(),
                    onPressed: saving || choosing ? null : action,
                    icon: AppIcon(icon, size: 22),
                    label: Text(label),
                  );
                  final gallery = choice(
                    '相册',
                    'profile-avatar-gallery',
                    AppIcons.imageCache,
                    onGallery,
                  );
                  final system = choice(
                    '系统头像',
                    'profile-avatar-system',
                    AppIcons.profile,
                    onSystemAvatar,
                  );
                  if (constraints.maxWidth <
                      240 + MediaQuery.textScalerOf(context).scale(70)) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [gallery, const SizedBox(height: 10), system],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: gallery),
                      const SizedBox(width: 12),
                      Expanded(child: system),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class ProfileBiographyEditorView extends StatelessWidget {
  const ProfileBiographyEditorView({
    super.key,
    required this.controller,
    required this.saving,
    required this.onSave,
  });

  final TextEditingController controller;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('profile-biography-editor'),
    backgroundColor: context.colors.surface,
    appBar: AppBar(
      backgroundColor: context.colors.surface,
      title: const Text('个人简介', maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        _ProfileSaveAction(saving: saving, onSave: saving ? null : onSave),
      ],
    ),
    body: SafeArea(
      top: false,
      child: TextField(
        key: const ValueKey('profile-bio'),
        controller: controller,
        enabled: !saving,
        expands: true,
        minLines: null,
        maxLines: null,
        maxLength: 120,
        textAlignVertical: TextAlignVertical.top,
        textInputAction: TextInputAction.newline,
        keyboardType: TextInputType.multiline,
        style: TextStyle(fontSize: 16, height: 1.7, color: context.colors.ink),
        decoration: const InputDecoration(
          hintText: '介绍一下自己',
          filled: false,
          contentPadding: EdgeInsets.fromLTRB(20, 16, 20, 24),
          counterText: '',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
        ),
      ),
    ),
  );
}

class _ProfileSaveAction extends StatelessWidget {
  const _ProfileSaveAction({
    required this.saving,
    required this.onSave,
    this.inverted = false,
  });

  final bool saving, inverted;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 16),
    child: Center(
      child: FilledButton(
        key: const ValueKey('profile-save'),
        style: FilledButton.styleFrom(
          foregroundColor: inverted ? Colors.black : context.colors.accent,
          backgroundColor: inverted ? Colors.white : context.colors.accentSoft,
          disabledBackgroundColor: inverted
              ? const Color(0xFF303030)
              : context.colors.inset,
          minimumSize: const Size(56, 34),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ).withoutHover(),
        onPressed: onSave,
        child: saving
            ? Semantics(
                label: '正在保存…',
                child: const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : const Text('保存'),
      ),
    ),
  );
}
