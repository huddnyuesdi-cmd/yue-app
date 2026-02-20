class LayoutConfig {
  static const double tabletBreakpoint = 600;
  static const double largeTabletBreakpoint = 900;
  static const double maxFormWidth = 480;
  static const double _designWidth = 360.0;

  static int getGridColumnCount(double width) {
    if (width >= largeTabletBreakpoint) return 4;
    if (width >= tabletBreakpoint) return 3;
    return 2;
  }

  /// Returns a scale factor based on screen width relative to design width (360).
  /// Clamped between 0.85 and 1.3 to avoid extremes on very small or very large screens.
  static double scaleFactor(double screenWidth) {
    final factor = screenWidth / _designWidth;
    return factor.clamp(0.85, 1.3);
  }

  /// Scales a value responsively based on screen width.
  static double scaleSize(double screenWidth, double value) {
    return value * scaleFactor(screenWidth);
  }
}
