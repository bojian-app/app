import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_qr_scanner.dart';

final _inviteCodePattern = RegExp(r'^[2-9A-HJKMNP-Z]{8}$');

/// Returns the invite code carried by a shared invitation QR code, or null
/// when [raw] is anything else. Codes are matched case-insensitively.
String? parseInvitationCode(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (raw.length > 512 ||
      uri == null ||
      uri.scheme != 'https' ||
      uri.host != 'bojian.kelance.cn' ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  final values = uri.queryParametersAll['invite_code'];
  if (values == null || values.length != 1) return null;
  final code = values.single.trim().toUpperCase();
  return _inviteCodePattern.hasMatch(code) ? code : null;
}

/// Full-screen scanner for a friend's invitation QR code; pops with the
/// code it found.
class InvitationScanPage extends StatefulWidget {
  const InvitationScanPage({super.key, this.scannerBuilder});

  /// Replaces the camera in tests.
  final Widget Function(BuildContext, ValueChanged<String> onCode)?
  scannerBuilder;

  @override
  State<InvitationScanPage> createState() => _InvitationScanPageState();
}

class _InvitationScanPageState extends State<InvitationScanPage> {
  Key _scannerKey = UniqueKey();

  void _detect(String raw) {
    final code = parseInvitationCode(raw);
    if (code != null) {
      Navigator.of(context).pop(code);
      return;
    }
    // The scanner stops after one result; remount it for another try.
    setState(() => _scannerKey = UniqueKey());
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('请扫描好友分享的博简邀请二维码')));
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
    child: Scaffold(
      key: const ValueKey('invitation-scan-page'),
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          KeyedSubtree(
            key: _scannerKey,
            child:
                widget.scannerBuilder?.call(context, _detect) ??
                AppQRScanner(onCode: _detect, hint: '对准好友分享的邀请二维码，自动识别'),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton(
                  key: const ValueKey('invitation-scan-cancel'),
                  onPressed: () => Navigator.maybePop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    minimumSize: const Size(64, 48),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  child: const Text('取消'),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
