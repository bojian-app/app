import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:bojian_mobile/about_page.dart';
import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/account_pages.dart';
import 'package:bojian_mobile/agreement_dialog.dart';
import 'package:bojian_mobile/ai_consent.dart';
import 'package:bojian_mobile/app_shell.dart';
import 'package:bojian_mobile/auth_page.dart';
import 'package:bojian_mobile/customer_service_page.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/developer_verification_page.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:bojian_mobile/feedback_page.dart';
import 'package:bojian_mobile/invitation_dialog.dart';
import 'package:bojian_mobile/legal_document.dart';
import 'package:bojian_mobile/legal_document_page.dart';
import 'package:bojian_mobile/login_phone_binding_page.dart';
import 'package:bojian_mobile/membership_page.dart';
import 'package:bojian_mobile/my_articles_page.dart';
import 'package:bojian_mobile/order_history_page.dart';
import 'package:bojian_mobile/phone_binding_dialog.dart';
import 'package:bojian_mobile/privacy_consent.dart';
import 'package:bojian_mobile/profile_edit_actions.dart';
import 'package:bojian_mobile/profile_identity.dart';
import 'package:bojian_mobile/resume_ai_optimization_page.dart';
import 'package:bojian_mobile/resume_assistance_page.dart';
import 'package:bojian_mobile/resume_option_picker.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:bojian_mobile/resume_template_picker.dart';
import 'package:bojian_mobile/saved_articles_page.dart';
import 'package:bojian_mobile/settings_page.dart';
import 'package:bojian_mobile/user_profile_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/fake_gateway.dart';
import 'page_performance_metrics.dart';
import 'auxiliary_performance_pages.dart';

typedef _Page = ({String name, Widget Function() make});
typedef _Window = ({String phase, int start, int end});

// Allow the engine to present frames naturally. Pumping a fixed sequence of
// artificial 16ms steps would measure the test runner's pacing on 120Hz phones.
Future<void> _live(WidgetTester tester, int milliseconds) async {
  await tester.pump();
  await Future<void>.delayed(Duration(milliseconds: milliseconds));
}

