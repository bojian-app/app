import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
// The production plugin exposes its platform interface for test implementations.
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class FakeTemplateWebView extends WebViewPlatform {
  final controllers = <FakeTemplateWebController>[];
  final loaded = Completer<void>();
  bool autoReady = true;
  void install() => WebViewPlatform.instance = this;
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final value = FakeTemplateWebController(params, this);
    controllers.add(value);
    return value;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => FakeTemplateNavigation(params);
  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => FakeTemplateWebWidget(params);
}

class FakeTemplateWebController extends PlatformWebViewController {
  FakeTemplateWebController(super.params, this.owner) : super.implementation();
  final FakeTemplateWebView owner;
  JavaScriptChannelParams? channel;
  FakeTemplateNavigation? navigation;
  String? html, filePath;
  final scripts = <String>[];
  int loadCount = 0;
  @override
  Future<void> loadFile(String absoluteFilePath) async {
    loadCount++;
    filePath = absoluteFilePath;
    html = await File(absoluteFilePath).readAsString();
    if (owner.autoReady) message('{"type":"ready","count":2}');
    if (!owner.loaded.isCompleted) owner.loaded.complete();
  }

  void message(String value) =>
      channel!.onMessageReceived(JavaScriptMessage(message: value));
  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}
  @override
  Future<void> setBackgroundColor(Color color) async {}
  @override
  Future<void> runJavaScript(String script) async {
    scripts.add(script);
    final openPage = RegExp(r'^window\.openPreviewPage\?\.\((\d+)\);$')
        .firstMatch(script);
    if (openPage != null) {
      message('{"type":"open-page","index":${openPage.group(1)}}');
    }
  }

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {
    channel = params;
  }

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {
    navigation = handler as FakeTemplateNavigation;
  }
}

class FakeTemplateNavigation extends PlatformNavigationDelegate {
  FakeTemplateNavigation(super.params) : super.implementation();
  NavigationRequestCallback? request;
  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async {
    request = callback;
  }

  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async {}
  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {}
}

class FakeTemplateWebWidget extends PlatformWebViewWidget {
  FakeTemplateWebWidget(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Colors.white,
    child: SizedBox.expand(key: ValueKey('live-template-webview')),
  );
}
