import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/feed_search.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

/// Holds each search open until the test answers it.
class SearchGateway extends FakeGateway {
  final asked = <Map<String, String>>[];
  final answers = <Completer<ApiDocument>>[];

  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) {
    if (method != 'GetFeed' || query['query'] == null) {
      return super.call(
        method,
        path: path,
        query: query,
        body: body,
        headers: headers,
      );
    }
    asked.add(Map.of(query));
    answers.add(Completer());
    return answers.last.future;
  }

  void answer(int index, List<int> ids, {String next = ''}) {
    answers[index].complete(
      ApiDocument({
        'items': [
          for (final id in ids) {'id': id, 'title': '动态 $id'},
        ],
      }, nextCursor: next),
    );
  }
}

void main() {
  Future<(SearchGateway, FeedSearch)> start(WidgetTester tester) async {
    final api = SearchGateway();
    final store = await testStore(authenticated: true, api: api);
    final search = FeedSearch(store);
    addTearDown(() {
      search.dispose();
      store.dispose();
    });
    return (api, search);
  }

  testWidgets('Only the term typing settled on is sent', (tester) async {
    final (api, search) = await start(tester);
    search.change('跨');
    await tester.pump(const Duration(milliseconds: 200));
    search.change(' 跨境 ');
    await tester.pump(const Duration(milliseconds: 200));
    expect(api.asked, isEmpty);
    expect(search.waiting, isTrue);
    await tester.pump(FeedSearch.pause);
    expect(api.asked, [
      {'query': '跨境', 'limit': '20'},
    ]);
    api.answer(0, [1, 2]);
    await tester.pump();
    expect(search.waiting, isFalse);
    expect(search.results.map((s) => s.id), [1, 2]);
    search.change('');
    expect(search.results, isEmpty);
    expect(api.asked, hasLength(1));
  });

  testWidgets('A late answer for an older term is ignored', (tester) async {
    final (api, search) = await start(tester);
    search.change('旧');
    await tester.pump(FeedSearch.pause);
    search.change('新');
    await tester.pump(FeedSearch.pause);
    api.answer(1, [2]);
    await tester.pump();
    api.answer(0, [1]);
    await tester.pump();
    expect(search.results.map((s) => s.id), [2]);
    expect(search.loading, isFalse);
  });

  testWidgets('Pages follow the cursor, and a failed page can be retried', (
    tester,
  ) async {
    final (api, search) = await start(tester);
    search.change('简历');
    await tester.pump(FeedSearch.pause);
    api.answer(0, [1, 2], next: 'second');
    await tester.pump();
    expect(search.canLoadMore, isTrue);
    unawaited(search.load(more: true));
    await tester.pump();
    expect(api.asked.last['cursor'], 'second');
    api.answers[1].completeError(const ApiFailure('服务器暂不可用'));
    await tester.pump();
    expect(search.failed, isTrue);
    expect(search.canLoadMore, isFalse);
    expect(search.results, hasLength(2));
    unawaited(search.retry());
    await tester.pump();
    expect(api.asked.last['cursor'], 'second');
    api.answer(2, [2, 3]);
    await tester.pump();
    expect(search.results.map((s) => s.id), [1, 2, 3]);
    expect(search.canLoadMore, isFalse);
  });

  testWidgets('A failed new term shows nothing from the last one', (
    tester,
  ) async {
    final (api, search) = await start(tester);
    search.change('甲');
    await tester.pump(FeedSearch.pause);
    api.answer(0, [1]);
    await tester.pump();
    search.change('乙');
    await tester.pump(FeedSearch.pause);
    api.answers[1].completeError(const ApiFailure('服务器暂不可用'));
    await tester.pump();
    expect(search.failed, isTrue);
    expect(search.results, isEmpty);
    unawaited(search.retry());
    await tester.pump();
    expect(api.asked.last, {'query': '乙', 'limit': '20'});
    api.answer(2, [4]);
    await tester.pump();
    expect(search.results.map((s) => s.id), [4]);
  });

  testWidgets('A post taken down leaves the results', (tester) async {
    final (api, search) = await start(tester);
    search.change('动态');
    await tester.pump(FeedSearch.pause);
    api.answer(0, [5, 6]);
    await tester.pump();
    api.documents['PostArticlesIdUnpublish'] = {'id': 5, 'status': 'DRAFT'};
    await search.store.unpublishArticle(5);
    await tester.pump();
    expect(search.results.map((s) => s.id), [6]);
  });
}
