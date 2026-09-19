import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/l10n/app_localizations.dart';
import 'package:kikoeru_flutter/src/providers/auth_provider.dart';
import 'package:kikoeru_flutter/src/providers/settings_provider.dart';
import 'package:kikoeru_flutter/src/screens/search_screen.dart';
import 'package:kikoeru_flutter/src/services/kikoeru_api_service.dart'
    show KikoeruApiService;
import 'package:kikoeru_flutter/src/utils/app_page_route.dart';
import 'package:kikoeru_flutter/src/widgets/floating_feed_toolbar.dart';
import 'package:kikoeru_flutter/src/widgets/main_navigation_rail.dart';
import 'package:real_liquid_glass/real_liquid_glass.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records the actual platform-channel boundary. UIKit's visual effect and
/// native tracking require a device; these tests exercise the Flutter bridge.
class _NativeControls {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final configurations = <int, Map<Object?, Object?>>{};
  final acceptedGestures = <int>{};
  final channels = <MethodChannel>[];
  Completer<void>? creationGate;

  _NativeControls() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final args = call.arguments as Map;
        final viewType = args['viewType'];
        if (viewType != 'real_liquid_glass/segmented_control' &&
            viewType != 'real_liquid_glass/navigation_rail') {
          return null;
        }
        final id = args['id'] as int;
        final bytes = args['params'] as Uint8List;
        configurations[id] =
            const StandardMessageCodec().decodeMessage(
                  ByteData.sublistView(bytes),
                )
                as Map<Object?, Object?>;
        final channel = MethodChannel('${viewType}_$id');
        channels.add(channel);
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'update') {
            configurations[id] = call.arguments as Map<Object?, Object?>;
          }
          return null;
        });
        await creationGate?.future;
      } else if (call.method == 'acceptGesture') {
        acceptedGestures.add((call.arguments as Map)['id'] as int);
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      for (final channel in channels) {
        messenger.setMockMethodCallHandler(channel, null);
      }
    });
  }

  Future<void> select(int viewId, String itemId, {bool reselect = false}) {
    final completion = Completer<void>();
    ServicesBinding.instance.channelBuffers.push(
      'real_liquid_glass/segmented_control_$viewId',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall(reselect ? 'reselected' : 'selected', {'id': itemId}),
      ),
      (_) => completion.complete(),
    );
    return completion.future;
  }

  Future<void> selectNavigation(int viewId, int index) {
    final completion = Completer<void>();
    ServicesBinding.instance.channelBuffers.push(
      'real_liquid_glass/navigation_rail_$viewId',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('selected', {'index': index}),
      ),
      (_) => completion.complete(),
    );
    return completion.future;
  }
}

