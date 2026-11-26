import 'package:bojian_mobile/app_qr_scan_effect.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/developer_verification_controller.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:bojian_mobile/identity_verification_pages.dart';
import 'package:bojian_mobile/identity_verification_service.dart';
import 'package:bojian_mobile/invitation_scan_page.dart';
import 'package:bojian_mobile/resume_guidance_view.dart';
import 'package:bojian_mobile/resume_photo_crop.dart';
import 'package:bojian_mobile/settings_page.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _OfflineIdentity extends DeveloperVerificationController {
  _OfflineIdentity(AppStore store)
    : super(store: store, pickPhoto: () async => null);

  @override
  final RecognizedIdentity identity = RecognizedIdentity(
    token: 'fixture',
    name: '示例用户',
    maskedNumber: '************0000',
    validFrom: '2026-01-01',
    validUntil: '2036-01-01',
    longTerm: false,
    expiresAt: DateTime.utc(2099),
  );

  @override
  final IdentityFaceSession faceSession = IdentityFaceSession(
    id: 'fixture',
    status: IdentityFaceStatus.pending,
    expiresAt: DateTime.utc(2099),
  );
}

Future<List<({String name, Widget Function() make})>> auxiliaryPerformancePages(
  AppStore store,
) async {
  final controller = _OfflineIdentity(store);
  addTearDown(controller.dispose);
  final asset = await rootBundle.load('assets/customer_service/assistant.webp');
  final photo = XFile.fromData(
    asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
    name: 'sample.webp',
    mimeType: 'image/webp',
  );
  return [
    (name: 'story-search', make: () => StorySearch(store: store)),
    (
      name: 'resume-guidance',
      make: () => ResumeGuidanceView(
        store: store,
        id: 1,
        initialData: {
          'is_owner': true,
          'source_resume_id': store.resumes.first.id,
          'snapshot': store.resumes.first.source,
          'can_review': false,
        },
      ),
    ),
    (
      name: 'account-appeal',
      make: () => buildFeedbackPage(store, appeal: true),
    ),
    (name: 'resume-photo-crop', make: () => ResumePhotoCropPage(file: photo)),
    (
      name: 'identity-confirm',
      make: () => IdentityConfirmationPage(controller: controller),
    ),
    (
      name: 'face-instructions',
      make: () => IdentityFacePage(controller: controller),
    ),
    (
      name: 'scanner-overlay',
      make: () => InvitationScanPage(
        scannerBuilder: (context, onCode) =>
            const AppQRScanEffect(color: Colors.blue, enabled: true),
      ),
    ),
  ];
}
