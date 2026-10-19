import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/messages_page.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:bojian_mobile/article_reaction_button.dart';
import 'package:bojian_mobile/guidance_feed_card.dart';
import 'package:bojian_mobile/resume_document.dart';
import 'package:bojian_mobile/resume_guidance_privacy.dart';
import 'package:bojian_mobile/resume_guidance_share.dart';
import 'package:bojian_mobile/resume_guidance_view.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class GuidanceGateway extends FakeGateway {
  final shares = <Map<String, dynamic>>[];
  final keys = <String>[];
  Map<String, String>? guidancePath;
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (method == 'PostResumesIdGuidance') {
      shares.add(body!);
      keys.add(headers['idempotency-key']!);
      guidancePath = path;
    }
    if (method == 'GetNotificationsIdGuidance') guidancePath = path;
    return super.call(
      method,
      path: path,
      query: query,
      body: body,
      headers: headers,
    );
  }
}

ResumeDraft draft() => ResumeDraft(
  id: 42,
  title: '前端开发简历',
  source: {
    'personal_info': {'full_name': '测试用户', 'phone': '13800000000'},
    'work_experiences': [
      {'company': '测试公司', 'position': '前端', 'description': '开发网站'},
    ],
  },
);

Future<void> mountShare(WidgetTester tester, AppStore store) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => openPage(
              context,
              ResumeGuidanceShare(store: store, resume: draft()),
            ),
            child: const Text('打开'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Owner sees full private resume and can zoom using controls and gestures',
    (tester) async {
      final api = GuidanceGateway();
      api.documents['GetResumesId'] = {
        'id': 42,
        'title': '前端简历',
        'content': draft().source,
      };
      api.documents['GetArticlesIdGuidanceAnnotations'] = {
        'items': [
          {
            'id': 1,
            'reviewer_id': 2,
            'reviewer_name': '小明',
            'field_path': 'work_experiences.0.description',
            'selected_text': '开发网站',
            'suggestion': '建议补充指标',
          },
        ],
      };
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ResumeGuidanceView(
            store: store,
            id: 77,
            initialData: {
              'is_owner': true,
              'source_resume_id': 42,
              'snapshot': {},
              'can_review': false,
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ResumeDocumentView), findsOneWidget);
      expect(find.text('简历详情'), findsOneWidget);
      expect(api.calls, isNot(contains('GetArticlesIdGuidanceAnnotations')));
      final view = tester.widget<ResumeDocumentView>(
        find.byType(ResumeDocumentView),
      );
      expect(view.resume.name, '测试用户');
      expect(view.resume.phone, '13800000000');
      expect(
        view.resume.source['work_experiences'],
        draft().source['work_experiences'],
      );
      expect(api.calls, contains('GetResumesId'));
      final state = tester.state<ResumeDocumentViewState>(
        find.byType(ResumeDocumentView),
      );
      expect(find.byTooltip('放大简历'), findsNothing);
      expect(find.byTooltip('缩小简历'), findsNothing);
      expect(find.text('复位'), findsNothing);
      final point =
          tester.getTopLeft(
            find.byKey(const ValueKey('resume-gesture-viewport')),
          ) +
          const Offset(150, 100);
      final left = await tester.startGesture(
        point - const Offset(40, 0),
        pointer: 1,
      );
      final right = await tester.startGesture(
        point + const Offset(40, 0),
        pointer: 2,
      );
      await tester.pump();
      await left.moveBy(const Offset(-40, 0));
      await right.moveBy(const Offset(40, 0));
      await tester.pump();
      await left.moveBy(const Offset(-20, 0));
      await right.moveBy(const Offset(20, 0));
      await tester.pump();
      await left.up();
      await right.up();
      await tester.pumpAndSettle();
      expect(state.transform.value.getMaxScaleOnAxis(), greaterThan(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Non-owner masks only fields and never fetches private source', (
    tester,
  ) async {
    final api = GuidanceGateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    final source = draft().source;
    (source['work_experiences'] as List).first['description'] = '在测试公司负责开发';
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: ResumeGuidanceView(
          store: store,
          id: 77,
          initialData: {
            'is_owner': false,
            'source_resume_id': 42,
            'snapshot': source,
            'can_review': true,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final view = tester.widget<ResumeDocumentView>(
      find.byType(ResumeDocumentView),
    );
    expect(view.resume.name, resumePrivacyMask);
    final work = (view.resume.source['work_experiences'] as List).first;
    expect(work['company'], resumePrivacyMask);
    expect(work['description'], '在测试公司负责开发');
    expect(api.calls, isNot(contains('GetResumesId')));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Guidance feed card has no social actions and opens resume directly',
    (tester) async {
      final api = GuidanceGateway();
      api.documents['GetArticlesIdGuidance'] = {
        'title': '前端开发简历',
        'snapshot': draft().source,
        'question': '工作经历怎么突出重点？',
        'can_review': false,
      };
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      final story = Story(
        id: 77,
        title: '前端开发简历',
        author: '小林',
        role: '',
        category: '简历求指点',
        hasGuidance: true,
        excerpt: '不应展示的完整简历正文',
        paragraphs: [],
        likes: 22,
        commentCount: 33,
        content: {'kind': 'RESUME_GUIDANCE', 'question': '工作经历怎么突出重点？'},
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: StoryCard(story: story, store: store),
          ),
        ),
      );
      expect(find.byType(GuidanceFeedCard), findsOneWidget);
      expect(find.byType(ArticleReactionButton), findsNothing);
      expect(find.text('22'), findsNothing);
      expect(find.text('33'), findsNothing);
      expect(find.text('不应展示的完整简历正文'), findsNothing);
      await tester.tap(find.text('查看简历并指点'));
      await tester.pumpAndSettle();
      expect(find.byType(ResumeGuidanceView), findsOneWidget);
      expect(api.calls, contains('GetArticlesIdGuidance'));
      expect(api.calls, isNot(contains('GetArticlesIdComments')));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Card exposes guidance independently from preview', (
    tester,
  ) async {
    final store = await testStore(authenticated: true);
    addTearDown(store.dispose);
    store.resumes.add(draft());
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(body: ResumeLibrary(store: store)),
      ),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('resume-optimize-42')),
    );
    await tester.tap(find.byKey(const ValueKey('resume-optimize-42')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('resume-guidance-42')));
    await tester.pumpAndSettle();
    expect(find.byType(ResumeGuidanceShare), findsOneWidget);
    expect(find.byType(ResumePreview), findsNothing);
  });

  testWidgets(
    'Community request uses snapshot and hides contact/photo by default',
    (tester) async {
      final api = GuidanceGateway()
        ..documents['PostResumesIdGuidance'] = {'id': 9, 'status': 'SUBMITTED'};
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await mountShare(tester, store);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.textContaining('分享的是'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('guidance-question')),
        '工作经历怎么突出重点？',
      );
      await tester.tap(find.byKey(const ValueKey('guidance-submit')));
      await tester.pumpAndSettle();
      expect(api.guidancePath, {'id': '42'});
      expect(api.shares.single, {
        'version': 2,
        'destination': 'CIRCLE',
        'question': '工作经历怎么突出重点？',
        'hidden_fields': [
          'personal_info',
          'photo',
          'projects.url',
          'educations.institution',
          'work_experiences.company',
          'projects.name',
          'certifications.issuer',
        ],
      });
      expect(api.keys.single, isNotEmpty);
      expect(find.byType(ResumeGuidanceShare), findsNothing);
      expect(find.text('已提交审核，通过后展示在社区'), findsOneWidget);
    },
  );

  testWidgets(
    'Friend mode requires selection and sends only chosen recipients',
    (tester) async {
      final api = GuidanceGateway();
      api.documents['GetFriends'] = {
        'items': [
          {'id': 2, 'display_name': '小林', 'public_id': 'LIN'},
          {'id': 3, 'display_name': '小陈', 'public_id': 'CHEN'},
        ],
      };
      api.documents['PostResumesIdGuidance'] = {'id': 11, 'status': 'SENT'};
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await mountShare(tester, store);
      await tester.tap(find.text('指定用户'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('guidance-submit')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('小林'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('guidance-submit')));
      await tester.pumpAndSettle();
      expect(api.shares.single['destination'], 'FRIENDS');
      expect(api.shares.single['friend_ids'], [2]);
      expect(api.shares.single['hidden_fields'], [
        'personal_info',
        'photo',
        'projects.url',
        'educations.institution',
        'work_experiences.company',
        'projects.name',
        'certifications.issuer',
      ]);
      expect(find.text('指点邀请已发送'), findsOneWidget);
    },
  );

  testWidgets('Failure preserves form and retry reuses idempotency key', (
    tester,
  ) async {
    final api = GuidanceGateway()..failing = 'PostResumesIdGuidance';
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await mountShare(tester, store);
    await tester.enterText(
      find.byKey(const ValueKey('guidance-question')),
      '请帮我看看',
    );
    await tester.tap(find.byKey(const ValueKey('guidance-submit')));
    await tester.pumpAndSettle();
    expect(find.byType(ResumeGuidanceShare), findsOneWidget);
    api.failing = null;
    api.documents['PostResumesIdGuidance'] = {'id': 15};
    await tester.tap(find.byKey(const ValueKey('guidance-submit')));
    await tester.pumpAndSettle();
    expect(api.keys, hasLength(2));
    expect(api.keys[0], api.keys[1]);
    expect(api.shares[1]['question'], '请帮我看看');
  });

  testWidgets(
    'Feedback notification opens original invitation, not feedback ID',
    (tester) async {
      final api = GuidanceGateway();
      api.documents['GetNotificationsIdGuidance'] = {
        'title': '前端开发简历',
        'snapshot': draft().source,
        'question': '帮我看看',
        'can_review': false,
        'suggestions': [],
      };
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      store.inbox.add(
        InboxItem(
          '收到建议',
          '前端开发简历',
          '',
          0,
          id: 99,
          type: 'RESUME_GUIDANCE_FEEDBACK',
          read: true,
          subjectID: 11,
          subjectType: 'GUIDANCE_NOTIFICATION',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(body: MessagesPage(store: store)),
        ),
      );
      await tester.tap(find.text('收到建议'));
      await tester.pumpAndSettle();
      expect(api.guidancePath, {'id': '11'});
      expect(find.byType(ResumeGuidanceView), findsOneWidget);
      expect(find.text('帮我看看'), findsOneWidget);
      expect(find.text('给出建议'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
