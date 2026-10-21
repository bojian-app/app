import 'package:bojian_mobile/ads/ads_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pangle_ads/pangle_ads.dart';

void main() {
  testWidgets('广告未就绪时 Banner 不占位，也不创建原生视图', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AdsBanner())),
    );

    expect(find.byType(PangleBannerView), findsNothing);
    expect(tester.getSize(find.byType(AdsBanner)), Size.zero);
  });
}
