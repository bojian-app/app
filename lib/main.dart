import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_shell.dart';
import 'auth_page.dart';
import 'app_store.dart';
import 'design.dart';
import 'startup_screen.dart';
import 'resume_files.dart';
import 'resume_pages.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  // Keep decoded previews bounded while browsing; old entries are evicted by LRU.
  PaintingBinding.instance.imageCache
    ..maximumSize = 160
    ..maximumSizeBytes = 32 * 1024 * 1024;
  runApp(MyApp(nativeStartup: args.contains('--native-startup')));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.nativeStartup = false, this.store});
  final bool nativeStartup;
  final AppStore? store;
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final AppStore store = widget.store ?? AppStore();
  final navigatorKey = GlobalKey<NavigatorState>();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  final files = ResumeFiles.instance;
  bool openingImport = false;
  bool entryAllowed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    entryAllowed = store.isAuthenticated || store.isGuest;
    store.addListener(sessionChanged);
    files.incoming.addListener(sharedFileChanged);
    files.error.addListener(sharedFileError);
    unawaited(files.start());
    unawaited(store.initialize());
  }

  void sessionChanged() {
    final allowed = store.isAuthenticated || store.isGuest;
    if (entryAllowed == allowed) return;
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
    setState(() => entryAllowed = allowed);
    final notice = store.sessionNotice;
    if (!allowed && notice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = navigatorKey.currentContext;
        if (!mounted || context == null || store.isAuthenticated) return;
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(notice['title']!),
            content: Text(notice['message']!),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
      });
    }
    if (store.isAuthenticated) sharedFileChanged();
  }

  void sharedFileChanged() {
    if (!store.isAuthenticated ||
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
          builder: (_) => ImportResume(store: store, initialFile: file),
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
    WidgetsBinding.instance.removeObserver(this);
    store.removeListener(sessionChanged);
    files.incoming.removeListener(sharedFileChanged);
    files.error.removeListener(sharedFileError);
    store.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) store.setForeground(true);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      store.setForeground(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = Builder(
      builder: (context) => AnimatedSwitcher(
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
            ? AppShell(key: const ValueKey('signed-in-home'), store: store)
            : AuthPage(key: const ValueKey('signed-out-home'), store: store),
      ),
    );
    return MaterialApp(
      title: '博简',
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      ),
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: canvasColor,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
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
          child: child!,
        ),
      ),
      home: widget.nativeStartup ? home : StartupScreen(child: home),
    );
  }
}
