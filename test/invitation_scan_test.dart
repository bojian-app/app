import 'package:bojian_mobile/invitation_scan_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Only shared invitation links yield a code', () {
    expect(
      parseInvitationCode('https://bojian.kelance.cn?invite_code=k7q2m9xd'),
      'K7Q2M9XD',
    );
    expect(
      parseInvitationCode('https://bojian.kelance.cn/?invite_code=K7Q2M9XD'),
      'K7Q2M9XD',
    );
    for (final raw in [
      'K7Q2M9XD',
      'http://bojian.kelance.cn?invite_code=K7Q2M9XD',
      'https://evil.example?invite_code=K7Q2M9XD',
      'https://bojian.kelance.cn?invite_code=100000',
      'https://bojian.kelance.cn?invite_code=K7Q2M9XO',
      'https://bojian.kelance.cn?invite_code=K7Q2M9XD&invite_code=A2B3C4D5',
      'https://bojian.kelance.cn/app-login#v=1',
    ]) {
      expect(parseInvitationCode(raw), isNull, reason: raw);
    }
  });

  testWidgets('Scanning returns the code and ignores other QR codes', (
    tester,
  ) async {
    late ValueChanged<String> scan;
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => InvitationScanPage(
                    scannerBuilder: (context, onCode) {
                      scan = onCode;
                      return const SizedBox.expand();
                    },
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    scan('https://example.com');
    await tester.pump();
    expect(find.text('请扫描好友分享的最优简邀请二维码'), findsOneWidget);
    expect(find.byKey(const ValueKey('invitation-scan-page')), findsOneWidget);
    scan('https://bojian.kelance.cn?invite_code=a2b3c4d5');
    await tester.pumpAndSettle();
    expect(result, 'A2B3C4D5');
  });
}