class _PageGateway extends FakeGateway {
  _PageGateway() : super(seeded: true);

  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (method == 'GetUsersFirstSecond') {
      return ApiDocument(
        documents[path['second'] == 'profile'
            ? 'GetUsersId'
            : 'GetUsersIdArticles']!,
      );
    }
    if (method == 'GetArticlesId') {
      final stories =
          documents['GetFeed']!['items'] as List<Map<String, dynamic>>;
      return ApiDocument(
        stories.firstWhere((row) => '${row['id']}' == path['id']),
      );
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

FakeGateway _fixture() {
  final api = _PageGateway();
  final first =
      (api.documents['GetFeed']!['items'] as List).first
          as Map<String, dynamic>;
  final stories = [
    for (var i = 1; i <= 70; i++)
      {
        ...first,
        'id': i,
        'title': '求职经历与项目分享 $i',
        'status': 'PUBLISHED',
        'visibility': 'PUBLIC',
        'is_favorited': true,
      },
  ];
  final resume =
      (api.documents['GetResumes']!['items'] as List).first
          as Map<String, dynamic>;
  final resumes = [
    for (var i = 1; i <= 25; i++) {...resume, 'id': i, 'title': '产品经理简历 $i'},
  ];
  api.documents.addAll({
    'GetFeed': {'items': stories},
    'GetResumes': {'items': resumes},
    'GetResumesId': Map<String, dynamic>.from(resumes.first),
    'GetArticlesId': Map<String, dynamic>.from(stories.first),
    'GetArticlesIdComments': {
      'items': [
        for (var i = 1; i <= 45; i++)
          {
            'id': i,
            'content': '建议补充工作成果 $i',
            'author': {'id': 2, 'display_name': '读者 $i'},
          },
      ],
    },
    'GetMeArticles': {'items': stories},
    'GetUsersIdArticles': {'items': stories},
    'GetMeFavorites': {'items': stories},
    'GetUsersId': {...api.documents['GetMe']!, 'id': 2},
    for (final method in ['GetJobTitles', 'GetIndustries', 'GetCities'])
      method: {
        'items': [
          for (var i = 1; i <= 60; i++) {'id': i, 'name': '候选项 $i'},
        ],
      },
    'GetMeIdentityVerification': {'status': 'NOT_VERIFIED'},
    'GetInvitations': {
      'invite_code': 'A2B3C4D5',
      'download_url': 'https://example.invalid/download',
      'completed_count': 2,
      'pending_count': 1,
    },
    'GetMembership': {'active': false, 'ai_packs': []},
    'GetMembershipPlans': {
      'channels': ['ALIPAY', 'WECHAT'],
      'ai_addons': [
        {
          'kind': 'TEXT',
          'name': '单段生成',
          'unit_price_cents': 100,
          'max_quantity': 100,
        },
      ],
    },
    'GetMembershipWallet': {
      'coupons': [
        for (var i = 1; i <= 10; i++)
          {
            'id': i,
            'title': '月卡立减券 $i',
            'amount_cents': 100,
            'plan_code': 'MONTH',
            'status': 'AVAILABLE',
            'expires_at': '2030-10-01',
          },
      ],
      'cards': [
        {
          'id': 1,
          'plan_code': 'MONTH',
          'expires_at': '2030-10-01',
          'status': 'AVAILABLE',
        },
      ],
    },
    'GetTemplates': {
      'items': [
        for (var i = 1; i <= 24; i++)
          {
            'id': i,
            'name': '职业模板 $i',
            'pricing_type': 'PAID',
            'price_cents': 1000,
            'compatible': true,
          },
      ],
    },
    'GetMeTemplates': {
      'items': [
        for (var i = 1; i <= 6; i++)
          {
            'id': i,
            'name': '已购模板 $i',
            'pricing_type': 'PAID',
            'source': 'ACQUIRED',
          },
      ],
    },
    'GetNotifications': {
      'items': [
        for (var i = 1; i <= 40; i++)
          {
            'id': i,
            'type': 'SYSTEM',
            'payload': {'title': '系统通知 $i', 'body': '账号服务提醒'},
            'read_at': '2026-10-02T00:00:00Z',
            'created_at': '2026-10-01T00:00:00Z',
          },
      ],
    },
    'GetMembershipOrderHistory': {
      'items': [
        for (var i = 1; i <= 30; i++)
          {
            'id': i,
            'title': '会员月卡',
            'status': 'PAID',
            'amount_milliunits': 9000,
            'channel': 'ALIPAY',
            'currency': 'CNY',
            'order_no': 'TEST000$i',
            'created_at': '2026-10-01T00:00:00Z',
          },
      ],
    },
  });
  return api;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('Offline page presentation and scrolling timings', (
    tester,
  ) async {
    final store = await testStore(authenticated: true, api: _fixture());
    final guest = await testStore();
    expect(store.resumes, hasLength(25), reason: 'resumes: ${store.errors}');
    expect(store.stories, hasLength(70), reason: 'stories: ${store.errors}');
    expect(store.inbox, hasLength(40), reason: 'inbox: ${store.errors}');
    final draft = store.resumes.first;
    final navigator = GlobalKey<NavigatorState>();
    final shell = GlobalKey<AppShellState>();
    final frames = <FrameTiming>[];
    void collect(List<FrameTiming> arrivals) => frames.addAll(arrivals);
    binding.addTimingsCallback(collect);
    addTearDown(() {
      binding.removeTimingsCallback(collect);
      store.dispose();
      guest.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        navigatorKey: navigator,
        home: AppShell(key: shell, store: store),
      ),
    );
    await _live(tester, 800);
    final pages = <_Page>[
      (name: 'discover', make: () => AppShell(store: store)),
      (
        name: 'article',
        make: () => StoryDetail(story: store.stories.first, store: store),
      ),
      (name: 'profile', make: () => ProfilePage(store: store)),
      (name: 'membership', make: () => MembershipPage(store: store)),
      (name: 'customer-service', make: () => CustomerServicePage(store: store)),
      (
        name: 'messages',
        make: () => MessagesPage(store: store, standalone: true),
      ),
      (
        name: 'public-profile',
        make: () => UserProfilePage(store: store, userID: 2),
      ),
      (
        name: 'profile-details',
        make: () => ProfileDetailsPage(
          store: store,
          onEdit: (_) async {},
          onAvatar: (_) async {},
        ),
      ),
      for (final action in ProfileEditAction.values)
        (
          name: 'edit-profile-${action.name}',
          make: () => ProfileEditor(store: store, action: action),
        ),
      (name: 'resume-library', make: () => ResumeLibrary(store: store)),
      (
        name: 'resume-preview',
        make: () => ResumePreview(store: store, resumeId: draft.id),
      ),
      (
        name: 'resume-editor',
        make: () => ResumeEditor(store: store, draft: draft.copy()),
      ),
      (
        name: 'resume-templates',
        make: () => ResumeTemplatePicker(store: store, resume: draft),
      ),
      (
        name: 'resume-ai-optimization',
        make: () => ResumeAIOptimizationPage(store: store, resume: draft),
      ),
      (
        name: 'resume-ai-creation',
        make: () => ResumeAssistancePage(store: store),
      ),
      (name: 'resume-import', make: () => ImportResume(store: store)),
      for (final kind in ResumeOptionKind.values)
        (
          name: 'picker-${kind.name}',
          make: () => ResumeOptionPicker(store: store, kind: kind),
        ),
      (name: 'articles-owned', make: () => MyArticlesPage(store: store)),
      (name: 'articles-saved', make: () => SavedArticlesPage(store: store)),
      (name: 'article-composer', make: () => StoryComposer(store: store)),
      (
        name: 'membership-checkout',
        make: () =>
            MembershipCheckoutPage(store: store, plan: membershipPlans.first),
      ),
      (
        name: 'ai-addon-checkout',
        make: () => AIAddonCheckoutPage(
          store: store,
          offer: const AIAddonOffer(
            kind: 'TEXT',
            name: '单段生成',
            unitPriceCents: 100,
            maxQuantity: 100,
          ),
        ),
      ),
      (
        name: 'order-result',
        make: () => MembershipOrderResultPage(
          store: store,
          plan: membershipPlans.first,
          order: const {'id': 1, 'status': 'PAID'},
        ),
      ),
      (
        name: 'membership-wallet',
        make: () => MembershipWalletPage(store: store),
      ),
      (name: 'order-history', make: () => OrderHistoryPage(store: store)),
      (name: 'settings', make: () => SettingsPage(store: store)),
      (name: 'security', make: () => AccountSecurityPage(store: store)),
      (name: 'verification', make: () => VerificationPage(store: store)),
      (
        name: 'developer-verification',
        make: () => DeveloperVerificationPage(store: store),
      ),
      (name: 'feedback', make: () => FeedbackPage(store: store)),
      (name: 'about', make: () => AboutPage(store: store)),
      for (final kind in LegalDocumentKind.values)
        (name: 'legal-${kind.name}', make: () => LegalDocumentPage(kind: kind)),
      (name: 'auth', make: () => AuthPage(store: guest)),
      (
        name: 'login-binding',
        make: () => LoginPhoneBindingPage(
          store: guest,
          token: 'fixture',
          provider: 'WECHAT',
        ),
      ),
      (name: 'friend-search', make: () => AddFriendSheet(store: store)),
      (name: 'invitation', make: () => InvitationDialog(store: store)),
      (name: 'phone-binding', make: () => PhoneBindingDialog(store: store)),
      (
        name: 'login-agreement',
        make: () => AgreementDialog(onOpenTerms: () {}, onOpenPrivacy: () {}),
      ),
      (name: 'privacy-consent', make: () => const PrivacyConsentDialog()),
      (name: 'ai-consent', make: () => const AiConsentDialog()),
      ...await auxiliaryPerformancePages(store),
    ];
    const selected = String.fromEnvironment('PERF_PAGES');
    final filter = selected.split(',').where((v) => v.isNotEmpty).toSet();
    final hz = tester.view.display.refreshRate;
    final report = <String, dynamic>{};
    binding.reportData = {
      ...?binding.reportData,
      'refresh_hz': hz,
      'pages': report,
    };
    for (final page in pages.where(
      (p) => filter.isEmpty || filter.contains(p.name),
    )) {
      final windows = <_Window>[];
      Future<void> measure(String phase, Future<void> Function() work) async {
        final start = developer.Timeline.now;
        await work();
        windows.add((phase: phase, start: start, end: developer.Timeline.now));
      }

      final name = page.name;
      final marker = ValueKey('profiled-page-$name');
      final row = <String, dynamic>{'page': name, 'refresh_hz': hz};
      debugPrintSynchronously('PAGE_PERF_START $name');
      await measure('enter', () async {
        unawaited(
          openPage<void>(
            shell.currentContext!,
            KeyedSubtree(
              key: marker,
              child: Scaffold(body: page.make()),
            ),
          ),
        );
        await _live(tester, 720);
      });
      final visiblePage = find.byKey(marker);
      expect(visiblePage, findsOneWidget, reason: name);
      final scrollables = find.descendant(
        of: visiblePage,
        matching: find.byType(Scrollable),
      );
      final positions = <ScrollPosition>[];
      Rect? target;
      for (final e in scrollables.evaluate()) {
        final state = (e as StatefulElement).state as ScrollableState;
        final pos = state.position;
        if (!pos.hasContentDimensions ||
            pos.axis != Axis.vertical ||
            pos.maxScrollExtent - pos.minScrollExtent < 4) {
          continue;
        }
        final box = e.renderObject as RenderBox;
        final rect = box.localToGlobal(Offset.zero) & box.size;
        if (rect.height < 80 || rect.width < 80) continue;
        positions.add(pos);
        if (target == null || rect.height > target.height) target = rect;
      }
      row['scroll_status'] = 'no-scrollable-content';
      if (target != null) {
        final before = [for (final pos in positions) pos.pixels];
        final rect = target;
        await measure('scroll', () async {
          await tester.timedDragFrom(
            Offset(rect.center.dx, rect.top + rect.height * .72),
            Offset(0, -math.min(350.0, rect.height * .45)),
            const Duration(milliseconds: 520),
            frequency: hz.clamp(60, 120),
          );
          await _live(tester, 220);
        });
        var distance = 0.0;
        for (var i = 0; i < positions.length; i++) {
          distance = math.max(
            distance,
            (positions[i].pixels - before[i]).abs(),
          );
        }
        row['scroll_distance_px'] = distance.round();
        row['scroll_status'] = distance >= 1
            ? 'scrolled'
            : 'gesture-no-displacement';
      }
      await measure('return', () async {
        navigator.currentState!.pop();
        await _live(tester, 600);
      });
      // The profile engine reports FrameTiming in batches. Frame timestamps
      // use the same monotonic epoch as Timeline.now; never attribute by arrival time.
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      for (final w in windows) {
        final sample = frames.where((f) {
          final t = f.timestampInMicroseconds(FramePhase.vsyncStart);
          return t >= w.start && t < w.end;
        }).toList();
        row[w.phase] = summarizePageFrames(sample, hz);
      }
      report[name] = row;
      debugPrintSynchronously('PAGE_PERF ${jsonEncode(row)}');
      frames.clear();
      expect(tester.takeException(), isNull, reason: name);
    }
    expect(report, isNotEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  }, timeout: const Timeout(Duration(minutes: 15)));
}
