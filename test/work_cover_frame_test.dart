import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/l10n/app_localizations.dart';
import 'package:kikoeru_flutter/src/widgets/work_detail/work_cover_frame.dart';

Widget _testApp(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('renders cover layers inside a hero frame', (tester) async {
    await tester.pumpWidget(
      _testApp(
        const WorkCoverFrame(
          heroTag: 'cover-1',
          isLandscape: false,
          layers: [
            Center(child: Text('Cover Layer')),
          ],
        ),
      ),
    );

    expect(find.byType(Hero), findsOneWidget);
    expect(find.text('Cover Layer'), findsOneWidget);
    expect(find.text('Subtitle'), findsNothing);
  });

  testWidgets('shows subtitle badge and handles long press', (tester) async {
    var longPressCount = 0;

    await tester.pumpWidget(
      _testApp(
        WorkCoverFrame(
          heroTag: 'cover-2',
          isLandscape: true,
          showSubtitleBadge: true,
          onLongPress: () => longPressCount++,
          layers: const [
            Center(child: Text('Cover Layer')),
          ],
        ),
      ),
    );

    expect(find.text('Subtitle'), findsOneWidget);

    await tester.longPress(find.text('Cover Layer'));

    expect(longPressCount, 1);
  });
}
