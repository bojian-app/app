import 'dart:convert';

import 'package:flutter/material.dart';

import 'api/bojian_api.dart';
import 'app_theme.dart';

typedef AppearanceChoice = ({AppAccent accent, ThemeMode mode});

/// Local to this installation, including when switching accounts.
class AppAppearance extends ValueNotifier<AppearanceChoice> {
  AppAppearance(this._storage) : super(_defaults);

  static const _defaults = (accent: AppAccent.blue, mode: ThemeMode.system);

  static const _key = 'bojian.appearance';
  final SessionStorage _storage;
  Future<void>? _initialization;
  Future<void> _writes = Future.value();
  AppearanceChoice _saved = _defaults;
  int _revision = 0;
  bool _disposed = false;

  Future<void> restore() => _initialization ??= _restore();

  Future<void> _restore() async {
    try {
      final raw = await _storage.read(_key);
      if (_disposed || raw == null) return;
      final data = jsonDecode(raw);
      if (data is! Map) return;
      _saved = (
        accent: AppAccent.values.asNameMap()[data['accent']] ?? AppAccent.blue,
        mode: ThemeMode.values.asNameMap()[data['mode']] ?? ThemeMode.system,
      );
      value = _saved;
    } catch (_) {
      // Appearance is optional. An unreadable preference must not block sign-in.
    }
  }

  Future<void> update({AppAccent? accent, ThemeMode? mode}) async {
    await restore();
    if (_disposed) return;
    final next = (accent: accent ?? value.accent, mode: mode ?? value.mode);
    if (next == value) return _writes;
    final revision = ++_revision;
    final write = _writes.catchError((_) {}).then((_) async {
      try {
        await _storage.write(
          _key,
          jsonEncode({'accent': next.accent.name, 'mode': next.mode.name}),
        );
        _saved = next;
      } catch (_) {
        if (!_disposed && revision == _revision) value = _saved;
        rethrow;
      }
    });
    _writes = write;
    value = next;
    await write;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

extension AppearanceModeLabel on ThemeMode {
  String get label => switch (this) {
    ThemeMode.system => '跟随系统',
    ThemeMode.light => '浅色',
    ThemeMode.dark => '深色',
  };
}
