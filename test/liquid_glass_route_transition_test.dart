import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/utils/app_page_route.dart';
import 'package:real_liquid_glass/real_liquid_glass.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    testWidgets(
      'keeps native glass mounted during $platform route transitions',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        try {
          final nativeViewType = platform == TargetPlatform.iOS
              ? UiKitView
              : AppKitView;
          final navigatorKey = GlobalKey<NavigatorState>();

          Widget glassPage() => const Scaffold(
            body: Center(
              child: SizedBox(
                width: 160,
                height: 64,
                child: LiquidGlassContainer(child: Text('Mini player')),
              ),
            ),
          );

          await tester.pumpWidget(
            MaterialApp(navigatorKey: navigatorKey, home: glassPage()),
          );
          await tester.pumpAndSettle();
          expect(find.byType(nativeViewType), findsOneWidget);
          final originalNativeView = tester.element(
            find.byType(nativeViewType),
          );

          navigatorKey.currentState!.push(
            AppPageRoute<void>(builder: (_) => glassPage()),
          );
          await tester.pump();
          expect(find.byType(nativeViewType), findsWidgets);
          expect(originalNativeView.mounted, isTrue);

          await tester.pumpAndSettle();
          expect(find.byType(nativeViewType), findsOneWidget);

          final detailNativeView = tester.element(find.byType(nativeViewType));
          final gesture = await tester.startGesture(const Offset(240, 150));
          await gesture.moveBy(const Offset(30, 0));
          await gesture.moveBy(const Offset(140, 0));
          await tester.pump();
          expect(originalNativeView.mounted, isTrue);
          expect(detailNativeView.mounted, isTrue);
          await gesture.cancel();
          await tester.pumpAndSettle();
          expect(tester.element(find.byType(nativeViewType)), detailNativeView);

          await tester.timedDragFrom(
            const Offset(240, 150),
            const Offset(520, 0),
            const Duration(seconds: 1),
          );
          await tester.pump();
          expect(find.byType(nativeViewType), findsWidgets);
          expect(originalNativeView.mounted, isTrue);
          await tester.pumpAndSettle();
          expect(
            tester.element(find.byType(nativeViewType)),
            originalNativeView,
          );
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }
}
