import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/template_preview_cache.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeGateway api;
  late AppStore store;
  setUp(() async {
    api = FakeGateway();
    store = AppStore(api: api, storage: MemoryStorage());
    await store.initialize();
    store.session = {'access_token': 'test'};
    api.documents['GetTemplatesIdDom'] = {
      'template_id': 4,
      'version': 1,
      'html': '<h1>{{name}}</h1>',
      'css': '',
    };
  });
  tearDown(() => store.dispose());

  test(
    'Repeated views share DOM; explicit refresh and new versions fetch again',
    () async {
      await Future.wait([
        loadTemplatePreviewDOM(store, 4, 1),
        loadTemplatePreviewDOM(store, 4, 1),
      ]);
      await loadTemplatePreviewDOM(store, 4, 1);
      expect(api.calls.where((c) => c == 'GetTemplatesIdDom'), hasLength(1));
      await loadTemplatePreviewDOM(store, 4, 1, refresh: true);
      api.documents['GetTemplatesIdDom']!['version'] = 2;
      await loadTemplatePreviewDOM(store, 4, 2);
      expect(api.calls.where((c) => c == 'GetTemplatesIdDom'), hasLength(3));
    },
  );

  test('Account changes and failed requests never reuse another session or failure', () async {
    await loadTemplatePreviewDOM(store, 4, 1);
    store.epoch++;
    api.failing = 'GetTemplatesIdDom';
    await expectLater(loadTemplatePreviewDOM(store, 4, 1), throwsA(anything));
    api.failing = null;
    api.documents['GetTemplatesIdDom']!['html'] = '<p>new session</p>';
    final result = await loadTemplatePreviewDOM(store, 4, 1);
    expect(result.data['html'], '<p>new session</p>');
    expect(api.calls.where((c) => c == 'GetTemplatesIdDom'), hasLength(3));
  });
}
