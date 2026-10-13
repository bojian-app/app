import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/messages_page.dart';
import 'package:bojian_mobile/profile_avatar.dart';
import 'package:bojian_mobile/resume_guidance_review.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  testWidgets(
    'Feedback notifications identify actors, resume titles and comment/rewrite/reply kinds',
    (tester) async {
      final api = FakeGateway();
      final notifications = [
        ('COMMENT', '小林评论了你的简历', '评论', '小林'),
        ('REWRITE', '小周为你的简历提出了改写建议', '改写', '小周'),
        ('REPLY', '未设置用户昵称回复了你在简历中的评论', '回复', ''),
        ('MIXED', '小夏为你的简历提供了评论和改写建议', '评论·改写', '小夏'),
      ];
      api.documents['GetNotifications'] = {
        'items': [
          for (var index = 0; index < notifications.length; index++)
            {
              'id': index + 100,
              'type': 'RESUME_GUIDANCE_FEEDBACK',
              'actor_id': index + 2,
              'actor': {
                'display_name': notifications[index].$4,
                'avatar_url': '',
              },
              'subject_type': 'ARTICLE',
              'subject_id': 20,
              'payload': {
                'title': notifications[index].$2,
                'body': '《前端简历${index + 1}》',
                'feedback_type': notifications[index].$1,
              },
            },
        ],
      };
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(body: MessagesPage(store: store)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProfileAvatar), findsNWidgets(4));
      for (var index = 0; index < notifications.length; index++) {
        expect(find.text(notifications[index].$2), findsOneWidget);
        expect(find.text(notifications[index].$3), findsOneWidget);
        expect(find.text('《前端简历${index + 1}》'), findsOneWidget);
        expect(store.inbox[index].feedbackType, notifications[index].$1);
        expect(store.inbox[index].actorID, index + 2);
      }
      expect(
        tester.widget<Text>(find.text('评论')).style!.color,
        guidanceCommentColor,
      );
      expect(
        tester.widget<Text>(find.text('改写')).style!.color,
        guidanceReplacementColor,
      );
      expect(store.inbox[2].actorName, '未设置用户昵称');
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
