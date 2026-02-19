class LayoutConfig {
  static const double tabletBreakpoint = 600;
  static const double largeTabletBreakpoint = 900;

  static int getGridColumnCount(double width) {
    if (width >= largeTabletBreakpoint) return 4;
    if (width >= tabletBreakpoint) return 3;
    return 2;
  }
}
