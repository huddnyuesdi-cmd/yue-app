class LayoutConfig {
  static const double maxFormWidth = 480;

  static double getPublishMaxWidth(double screenWidth) {
    if (screenWidth >= 1200) return 680;
    if (screenWidth >= 768) return 600;
    return 480;
  }

  static int getGridColumnCount(double width) {
    return 2;
  }
}
