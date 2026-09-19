import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

/// A destination in an iOS segmented control. [id] stays stable across locale
/// changes and insertion/removal of neighboring destinations.
@immutable
class LiquidGlassSegment {
  const LiquidGlassSegment({
    required this.id,
    required this.label,
    this.sfSymbol,
  });

  final String id;
  final String label;
  final String? sfSymbol;
}

/// A complete UIKit segmented control, including its touch-driven selection
/// lens on iOS 26+. The caller supplies a fallback on other platforms.
///
/// UIKit renders the labels as well as the surface so they participate in the
/// system lens. A native scroll view keeps long groups accessible on small
/// screens without a Flutter scroll recognizer intercepting selection drags.
class NativeGlassSegmentedControl extends StatefulWidget {
  const NativeGlassSegmentedControl({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onChanged,
    required this.segmentWidths,
    required this.fontSize,
    required this.selectedColor,
    required this.foregroundColor,
  }) : assert(items.length >= 2),
       assert(currentIndex >= 0 && currentIndex < items.length),
       assert(segmentWidths.length == items.length);

  final List<LiquidGlassSegment> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final List<double> segmentWidths;
  final double fontSize;
  final Color selectedColor;
  final Color foregroundColor;

  @override
  State<NativeGlassSegmentedControl> createState() =>
      _NativeGlassSegmentedControlState();
}

class _NativeGlassSegmentedControlState
    extends State<NativeGlassSegmentedControl> {
  MethodChannel? _channel;

  Map<String, Object?> get _params => {
    'items': [
      for (final item in widget.items)
        {'id': item.id, 'label': item.label, 'symbol': item.sfSymbol},
    ],
    'selectedId': widget.items[widget.currentIndex].id,
    'widths': widget.segmentWidths,
    'fontSize': widget.fontSize,
    'selectedColor': widget.selectedColor.toARGB32(),
    'foregroundColor': widget.foregroundColor.toARGB32(),
    'dark': CupertinoTheme.brightnessOf(context) == Brightness.dark,
    'rtl': Directionality.of(context) == TextDirection.rtl,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _update();
  }

  @override
  void didUpdateWidget(NativeGlassSegmentedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  void _update() => _channel?.invokeMethod<void>('update', _params);

  void _onCreated(int id) {
    if (!mounted) return;
    final channel = MethodChannel('real_liquid_glass/segmented_control_$id');
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      if (call.method != 'selected' || call.arguments is! Map) return;
      final id = (call.arguments as Map)['id'];
      final index = widget.items.indexWhere((item) => item.id == id);
      // Ignore delayed callbacks for tabs removed while the platform view was
      // tracking a touch. UIKit already filters repeated selections; comparing
      // with widget.currentIndex here would drop a return selection received
      // before Flutter has rebuilt after the previous native selection.
      if (index >= 0) widget.onChanged(index);
    });
    // Selection/settings may have changed while UIKit was creating the view.
    _update();
  }

  @override
  Widget build(BuildContext context) => UiKitView(
    viewType: 'real_liquid_glass/segmented_control',
    creationParams: _params,
    creationParamsCodec: const StandardMessageCodec(),
    // Deliver touch-down immediately, including a stationary hold. UIKit owns
    // scrolling and tracking inside this control; page-back gestures stay out.
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
