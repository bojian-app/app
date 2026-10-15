import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'design.dart';
import 'startup_scene.dart';

/// A single playful dolphin scene, with the destination preparing underneath.
class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key, required this.child});

  final Widget child;

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _timeline;
  late final CurvedAnimation _exitCurve;
  late final Animation<double> _coverOpacity;
  bool _started = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timeline = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2180),
    )..addStatusListener(_statusChanged);
    _exitCurve = CurvedAnimation(
      parent: _timeline,
      curve: const Interval(2000 / 2180, 1, curve: Curves.easeInOutCubic),
    );
    _coverOpacity = Tween<double>(begin: 1, end: 0).animate(_exitCurve);
  }

  void _statusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) _finish();
  }

  void _finish() {
    if (!mounted || _finished) return;
    _timeline.stop();
    setState(() => _finished = true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _timeline.stop();
      // Dependency changes already schedule a build; do not remount the child.
      _finished = true;
    }
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_finished) _timeline.forward();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _finish();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timeline.removeStatusListener(_statusChanged);
    _exitCurve.dispose();
    _timeline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      IgnorePointer(
        ignoring: !_finished,
        child: ExcludeSemantics(
          excluding: !_finished,
          child: ExcludeFocus(excluding: !_finished, child: widget.child),
        ),
      ),
      if (!_finished)
        FadeTransition(
          key: const ValueKey('startup'),
          opacity: _coverOpacity,
          child: AnimatedBuilder(
            animation: _timeline,
            builder: (context, _) {
              final progress = (_timeline.value * 2180 / 2000).clamp(0.0, 1.0);
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle.dark,
                child: Material(
                  color: canvasColor,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Semantics(
                        label: '博简，把繁杂，变简单。',
                        image: true,
                        child: RepaintBoundary(
                          child: CustomPaint(
                            key: const ValueKey('startup-dolphin-scene'),
                            painter: StartupScenePainter(
                              progress: progress,
                              textScaler: MediaQuery.textScalerOf(context),
                            ),
                          ),
                        ),
                      ),
                      SafeArea(
                        child: Align(
                          alignment: AlignmentDirectional.topEnd,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(
                              top: 12,
                              end: 16,
                            ),
                            child: CupertinoButton(
                              onPressed: _finish,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(48, 48),
                              child: const Text(
                                '跳过',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF697586),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
    ],
  );
}
