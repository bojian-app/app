import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_store.dart';

/// The home page's search. It asks the server for the dynamics matching a term
/// and pages through them, apart from the feed's own list.
class FeedSearch extends ChangeNotifier {
  FeedSearch(this.store) : _account = store.epoch {
    store.addListener(_accountChanged);
    _events = store.realtimeEvents.listen(_event);
  }

  /// How long typing has to pause before the term is sent.
  static const pause = Duration(milliseconds: 350);

  final AppStore store;
  String term = '';

  /// The term [results] and [failed] answer. It trails [term] while the reader
  /// types and while the answer is on its way.
  String answered = '';
  List<Story> results = [];
  String cursor = '';
  bool loading = false, loadingMore = false, failed = false;

  int _account, _generation = 0;
  Timer? _timer;
  late final StreamSubscription<Map<String, dynamic>> _events;

  bool get waiting => answered != term;

  bool get canLoadMore =>
      !waiting && !loading && !loadingMore && !failed && cursor.isNotEmpty;

  void change(String value) {
    final next = value.trim();
    if (next == term) return;
    term = next;
    _drop();
    if (term.isEmpty) {
      answered = '';
      results = [];
      cursor = '';
    } else {
      _timer = Timer(pause, () => unawaited(load()));
    }
    notifyListeners();
  }

  /// Forgets the waiting request and whatever is still on its way.
  void _drop() {
    _timer?.cancel();
    _generation++;
    loading = loadingMore = failed = false;
  }

  /// Sends the term now: its first page, or the one after what is listed.
  Future<void> load({bool more = false}) async {
    if (term.isEmpty || more && !canLoadMore) return;
    _timer?.cancel();
    final request = ++_generation;
    final wanted = term, account = store.epoch;
    loading = !more;
    loadingMore = more;
    failed = false;
    notifyListeners();
    try {
      final response = await store.request(
        'GetFeed',
        query: {'query': wanted, 'limit': '20', if (more) 'cursor': cursor},
        expectedEpoch: account,
      );
      if (request != _generation) return;
      final seen = {if (more) ...results.map((story) => story.id)};
      results = [
        if (more) ...results,
        ...items(response.data)
            .map(decodeStory)
            .where((story) => seen.add(story.id)),
      ];
      cursor = response.nextCursor;
      answered = wanted;
    } catch (_) {
      if (request != _generation) return;
      // Another term's results would pass for this one's.
      if (answered != wanted) {
        results = [];
        cursor = '';
      }
      answered = wanted;
      failed = true;
    }
    loading = loadingMore = false;
    notifyListeners();
  }

  /// Repeats whichever request failed.
  Future<void> retry() {
    final more = results.isNotEmpty && cursor.isNotEmpty;
    failed = false;
    return load(more: more);
  }

  void _accountChanged() {
    if (_account == store.epoch) return;
    _account = store.epoch;
    _drop();
    term = answered = cursor = '';
    results = [];
    notifyListeners();
  }

  /// A post taken down leaves the results as it leaves the feed.
  void _event(Map<String, dynamic> event) {
    final data = event['data'] is Map ? event['data'] as Map : const {};
    final removed =
        event['type'] == 'content.removed' &&
        const {'ARTICLE', 'POST'}.contains(data['subject_type']);
    final withdrawn =
        event['type'] == 'article.updated' &&
        data['status'] != null &&
        data['status'] != 'PUBLISHED';
    if (!removed && !withdrawn) return;
    final id = integer(data['article_id']);
    if (!results.any((story) => story.id == id)) return;
    results = [...results.where((story) => story.id != id)];
    notifyListeners();
  }

  @override
  void dispose() {
    _drop();
    store.removeListener(_accountChanged);
    unawaited(_events.cancel());
    super.dispose();
  }
}
