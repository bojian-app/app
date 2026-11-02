import 'dart:io';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/resume_wechat_share.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluwx_no_pay/fluwx_no_pay.dart';
import 'package:share_plus/share_plus.dart';

class _SDK implements Fluwx {
  bool installed = true;
  bool launched = true;
  WeChatShareFileModel? request;

  @override
  Future<bool> registerApi({
    required String appId,
    bool doOnIOS = true,
    bool doOnAndroid = true,
    String? universalLink,
  }) async => true;

  @override
  Future<bool> get isWeChatInstalled async => installed;

  @override
  Future<bool> share(WeChatShareModel what) async {
    request = what as WeChatShareFileModel;
    return launched;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory directory;
  late _SDK sdk;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('bojian-wechat-test-');
    sdk = _SDK();
  });
  tearDown(() => directory.delete(recursive: true));

  Future<XFile> resume(String suffix) async {
    final source = File('${directory.path}/我的简历.$suffix');
    await source.writeAsString(suffix == 'pdf' ? '%PDF-test' : 'PK-test');
    return XFile(source.path);
  }

  for (final suffix in ['pdf', 'docx']) {
    test('Dispatches $suffix without waiting for a WeChat response', () async {
      final file = await resume(suffix);
      await ResumeWeChatSharer(sdk).share(file);
      expect(sdk.request!.title, '我的简历.$suffix');
      expect(sdk.request!.source.suffix, '.$suffix');
      expect(sdk.request!.scene, WeChatScene.session);
      expect(await File(file.path).exists(), isTrue);
    });
  }

  test(
    'Missing WeChat leaves the file available for other share options',
    () async {
      sdk.installed = false;
      final file = await resume('pdf');
      await expectLater(
        ResumeWeChatSharer(sdk).share(file),
        throwsA(isA<ApiFailure>()),
      );
      expect(sdk.request, isNull);
      expect(await File(file.path).exists(), isTrue);
    },
  );

  test('Rejected launch reports failure and allows retry', () async {
    sdk.launched = false;
    final file = await resume('pdf');
    final sharer = ResumeWeChatSharer(sdk);
    await expectLater(sharer.share(file), throwsA(isA<ApiFailure>()));
    sdk.launched = true;
    await sharer.share(file);
  });

  test('A removed export is rejected before dispatch', () async {
    final file = await resume('pdf');
    await File(file.path).delete();
    await expectLater(
      ResumeWeChatSharer(sdk).share(file),
      throwsA(isA<ApiFailure>()),
    );
    expect(sdk.request, isNull);
  });
}
