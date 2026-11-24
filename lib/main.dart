import 'app_page_bar.dart';
import 'app_appearance.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_shell.dart';
import 'app_environment.dart';
import 'auth_page.dart';
import 'app_store.dart';
import 'membership_status.dart';
import 'app_update.dart';
import 'apple_membership_products.dart';
import 'apple_membership_purchases.dart';
import 'confirmation_dialog.dart';
import 'design.dart';
import 'banner_ads.dart';
import 'privacy_consent.dart';
import 'startup_animation.dart';
import 'resume_files.dart';
import 'resume_pages.dart';
import 'resume_system_fonts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Keep decoded previews bounded while browsing; old entries are evicted by LRU.
  PaintingBinding.instance.imageCache
    ..maximumSize = 160
    ..maximumSizeBytes = 32 * 1024 * 1024;
  // Previews pick their bold face synchronously; know it before the first one.
  await ResumeSystemFonts.refresh();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    this.startupAnimationEnabled = true,
    this.bannerAdsEnabled = true,
    this.store,
    this.requirePrivacyConsent,
  });
  final bool startupAnimationEnabled;
  final bool bannerAdsEnabled;
  final AppStore? store;

  /// 启动时是否先弹隐私政策；默认只有使用真实存储（未注入 store）时弹出。
  final bool? requirePrivacyConsent;
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final AppStore store = widget.store ?? AppStore();
  AppleMembershipPurchases? applePurchases;
  final navigatorKey = GlobalKey<NavigatorState>();
  final shellKey = GlobalKey<AppShellState>();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  final files = ResumeFiles.instance;
  bool openingImport = false;
  bool entryAllowed = false;
  bool preparingStartup = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    entryAllowed = store.isAuthenticated || store.isGuest;
    store.addListener(sessionChanged);
    files.incoming.addListener(sharedFileChanged);
    files.error.addListener(sharedFileError);
    unawaited(files.start());
    unawaited(prepareStartup());
  }

  Future<void> prepareStartup() async {
    try {
      await WidgetsBinding.instance.endOfFrame;
      // 同意隐私政策前不读取设备信息、不恢复登录、不初始化任何 SDK。
      if (widget.requirePrivacyConsent ?? widget.store == null) {
        await PrivacyConsent.ensure(
          store.storage,
          () => navigatorKey.currentContext!,
        );
        if (!mounted) return;
      }
      if (usesAppleMembership) {
        applePurchases = AppleMembershipPurchases.forStore(store);
      }
      // Restore the session while the local animation plays; never request an ad.
      unawaited(AppUpdates.instance.refresh(store));
      final initialization = store.initialize();
      final reduceMotion = WidgetsBinding
          .instance
          .platformDispatcher
          .accessibilityFeatures
          .disableAnimations;
      await Future.wait([
        initialization,
        store.appearance.restore(),
        if (widget.startupAnimationEnabled && !reduceMotion)
          Future<void>.delayed(startupAnimationDuration),
      ]);
    } finally {
      BannerAds.ready.value = mounted && widget.bannerAdsEnabled;
      if (mounted) {
        setState(() => preparingStartup = false);
        sharedFileChanged();
      }
    }
  }

  void sessionChanged() {
    final allowed = store.isAuthenticated || store.isGuest;
    final entryChanged = entryAllowed != allowed;
    if (entryChanged) {
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
      setState(() => entryAllowed = allowed);
    }
    final notice = store.sessionNotice;
    if (entryChanged && !allowed && notice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = navigatorKey.currentContext;
        if (!mounted || context == null || store.isAuthenticated) return;
        showAppConfirmation(
          context,
          title: notice['title']!,
          content: Text(notice['message']!),
          confirmLabel: '知道了',
          cancelLabel: null,
        );
      });
    }
    if (store.isAuthenticated) {
      sharedFileChanged();
      unawaited(MembershipStatus.instance.refresh(store));
    } else {
      MembershipStatus.instance.reset();
    }
  }

  void sharedFileChanged() {
    if (preparingStartup ||
        !store.foreground ||
        !store.isAuthenticated ||
        files.activeImports > 0 ||
        files.incoming.value == null ||
        openingImport) {
      return;
    }
    openingImport = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      openingImport = false;
      if (!mounted || !store.isAuthenticated || files.activeImports > 0) return;
      final file = files.incoming.value;
      final navigator = navigatorKey.currentState;
      if (file == null || navigator == null) return;
      files.incoming.value = null;
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => ImportResume(
            store: store,
            initialFile: file,
            onSaved: () {
              shellKey.currentState?.select(AppShell.profileTab);
              navigator.popUntil((route) => route.isFirst);
              navigator.push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppPageBar(title: const Text('我的简历')),
                    body: SafeArea(
                      child: ResumeLibrary(store: store, embedded: true),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    });
  }

  void sharedFileError() {
    final message = files.error.value;
    if (message == null) return;
    files.error.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final messenger = messengerKey.currentState;
        if (messenger != null) {
          messenger.showSnackBar(appFeedbackBar(messenger.context, message));
        }
      }
    });
  }

  @override
  void dispose() {
    BannerAds.ready.value = false;
    WidgetsBinding.instance.removeObserver(this);
    store.removeListener(sessionChanged);
    files.incoming.removeListener(sharedFileChanged);
    files.error.removeListener(sharedFileError);
    applePurchases?.dispose();
    store.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      store.setForeground(true);
      if (!preparingStartup) unawaited(AppUpdates.instance.refresh(store));
      unawaited(applePurchases?.syncUnfinished());
      unawaited(MembershipStatus.instance.refresh(store, force: true));
      sharedFileChanged();
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      store.setForeground(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = Builder(
      builder: (context) {
        return AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 380),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, .025),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          layoutBuilder: (current, previous) => Stack(
            fit: StackFit.expand,
            children: [
              for (final child in previous)
                ExcludeSemantics(child: IgnorePointer(child: child)),
              ?current,
            ],
          ),
          child: preparingStartup
              ? StartupAnimation(
                  key: const ValueKey('startup-session-gate'),
                  animate: widget.startupAnimationEnabled,
                )
              : entryAllowed
              ? AppShell(key: shellKey, store: store)
              : AuthPage(key: const ValueKey('signed-out-home'), store: store),
        );
      },
    );
    return ValueListenableBuilder<AppearanceChoice>(
      valueListenable: store.appearance,
      child: home,
      builder: (context, appearance, home) => MaterialApp(
        themeAnimationStyle: AnimationStyle.noAnimation,
        title: '拾页',
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: messengerKey,
        debugShowCheckedModeBanner: false,
        theme: appearance.accent.lightTheme,
        darkTheme: appearance.accent.darkTheme,
        themeMode: appearance.mode,
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        ),
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: appSystemUiStyle(context),
          child: Actions(
            actions: {
              EditableTextTapOutsideIntent:
                  CallbackAction<EditableTextTapOutsideIntent>(
                    onInvoke: (intent) {
                      intent.focusNode.unfocus();
                      return null;
                    },
                  ),
            },
            child: TooltipVisibility(
              visible: false,
              child: AppEnvironment.isLocal
                  ? Banner(
                      message: '本地测试',
                      location: BannerLocation.topEnd,
                      child: child!,
                    )
                  : child!,
            ),
          ),
        ),
        home: home,
      ),
    );
  }
}
