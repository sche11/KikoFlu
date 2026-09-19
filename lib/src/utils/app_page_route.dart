import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A standard page route with touch-driven content-area swipe back.
///
/// Use this for pages whose primary interaction is vertical scrolling. Keep
/// MaterialPageRoute for pagers, image/PDF viewers and text selection/editing
/// pages where dragging is a primary interaction.
/// Child horizontal gestures (sliders, carousels, the mini player, etc.) enter
/// the gesture arena first and retain priority over this route's recognizer.
class AppPageRoute<T> extends MaterialPageRoute<T> {
  AppPageRoute({
    required super.builder,
    super.settings,
    super.fullscreenDialog,
  });

  NavigatorState? _gestureNavigator;
  AnimationStatusListener? _settleListener;

  bool get _canStartContentGesture =>
      isCurrent &&
      popGestureEnabled &&
      secondaryAnimation!.isDismissed &&
      !navigator!.userGestureInProgress;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final theme = Theme.of(context);
    final builder = theme.pageTransitionsTheme.builders[theme.platform];
    // Predictive transitions need Android's system start/update/commit events.
    // A content drag only drives the route animation, so use that builder's
    // ordinary transition to finish fading out instead of disappearing at 90%
    // scale. Actual system back gestures continue through the framework below.
    final PageTransitionsBuilder? contentTransition = switch (builder) {
      PredictiveBackPageTransitionsBuilder(:final fallbackColor) =>
        FadeForwardsPageTransitionsBuilder(backgroundColor: fallbackColor),
      PredictiveBackFullscreenPageTransitionsBuilder(:final fallbackColor) =>
        ZoomPageTransitionsBuilder(backgroundColor: fallbackColor),
      _ => null,
    };
    final transition = _gestureNavigator != null && contentTransition != null
        ? contentTransition.buildTransitions(
            this,
            context,
            animation,
            secondaryAnimation,
            child,
          )
        : super.buildTransitions(context, animation, secondaryAnimation, child);
    if (fullscreenDialog) {
      return transition;
    }

    // Retain the platform's route transition and system back gestures, including
    // their Hero and native platform-view lifecycles throughout the gesture.
    return _ContentBackGesture<T>(route: this, child: transition);
  }

  void _startContentGesture() {
    if (!_canStartContentGesture) return;
    _gestureNavigator = navigator!;
    _gestureNavigator!.didStartUserGesture();
  }

  void _updateContentGesture(double delta) {
    if (_gestureNavigator == null || _settleListener != null || !isCurrent) {
      return;
    }
    controller!.value -= delta;
  }

  void _endContentGesture(double velocity, {bool canceled = false}) {
    final gestureNavigator = _gestureNavigator;
    if (gestureNavigator == null || _settleListener != null) return;

    // Match Cupertino's distance/velocity decision and settling curve. A system
    // cancellation or a newly installed PopScope must restore the page.
    final bool restore;
    if (!isCurrent) {
      restore = isActive;
    } else {
      restore =
          canceled ||
          willHandlePopInternally ||
          popDisposition == RoutePopDisposition.doNotPop ||
          (velocity.abs() >= 1.0 ? velocity <= 0 : controller!.value > 0.5);
    }

    const duration = Duration(milliseconds: 350);
    const curve = Curves.fastEaseInToSlowEaseOut;
    if (restore) {
      controller!.animateTo(1.0, duration: duration, curve: curve);
    } else {
      if (isCurrent) gestureNavigator.pop();
      if (controller!.isAnimating) {
        controller!.animateBack(0.0, duration: duration, curve: curve);
      }
    }

    if (controller!.isAnimating) {
      _settleListener = (status) {
        if (status == AnimationStatus.completed ||
            status == AnimationStatus.dismissed) {
          _stopContentGesture();
        }
      };
      controller!.addStatusListener(_settleListener!);
    } else {
      _stopContentGesture();
    }
  }

  void _stopContentGesture() {
    if (_settleListener != null) {
      controller!.removeStatusListener(_settleListener!);
      _settleListener = null;
    }
    final gestureNavigator = _gestureNavigator;
    _gestureNavigator = null;
    if (gestureNavigator?.mounted ?? false) {
      gestureNavigator!.didStopUserGesture();
    }
  }

  @override
  void dispose() {
    if (_settleListener != null) {
      controller!.removeStatusListener(_settleListener!);
      _settleListener = null;
    }
    final gestureNavigator = _gestureNavigator;
    _gestureNavigator = null;
    if (gestureNavigator != null) {
      // The route can be removed while a finger is still down. Notify after
      // disposal, when the navigator is no longer updating its route history.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (gestureNavigator.mounted) gestureNavigator.didStopUserGesture();
      });
    }
    super.dispose();
  }
}

class _ContentBackGesture<T> extends StatefulWidget {
  const _ContentBackGesture({required this.route, required this.child});

  final AppPageRoute<T> route;
  final Widget child;

  @override
  State<_ContentBackGesture<T>> createState() => _ContentBackGestureState<T>();
}

class _ContentBackGestureState<T> extends State<_ContentBackGesture<T>> {
  late final _BackDragRecognizer _recognizer = _BackDragRecognizer()
    ..onStart = (_) {
      widget.route._startContentGesture();
    }
    ..onUpdate = (details) {
      widget.route._updateContentGesture(
        details.primaryDelta! * _direction / _width,
      );
    }
    ..onEnd = (details) {
      widget.route._endContentGesture(
        details.velocity.pixelsPerSecond.dx * _direction / _width,
      );
    }
    ..onCancel = () {
      widget.route._endContentGesture(0, canceled: true);
    };

  double _direction = 1;
  double _width = 1;

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.route._canStartContentGesture) return;
    // Desktop text fields do not always claim horizontal touch drags. Keep
    // caret/selection gestures inside editors out of the route gesture arena.
    final hitTest = HitTestResult();
    WidgetsBinding.instance.hitTestInView(
      hitTest,
      event.position,
      event.viewId,
    );
    if (hitTest.path.any((entry) => entry.target is RenderEditable)) return;
    _direction = Directionality.of(context) == TextDirection.ltr ? 1 : -1;
    _width = context.size!.width;
    if (_width <= 0) return;
    _recognizer
      ..direction = _direction
      ..gestureSettings = MediaQuery.gestureSettingsOf(context)
      ..addPointer(event);
  }

  @override
  void dispose() {
    _recognizer.dispose();
    final route = widget.route;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      route._endContentGesture(0, canceled: true);
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: _onPointerDown,
    onPointerCancel: (_) => widget.route._endContentGesture(0, canceled: true),
    child: widget.child,
  );
}

class _BackDragRecognizer extends HorizontalDragGestureRecognizer {
  _BackDragRecognizer() : super(supportedDevices: {PointerDeviceKind.touch}) {
    onlyAcceptDragOnThreshold = true;
  }

  double direction = 1;

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) {
    if (!super.hasSufficientGlobalDistanceToAccept(
      pointerDeviceKind,
      deviceTouchSlop,
    )) {
      return false;
    }
    if (globalDistanceMoved * direction <= 0) {
      resolve(GestureDisposition.rejected);
      return false;
    }
    return true;
  }
}
