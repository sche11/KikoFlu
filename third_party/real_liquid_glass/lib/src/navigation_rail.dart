import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import 'bottom_bar.dart';

/// Native glass buttons for a vertical navigation rail on iOS 26+.
/// UIKit owns button content, pressed effects and scrolling on short screens.
class NativeGlassNavigationRail extends StatefulWidget {
  const NativeGlassNavigationRail({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onChanged,
    required this.selectedColor,
    required this.selectedBackgroundColor,
    required this.foregroundColor,
    required this.fontSize,
    this.badgeIndex,
    this.badgeColor,
  }) : assert(items.length >= 2),
       assert(currentIndex >= 0 && currentIndex < items.length);

  final List<LiquidGlassBarItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final Color selectedColor;
  final Color selectedBackgroundColor;
  final Color foregroundColor;
  final double fontSize;
  final int? badgeIndex;
  final Color? badgeColor;

  @override
  State<NativeGlassNavigationRail> createState() =>
      _NativeGlassNavigationRailState();
}

class _NativeGlassNavigationRailState extends State<NativeGlassNavigationRail> {
  MethodChannel? _channel;

  Map<String, Object?> get _params => {
    'items': [
      for (final item in widget.items)
        {
          'label': item.label,
          'symbol': item.sfSymbol,
          'selectedSymbol': item.selectedSfSymbol ?? item.sfSymbol,
        },
    ],
    'currentIndex': widget.currentIndex,
    'selectedColor': widget.selectedColor.toARGB32(),
    'selectedBackgroundColor': widget.selectedBackgroundColor.toARGB32(),
    'foregroundColor': widget.foregroundColor.toARGB32(),
    'fontSize': widget.fontSize,
    'badgeIndex': widget.badgeIndex,
    'badgeColor': widget.badgeColor?.toARGB32(),
    'dark': CupertinoTheme.brightnessOf(context) == Brightness.dark,
    'rtl': Directionality.of(context) == TextDirection.rtl,
  };

  void _update() => _channel?.invokeMethod<void>('update', _params);

  @override
  void didUpdateWidget(NativeGlassNavigationRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _update();
  }

  void _onCreated(int id) {
    if (!mounted) return;
    _channel = MethodChannel('real_liquid_glass/navigation_rail_$id');
    _channel!.setMethodCallHandler((call) async {
      if (call.method != 'selected' || call.arguments is! Map) return;
      final index = (call.arguments as Map)['index'];
      if (index is int && index >= 0 && index < widget.items.length) {
        widget.onChanged(index);
      }
    });
    _update();
  }

  @override
  Widget build(BuildContext context) => UiKitView(
    viewType: 'real_liquid_glass/navigation_rail',
    creationParams: _params,
    creationParamsCodec: const StandardMessageCodec(),
    gestureRecognizers: const {
      Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
    },
    onPlatformViewCreated: _onCreated,
  );

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }
}
