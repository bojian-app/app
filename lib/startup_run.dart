import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// The longest the finished startup waits for the resume to change hands, so
/// stalled artwork or a paused ticker can never keep anyone out of the app.
const startupHandoverLimit = Duration(seconds: 4);

/// Real startup progress, shared by the session gate and its animation.
class StartupLoading extends ChangeNotifier {
  int completedSteps = 0;
  bool loaded = false;
  final _delivered = Completer<void>();

  /// Completes once the animation has handed the resume over.
  Future<void> get delivered => _delivered.future;

  Future<void> track(Future<void> step) => step.then((_) {
    completedSteps++;
  });

  void finish() {
    loaded = true;
    notifyListeners();
  }

  void deliver() {
    if (!_delivered.isCompleted) _delivered.complete();
  }
}

/// The man only takes the resume in [delivered].
enum StartupStage { running, offering, reaching, delivered }

/// How far the runner has got. Distances are in the office artwork's pixels.
///
/// Until startup has loaded there is no office to reach: she runs down an
/// endless street, quickly at first and slower the longer loading takes, with a
/// fresh burst whenever a step completes. Once loaded the office scrolls in and
/// she sprints to it.
class StartupRun {
  StartupRun();

  /// The still picture for reduced motion: at the desk, resume still in hand.
  StartupRun.arrived() : officeX = officeRestX, _handover = 0;

  static const sprintSpeed = 1900.0, jogSpeed = 750.0;

  /// Left edge of the office on screen: just out of view, then at rest.
  static const officeStartX = 1590.0, officeRestX = -104.0;

  /// Even an instant load shows this much of the street, in seconds.
  static const minimumRun = .35;

  static const _tiring = 1.1;
  static const _braking = 6000.0, _arrivalSpeed = 450.0;
  static const _offering = .2, _reaching = .25, _resting = .4;

  double _time = 0, _burstAt = 0;
  int _steps = 0;
  double? _handover;

  double distance = 0;
  double speed = sprintSpeed;
  double? officeX;

  StartupStage get stage {
    final time = _handover;
    if (time == null) return StartupStage.running;
    if (time < _offering) return StartupStage.offering;
    if (time < _offering + _reaching) return StartupStage.reaching;
    return StartupStage.delivered;
  }

  /// Seconds since she stopped at the desk.
  double get arrivedFor => _handover ?? 0;

  /// Seconds since the man took the resume; negative before that.
  double get deliveredFor => arrivedFor - _offering - _reaching;

  bool get finished => deliveredFor >= _resting;

  void advance(
    double seconds, {
    required bool loaded,
    required int completedSteps,
  }) {
    _time += seconds;
    final handover = _handover;
    if (handover != null) {
      _handover = handover + seconds;
      return;
    }
    if (completedSteps > _steps) {
      _steps = completedSteps;
      _burstAt = _time;
    }
    if (officeX == null && loaded && _time >= minimumRun) {
      officeX = officeStartX;
    }
    final office = officeX;
    final target = office != null
        ? sprintSpeed
        : jogSpeed +
              (sprintSpeed - jogSpeed) * math.exp((_burstAt - _time) / _tiring);
    speed += (target - speed) * (1 - math.exp(-seconds * 8));
    if (office == null) {
      distance += speed * seconds;
      return;
    }
    final remaining = office - officeRestX;
    speed = math.min(
      speed,
      math.max(_arrivalSpeed, math.sqrt(2 * _braking * remaining)),
    );
    final step = math.min(speed * seconds, remaining);
    distance += step;
    officeX = office - step;
    if (step >= remaining) {
      officeX = officeRestX;
      _handover = 0;
    }
  }
}
