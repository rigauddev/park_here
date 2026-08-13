class CheckinValidator {

  static const double allowedRadiusMeters = 30;

  static bool isInsideAllowedRadius(double distance) {
    return distance <= allowedRadiusMeters;
  }
}
