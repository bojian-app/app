import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrintSynchronously;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android update verification serves platform messages', (
    tester,
  ) async {
    if (!Platform.isAndroid) return;
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    const channel = MethodChannel('cn.kelance.bojian/settings');
    final root = await getTemporaryDirectory();
    final dir = Directory('${root.path}/update');
    await dir.create(recursive: true);
    final measurements = <Map<String, int>>[];
    for (var i = 0; i < 4; i++) {
      final file = File('${dir.path}/perf-synthetic-$i.bin');
      final block = Uint8List(1024 * 1024);
      final sink = file.openWrite();
      for (var n = 0; n < 64; n++) {
        sink.add(block);
      }
      await sink.close();
      final clock = Stopwatch()..start();
      final check = channel.invokeMethod<String>('installApk', {
        'path': file.path,
        'sha256': '00',
      });
      // This harmless UI-thread channel message is submitted immediately behind the hash request.
      await channel.invokeMethod<dynamic>('appInfo');
      final queueMicros = clock.elapsedMicroseconds;
      expect(await check, 'checksum');
      measurements.add({
        'platform_reply_us': queueMicros,
        'checksum_done_us': clock.elapsedMicroseconds,
      });
      expect(await file.exists(), false);
    }
    (binding.reportData ??= {})['update_responsiveness'] = measurements;
    debugPrintSynchronously('UPDATE_RESPONSIVENESS $measurements');
  });
}
