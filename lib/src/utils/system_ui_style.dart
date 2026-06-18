import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const transparentSystemBarsStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  systemStatusBarContrastEnforced: false,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarContrastEnforced: false,
);

SystemUiOverlayStyle transparentSystemBarsForBrightness(Brightness brightness) {
  final iconBrightness =
      brightness == Brightness.light ? Brightness.dark : Brightness.light;

  return transparentSystemBarsStyle.copyWith(
    statusBarIconBrightness: iconBrightness,
    systemNavigationBarIconBrightness: iconBrightness,
  );
}
