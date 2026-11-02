import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/template_dom_storage.dart';
import 'package:bojian_mobile/template_market_store.dart';
import 'package:bojian_mobile/template_preview_cache.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'support/fake_gateway.dart';

class CachePaths extends PathProviderPlatform {
  CachePaths(this.path);
  final String path;
  @override
  Future<String?> getApplicationCachePath() async => path;
}

class AcquisitionGateway extends FakeGateway {
  Completer<ApiDocument>? download;
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (method == 'PostTemplatesIdAcquisitions' ||
        method == 'PostTemplateOrders') {
      calls.add(method);
      documents['GetMeTemplates'] = {
        'items': [
          {'id': 4, 'version': 1, 'source': 'ACQUIRED'},
        ],
      };
      return ApiDocument({
        'acquired': true,
        'status': 'PAID',
        'wallet': {'available_points': 10},
      });
    }
    if (method == 'GetTemplatesIdDom' && download != null) {
      calls.add(method);
      return download!.future;
    }
    return super.call(
      method,
      path: path,
      query: query,
      body: body,
      headers: headers,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late AcquisitionGateway api;
  late PathProviderPlatform originalPaths;
  final stores = <AppStore>[];
  Map<String, dynamic> dom(int version) => {
    'template_id': 4,
    'version': version,
    'html': '<h1>{{name}}</h1>',
    'css': 'body{color:green}',
    'schema': {'protocol_version': 2},
  };
  Future<AppStore> session([int userID = 12]) async {
    final store = AppStore(api: api, storage: MemoryStorage());
    await store.initialize();
    store.session = {'access_token': 'fixture'};
    store.userID = userID;
    stores.add(store);
    return store;
  }

  Future<List<File>> cachedFiles() async => directory
      .list(recursive: true)
      .where((item) => item is File && item.path.endsWith('.json'))
      .cast<File>()
      .toList();

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'bojian-template-cache-test-',
    );
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = CachePaths(directory.path);
    api = AcquisitionGateway();
    api.documents['GetTemplatesIdDom'] = dom(1);
    api.documents['GetTemplatesId'] = {
      'id': 4,
      'version': 1,
      'revision': 2,
      'status': 'PUBLISHED',
      'compatible': true,
      'pricing_type': 'FREE',
      'price_points': 0,
    };
    api.documents['GetMeTemplates'] = {'items': []};
  });
  tearDown(() async {
    for (final store in stores) {
      store.dispose();
    }
    stores.clear();
    PathProviderPlatform.instance = originalPaths;
    await directory.delete(recursive: true);
  });

  for (final paid in [false, true]) {
    test(
      '${paid ? 'Paid' : 'Free'} acquisition predownloads without delaying success',
      () async {
        final store = await session();
        final market = TemplateMarketStore(store);
        addTearDown(market.dispose);
        if (paid) {
          api.documents['GetTemplatesId']!.addAll({
            'pricing_type': 'PAID',
            'price_points': 20,
          });
        }
        api.download = Completer<ApiDocument>();
        await market.acquire(
          id: 4,
          quotedPrice: paid ? 20 : 0,
          quotedRevision: 2,
          idempotencyKey: 'fixture',
        );
        expect(market.ownedIDs, contains(4));
        final pending = loadTemplatePreviewDOM(store, 4, 1, persist: true);
        api.download!.complete(ApiDocument(dom(1)));
        await pending;
        expect(
          api.calls.where((call) => call == 'GetTemplatesIdDom'),
          hasLength(1),
        );
        expect(await cachedFiles(), hasLength(1));
        final reopened = await session();
        api.failing = 'GetResumesIdDomPreview';
        final result = await loadResumeTemplateDOM(reopened, 22, 4);
        expect(result.data['html'], dom(1)['html']);
        expect(
          api.calls.where((call) => call == 'GetTemplatesIdDom'),
          hasLength(1),
        );
        expect(api.calls, isNot(contains('GetResumesIdDomPreview')));
      },
    );
  }

  test('Switching a resume and previewing it reuse acquired assets', () async {
    final store = await session();
    await predownloadAcquiredTemplate(store, 4, 1);
    api.documents['GetMeTemplates'] = {
      'items': [
        {'id': 4, 'version': 1, 'source': 'ACQUIRED', 'name': '已获取模板'},
      ],
    };
    api.documents['GetResumesId'] = {
      'id': 22,
      'revision': 3,
      'content': {
        'personal_info': {'full_name': '测试姓名'},
      },
    };
    api.failing = 'GetTemplatesIdDom';
    await store.changeResumeMarketTemplate(22, 4);
    api.failing = 'GetResumesIdDomPreview';
    final result = await loadResumeTemplateDOM(store, 22, 4);
    expect(result.data['html'], dom(1)['html']);
    expect(api.calls, contains('PatchResumesId'));
    expect(
      api.calls.where((call) => call == 'GetTemplatesIdDom'),
      hasLength(1),
    );
    expect(api.calls, isNot(contains('GetResumesIdDomPreview')));
    expect(
      (api.documents['GetResumes']!['items'] as List).single['template_id'],
      4,
    );
  });

  test(
    'Updated version fetches once; user resume data never enters disk cache',
    () async {
      final store = await session();
      await predownloadAcquiredTemplate(store, 4, 1);
      api.documents['GetMeTemplates'] = {
        'items': [
          {'id': 4, 'version': 2},
        ],
      };
      api.documents['GetResumesIdDomPreview'] = {
        ...dom(2),
        'template_version': 2,
        'resume_data': {'name': 'PRIVATE_RESUME_DATA'},
        'photo_url': 'PRIVATE_PHOTO_URL',
      }..remove('version');
      final result = await loadResumeTemplateDOM(store, 22, 4);
      expect(result.data['version'], 2);
      await loadResumeTemplateDOM(await session(), 22, 4);
      expect(
        api.calls.where((call) => call == 'GetResumesIdDomPreview'),
        hasLength(1),
      );
      for (final file in await cachedFiles()) {
        expect(await file.readAsString(), isNot(contains('PRIVATE_')));
      }
    },
  );

  test(
    'Account isolation and a changed session cannot reuse in-flight results',
    () async {
      final first = await session();
      await predownloadAcquiredTemplate(first, 4, 1);
      await loadTemplatePreviewDOM(await session(13), 4, 1, persist: true);
      expect(
        api.calls.where((call) => call == 'GetTemplatesIdDom'),
        hasLength(2),
      );
      api.download = Completer<ApiDocument>();
      final pending = loadTemplatePreviewDOM(first, 4, 2, persist: true);
      final rejected = expectLater(pending, throwsA(isA<ApiFailure>()));
      first.epoch++;
      api.download!.complete(ApiDocument(dom(2)));
      await rejected;
      expect(
        (await cachedFiles()).where((file) => file.path.endsWith('4-2.json')),
        isEmpty,
      );
    },
  );

  test(
    'Corrupt or evicted files redownload, failed download remains retryable',
    () async {
      await predownloadAcquiredTemplate(await session(), 4, 1);
      final file = (await cachedFiles()).single;
      await file.writeAsString('incomplete json');
      await predownloadAcquiredTemplate(await session(), 4, 1);
      expect(jsonDecode(await file.readAsString())['version'], 1);
      await file.delete();
      api.failing = 'GetTemplatesIdDom';
      final store = await session();
      await predownloadAcquiredTemplate(store, 4, 1);
      expect(await cachedFiles(), isEmpty);
      api.failing = null;
      await predownloadAcquiredTemplate(store, 4, 1);
      expect(await cachedFiles(), hasLength(1));
    },
  );

  test('Bound resume fallback does not reuse cache when current metadata is absent', () async {
    final store = await session();
    await predownloadAcquiredTemplate(store, 4, 1);
    api.documents['GetResumesIdDomPreview'] = {...dom(2), 'template_version': 2}
      ..remove('version');
    final value = await loadResumeTemplateDOM(store, 22, 4);
    expect(value.data['version'], 2);
    expect(api.calls, contains('GetResumesIdDomPreview'));
  });

  test('Disk cache stays bounded', () async {
    final disk = TemplateDomStorage(12);
    for (var id = 1; id <= 26; id++) {
      expect(await disk.write(id, 1, {...dom(1), 'template_id': id}), isTrue);
    }
    expect(await cachedFiles(), hasLength(TemplateDomStorage.maxEntries));
  });
}
