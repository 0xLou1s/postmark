/// Timings for the capture sequence and the nav bar.
abstract final class AppDurations {
  /// Scale down/up while the shutter presses the machine.
  static const pressAnim = Duration(milliseconds: 440);

  /// Hold while pressed, before the frame is captured.
  static const pressDown = Duration(milliseconds: 440);

  /// Settle after release, before the stamp ejects.
  static const springBack = Duration(milliseconds: 340);

  /// Full eject animation.
  static const eject = Duration(milliseconds: 1700);

  /// The nav thumb gliding between destinations, and the icon/label it carries.
  static const navThumb = Duration(milliseconds: 280);
  static const navIcon = Duration(milliseconds: 240);
  static const navLabel = Duration(milliseconds: 220);
}
