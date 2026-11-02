import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// ReorderableList captures the item's size when pickup starts. Wait for the
/// compact layout first, so the proxy, insertion gap and auto-scroll all use
/// the compact height rather than the original multi-page description.
class ResumeModuleDragListener extends ReorderableDragStartListener {
  const ResumeModuleDragListener({
    super.key,
    required super.index,
    required super.child,
    super.enabled,
    required this.prepare,
    required this.onMove,
    required this.onCancel,
  });

  final Future<Offset?> Function() prepare;
  final VoidCallback onMove, onCancel;

  @override
  MultiDragGestureRecognizer createRecognizer() => _CompactDragRecognizer(
    prepare: prepare,
    onMove: onMove,
    onCancel: onCancel,
  );
}

class _CompactDragRecognizer extends DelayedMultiDragGestureRecognizer {
  _CompactDragRecognizer({
    required this.prepare,
    required this.onMove,
    required this.onCancel,
  });
  final Future<Offset?> Function() prepare;
  final VoidCallback onMove, onCancel;

  @override
  set onStart(GestureMultiDragStartCallback? start) {
    super.onStart = start == null
        ? null
        : (position) =>
              _CompactDrag(position, start, prepare, onMove, onCancel);
  }
}

class _CompactDrag extends Drag {
  _CompactDrag(
    this.origin,
    GestureMultiDragStartCallback start,
    Future<Offset?> Function() prepare,
    this.onMove,
    this.onCancel,
  ) {
    _start(start, prepare);
  }

  final Offset origin;
  final VoidCallback onMove, onCancel;
  final List<DragUpdateDetails> _pending = [];
  Drag? _delegate;
  bool _finished = false;
  double _movement = 0;

  Future<void> _start(
    GestureMultiDragStartCallback start,
    Future<Offset?> Function() prepare,
  ) async {
    final anchor = await prepare();
    if (_finished) return;
    if (anchor == null) {
      cancel();
      return;
    }
    _delegate = start(anchor);
    // Keep the small feedback card under the finger after other cards shrink.
    _delegate?.update(
      DragUpdateDetails(delta: origin - anchor, globalPosition: origin),
    );
    for (final update in _pending) {
      _delegate?.update(update);
    }
    _pending.clear();
  }

  @override
  void update(DragUpdateDetails details) {
    if (_finished) return;
    _movement += details.delta.dy;
    if (_movement.abs() >= 6) onMove();
    if (_delegate == null) {
      _pending.add(details);
    } else {
      _delegate!.update(details);
    }
  }

  @override
  void end(DragEndDetails details) {
    if (_finished) return;
    _finished = true;
    if (_delegate == null) {
      onCancel();
    } else {
      _delegate!.end(details);
    }
  }

  @override
  void cancel() {
    if (_finished) return;
    _finished = true;
    _delegate?.cancel();
    onCancel();
  }
}

/// Restore the expanded layout only after the compact drop animation finishes.
class ResumeModuleDragProxy extends StatefulWidget {
  const ResumeModuleDragProxy({
    super.key,
    required this.onFinished,
    required this.child,
  });
  final VoidCallback onFinished;
  final Widget child;

  @override
  State<ResumeModuleDragProxy> createState() => _ResumeModuleDragProxyState();
}

class _ResumeModuleDragProxyState extends State<ResumeModuleDragProxy> {
  @override
  void dispose() {
    // The list disposes its animation before notifying later status listeners.
    // Removing the overlay is the reliable signal that its gap is gone too.
    final onFinished = widget.onFinished;
    WidgetsBinding.instance.addPostFrameCallback((_) => onFinished());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    elevation: 4,
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(12),
    child: widget.child,
  );
}
