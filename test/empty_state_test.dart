import 'package:bojian_mobile/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Shared artwork loads in light and dark narrow layouts with large text',
    (tester) async {
      for (final theme in [appTheme, appDarkTheme]) {
        var tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
                child: Center(
                  child: SizedBox(
                    width: 240,
                    height: 210,
                    child: EmptyState(
                      '没有找到相关内容',
                      '试试其他关键词，或去发现页看看。',
                      action: TextButton(
                        onPressed: () => tapped = true,
                        child: const Text('去看看'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(Image), findsOneWidget);
        final image = tester.widget<Image>(find.byType(Image));
        expect(image.excludeFromSemantics, isTrue);
        final provider = image.image as ResizeImage;
        expect(
          (provider.imageProvider as AssetImage).assetName,
          EmptyState.illustrationAsset,
        );
        await tester.ensureVisible(find.text('去看看'));
        await tester.tap(find.text('去看看'));
        expect(tapped, isTrue);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'List empty state stays compact and leaves parent refresh scrollable',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [EmptyState('还没有评论，聊聊你的看法', '', compact: true)],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Scrollable), findsOneWidget);
      expect(tester.getSize(find.byType(EmptyState)).height, lessThan(200));
      expect(tester.takeException(), isNull);
    },
  );
}
