class LayoutConfig {
  static const double tabletBreakpoint = 600;
  static const double largeTabletBreakpoint = 900;
  static const double maxFormWidth = 480;

  static int getGridColumnCount(double width) {
    if (width >= largeTabletBreakpoint) return 4;
    if (width >= tabletBreakpoint) return 3;
    return 2;
  }

  static bool isTablet(double width) => width >= tabletBreakpoint;

  static double getFormHorizontalPadding(double width) {
    if (width >= largeTabletBreakpoint) return (width - maxFormWidth) / 2;
    if (width >= tabletBreakpoint) return (width - maxFormWidth) / 2;
    return 28;
  }
}
