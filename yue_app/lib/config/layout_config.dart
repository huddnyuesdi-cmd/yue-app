class LayoutConfig {
  static const double maxFormWidth = 480;

  /// Returns a responsive max form width for tablets.
  /// On screens wider than 600px (tablet), allows up to 680px.
  static double getMaxFormWidth(double screenWidth) {
    if (screenWidth >= 900) return 680;
    if (screenWidth >= 600) return 560;
    return maxFormWidth;
  }

  static int getGridColumnCount(double width) {
    if (width >= 900) return 4;
    if (width >= 600) return 3;
    return 2;
  }

  /// Returns the media grid column count for the publish page.
  static int getMediaGridColumnCount(double width) {
    if (width >= 600) return 4;
    return 3;
  }
}
