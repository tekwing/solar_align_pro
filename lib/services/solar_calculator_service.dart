class SolarCalculatorService {
  /// Calculates the suggested year-round fixed tilt based on latitude.
  /// Standard rule of thumb: Optimal tilt roughly equals the location's latitude.
  double calculateOptimalTilt(double latitude) {
    // We use the absolute value because southern hemisphere latitudes are negative
    return latitude.abs();
  }

  /// Determines the ideal compass direction (azimuth) to face the panels.
  /// Northern Hemisphere (> 0) faces True South (180°)
  /// Southern Hemisphere (< 0) faces True North (0° or 360°)
  double calculateIdealAzimuth(double latitude) {
    if (latitude >= 0) {
      return 180.0; // Face South
    } else {
      return 0.0; // Face North
    }
  }

  double estimatePeakSunHours(double latitude) {
    double absLat = latitude.abs();

    // A simplified parabolic heuristic curve for offline estimation
    // Equation modeled roughly on global irradiance maps
    double psh = 6.5 - (absLat * 0.05);

    // Cap minimum and maximum realistic values
    if (psh > 7.0) return 7.0; // Max desert conditions
    if (psh < 2.5) return 2.5; // Extreme northern/southern winters

    return psh;
  }
}
