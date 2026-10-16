import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SharedResumeFile extends XFile {
  SharedResumeFile(super.path, {required this.originalName});

  final String originalName;

  @override
  String get name => originalName;
}

class ResumeFiles {
  ResumeFiles._();
  static final instance = ResumeFiles._();
  static const channel = MethodChannel('cn.kelance.bojian/resume_files');
  final incoming = ValueNotifier<XFile?>(null);
  final error = ValueNotifier<String?>(null);
  int activeImports = 0;

  Future<XFile?> pickLocal() => openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: '简历文件',
        extensions: ['pdf', 'doc', 'docx'],
        mimeTypes: [
          'application/pdf',
          'application/msword',
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        ],
        uniformTypeIdentifiers: [
          'com.adobe.pdf',
          'com.microsoft.word.doc',
          'org.openxmlformats.wordprocessingml.document',
        ],
      ),
    ],
  );

  void receive(dynamic data) {
    if (data is Map && data['error'] is String) {
      error.value = data['error'] as String;
    }
    if (data is Map && data['path'] is String && data['name'] is String) {
      if (incoming.value?.path == data['path']) return;
      incoming.value = SharedResumeFile(
        data['path'] as String,
        originalName: data['name'] as String,
      );
    }
  }

  Future<void> start() async {
    if (!Platform.isAndroid) return;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'sharedResumeAvailable') {
        receive(await channel.invokeMethod<Object?>('takeSharedResume'));
      }
    });
    try {
      receive(await channel.invokeMethod<Object?>('takeSharedResume'));
    } on PlatformException catch (e) {
      error.value = e.message ?? '无法读取分享的文件，请重新选择';
    }
  }

  Future<void> openWeChat() => channel.invokeMethod<void>('openWeChat');
}
