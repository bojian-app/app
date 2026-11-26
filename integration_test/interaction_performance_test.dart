import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:bojian_mobile/account_pages.dart';
import 'package:bojian_mobile/ai_consent.dart';
import 'package:bojian_mobile/agreement_dialog.dart';
import 'package:bojian_mobile/privacy_consent.dart';
import 'package:bojian_mobile/confirmation_dialog.dart';
import 'package:bojian_mobile/app_shell.dart';
import 'package:bojian_mobile/customer_service_page.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:bojian_mobile/membership_page.dart';
import 'package:bojian_mobile/resume_module_order.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:bojian_mobile/resume_thumbnail.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/fake_gateway.dart';
import '../test/support/resume_editor_helpers.dart';
import 'page_performance_metrics.dart';

FakeGateway _fixture() {
  final api = FakeGateway(seeded: true);
  final resume =
      (api.documents['GetResumes']!['items'] as List).first
          as Map<String, dynamic>;
  final resumes = [
    for (var i = 1; i <= 9; i++)
      <String, dynamic>{
        ...resume,
        'id': i,
        'title': '测试简历 $i',
        'content': <String, dynamic>{
          ...(resume['content'] as Map<String, dynamic>),
          'work_experiences': [
            for (var j = 0; j < 8; j++)
              {
                'company': '项目团队 $j',
                'position': '产品经理',
                'start_date': '2020-01',
                'end_date': '2025-01',
                'description': '负责产品需求整理、用户研究和项目交付，协调研发进行上线验收。' * 4,
              },
          ],
        },
      },
  ];
  final session = {
    'id': 42,
    'status': 'CONNECTED',
    'waiting_for': 'USER',
    'agent_online': true,
    'agent_number': '0042',
    'messages': [
      for (var i = 0; i < 240; i++)
        {
          'sender': i.isEven ? 'AGENT' : 'USER',
          'text': '历史消息 $i ${'描述和补充说明。' * (i % 7 + 1)}',
        },
    ],
  };
  api.documents.addAll({
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
    'GetResumes': {'items': resumes},
    'GetResumesId': resumes.first,
    'PostSupportSessions': session,
    'GetSupportSessionsId': session,
    'GetNotifications': {
      'items': [
        for (var i = 1; i <= 500; i++)
          {
            'id': i,
            'type': 'SYSTEM',
            'payload': {'title': '账号通知 $i', 'body': '资料变更提醒'},
            'created_at': '2026-01-01T00:00:00Z',
            'read_at': '2026-01-01T00:00:00Z',
          },
      ],
    },
  });
  return api;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('Home navigation and populated page interactions', (
    tester,
  ) async {
    final api = _fixture();
    final store = await testStore(authenticated: true, api: api);
    expect(store.resumes, hasLength(9), reason: 'resumes: ${store.errors}');
    expect(store.inbox, hasLength(500), reason: 'inbox: ${store.errors}');
    final shell = GlobalKey<AppShellState>();
    final frames = <FrameTiming>[];
    final windows = <({String name, int start, int end})>[];
    final details = <String, Map<String, Object>>{};
    final hz = tester.view.display.refreshRate;
    void collect(List<FrameTiming> batch) => frames.addAll(batch);
    binding.addTimingsCallback(collect);
    addTearDown(() {
      binding.removeTimingsCallback(collect);
      store.dispose();
    });

    Future<void> wait(int milliseconds) =>
        Future<void>.delayed(Duration(milliseconds: milliseconds));
    Future<void> measure(String name, Future<void> Function() action) async {
      debugPrintSynchronously('PAGE_FLOW_START $name');
      final start = developer.Timeline.now;
      await action();
      windows.add((name: name, start: start, end: developer.Timeline.now));
      expect(tester.takeException(), isNull, reason: name);
    }

    Future<void> tap(Finder finder) async {
      expect(finder, findsOneWidget);
      await tester.tap(finder);
      await wait(550);
    }

    Finder byKey(String key) => find.byKey(ValueKey(key));
    Future<void> back() async {
      await tester.binding.handlePopRoute();
      await wait(650);
    }

    Future<void> scroll(String name, Finder page, {bool older = false}) async {
      final elements = find
          .descendant(of: page, matching: find.byType(Scrollable))
          .evaluate();
      final target = elements
          .map(
            (element) => (element as StatefulElement).state as ScrollableState,
          )
          .firstWhere(
            (state) =>
                state.position.axis == Axis.vertical &&
                state.position.hasContentDimensions &&
                state.position.maxScrollExtent -
                        state.position.minScrollExtent >
                    100,
          );
      final box = target.context.findRenderObject()! as RenderBox;
      final r = box.localToGlobal(Offset.zero) & box.size;
      final before = target.position.pixels;
      await measure(name, () async {
        for (var i = 0; i < 3; i++) {
          await tester.timedDragFrom(
            Offset(r.center.dx, r.top + r.height * (older ? .28 : .72)),
            Offset(0, r.height * (older ? .44 : -.44)),
            const Duration(milliseconds: 480),
            frequency: hz.clamp(60, 120),
          );
          await wait(180);
        }
      });
      final distance = (target.position.pixels - before).abs();
      expect(distance, greaterThan(1), reason: name);
      details[name] = {'scroll_distance_px': distance.round()};
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: AppShell(key: shell, store: store),
      ),
    );
    await wait(800);
    for (final visit in ['first', 'retained']) {
      await measure(
        'avatar-menu-$visit',
        () => tap(byKey('discovery-profile')),
      );
      expect(byKey('discovery-scan'), findsOneWidget);
      await measure(
        'avatar-member-$visit',
        () => tap(byKey('discovery-membership')),
      );
      expect(find.byType(MembershipPage), findsOneWidget);
      await measure('member-back-$visit', back);

      await tap(byKey('discovery-profile'));
      await measure(
        'avatar-profile-$visit',
        () => tap(byKey('discovery-my-page')),
      );
      expect(find.byType(ProfilePage), findsOneWidget);
      if (visit == 'first') {
        final thumbnails = find
            .byType(StandardResumeThumbnail)
            .evaluate()
            .length;
        expect(thumbnails, greaterThan(0));
        await measure('profile-resume-grid-refresh', () async {
          for (var i = 0; i < 45; i++) {
            store.changed();
            await binding.endOfFrame;
          }
        });
        details['profile-resume-grid-refresh'] = {
          'notifications': 45,
          'mounted_thumbnails': thumbnails,
          'work_entries_per_resume': 8,
        };
        await measure('profile-settings', () => tap(byKey('profile-settings')));
        expect(find.byType(SettingsPage), findsOneWidget);
        for (final item in [('主题色', 'accent'), ('外观模式', 'mode')]) {
          final row = find.text(item.$1);
          await tester.ensureVisible(row);
          await measure('settings-${item.$2}', () => tap(row));
          await back();
        }
        await back();
      }
      await measure('profile-back-$visit', back);
      expect(find.byType(DiscoveryPage), findsOneWidget);

      await tap(byKey('discovery-profile'));
      await measure(
        'home-service-$visit',
        () => tap(byKey('discovery-service')),
      );
      expect(find.byType(CustomerServicePage), findsOneWidget);
      if (visit == 'first') {
        await measure('service-faq-open', () => tap(find.text('账号信息')));
        expect(find.text('已解决'), findsOneWidget);
        await back();
        await measure('service-history-open', () => tap(find.text('发起新服务')));
        expect(find.text('客服小简'), findsOneWidget);
        expect(api.calls, contains('PostSupportSessions'));
        await scroll(
          'service-history-scroll',
          find.byType(CustomerServicePage),
          older: true,
        );
        final before = api.calls
            .where((m) => m == 'GetSupportSessionsId')
            .length;
        await measure('service-unchanged-poll', () => wait(2300));
        final polls =
            api.calls.where((m) => m == 'GetSupportSessionsId').length - before;
        expect(polls, greaterThan(0));
        details['service-unchanged-poll'] = {'polls': polls};
        await back();
      }
      await measure('service-back-$visit', back);
      expect(find.byType(DiscoveryPage), findsOneWidget);
    }

    await measure(
      'home-notifications-500',
      () => tap(byKey('discovery-messages')),
    );
    expect(store.inbox.length, 500);
    await scroll('notifications-scroll', find.byType(MessagesPage));
    await back();

    for (final (id, dialog) in <(String, Widget)>[
      ('ai-consent', const AiConsentDialog()),
      ('privacy-consent', const PrivacyConsentDialog()),
      (
        'login-agreement',
        AgreementDialog(onOpenTerms: () {}, onOpenPrivacy: () {}),
      ),
    ]) {
      await measure('dialog-$id', () async {
        unawaited(
          showAppDialog<void>(shell.currentContext!, builder: (_) => dialog),
        );
        await wait(650);
        expect(find.byType(dialog.runtimeType), findsOneWidget);
      });
      await measure('dialog-$id-close', () async {
        Navigator.of(shell.currentContext!).pop();
        await wait(550);
      });
    }
    final editor = ResumeEditor(
      store: store,
      draft: store.resumes.first.copy(),
    );
    unawaited(openPage<void>(shell.currentContext!, editor));
    await wait(650);
    final sections = ['personal', ...resumeModules.map((e) => e.$1)];
    for (var i = 0; i < sections.length; i++) {
      await measure(
        'editor-${sections[i]}',
        () => openResumeSection(tester, i),
      );
      expect(find.byKey(const ValueKey('resume-section-save')), findsOneWidget);
      await back();
    }
    await back();
    // Flutter profile batches callbacks. Match by monotonic vsync timestamps,
    // after giving the engine time to deliver its final batch.
    await wait(1300);
    final report = <String, dynamic>{};
    for (final w in windows) {
      final sample = frames.where((f) {
        final vsync = f.timestampInMicroseconds(FramePhase.vsyncStart);
        return vsync >= w.start && vsync < w.end;
      }).toList();
      final row = {
        'flow': w.name,
        'refresh_hz': hz,
        ...summarizePageFrames(sample, hz),
        ...?details[w.name],
      };
      report[w.name] = row;
      debugPrintSynchronously('PAGE_FLOW ${jsonEncode(row)}');
    }
    binding.reportData = {
      ...?binding.reportData,
      'refresh_hz': hz,
      'flows': report,
    };
    await tester.pumpWidget(const SizedBox.shrink());
  }, timeout: const Timeout(Duration(minutes: 5)));
}
