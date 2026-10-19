import 'package:flutter/material.dart';

enum GuidanceGesture { tap, type, hold, read }

/// Custom gesture surfaces observe the same lock as ordinary scroll views.
class GuidanceScrollLock extends InheritedWidget {
  const GuidanceScrollLock({
    super.key,
    required this.locked,
    required super.child,
  });

  final bool locked;

  static bool isLocked(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<GuidanceScrollLock>()
          ?.locked ??
      false;

  @override
  bool updateShouldNotify(GuidanceScrollLock oldWidget) =>
      oldWidget.locked != locked;
}

/// Presentation events emitted by actual controls, after their action succeeds.
/// The guide observes these events; it never invokes a business operation.
class GuidanceFlowController extends ChangeNotifier {
  final _completed = <String>{};
  int? _account;

  void bindAccount(int account) {
    if (_account == account) return;
    final changed = _account != null;
    _account = account;
    if (changed && _completed.isNotEmpty) {
      _completed.clear();
      notifyListeners();
    }
  }

  bool contains(String event) => _completed.contains(event);

  void complete(String event) {
    if (_completed.add(event)) notifyListeners();
  }
}

class GuidanceStep {
  const GuidanceStep(
    this.target,
    this.title,
    this.description, {
    this.prefix = false,
    this.event,
    this.gesture = GuidanceGesture.tap,
    this.optional = false,
    this.acknowledgeLabel,
  });

  final String target, title, description;
  final String? event;
  final String? acknowledgeLabel;
  final bool prefix, optional;
  final GuidanceGesture gesture;
  String get id => event ?? target;

  bool matches(Widget widget) {
    final key = widget.key;
    return key is ValueKey<String> &&
        (prefix ? key.value.startsWith(target) : key.value == target);
  }
}
