import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/utils/app_page_route.dart';

class _GestureObserver extends NavigatorObserver {
  int starts = 0;
  int stops = 0;

  @override
  void didStartUserGesture(
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
  ) {
    starts++;
  }

  @override
  void didStopUserGesture() {
    stops++;
  }
}

void main() {
  void testPlatformWidgets(String description, WidgetTesterCallback callback) {
    testWidgets(description, callback, variant: TargetPlatformVariant.all());
  }

  Future<AppPageRoute<void>> openPage(
    WidgetTester tester, {
    Widget? body,
    _GestureObserver? observer,
    bool fullscreenDialog = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [if (observer != null) observer],
        home: const Scaffold(body: Text('Home')),
      ),
    );
    final route = AppPageRoute<void>(
      fullscreenDialog: fullscreenDialog,
      builder: (_) =>
          Scaffold(body: body ?? const Center(child: Text('Details'))),
    );
    tester.state<NavigatorState>(find.byType(Navigator)).push(route);
    await tester.pumpAndSettle();
    return route;
  }

  testPlatformWidgets('content swipe is interactive and can finish or cancel', (
    tester,
  ) async {
    final observer = _GestureObserver();
    final route = await openPage(tester, observer: observer);
    final navigator = route.navigator!;

    final shortDrag = await tester.startGesture(const Offset(240, 300));
    await shortDrag.moveBy(const Offset(30, 0));
    await shortDrag.moveBy(const Offset(140, 0));
    await tester.pump();
    expect(route.animation!.value, inExclusiveRange(0.5, 1.0));
    expect(navigator.userGestureInProgress, isTrue);
    expect(find.text('Home'), findsOneWidget);
    await shortDrag.up();
    await tester.pumpAndSettle();
    expect(route.animation!.value, 1.0);
    expect(route.isCurrent, isTrue);
    expect(navigator.userGestureInProgress, isFalse);
    expect(observer.starts, 1);
    expect(observer.stops, 1);

    await tester.timedDragFrom(
      const Offset(240, 300),
      const Offset(520, 0),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(find.text('Details'), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    expect(navigator.userGestureInProgress, isFalse);
    expect(observer.starts, 2);
    expect(observer.stops, 2);
  });

  testPlatformWidgets('a short right flick from screen center goes back', (
    tester,
  ) async {
    final route = await openPage(tester);
    final navigator = route.navigator!;
    await tester.flingFrom(const Offset(400, 300), const Offset(180, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Details'), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    expect(navigator.userGestureInProgress, isFalse);
  });

  testPlatformWidgets('left swipe and mouse drag do not start content back', (
    tester,
  ) async {
    final observer = _GestureObserver();
    final route = await openPage(tester, observer: observer);
    await tester.dragFrom(const Offset(650, 300), const Offset(-500, 0));
    await tester.pumpAndSettle();
    final mouse = await tester.startGesture(
      const Offset(200, 300),
      kind: PointerDeviceKind.mouse,
    );
    await mouse.moveBy(const Offset(500, 0));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(route.isCurrent, isTrue);
    expect(observer.starts, 0);
  });

  testPlatformWidgets('vertical scroll keeps control of its gesture', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final observer = _GestureObserver();
    final route = await openPage(
      tester,
      observer: observer,
      body: ListView.builder(
        controller: scroll,
        itemExtent: 60,
        itemCount: 50,
        itemBuilder: (_, i) => Text('Row $i'),
      ),
    );
    await tester.dragFrom(const Offset(300, 450), const Offset(30, -250));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(100));
    expect(route.isCurrent, isTrue);
    expect(observer.starts, 0);
  });

  testPlatformWidgets('horizontal carousel wins even at its leading boundary', (
    tester,
  ) async {
    final scroll = ScrollController(initialScrollOffset: 200);
    addTearDown(scroll.dispose);
    final observer = _GestureObserver();
    final route = await openPage(
      tester,
      observer: observer,
      body: Center(
        child: SizedBox(
          height: 160,
          child: ListView.builder(
            controller: scroll,
            scrollDirection: Axis.horizontal,
            itemExtent: 120,
            itemCount: 20,
            itemBuilder: (_, i) => Text('Cover $i'),
          ),
        ),
      ),
    );
    await tester.dragFrom(const Offset(240, 300), const Offset(450, 0));
    await tester.pumpAndSettle();
    expect(scroll.offset, lessThan(200));
    scroll.jumpTo(0);
    await tester.dragFrom(const Offset(240, 300), const Offset(450, 0));
    await tester.pumpAndSettle();
    expect(route.isCurrent, isTrue);
    expect(observer.starts, 0);
  });

  testPlatformWidgets('sliders and switches keep their horizontal gestures', (
    tester,
  ) async {
    var value = 0.25;
    var enabled = false;
    final observer = _GestureObserver();
    final route = await openPage(
      tester,
      observer: observer,
      body: StatefulBuilder(
        builder: (context, setState) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Slider(value: value, onChanged: (v) => setState(() => value = v)),
              Switch.adaptive(
                value: enabled,
                onChanged: (v) => setState(() => enabled = v),
              ),
            ],
          );
        },
      ),
    );
    await tester.drag(find.byType(Slider), const Offset(260, 0));
    await tester.pumpAndSettle();
    expect(value, greaterThan(0.25));
    await tester.drag(find.byType(Switch), const Offset(40, 0));
    await tester.pumpAndSettle();
    expect(enabled, isTrue);
    expect(route.isCurrent, isTrue);
    expect(observer.starts, 0);
  });

  testPlatformWidgets(
    'dismissible mini-player style controls keep the gesture',
    (tester) async {
      var dismissed = false;
      final observer = _GestureObserver();
      final route = await openPage(
        tester,
        observer: observer,
        body: StatefulBuilder(
          builder: (context, setState) {
            return Center(
              child: dismissed
                  ? const SizedBox.shrink()
                  : Dismissible(
                      key: const ValueKey('mini-player'),
                      onDismissed: (_) => setState(() => dismissed = true),
                      child: const SizedBox(height: 100, width: 600),
                    ),
            );
          },
        ),
      );
      await tester.dragFrom(const Offset(240, 300), const Offset(500, 0));
      await tester.pumpAndSettle();
      expect(dismissed, isTrue);
      expect(route.isCurrent, isTrue);
      expect(observer.starts, 0);
    },
  );

  testPlatformWidgets('text-field cursor dragging does not navigate back', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'A long editable setting');
    addTearDown(controller.dispose);
    final observer = _GestureObserver();
    final route = await openPage(
      tester,
      observer: observer,
      body: Center(child: TextField(controller: controller)),
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(TextField), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(route.isCurrent, isTrue);
    expect(observer.starts, 0);
    // An active editor must not disable swiping elsewhere on the page.
    await tester.flingFrom(const Offset(400, 150), const Offset(180, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(observer.starts, 1);
  });

  testPlatformWidgets('PopScope and full-screen dialogs prevent content back', (
    tester,
  ) async {
    final observer = _GestureObserver();
    final guarded = await openPage(
      tester,
      observer: observer,
      body: const PopScope(canPop: false, child: Text('Guarded')),
    );
    await tester.dragFrom(const Offset(200, 300), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(guarded.isCurrent, isTrue);
    expect(observer.starts, 0);

    final dialog = AppPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const Scaffold(body: Text('Dialog')),
    );
    guarded.navigator!.push(dialog);
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(200, 300), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(dialog.isCurrent, isTrue);
    expect(observer.starts, 0);
  });

  testPlatformWidgets(
    'pointer cancellation restores even after half of the page',
    (tester) async {
      final observer = _GestureObserver();
      final route = await openPage(tester, observer: observer);
      final drag = await tester.startGesture(const Offset(200, 300));
      await drag.moveBy(const Offset(30, 0));
      await drag.moveBy(const Offset(450, 0));
      await tester.pump();
      expect(route.animation!.value, lessThan(0.5));
      await drag.cancel();
      await tester.pumpAndSettle();
      expect(route.isCurrent, isTrue);
      expect(route.animation!.value, 1.0);
      expect(observer.starts, 1);
      expect(observer.stops, 1);
    },
  );

  testPlatformWidgets(
    'programmatic navigation during a drag releases gesture state',
    (tester) async {
      final observer = _GestureObserver();
      final route = await openPage(tester, observer: observer);
      final navigator = route.navigator!;
      final drag = await tester.startGesture(const Offset(200, 300));
      await drag.moveBy(const Offset(30, 0));
      await drag.moveBy(const Offset(100, 0));
      await tester.pump();
      navigator.removeRoute(route);
      await tester.pumpAndSettle();
      await drag.up();
      await tester.pumpAndSettle();
      expect(navigator.userGestureInProgress, isFalse);
      expect(observer.starts, 1);
      expect(observer.stops, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testPlatformWidgets('ordinary routes and root cannot content-swipe back', (
    tester,
  ) async {
    final route = await openPage(tester);
    final navigator = route.navigator!;
    final ordinary = MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('Gallery')),
    );
    navigator.push(ordinary);
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(200, 300), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(ordinary.isCurrent, isTrue);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(route.isCurrent, isTrue);
    navigator.removeRouteBelow(route);
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(200, 300), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(route.isCurrent, isTrue);
    expect(route.isFirst, isTrue);
  });

  testPlatformWidgets('a popup opened during the drag is not dismissed', (
    tester,
  ) async {
    final observer = _GestureObserver();
    final route = await openPage(tester, observer: observer);
    final navigator = route.navigator!;
    final drag = await tester.startGesture(const Offset(200, 300));
    await drag.moveBy(const Offset(30, 0));
    await drag.moveBy(const Offset(450, 0));
    await tester.pump();
    showDialog<void>(
      context: tester.element(find.text('Details')),
      builder: (_) => const AlertDialog(content: Text('Confirmation')),
    );
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();
    expect(find.text('Confirmation'), findsOneWidget);
    expect(route.isActive, isTrue);
    expect(route.animation!.value, 1.0);
    expect(navigator.userGestureInProgress, isFalse);
    expect(observer.starts, 1);
    expect(observer.stops, 1);
    await tester.dragFrom(const Offset(200, 300), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Confirmation'), findsOneWidget);
    expect(observer.starts, 1);
  });

  testPlatformWidgets(
    'PopScope becoming blocked during a swipe restores the page',
    (tester) async {
      final canPop = ValueNotifier(true);
      addTearDown(canPop.dispose);
      final route = await openPage(
        tester,
        body: ValueListenableBuilder<bool>(
          valueListenable: canPop,
          builder: (_, value, __) =>
              PopScope(canPop: value, child: const Text('Details')),
        ),
      );
      final drag = await tester.startGesture(const Offset(200, 300));
      await drag.moveBy(const Offset(30, 0));
      await drag.moveBy(const Offset(450, 0));
      canPop.value = false;
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();
      expect(route.isCurrent, isTrue);
      expect(route.animation!.value, 1.0);
      expect(route.navigator!.userGestureInProgress, isFalse);
    },
  );

  testPlatformWidgets('drag handles keep reorder gestures', (tester) async {
    var reorders = 0;
    final observer = _GestureObserver();
    final route = await openPage(
      tester,
      observer: observer,
      body: ReorderableListView.builder(
        itemCount: 5,
        buildDefaultDragHandles: false,
        onReorderItem: (_, __) => reorders++,
        itemBuilder: (_, i) => ListTile(
          key: ValueKey(i),
          title: Text('Setting $i'),
          trailing: ReorderableDragStartListener(
            index: i,
            child: const Icon(Icons.drag_handle),
          ),
        ),
      ),
    );
    final handle = await tester.startGesture(
      tester.getCenter(find.byType(ReorderableDragStartListener).first),
    );
    await handle.moveBy(const Offset(20, 20));
    await tester.pump();
    await handle.moveBy(const Offset(0, 120));
    await tester.pump(const Duration(milliseconds: 500));
    await handle.up();
    await tester.pumpAndSettle();
    expect(reorders, 1);
    expect(route.isCurrent, isTrue);
    expect(observer.starts, 0);
  });

  testPlatformWidgets('Hero participates in interactive content back', (
    tester,
  ) async {
    final flights = <HeroFlightDirection>[];
    Widget cover(double size) => Hero(
      tag: 'cover',
      transitionOnUserGestures: true,
      flightShuttleBuilder: (_, __, direction, from, ___) {
        flights.add(direction);
        return (from.widget as Hero).child;
      },
      child: SizedBox(
        width: size,
        height: size,
        child: const ColoredBox(color: Colors.blue),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: cover(60))),
      ),
    );
    final route = AppPageRoute<void>(
      builder: (_) => Scaffold(body: Center(child: cover(200))),
    );
    tester.state<NavigatorState>(find.byType(Navigator)).push(route);
    await tester.pumpAndSettle();
    expect(flights, contains(HeroFlightDirection.push));
    final drag = await tester.startGesture(const Offset(240, 150));
    await drag.moveBy(const Offset(30, 0));
    await drag.moveBy(const Offset(160, 0));
    await tester.pump();
    expect(flights, contains(HeroFlightDirection.pop));
    await drag.cancel();
    await tester.pumpAndSettle();
    expect(route.isCurrent, isTrue);
    expect(find.byType(Hero), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Android content back fades out before the route is removed',
    (tester) async {
      final route = await openPage(tester);
      final page = tester.element(find.text('Details'));
      final drag = await tester.startGesture(const Offset(240, 300));
      await drag.moveBy(const Offset(30, 0));
      await drag.moveBy(const Offset(440, 0));
      await tester.pump();
      expect(route.animation!.value, lessThan(0.5));
      await drag.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 175));
      expect(page.mounted, isTrue);
      final fades = tester.widgetList<Widget>(
        find.ancestor(
          of: find.text('Details'),
          matching: find.byWidgetPredicate(
            (widget) => widget is Opacity || widget is FadeTransition,
          ),
        ),
      );
      final opacity = fades.fold<double>(
        1,
        (value, widget) =>
            value *
            switch (widget) {
              Opacity(:final opacity) => opacity,
              FadeTransition(:final opacity) => opacity.value,
              _ => 1,
            },
      );
      expect(opacity, lessThan(1));
      await tester.pumpAndSettle();
      expect(find.text('Details'), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'Android system back and content back retain separate gesture lifecycles',
    (tester) async {
      Future<Object?> systemBack(
        String method, [
        Map<String, Object>? args,
      ]) async {
        final reply = await tester.binding.defaultBinaryMessenger
            .handlePlatformMessage(
              SystemChannels.backGesture.name,
              const StandardMethodCodec().encodeMethodCall(
                MethodCall(method, args),
              ),
              null,
            );
        return const StandardMethodCodec().decodeEnvelope(reply!);
      }

      final observer = _GestureObserver();
      final route = await openPage(tester, observer: observer);
      final navigator = route.navigator!;
      const start = <String, Object>{
        'touchOffset': [5.0, 300.0],
        'progress': 0.0,
        'swipeEdge': 0,
      };
      const progress = <String, Object>{
        'touchOffset': [150.0, 300.0],
        'progress': 0.35,
        'swipeEdge': 0,
      };
      expect(await systemBack('startBackGesture', start), isTrue);
      await systemBack('updateBackGestureProgress', progress);
      await tester.pump();
      expect(navigator.userGestureInProgress, isTrue);
      final systemValue = route.animation!.value;
      await tester.dragFrom(const Offset(240, 300), const Offset(400, 0));
      await tester.pump();
      expect(observer.starts, 1);
      expect(route.animation!.value, systemValue);
      await systemBack('cancelBackGesture');
      await tester.pumpAndSettle();
      expect(route.isCurrent, isTrue);
      expect(navigator.userGestureInProgress, isFalse);

      final drag = await tester.startGesture(const Offset(240, 300));
      await drag.moveBy(const Offset(30, 0));
      await drag.moveBy(const Offset(140, 0));
      await tester.pump();
      expect(observer.starts, 2);
      expect(route.animation!.value, lessThan(1));
      await drag.cancel();
      await tester.pumpAndSettle();
      expect(route.isCurrent, isTrue);
      expect(navigator.userGestureInProgress, isFalse);

      expect(await systemBack('startBackGesture', start), isTrue);
      await systemBack('updateBackGestureProgress', progress);
      await tester.pump();
      await systemBack('commitBackGesture');
      await tester.pumpAndSettle();
      expect(find.text('Details'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
      expect(navigator.userGestureInProgress, isFalse);
      expect(observer.starts, 3);
      expect(observer.stops, 3);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'Cupertino edge gestures still work on ordinary routes',
    (tester) async {
      final route = await openPage(tester);
      final navigator = route.navigator!;
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Gallery')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(5, 300), const Offset(700, 0));
      await tester.pumpAndSettle();
      expect(route.isCurrent, isTrue);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    }),
  );
}
