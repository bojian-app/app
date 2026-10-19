import 'dart:math';

import 'package:flutter/foundation.dart';

import 'api/bojian_api.dart';
import 'app_store.dart';

/// Owns submission state and preserves a key when retrying a lost response.
class ResumeCreationController extends ChangeNotifier {
  ResumeCreationController(this.store);
  final AppStore store;
  bool submitting = false;
  bool _disposed = false;
  String? _description, _requestKey;

  Future<int?> submit(String input) async {
    if (submitting) return null;
    final description = input.trim();
    if (description.runes.length < 10 || description.runes.length > 5000) {
      throw const ApiFailure('请填写10至5000字的经历描述');
    }
    if (!store.alive || !store.isAuthenticated) {
      throw const ApiFailure('请先登录后再发起协助');
    }
    if (_description != description || _requestKey == null) {
      _description = description;
      final random = Random.secure();
      _requestKey = List.generate(
        24,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
    }
    final epoch = store.epoch;
    submitting = true;
    notifyListeners();
    try {
      final response = await store.request(
        'PostResumeCreationJobs',
        expectedEpoch: epoch,
        body: {'description': description, 'request_key': _requestKey},
      );
      if (_disposed ||
          !store.alive ||
          epoch != store.epoch ||
          !store.isAuthenticated) {
        return null;
      }
      final id = integer(response.data['id']);
      if (id <= 0 ||
          !const {
            'QUEUED',
            'RUNNING',
            'SUCCEEDED',
            'FAILED',
          }.contains(response.data['status'])) {
        throw const ApiFailure('未能确认协助任务，请重试');
      }
      if (response.data['status'] == 'FAILED') {
        _requestKey = null;
        throw const ApiFailure('上次协助未完成，请重新发起');
      }
      return id;
    } catch (_) {
      if (_disposed ||
          !store.alive ||
          epoch != store.epoch ||
          !store.isAuthenticated) {
        return null;
      }
      rethrow;
    } finally {
      submitting = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
