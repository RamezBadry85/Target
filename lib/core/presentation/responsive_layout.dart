abstract final class ResponsiveLayout {
  static const double desktopBreakpoint = 1100;
  static const double compactBreakpoint = 600;

  static bool usesSidebar(double width) => width >= desktopBreakpoint;
}
