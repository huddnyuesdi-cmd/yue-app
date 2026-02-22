class LayoutConfig {
  static const double maxFormWidth = 480;

  static double getPublishMaxWidth(double screenWidth) {
    if (screenWidth >= 1200) return 680;
    if (screenWidth >= 768) return 600;
    return screenWidth;
  }

  static double getPublishHorizontalPadding(double screenWidth) {
    if (screenWidth >= 768) return 24;
    if (screenWidth >= 480) return 20;
    return 16;
  }

  static double getMediaThumbnailSize(double screenWidth) {
    if (screenWidth >= 768) return 100;
    if (screenWidth >= 480) return 90;
    return 80;
  }

  static int getGridColumnCount(double width) {
    return 2;
  }
}
