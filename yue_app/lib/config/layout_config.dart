import 'package:flutter/widgets.dart';

class LayoutConfig {
  static const double mobileBreakpoint = 450;
  static const double tabletBreakpoint = 600;
  static const double largeTabletBreakpoint = 800;
  static const double desktopBreakpoint = 1200;
  static const double maxFormWidth = 480;

  /// Maximum content width on wide screens to prevent content from stretching.
  static const double maxContentWidth = 800;

  /// Base design width used as scaling reference (standard mobile width).
  static const double baseDesignWidth = 375.0;

  static int getGridColumnCount(double width) {
    if (width >= desktopBreakpoint) return 5;
    if (width >= largeTabletBreakpoint) return 4;
    if (width >= tabletBreakpoint) return 3;
    return 2;
  }

  /// Returns a scale factor relative to the base design width.
  /// Clamped to 0.8–2.0 to prevent excessively small UI on narrow screens
  /// or oversized UI on very wide screens.
  static double scaleFactor(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return (screenWidth / baseDesignWidth).clamp(0.8, 2.0);
  }

  /// Scales a dimension value based on the current screen width.
  static double scaleSize(BuildContext context, double size) {
    return size * scaleFactor(context);
  }
}
