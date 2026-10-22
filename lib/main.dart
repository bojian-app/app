import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_shell.dart';
import 'auth_page.dart';
import 'app_store.dart';
import 'confirmation_dialog.dart';
import 'phone_binding_dialog.dart';
import 'design.dart';
import 'startup_ads.dart';
import 'resume_files.dart';
import 'resume_pages.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Keep decoded previews bounded while browsing; old entries are evicted by LRU.
  PaintingBinding.instance.imageCache
    ..maximumSize = 160
    ..maximumSizeBytes = 32 * 1024 * 1024;
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.startupAdsEnabled = true, this.store});
  final bool startupAdsEnabled;
  final AppStore? store;
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final AppStore store = widget.store ?? AppStore();
  final navigatorKey = GlobalKey<NavigatorState>();
  final shellKey = GlobalKey<AppShellState>();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  final files = ResumeFiles.instance;
  bool openingImport = false;
  bool entryAllowed = false;
  int? phoneBindingPromptEpoch;
  bool showingPhoneBinding = false;
  bool preparingStartup = true;
  bool startupInterrupted = false;

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
      await store.initialize();
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      // Only a restored login may request an ad at cold start. A fresh login,
      // guest visit or return from another app must never trigger a late splash.
      if (mounted &&
          widget.startupAdsEnabled &&
          store.isAuthenticated &&
          !startupInterrupted &&
          (WidgetsBinding.instance.lifecycleState == null ||
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed)) {
        await StartupAds.showOnce();
      }
    } finally {
      StartupAds.readyForBanner.value = mounted && widget.startupAdsEnabled;
      if (mounted) {
        setState(() => preparingStartup = false);
        maybeShowPhoneBinding();
        sharedFileChanged();
      }
    }
  }

  void sessionChanged() {
    if (preparingStartup && !store.restoring && !store.isAuthenticated) {
      startupInterrupted = true;
      if (widget.startupAdsEnabled) unawaited(StartupAds.cancel());
    }
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
      maybeShowPhoneBinding();
      sharedFileChanged();
    }
  }

  void maybeShowPhoneBinding() {
    if (preparingStartup ||
        !store.foreground ||
        !store.isAuthenticated ||
        !store.phoneBindingChecked ||
        store.hasBoundPhone ||
        phoneBindingPromptEpoch == store.epoch ||
        showingPhoneBinding) {
      return;
    }
    final version = store.epoch;
    phoneBindingPromptEpoch = version;
    showingPhoneBinding = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final context = navigatorKey.currentContext;
      try {
        if (!mounted ||
            context == null ||
            !store.isAuthenticated ||
            store.epoch != version ||
            store.hasBoundPhone) {
          return;
        }
        await showPhoneBindingDialog(context, store: store);
      } finally {
        showingPhoneBinding = false;
        if (mounted) {
          maybeShowPhoneBinding();
          sharedFileChanged();
        }
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void sharedFileChanged() {
    if (preparingStartup ||
        !store.foreground ||
        !store.isAuthenticated ||
        showingPhoneBinding ||
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
              shellKey.currentState?.select(3);
              navigator.popUntil((route) => route.isFirst);
              navigator.push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('我的简历')),
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
        messengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    });
  }

  @override
  void dispose() {
    if (widget.startupAdsEnabled) unawaited(StartupAds.cancel());
    WidgetsBinding.instance.removeObserver(this);
    store.removeListener(sessionChanged);
    files.incoming.removeListener(sharedFileChanged);
    files.error.removeListener(sharedFileError);
    store.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      store.setForeground(true);
      maybeShowPhoneBinding();
      sharedFileChanged();
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      store.setForeground(false);
      startupInterrupted = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = Builder(
      builder: (context) {
        // A missing session is inconclusive until secure storage has finished.
        // Keep both auth and the app shell out of the first frame, including
        // while the native splash is loading/showing, to avoid flashing either.
        if (preparingStartup) {
          return ColoredBox(
            key: const ValueKey('startup-session-gate'),
            color: context.colors.canvas,
          );
        }
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
          child: entryAllowed
              ? AppShell(key: shellKey, store: store)
              : AuthPage(key: const ValueKey('signed-out-home'), store: store),
        );
      },
    );
    return MaterialApp(
      title: '博简',
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      darkTheme: appDarkTheme,
      themeMode: ThemeMode.system,
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
          child: TooltipVisibility(visible: false, child: child!),
        ),
      ),
      home: home,
    );
  }
}
