import 'package:bojian_mobile/article_privacy.dart';
import 'package:bojian_mobile/article_topic.dart';
import 'package:bojian_mobile/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  testWidgets('隐私选择仅在确定后生效，旧草稿保留好友可见范围', (tester) async {
    var privacy = ArticlePrivacy.fromDraft({
      'visibility': 'FRIENDS',
      'content': {'followed_replies_only': true},
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                privacy = await editArticlePrivacy(context, privacy) ?? privacy;
              },
              child: const Text('设置'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('好友可见'), findsOneWidget);
    await tester.tap(find.text('私密'));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(privacy.visibility, 'FRIENDS');
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('私密'));
    await tester.tap(find.text('仅我关注的可回复'));
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(privacy, const ArticlePrivacy(visibility: 'PRIVATE'));
  });

  testWidgets('话题可以选择结果，也可以保留空格创建，读者打开公开动态列表', (tester) async {
    final gateway = FakeGateway()
      ..documents['GetArticleTopics'] = {
        'items': [
          {'name': 'test 1', 'article_count': 3},
        ],
      }
      ..documents['GetFeed'] = {
        'items': [
          {
            'id': 3,
            'title': '公开动态测试',
            'author': {'id': 5, 'display_name': '作者'},
          },
        ],
      };
    final store = await testStore(authenticated: true, api: gateway);
    addTearDown(store.dispose);
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: () async {
                    selected = await pickArticleTopic(context, store);
                  },
                  child: const Text('添加'),
                ),
                TextButton(
                  onPressed: () => openArticleTopic(context, store, 'test 1'),
                  child: const Text('阅读'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'test');
    await tester.pump(const Duration(milliseconds: 230));
    await tester.pumpAndSettle();
    expect(find.text('3 条动态'), findsOneWidget);
    await tester.tap(find.text('#test 1#'));
    await tester.pumpAndSettle();
    expect(selected, 'test 1');
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  新 话题  ');
    await tester.pump();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(selected, '新 话题');
    await tester.tap(find.text('阅读'));
    await tester.pumpAndSettle();
    expect(find.text('#test 1#'), findsOneWidget);
    expect(find.text('公开动态测试'), findsOneWidget);
  });
}
