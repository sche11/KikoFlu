import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/utils/system_ui_style.dart';

void main() {
  test('transparent system bars disable Android contrast scrims', () {
    expect(transparentSystemBarsStyle.statusBarColor, Colors.transparent);
    expect(
      transparentSystemBarsStyle.systemNavigationBarColor,
      Colors.transparent,
    );
    expect(
      transparentSystemBarsStyle.systemNavigationBarDividerColor,
      Colors.transparent,
    );
    expect(transparentSystemBarsStyle.systemStatusBarContrastEnforced, false);
    expect(
      transparentSystemBarsStyle.systemNavigationBarContrastEnforced,
      false,
    );
  });

  test('transparent system bars use readable icons for theme brightness', () {
    final lightStyle = transparentSystemBarsForBrightness(Brightness.light);
    final darkStyle = transparentSystemBarsForBrightness(Brightness.dark);

    expect(lightStyle.statusBarIconBrightness, Brightness.dark);
    expect(lightStyle.systemNavigationBarIconBrightness, Brightness.dark);
    expect(darkStyle.statusBarIconBrightness, Brightness.light);
    expect(darkStyle.systemNavigationBarIconBrightness, Brightness.light);
  });
}
