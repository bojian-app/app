import 'dart:async';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

import 'api/bojian_api.dart';
import 'app_store.dart';
import 'identity_verification_service.dart';
import 'identity_face_sdk.dart';

enum VerificationPhotoSide { portrait, emblem }

typedef VerificationPhotoPicker = Future<XFile?> Function();

class DeveloperVerificationController extends ChangeNotifier {
  DeveloperVerificationController({
    required this.store,
    required this.pickPhoto,
    IdentityVerificationService? service,
    IdentityFaceSdk? sdk,
  }) : _sdk = sdk ?? IdentityFaceSdk(),
       _service = service ?? IdentityVerificationService(store),
       _epoch = store.epoch {
    store.addListener(_accountChanged);
  }

  final AppStore store;
  final VerificationPhotoPicker pickPhoto;
  final IdentityVerificationService _service;
  final IdentityFaceSdk _sdk;
  final int _epoch;
  ui.Image? _portrait, _emblem;
  RecognizedIdentity? _identity;
  IdentityFaceSession? _faceSession;
  String? _progress;
  bool _agreed = false, _busy = false, _disposed = false;
  String? _error;

  ui.Image? photo(VerificationPhotoSide side) =>
      side == VerificationPhotoSide.portrait ? _portrait : _emblem;
  bool get agreed => _agreed;
  bool get busy => _busy;
  String? get error => _error;
  String? get progress => _progress;
  RecognizedIdentity? get identity => _identity;
  IdentityFaceSession? get faceSession => _faceSession;
  bool get sessionCurrent =>
      !_disposed && store.isAuthenticated && store.epoch == _epoch;
  bool get canContinue =>
      sessionCurrent &&
      !_busy &&
      _agreed &&
      _portrait != null &&
      _emblem != null;

  void setAgreed(bool value) {
    if (_busy || !sessionCurrent) return;
    _agreed = value;
    if (!value) {
      _identity = null;
      _faceSession = null;
    }
    notifyListeners();
  }

  Future<void> selectPhoto(VerificationPhotoSide side) async {
    if (_busy || !sessionCurrent) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final file = await pickPhoto();
      if (file == null || !sessionCurrent) return;
      final length = await file.length();
      if (!sessionCurrent) return;
      if (length <= 0 || length > 8 * 1024 * 1024) {
        _error = '请选择不超过 8 MB 的有效照片';
        return;
      }
      final bytes = await file.readAsBytes();
      if (!sessionCurrent) return;
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 960,
        allowUpscaling: false,
      );
      late final ui.Image image;
      try {
        final frame = await codec.getNextFrame();
        image = frame.image;
      } finally {
        codec.dispose();
      }
      if (!sessionCurrent) {
        image.dispose();
        return;
      }
      if (side == VerificationPhotoSide.portrait) {
        _portrait?.dispose();
        _portrait = image;
      } else {
        _emblem?.dispose();
        _emblem = image;
      }
      _identity = null;
      _faceSession = null;
    } catch (error) {
      if (sessionCurrent) {
        _error = error is ApiFailure
            ? error.message
            : '无法读取照片，请重新选择 JPG、PNG 或 WebP 图片';
      }
    } finally {
      if (!_disposed) {
        _busy = false;
        notifyListeners();
      }
    }
  }

  void _accountChanged() {
    if (sessionCurrent) return;
    unawaited(_sdk.cancel());
    _clearPhotos();
    _agreed = false;
    _error = null;
    _identity = null;
    _faceSession = null;
    _progress = null;
    notifyListeners();
  }

  Future<bool> recognize() async {
    if (!canContinue) return false;
    _busy = true;
    _error = null;
    _progress = '正在识别身份证信息…';
    notifyListeners();
    ui.Image? front, back;
    try {
      await _service.checkAvailable();
      if (!sessionCurrent) return false;
      await _sdk.checkAvailable();
      if (!sessionCurrent) return false;
      front = _portrait!.clone();
      back = _emblem!.clone();
      final frontData = await front.toByteData(format: ui.ImageByteFormat.png);
      final backData = await back.toByteData(format: ui.ImageByteFormat.png);
      if (!sessionCurrent) return false;
      if (frontData == null || backData == null) {
        throw const ApiFailure('无法处理证件照片，请重新选择');
      }
      final recognized = await _service.recognize(
        frontData.buffer.asUint8List(
          frontData.offsetInBytes,
          frontData.lengthInBytes,
        ),
        backData.buffer.asUint8List(
          backData.offsetInBytes,
          backData.lengthInBytes,
        ),
      );
      if (!sessionCurrent) return false;
      _identity = recognized;
      _faceSession = null;
      return true;
    } catch (error) {
      if (sessionCurrent) {
        _error = error is ApiFailure ? error.message : '证件识别失败，请稍后重试';
      }
      return false;
    } finally {
      front?.dispose();
      back?.dispose();
      if (!_disposed) {
        _busy = false;
        _progress = null;
        notifyListeners();
      }
    }
  }

  Future<bool> startFace() async {
    final identity = _identity;
    if (_busy || !sessionCurrent || !_agreed || identity == null) return false;
    _busy = true;
    _error = null;
    _progress = '正在创建人脸核验…';
    notifyListeners();
    try {
      final session = await _service.start(identity);
      if (!sessionCurrent) return false;
      _faceSession = session;
      return true;
    } catch (error) {
      if (sessionCurrent) {
        _error = error is ApiFailure ? error.message : '无法发起人脸核验，请稍后重试';
      }
      return false;
    } finally {
      if (!_disposed) {
        _busy = false;
        _progress = null;
        notifyListeners();
      }
    }
  }

  Future<void> runFace({required int accentColor, required bool dark}) async {
    final session = _faceSession;
    if (_busy ||
        !sessionCurrent ||
        !_agreed ||
        session == null ||
        session.status != IdentityFaceStatus.pending) {
      return;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    var completed = false;
    try {
      completed = await _sdk.verify(
        session,
        accentColor: accentColor,
        dark: dark,
      );
      if (sessionCurrent && !completed) _error = '已取消人脸核验，可重新开始';
    } catch (error) {
      if (sessionCurrent) {
        _error = error is ApiFailure ? error.message : '人脸核验未完成，请重试';
      }
    } finally {
      if (!_disposed) {
        _busy = false;
        notifyListeners();
      }
    }
    if (completed && sessionCurrent) await refreshFace();
  }

  void cancelFace() => unawaited(_sdk.cancel());

  Future<void> refreshFace() async {
    final session = _faceSession;
    if (_busy ||
        !sessionCurrent ||
        session == null ||
        session.status != IdentityFaceStatus.pending) {
      return;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final updated = await _service.refresh(session);
      if (sessionCurrent) {
        _faceSession = updated;
        if (updated.status == IdentityFaceStatus.verified) {
          store.recordIdentityVerificationSuccess(
            verificationID: updated.verificationID!,
            expectedEpoch: _epoch,
          );
        }
      }
    } catch (error) {
      if (sessionCurrent) {
        _error = error is ApiFailure ? error.message : '无法获取核验结果，请稍后重试';
      }
    } finally {
      if (!_disposed) {
        _busy = false;
        notifyListeners();
      }
    }
  }

  void _clearPhotos() {
    _portrait?.dispose();
    _emblem?.dispose();
    _portrait = null;
    _emblem = null;
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sdk.cancel());
    store.removeListener(_accountChanged);
    _clearPhotos();
    _identity = null;
    _faceSession = null;
    super.dispose();
  }
}