class _SuggestionsApi extends Fake implements KikoeruApiService {
  @override
  Future<List<dynamic>> getAllTags() async => [];
  @override
  Future<List<dynamic>> getAllVas() async => [];
  @override
  Future<List<dynamic>> getAllCircles() async => [];
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      LiquidGlassNavigationNotifier.preferenceKey: true,
    });
    LiquidGlass.debugOverrideCapabilities(
      const LiquidGlassCapabilities(
        nativeGlass: true,
        reduceTransparency: false,
        osMajorVersion: 26,
      ),
    );
  });
  tearDown(() => LiquidGlass.debugOverrideCapabilities(null));

  void testIosWidgets(String name, WidgetTesterCallback callback) {
    testWidgets(
      name,
      callback,
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  const items = [
    LiquidGlassSegment(id: 'all', label: '全部', sfSymbol: 'square.grid.2x2'),
    LiquidGlassSegment(id: 'popular', label: '热门', sfSymbol: 'flame'),
    LiquidGlassSegment(id: 'recommended', label: '推荐', sfSymbol: 'sparkles'),
  ];

  Widget toolbar({bool collapse = false, ValueChanged<int>? onChanged}) =>
      FloatingFeedToolbar(
        collapseModesWhenNeeded: collapse,
        modeActions: [
          for (var i = 0; i < items.length; i++)
            FloatingFeedModeAction(
              id: items[i].id,
              sfSymbol: items[i].sfSymbol,
              icon: Icons.filter_alt,
              label: items[i].label,
              isSelected: i == 0,
              onPressed: () => onChanged?.call(i),
            ),
        ],
        toolActions: [
          FloatingFeedToolAction(
            icon: Icons.sort,
            tooltip: 'Sort',
            onPressed: () {},
          ),
        ],
      );

  Widget app(Widget child, {double width = 350}) => ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );

  testIosWidgets('iOS 26 mode toolbar uses one complete native selector', (
    tester,
  ) async {
    final native = _NativeControls();
    var selected = -1;
    await tester.pumpWidget(
      app(toolbar(onChanged: (index) => selected = index)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NativeGlassSegmentedControl), findsOneWidget);
    expect(find.text('全部'), findsNothing); // Labels belong to UIKit.
    // The selector must keep the same backing material as the tool capsule.
    expect(find.byType(LiquidGlassContainer), findsNWidgets(2));
    final selectorGlass = tester.widget<LiquidGlassContainer>(
      find.ancestor(
        of: find.byType(NativeGlassSegmentedControl),
        matching: find.byType(LiquidGlassContainer),
      ),
    );
    expect(selectorGlass.style, LiquidGlassStyle.regular);
    expect(selectorGlass.shape, const LiquidGlassShape.capsule());
    final theme = Theme.of(tester.element(find.byType(FloatingFeedToolbar)));
    final config = native.configurations.values.single;
    expect(config['selectedId'], 'all');
    expect(
      config['selectedBackgroundColor'],
      theme.colorScheme.primaryContainer.toARGB32(),
    );
    expect(config['allowReselect'], isFalse);
    expect((config['items'] as List)[1], {
      'id': 'popular',
      'label': '热门',
      'symbol': 'flame',
      'selectedSymbol': null,
    });
    expect(tester.getSize(find.byType(FloatingFeedToolbar)).height, 48);
    await native.select(native.configurations.keys.single, 'popular');
    expect(selected, 1);
  });

  testIosWidgets(
    'rapid native changes preserve the final selection before rebuilding',
    (tester) async {
      final native = _NativeControls();
      var current = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (_, setState) => SizedBox(
              width: 300,
              height: 48,
              child: NativeGlassSegmentedControl(
                items: items,
                currentIndex: current,
                onChanged: (index) => setState(() => current = index),
                segmentWidths: const [100, 100, 100],
                fontSize: 14,
                selectedColor: Colors.blue,
                selectedBackgroundColor: Colors.lightBlue,
                foregroundColor: Colors.grey,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final id = native.configurations.keys.single;
      await native.select(id, 'popular');
      await native.select(id, 'all');
      expect(current, 0);
      await tester.pumpAndSettle();
      expect(native.configurations[id]!['selectedId'], 'all');
    },
  );

  testIosWidgets(
    'selection, theme and labels update without recreating UIKit',
    (tester) async {
      final native = _NativeControls();
      var current = 0;
      var entries = List<LiquidGlassSegment>.of(items);
      var dark = false;
      var fontSize = 14.0;
      var callbacks = 0;
      late StateSetter update;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MaterialApp(
              theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
              ),
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 300,
                    height: 48,
                    child: NativeGlassSegmentedControl(
                      items: entries,
                      currentIndex: current,
                      onChanged: (index) => setState(() {
                        current = index;
                        callbacks++;
                      }),
                      segmentWidths: [for (final _ in entries) 100],
                      fontSize: fontSize,
                      selectedColor: Colors.blue,
                      selectedBackgroundColor: dark
                          ? Colors.indigo
                          : Colors.lightBlue,
                      foregroundColor: Colors.grey,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      final id = native.configurations.keys.single;
      final element = tester.element(find.byType(UiKitView));
      await native.select(id, 'recommended');
      await tester.pumpAndSettle();
      expect(current, 2);
      expect(callbacks, 1);
      expect(native.configurations[id]!['selectedId'], 'recommended');
      update(() {
        entries = [
          items[2],
          const LiquidGlassSegment(
            id: 'all',
            label: 'All',
            sfSymbol: 'square.grid.2x2',
          ),
        ];
        current = 0;
        dark = true;
        fontSize = 20;
      });
      await tester.pumpAndSettle();
      expect(native.configurations[id]!['dark'], isTrue);
      expect(
        native.configurations[id]!['selectedBackgroundColor'],
        Colors.indigo.toARGB32(),
      );
      expect(native.configurations[id]!['fontSize'], 20);
      expect((native.configurations[id]!['items'] as List).length, 2);
      expect(
        ((native.configurations[id]!['items'] as List)[1] as Map)['label'],
        'All',
      );
      await native.select(id, 'popular'); // Removed tab, stale native callback.
      expect(callbacks, 1);
      await native.select(
        id,
        'all',
      ); // Stable ID now maps to a different index.
      await tester.pumpAndSettle();
      expect(current, 1);
      expect(callbacks, 2);
      expect(tester.element(find.byType(UiKitView)), same(element));
      expect(native.configurations.length, 1);
    },
  );

  testIosWidgets(
    'creation catches up with selection changed while awaiting UIKit',
    (tester) async {
      final native = _NativeControls()..creationGate = Completer<void>();
      var current = 0;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return SizedBox(
                width: 300,
                height: 48,
                child: NativeGlassSegmentedControl(
                  items: items,
                  currentIndex: current,
                  onChanged: (_) {},
                  segmentWidths: const [100, 100, 100],
                  fontSize: 14,
                  selectedColor: Colors.blue,
                  selectedBackgroundColor: Colors.lightBlue,
                  foregroundColor: Colors.grey,
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      update(() => current = 2);
      await tester.pump();
      native.creationGate!.complete();
      await tester.pumpAndSettle();
      expect(native.configurations.values.single['selectedId'], 'recommended');
    },
  );

  testIosWidgets('holding and sliding the selector does not start page back', (
    tester,
  ) async {
    final native = _NativeControls();
    await tester.pumpWidget(app(const Text('Home')));
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    final route = AppPageRoute<void>(
      builder: (_) => Scaffold(
        body: Center(child: SizedBox(width: 350, child: toolbar())),
      ),
    );
    navigator.push(route);
    await tester.pumpAndSettle();
    final drag = await tester.startGesture(
      tester.getCenter(find.byType(NativeGlassSegmentedControl)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      native.acceptedGestures,
      contains(native.configurations.keys.single),
    );
    await drag.moveBy(const Offset(180, 0));
    await tester.pump();
    expect(navigator.userGestureInProgress, isFalse);
    expect(route.animation!.value, 1.0);
    await drag.up();
    await tester.pumpAndSettle();
    expect(route.isCurrent, isTrue);
  });

  testIosWidgets(
    'narrow layouts leave scrolling to UIKit or retain the dropdown',
    (tester) async {
      _NativeControls();
      await tester.pumpWidget(app(toolbar(), width: 220));
      await tester.pumpAndSettle();
      expect(find.byType(NativeGlassSegmentedControl), findsOneWidget);
      expect(find.byKey(const ValueKey('feed-mode-scroll')), findsNothing);
      expect(
        tester.getSize(find.byType(NativeGlassSegmentedControl)).width,
        lessThanOrEqualTo(220 - 48 - 8),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(app(toolbar(collapse: true), width: 220));
      await tester.pumpAndSettle();
      expect(find.byType(NativeGlassSegmentedControl), findsNothing);
      await tester.tap(find.byKey(const ValueKey('feed-mode-dropdown')));
      await tester.pumpAndSettle();
      expect(find.text('热门'), findsOneWidget);
      expect(find.text('推荐'), findsOneWidget);
    },
  );

  testWidgets(
    'other platforms and legacy iOS keep their existing controls',
    (tester) async {
      LiquidGlass.debugOverrideCapabilities(
        const LiquidGlassCapabilities(
          nativeGlass: false,
          reduceTransparency: false,
          osMajorVersion: 18,
        ),
      );
      var selected = -1;
      await tester.pumpWidget(
        app(toolbar(onChanged: (index) => selected = index)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NativeGlassSegmentedControl), findsNothing);
      expect(find.byType(LiquidGlassContainer), findsNWidgets(2));
      await tester.tap(find.text('热门'));
      expect(selected, 1);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.android,
      TargetPlatform.windows,
      TargetPlatform.linux,
    }),
  );

  testIosWidgets('disabling glass on iOS 26 restores the Flutter selector', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      LiquidGlassNavigationNotifier.preferenceKey: false,
    });
    _NativeControls();
    await tester.pumpWidget(app(toolbar()));
    await tester.pumpAndSettle();
    expect(find.byType(NativeGlassSegmentedControl), findsNothing);
    expect(find.byType(LiquidGlassContainer), findsNothing);
    expect(find.text('全部'), findsOneWidget);
  });

  testIosWidgets(
    'search uses native segments and preserves include/exclude taps',
    (tester) async {
      final native = _NativeControls();
      final theme = ThemeData(colorSchemeSeed: Colors.teal);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            kikoeruApiServiceProvider.overrideWithValue(_SuggestionsApi()),
          ],
          child: MaterialApp(
            theme: theme,
            locale: const Locale('zh'),
            localizationsDelegates: S.localizationsDelegates,
            supportedLocales: S.supportedLocales,
            home: const SearchScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NativeGlassSegmentedControl), findsOneWidget);
      final id = native.configurations.keys.single;
      expect(native.configurations[id]!['selectedId'], 'keyword');
      expect(native.configurations[id]!['allowReselect'], isTrue);
      // Native callbacks can arrive before Flutter gets its next frame.
      await native.select(id, 'tag');
      await native.select(id, 'tag', reselect: true);
      await tester.pumpAndSettle();
      expect(find.text('排除: 标签'), findsOneWidget);
      await native.select(id, 'keyword');
      await tester.pumpAndSettle();
      for (final entry in [('tag', '标签'), ('va', '声优'), ('circle', '社团')]) {
        await native.select(id, entry.$1);
        await tester.pumpAndSettle();
        expect(find.text('包含：${entry.$2}（再次点击进入排除模式）'), findsOneWidget);
        expect(
          native.configurations[id]!['selectedBackgroundColor'],
          theme.colorScheme.primaryContainer.toARGB32(),
        );
        await native.select(id, entry.$1, reselect: true);
        await tester.pumpAndSettle();
        expect(find.text('排除: ${entry.$2}'), findsOneWidget);
        final config = native.configurations[id]!;
        expect(
          config['selectedBackgroundColor'],
          theme.colorScheme.errorContainer.toARGB32(),
        );
        expect(
          (config['items'] as List).cast<Map>().singleWhere(
            (item) => item['id'] == entry.$1,
          )['selectedSymbol'],
          'minus.circle',
        );
        // Ignore stale or invalid reselect callbacks, including an old tab.
        await native.select(id, 'keyword', reselect: true);
        await native.select(id, 'removed', reselect: true);
        await tester.pumpAndSettle();
        expect(find.text('排除: ${entry.$2}'), findsOneWidget);
        await native.select(id, entry.$1, reselect: true);
        await tester.pumpAndSettle();
        expect(find.text('包含：${entry.$2}（再次点击进入排除模式）'), findsOneWidget);
      }
      await native.select(id, 'keyword');
      await tester.pumpAndSettle();
      expect(find.textContaining('排除'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  const destinations = [
    NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
    NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
    NavigationDestination(icon: Icon(Icons.favorite), label: 'My'),
    NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
  ];

  testIosWidgets('rail viewport shrinks with the keyboard in landscape', (
    tester,
  ) async {
    _NativeControls();
    await tester.binding.setSurfaceSize(const Size(800, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(800, 400),
            padding: EdgeInsets.only(top: 24),
            viewInsets: EdgeInsets.only(bottom: 200),
          ),
          child: Scaffold(
            body: Row(
              children: [
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: MainNavigationRail(
                      selectedIndex: 0,
                      onDestinationSelected: (_) {},
                      destinations: destinations,
                      liquidGlass: true,
                    ),
                  ),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(NativeGlassNavigationRail)),
      const Size(96, 160),
    );
    expect(tester.takeException(), isNull);
  });

  testIosWidgets(
    'landscape rail uses native buttons and keeps selection, theme and badge',
    (tester) async {
      final native = _NativeControls();
      var selected = 0;
      var showBadge = true;
      var dark = false;
      var height = 600.0;
      late StateSetter update;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MaterialApp(
              theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
              ),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    height: height,
                    child: MainNavigationRail(
                      selectedIndex: selected,
                      onDestinationSelected: (index) =>
                          setState(() => selected = index),
                      destinations: destinations,
                      liquidGlass: true,
                      showUpdateBadge: showBadge,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NativeGlassNavigationRail), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      final id = native.configurations.keys.single;
      final element = tester.element(find.byType(UiKitView));
      expect(native.configurations[id]!['badgeIndex'], 3);
      expect((native.configurations[id]!['items'] as List)[0], {
        'label': 'Home',
        'symbol': 'house',
        'selectedSymbol': 'house.fill',
      });
      await native.selectNavigation(id, 2);
      await tester.pumpAndSettle();
      expect(selected, 2);
      expect(native.configurations[id]!['currentIndex'], 2);
      await native.selectNavigation(id, -1);
      await native.selectNavigation(id, 4);
      expect(selected, 2);
      update(() {
        showBadge = false;
        dark = true;
        height = 180;
      });
      await tester.pumpAndSettle();
      expect(native.configurations[id]!['badgeIndex'], isNull);
      expect(native.configurations[id]!['dark'], isTrue);
      final theme = Theme.of(tester.element(find.byType(MainNavigationRail)));
      expect(
        native.configurations[id]!['selectedBackgroundColor'],
        theme.colorScheme.primaryContainer.toARGB32(),
      );
      expect(
        tester.getSize(find.byType(NativeGlassNavigationRail)),
        const Size(96, 180),
      );
      expect(tester.element(find.byType(UiKitView)), same(element));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fallback rail exposes glass and honors transparency without native buttons',
    (tester) async {
      LiquidGlass.debugOverrideCapabilities(
        const LiquidGlassCapabilities(
          nativeGlass: false,
          reduceTransparency: false,
          osMajorVersion: 18,
        ),
      );
      var selected = 0;
      Future<void> pumpRail(bool glass) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MainNavigationRail(
                selectedIndex: selected,
                onDestinationSelected: (index) => selected = index,
                destinations: destinations,
                liquidGlass: glass,
                fallbackGlassTransparency: 0.7,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pumpRail(true);
      expect(find.byType(NativeGlassNavigationRail), findsNothing);
      expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .backgroundColor,
        Colors.transparent,
      );
      expect(
        tester
            .widget<LiquidGlassContainer>(find.byType(LiquidGlassContainer))
            .fallbackIntensity,
        0.7,
      );
      await tester.tap(find.byIcon(Icons.search));
      expect(selected, 1);
      await pumpRail(false);
      expect(find.byType(LiquidGlassContainer), findsNothing);
      expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .backgroundColor,
        isNull,
      );
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.android,
      TargetPlatform.windows,
      TargetPlatform.linux,
    }),
  );
}
