import 'package:bojian_mobile/customer_service_page.dart';
import 'package:bojian_mobile/profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'support/fake_gateway.dart';

class _ChatGallery extends ImagePickerPlatform {
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => XFile('assets/branding/app_icon.png');
}

void main() {
  testWidgets('人工会话从排队到接通、回复和释放', (tester) async {
    final api = FakeGateway();
    const notice = {
      'sender': 'SYSTEM',
      'text': '人工客服的服务时间为每天北京时间 09:00–18:00。服务时间内会为你匹配空闲客服，非服务时间暂时无法接通人工客服。',
    };
    const connection = {
      'sender': 'SYSTEM',
      'text': '已接通人工客服。轮到回复的一方五分钟内未回复，会话将自动结束。',
    };
    const reply = {'sender': 'AGENT', 'text': '请问是哪个订单？'};
    final queued = {
      'id': 42,
      'status': 'QUEUED',
      'ahead': 2,
      'messages': [notice],
    };
    final connected = {
      ...queued,
      'status': 'CONNECTED',
      'agent_number': '42',
      'waiting_for': 'USER',
      'messages': [notice, connection, reply],
    };
    api.documents['PostSupportSessions'] = {
      ...queued,
      'ahead': 0,
      'agent_online': false,
    };
    api.documents['GetSupportSessionsId'] = {
      ...queued,
      'ahead': 0,
      'agent_online': true,
    };
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(home: CustomerServicePage(store: store)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('发起新服务'));
    await tester.pumpAndSettle();
    expect(find.text('当前还没有客服在线。'), findsOneWidget);
    expect(find.text('自助服务'), findsNothing);
    expect(find.widgetWithText(TextButton, '咨询'), findsNothing);
    expect(find.textContaining('排队中'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.textContaining('前面有 0 人'), findsOneWidget);
    api.documents['GetSupportSessionsId'] = {...queued, 'agent_online': false};
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.textContaining('前面有 2 人'), findsOneWidget);
    api.documents['GetSupportSessionsId'] = connected;
    final greeting = find.text('您好！人工客服上班时间为法定工作日 09:00 - 18:00。');
    expect(greeting, findsOneWidget);
    final followup = find.text('其他时段，您可以通过「意见反馈」留言。');
    expect(followup, findsOneWidget);
    expect(
      tester.getTopLeft(followup).dy,
      greaterThan(tester.getBottomLeft(greeting).dy),
    );
    await tester.tapOnText(
      find.textRange.ofSubstring('意见反馈', descendentOf: followup),
    );
    await tester.pumpAndSettle();
    expect(find.text('提交'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(
      find.ancestor(of: greeting, matching: find.byType(Row)),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(
      find.text('已为您接通人工客服，请描述您遇到的问题。若等待回复满 5 分钟，本次会话将自动结束。'),
      findsOneWidget,
    );
    expect(find.text(reply['text']!), findsOneWidget);
    expect(find.text('客服「0042」'), findsOneWidget);
    expect(find.text('等待你回复'), findsOneWidget);
    api.documents['GetSupportSessionsId'] = {
      ...connected,
      'agent_typing': true,
    };
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('正在输入中...'), findsOneWidget);
    api.documents['GetSupportSessionsId'] = connected;
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('客服小简'), findsOneWidget);

    api.documents['PostSupportSessionsIdMessages'] = {
      ...connected,
      'waiting_for': 'AGENT',
      'messages': [
        notice,
        reply,
        {'sender': 'USER', 'text': '订单 123'},
      ],
    };
    await tester.enterText(find.byType(TextField), '订单 123');
    await tester.pump();
    await tester.tap(find.text('发送'));
    await tester.pumpAndSettle();
    expect(api.lastMutationBody?['text'], '订单 123');
    expect(find.text('订单 123'), findsOneWidget);
    expect(find.text('等待人工客服回复'), findsNothing);
    api.documents['GetSupportSessionsId'] = {
      ...connected,
      'status': 'CLOSED',
      'messages': [
        notice,
        connection,
        reply,
        {'sender': 'SYSTEM', 'text': '等待回复已超过五分钟，本次人工会话已结束。'},
      ],
    };
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('重新发起咨询'), findsOneWidget);
    expect(find.text('客服「0042」'), findsOneWidget);
    expect(find.text('超过五分钟未回复，本次对话已结束'), findsOneWidget);
    expect(api.calls, isNot(contains('PostFeedback')));
  });

  testWidgets('Questions get answers and unknown ones point to feedback', (
    tester,
  ) async {
    final store = await testStore(authenticated: true);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(home: CustomerServicePage(store: store)),
    );
    await tester.pumpAndSettle();
    expect(find.text('常见问题'), findsOneWidget);
    expect(find.text('如何查询注册时间'), findsOneWidget);
    final category = find.text('会员相关');
    await tester.ensureVisible(category);
    await tester.tap(category);
    await tester.pumpAndSettle();
    await tester.tap(find.text('开通后多久生效？'));
    await tester.pumpAndSettle();
    expect(find.textContaining('支付成功后立即生效'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('未解决'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      contains('开通后多久生效？'),
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('已解决'));
    await tester.pumpAndSettle();
    expect(find.text('常见问题'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '会员相关'))
          .selected,
      isTrue,
    );
    expect(find.text('感谢你的反馈'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('发起新服务'));
    await tester.pumpAndSettle();
    expect(find.text('你好，我是小简'), findsOneWidget);
    await tester.tap(find.text('如何查询注册时间'));
    await tester.pumpAndSettle();
    expect(find.textContaining('在账号 ID 下方'), findsOneWidget);
    expect(find.text('你可以这样问'), findsNothing);
    await tester.enterText(find.byType(TextField), '怎么查看订单');
    await tester.pump();
    await tester.tap(find.text('发送'));
    await tester.pumpAndSettle();
    expect(find.textContaining('会员中心右上角点「订单」'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump();
    await tester.tap(find.text('发送'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('提交意见反馈'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'zzzz',
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('客服图片支持预览、附说明和失败后重试', (tester) async {
    final original = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _ChatGallery();
    addTearDown(() => ImagePickerPlatform.instance = original);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final api = FakeGateway();
    api.documents['PostFilesUploads'] = {'id': 31};
    api.documents['PostFeedback'] = {'id': 72};
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    var uploads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerServicePage(
          store: store,
          uploadPhoto: (auth, file, mime) async {
            expect(auth['id'], 31);
            expect(mime, 'image/png');
            uploads++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('发起新服务'));
    await tester.pumpAndSettle();
    Future<void> pumpUntil(bool Function() ready) async {
      for (var i = 0; !ready() && i < 150; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(ready(), isTrue);
    }

    await tester.tap(find.byTooltip('发送图片'));
    await tester.pumpAndSettle();
    expect(find.text('拍照'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('photo-source-gallery')));
    await tester.pumpAndSettle();
    await pumpUntil(() => find.byTooltip('移除待发送图片').evaluate().isNotEmpty);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '发送'))
          .onPressed,
      isNotNull,
    );
    expect(api.calls, isNot(contains('PostFilesUploads')));
    await tester.enterText(find.byType(TextField), '这里显示异常');
    api.failing = 'PostFeedback';
    await tester.tap(find.text('发送'));
    await pumpUntil(() => api.calls.contains('PostFeedback'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('移除待发送图片'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    api.failing = null;
    await tester.tap(find.text('发送'));
    await tester.pumpAndSettle();
    expect(uploads, 1);
    expect(api.lastBody?['content'], '客服会话图片咨询：这里显示异常\n反馈附图：31');
    expect(find.textContaining('工单号为 72'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('查看已发送的图片'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Order consultation carries the selected order into feedback', (
    tester,
  ) async {
    final api = FakeGateway();
    api.documents['GetMembershipOrderHistory'] = {
      'items': [
        {
          'title': '月度会员',
          'order_no': 'TEST-21',
          'status': 'PAID',
          'amount_milliunits': 12000,
          'created_at': '2026-11-10T10:00:00',
          'paid_at': '2026-11-12T10:00:00',
        },
        {
          'title': '旧模板订单',
          'order_no': 'TEST-20',
          'status': 'PAID',
          'amount_milliunits': 5000,
          'created_at': '2026-11-09T10:00:00',
        },
      ],
    };
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(home: CustomerServicePage(store: store, embedded: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('¥12.00 · 2026-11-12'), findsOneWidget);
    expect(find.text('¥5.00'), findsOneWidget);
    expect(find.textContaining('已支付'), findsNothing);
    await tester.tap(find.text('咨询').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('提交意见反馈'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('提交意见反馈'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      contains('订单号：TEST-21'),
    );
    expect(api.calls, isNot(contains('PostFeedback')));
  });
  testWidgets('会话横滑后发送选中的订单并保留输入草稿', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final api = FakeGateway();
    final session = {'id': 42, 'status': 'CONNECTED', 'messages': []};
    api.documents['PostSupportSessions'] = session;
    api.documents['GetSupportSessionsId'] = session;
    const orderText = '咨询订单：会员订单3\n订单号：TEST-3\n金额：¥25.00\n支付日期：2026-11-15';
    final sent = {
      ...session,
      'messages': [
        {'sender': 'USER', 'text': orderText},
      ],
    };
    api.documents['PostSupportSessionsIdMessages'] = sent;
    api.documents['GetMembershipOrderHistory'] = {
      'items': [
        for (var i = 1; i <= 3; i++)
          {
            'title': '会员订单$i',
            'order_no': 'TEST-$i',
            'status': 'PAID',
            'amount_milliunits': 25000,
            'paid_at': '2026-11-15T10:00:00',
          },
      ],
    };
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(home: CustomerServicePage(store: store)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('发起新服务'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '待发送草稿');
    final strip = find.ancestor(
      of: find.text('会员订单1'),
      matching: find.byType(SingleChildScrollView),
    );
    expect(tester.getTopLeft(strip).dx, 0);
    final firstCard = find
        .ancestor(of: find.text('会员订单1'), matching: find.byType(Container))
        .first;
    expect(tester.getTopLeft(firstCard).dx, 24);
    expect(tester.getTopRight(strip).dx, 390);
    await tester.drag(strip, const Offset(-650, 0));
    await tester.pumpAndSettle();
    final lastCard = find
        .ancestor(of: find.text('会员订单3'), matching: find.byType(Container))
        .first;
    expect(tester.getTopRight(lastCard).dx, closeTo(390 - 24, 0.01));
    final tile = find
        .ancestor(of: find.text('会员订单3'), matching: find.byType(Row))
        .first;
    await tester.tap(find.descendant(of: tile, matching: find.text('发送')));
    await tester.pumpAndSettle();
    expect(
      api.lastMutationBody?['text'],
      '咨询订单：会员订单3\n订单号：TEST-3\n金额：¥25.00\n支付日期：2026-11-15',
    );
    expect(find.text('待发送草稿'), findsOneWidget);
    expect(find.text(orderText), findsNothing);
    expect(find.text('订单号：TEST-3'), findsOneWidget);
    final sentCard = find
        .ancestor(of: find.text('订单号：TEST-3'), matching: find.byType(Container))
        .first;
    expect(tester.getTopLeft(sentCard).dx, greaterThanOrEqualTo(24 + 32 + 8));
    expect(
      tester.getTopLeft(find.byType(ProfileAvatar)).dx -
          tester.getTopRight(sentCard).dx,
      8,
    );
    expect(tester.getTopRight(find.byType(ProfileAvatar)).dx, 390 - 24);
    expect(
      tester.getTopLeft(find.byType(ProfileAvatar)).dx,
      greaterThan(tester.getTopRight(find.text('订单号：TEST-3')).dx),
    );
    api.documents['GetSupportSessionsId'] = {
      ...sent,
      'messages': [
        {'sender': 'SYSTEM', 'text': '您好！人工客服上班时间为法定工作日 09:00 - 18:00。'},
        {'sender': 'USER', 'text': '咨询订单：名称足够长以填满气泡并换行的博简会员订单，订单号：TEST-3'},
        {'sender': 'USER', 'text': '咨询订单：会员订单1\n订单号：TEST-1\n¥25.00 · 已支付'},
      ],
    };
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('支付日期：2026-11-15'), findsNWidgets(2));
    expect(find.text('订单号：TEST-1'), findsOneWidget);
    expect(find.byType(ProfileAvatar), findsNWidgets(2));
    final greeting = find
        .ancestor(
          of: find.text('您好！人工客服上班时间为法定工作日 09:00 - 18:00。', findRichText: true),
          matching: find.byType(Container),
        )
        .first;
    final otherCard = find
        .ancestor(of: find.text('订单号：TEST-1'), matching: find.byType(Container))
        .first;
    for (final width in [320.0, 390.0, 480.0]) {
      tester.view.physicalSize = Size(width, 844);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(sentCard).width,
        closeTo(tester.getSize(greeting).width, .01),
      );
      expect(tester.getRect(otherCard).left, tester.getRect(sentCard).left);
      expect(tester.getRect(otherCard).right, tester.getRect(sentCard).right);
      expect(
        tester.getRect(sentCard).left,
        greaterThanOrEqualTo(tester.getRect(greeting).left - .01),
      );
    }
  });
}
