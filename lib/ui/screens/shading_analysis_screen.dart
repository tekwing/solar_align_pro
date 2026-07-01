import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';

import '../../../providers/project_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/theme_provider.dart';

enum SunSeason { today, summer, equinox, winter }

class ShadingAnalysisScreen extends ConsumerStatefulWidget {
  final String projectId;
  const ShadingAnalysisScreen({super.key, required this.projectId});

  @override
  ConsumerState<ShadingAnalysisScreen> createState() =>
      _ShadingAnalysisScreenState();
}

class _ShadingAnalysisScreenState extends ConsumerState<ShadingAnalysisScreen> {
  CameraController? _controller;

  SunSeason _selectedSeason = SunSeason.today;
  bool _showInstructions = true;

  // AR Sensor State
  double _heading = 0.0; // Compass Azimuth (0 to 360)
  double _pitch = 0.0; // Elevation Tilt (0 = Horizon, 90 = Sky)

  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;

  @override
  void initState() {
    super.initState();

    // Force Landscape Left for wider AR view
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _initCamera();
    _initSensors();
    _checkAndFetchLocation();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _controller = CameraController(
          cameras.first,
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _controller!.initialize();
        // Lock camera sensor to landscape so the video feed doesn't warp
        await _controller!.lockCaptureOrientation(
          DeviceOrientation.landscapeLeft,
        );
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  void _initSensors() {
    // Track device compass heading (Azimuth)
    _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
      if (!mounted) return;
      setState(() {
        // flutter_compass natively adjusts for screen orientation on most devices.
        // We use the raw heading directly.
        _heading = event.heading ?? 0.0;
      });
    });

    // Track device tilt (Pitch) to anchor the horizon
    _accelSubscription = accelerometerEventStream().listen((
      AccelerometerEvent event,
    ) {
      if (!mounted) return;
      setState(() {
        // In Landscape mode, gravity pulls on the X axis when held upright.
        // When tilted up to the sky, gravity shifts to the Z axis.
        // x.abs() ensures it works perfectly whether held in LandscapeLeft or LandscapeRight!
        _pitch = (math.atan2(event.z, event.x.abs()) * 180 / math.pi);
      });
    });
  }

  Future<void> _checkAndFetchLocation() async {
    final project = ref
        .read(projectListProvider)
        .firstWhere((p) => p.id == widget.projectId);
    final manualLat = ref.read(manualLatProvider);
    final manualLon = ref.read(manualLonProvider);

    // 1. Check for manual override first
    if (manualLat != null && manualLon != null) {
      await ref
          .read(projectListProvider.notifier)
          .updateProjectLocation(
            widget.projectId,
            manualLat,
            manualLon,
            project.suggestedTilt ?? 30.0,
          );
      return;
    }

    // 2. If we already have GPS, skip
    if (project.latitude != null && project.longitude != null) return;

    // 3. Hardware GPS Fallback
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        await ref
            .read(projectListProvider.notifier)
            .updateProjectLocation(
              widget.projectId,
              position.latitude,
              position.longitude,
              project.suggestedTilt ?? 30.0,
            );
      }
    } catch (e) {
      debugPrint("Error fetching GPS: $e");
    }
  }

  DateTime _getDateForSeason(SunSeason season) {
    final now = DateTime.now();
    switch (season) {
      case SunSeason.today:
        return now;
      case SunSeason.summer:
        return DateTime(now.year, 6, 21); // Summer Solstice (Highest Arc)
      case SunSeason.equinox:
        return DateTime(now.year, 3, 20); // Spring Equinox
      case SunSeason.winter:
        return DateTime(now.year, 12, 21); // Winter Solstice (Lowest Arc)
    }
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    _accelSubscription?.cancel();
    _controller?.dispose();

    // Critically important: Revert the app back to portrait when leaving!
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    // In landscape, we use left/right padding to avoid notches, and bottom for gestures
    final safePadding = MediaQuery.of(context).padding;

    final project = ref
        .watch(projectListProvider)
        .firstWhere((p) => p.id == widget.projectId);
    final manualLat = ref.watch(manualLatProvider);
    final manualLon = ref.watch(manualLonProvider);

    final activeLat = manualLat ?? project.latitude;
    final activeLon = manualLon ?? project.longitude;
    final simulationDate = _getDateForSeason(_selectedSeason);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Feed
          if (_controller?.value.isInitialized ?? false)
            CameraPreview(_controller!)
          else
            const Center(child: CircularProgressIndicator(color: Colors.amber)),

          // 2. Adaptive Dark Overlay for AR Contrast
          Container(color: Colors.black.withValues(alpha: 0.3)),

          // 3. True AR Compass Painter (Draws the Horizon, Arc, and Sun)
          CustomPaint(
            painter: _TrueARCylindricalPainter(
              heading: _heading,
              pitch: _pitch,
              latitude: activeLat,
              longitude: activeLon,
              simulationDate: simulationDate,
            ),
            size: Size.infinite,
          ),

          // 4. Top Telemetry HUD
          Positioned(
            top: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      'AZIMUTH: ${_heading.toStringAsFixed(0)}°  |  TILT: ${_pitch.toStringAsFixed(0)}°',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 5. Season Toggles
          if (activeLat != null && activeLon != null)
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSeasonChip('TODAY', SunSeason.today),
                      _buildSeasonChip('SUMMER', SunSeason.summer),
                      _buildSeasonChip('EQUINOX', SunSeason.equinox),
                      _buildSeasonChip('WINTER', SunSeason.winter),
                    ],
                  ),
                ),
              ),
            ),

          // 6. Restored Info Button (Aligned to bottom right safe area)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            bottom: _showInstructions ? -100 : 24 + safePadding.bottom,
            right: 24 + safePadding.right,
            child: FloatingActionButton.extended(
              backgroundColor: theme.colorScheme.primary,
              icon: const Icon(Icons.info_outline_rounded, color: Colors.white),
              label: Text(
                'Show Guide',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _showInstructions = true);
              },
            ),
          ),

          // 7. Instructions UI (Swipeable Bottom Sheet)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            bottom: _showInstructions ? 0 : -450,
            left: safePadding.left,
            right: safePadding.right,
            child: GestureDetector(
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null &&
                    details.primaryVelocity! > 0) {
                  setState(() => _showInstructions = false);
                }
              },
              child: Container(
                constraints: BoxConstraints(
                  maxHeight:
                      MediaQuery.of(context).size.height *
                      0.7, // Prevents covering the whole screen in landscape
                ),
                padding: EdgeInsets.fromLTRB(
                  24,
                  16,
                  24,
                  16 + safePadding.bottom,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A).withValues(alpha: 0.95)
                      : Colors.white.withValues(alpha: 0.95),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: theme.dividerColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.explore_rounded,
                            color: Colors.amber,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'WIDE HORIZON SCANNER',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.amber.shade600,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Pan your camera left and right along the horizon line.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: theme.colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Find the exact Sunrise and Sunset markers on your screen. The amber line between them shows the exact traveling path of the sun. Check if any trees block this path!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: theme.iconTheme.color?.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Swipe down to hide this panel.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: theme.iconTheme.color?.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 8. Back Button (Aligned to Top Left Safe Area)
          Positioned(
            top: 24,
            left: 24 + safePadding.left,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonChip(String label, SunSeason season) {
    final isSelected = _selectedSeason == season;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedSeason = season);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.amber : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// CYLINDRICAL AR SUN PATH PAINTER (Rock-Solid 2D Projection)
// -------------------------------------------------------------
class _TrueARCylindricalPainter extends CustomPainter {
  final double heading;
  final double pitch;
  final double? latitude;
  final double? longitude;
  final DateTime simulationDate;

  _TrueARCylindricalPainter({
    required this.heading,
    required this.pitch,
    this.latitude,
    this.longitude,
    required this.simulationDate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // A wider FOV perfect for capturing the broad winter arc in Landscape mode
    double fovX = 75.0;
    double fovY = 45.0;

    double pixelsPerDegreeX = size.width / fovX;
    double pixelsPerDegreeY = size.height / fovY;

    double centerX = size.width / 2;
    double centerY = size.height / 2;

    // Rock-Solid Cylindrical Projection
    // This perfectly maps spherical Azimuth/Elevation to flat screen coordinates
    // without the "fisheye" distortion or axis flipping of 3D matrix math.
    Offset? projectPoint(double az, double el) {
      double dx = _normalizeAngle(az - heading);
      double dy = el - pitch;

      // Do not render points that are physically behind the user
      if (dx.abs() > 120) return null;

      double px = centerX + (dx * pixelsPerDegreeX);
      double py = centerY - (dy * pixelsPerDegreeY);

      return Offset(px, py);
    }

    Paint horizonPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // 1. Draw the True Horizon Line (Always straight and perfectly anchored)
    double horizonOffsetY = pitch * pixelsPerDegreeY;
    canvas.drawLine(
      Offset(0, centerY + horizonOffsetY),
      Offset(size.width, centerY + horizonOffsetY),
      horizonPaint,
    );

    // 2. Draw Compass Direction Markers (N, E, S, W)
    List<int> compassPoints = [0, 90, 180, 270];
    List<String> compassLabels = ['NORTH', 'EAST', 'SOUTH', 'WEST'];

    for (int i = 0; i < compassPoints.length; i++) {
      Offset? pt = projectPoint(compassPoints[i].toDouble(), 0.0);

      // Only draw if it's currently visible on screen
      if (pt != null && pt.dx > -100 && pt.dx < size.width + 100) {
        // Vertical tick mark on the horizon
        canvas.drawLine(
          Offset(pt.dx, pt.dy - 10),
          Offset(pt.dx, pt.dy + 10),
          horizonPaint,
        );

        // Label
        _drawTextLabel(
          canvas,
          compassLabels[i],
          Offset(pt.dx, pt.dy + 15),
          Colors.white70,
          isSmall: true,
        );
      }
    }

    // 3. Draw the Sun's Traveling Path and Exact Sunrise/Sunset
    if (latitude != null && longitude != null) {
      DateTime startOfDay = DateTime(
        simulationDate.year,
        simulationDate.month,
        simulationDate.day,
        0,
        0,
      );

      List<Offset?> rawPathPoints = [];
      List<Map<String, dynamic>> timeMarkers = [];

      Map<String, dynamic>? exactSunrise;
      Map<String, dynamic>? exactSunset;

      bool foundSunrise = false;

      // Loop through every 15 minutes of the 24-hour day to map the path
      for (int min = 0; min <= 24 * 60; min += 15) {
        DateTime evalTime = startOfDay.add(Duration(minutes: min));
        SunPosition pos = SunPositionCalculator.getPosition(
          evalTime,
          latitude!,
          longitude!,
        );

        // We only care about points above (or slightly below) the horizon
        if (pos.elevation > -3.0) {
          Offset? pt = projectPoint(pos.azimuth, pos.elevation);
          rawPathPoints.add(pt);

          // Drop a time marker every 2 hours
          if (pt != null && evalTime.minute == 0 && evalTime.hour % 2 == 0) {
            timeMarkers.add({'offset': pt, 'label': _formatTime(evalTime)});
          }

          // Detect EXACT Sunrise (First point crossing above horizon)
          if (!foundSunrise && pos.elevation >= 0.0 && pt != null) {
            exactSunrise = {'offset': pt, 'time': evalTime};
            foundSunrise = true;
          }

          // Constantly update Sunset, the very last point above horizon becomes the Sunset!
          if (pos.elevation >= 0.0 && pt != null) {
            exactSunset = {'offset': pt, 'time': evalTime};
          }
        }
      }

      // Draw the continuous Sun Path curve
      if (rawPathPoints.length > 1) {
        Paint pathPaint = Paint()
          ..color = Colors.amber.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8.0
          ..strokeCap = StrokeCap.round;

        for (int i = 0; i < rawPathPoints.length - 1; i++) {
          if (rawPathPoints[i] != null && rawPathPoints[i + 1] != null) {
            // Optimization: Only draw line segments that are remotely visible
            if ((rawPathPoints[i]!.dx > -500 &&
                    rawPathPoints[i]!.dx < size.width + 500) ||
                (rawPathPoints[i + 1]!.dx > -500 &&
                    rawPathPoints[i + 1]!.dx < size.width + 500)) {
              canvas.drawLine(
                rawPathPoints[i]!,
                rawPathPoints[i + 1]!,
                pathPaint,
              );
            }
          }
        }
      }

      // Draw normal time markers
      for (var marker in timeMarkers) {
        Offset pt = marker['offset'];
        if (pt.dx > -50 &&
            pt.dx < size.width + 50 &&
            pt.dy > -50 &&
            pt.dy < size.height + 50) {
          canvas.drawCircle(pt, 4, Paint()..color = Colors.white54);
          _drawTextLabel(
            canvas,
            marker['label'],
            pt,
            Colors.white54,
            isSmall: true,
          );
        }
      }

      // Draw EXACT SUNRISE Pin
      if (exactSunrise != null) {
        Offset pt = exactSunrise['offset'];
        if (pt.dx > -100 &&
            pt.dx < size.width + 100 &&
            pt.dy > -100 &&
            pt.dy < size.height + 100) {
          _drawEventPin(
            canvas,
            'SUNRISE',
            _formatTime(exactSunrise['time']),
            pt,
            Colors.orangeAccent,
          );
        }
      }

      // Draw EXACT SUNSET Pin
      if (exactSunset != null) {
        Offset pt = exactSunset['offset'];
        if (pt.dx > -100 &&
            pt.dx < size.width + 100 &&
            pt.dy > -100 &&
            pt.dy < size.height + 100) {
          _drawEventPin(
            canvas,
            'SUNSET',
            _formatTime(exactSunset['time']),
            pt,
            Colors.deepPurpleAccent,
          );
        }
      }

      // 4. Draw Current Live Sun Position Indicator (If currently daytime)
      DateTime realNow = DateTime.now();
      DateTime simulatedCurrentTime = DateTime(
        simulationDate.year,
        simulationDate.month,
        simulationDate.day,
        realNow.hour,
        realNow.minute,
      );

      SunPosition currentPos = SunPositionCalculator.getPosition(
        simulatedCurrentTime,
        latitude!,
        longitude!,
      );

      if (currentPos.elevation > -2.0) {
        Offset? cPt = projectPoint(currentPos.azimuth, currentPos.elevation);

        if (cPt != null &&
            cPt.dx > -50 &&
            cPt.dx < size.width + 50 &&
            cPt.dy > -50 &&
            cPt.dy < size.height + 50) {
          canvas.drawCircle(cPt, 16, Paint()..color = Colors.amberAccent);
          canvas.drawCircle(
            cPt,
            36,
            Paint()
              ..color = Colors.amber.withValues(alpha: 0.6)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
          );
        }
      }
    }
  }

  void _drawEventPin(
    Canvas canvas,
    String title,
    String time,
    Offset pt,
    Color color,
  ) {
    // Draw the anchor dot
    canvas.drawCircle(pt, 6, Paint()..color = color);
    canvas.drawCircle(pt, 12, Paint()..color = color.withValues(alpha: 0.4));

    // Draw a line popping up from the horizon
    canvas.drawLine(
      pt,
      Offset(pt.dx, pt.dy - 30),
      Paint()
        ..color = color
        ..strokeWidth = 2,
    );

    // Draw the text box
    TextPainter tp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$title\n',
            style: GoogleFonts.plusJakartaSans(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          TextSpan(
            text: time,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    tp.layout();

    // Background plate for text
    Rect bgRect = Rect.fromCenter(
      center: Offset(pt.dx, pt.dy - 45),
      width: tp.width + 16,
      height: tp.height + 8,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(8)),
      Paint()..color = Colors.black87,
    );

    tp.paint(canvas, Offset(pt.dx - tp.width / 2, pt.dy - 45 - tp.height / 2));
  }

  void _drawTextLabel(
    Canvas canvas,
    String text,
    Offset pt,
    Color color, {
    bool isSmall = false,
  }) {
    TextPainter tp = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.plusJakartaSans(
          color: color,
          fontSize: isSmall ? 10 : 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(pt.dx - tp.width / 2, pt.dy - 20));
  }

  // Prevents the line from glitching back across the screen when crossing North (360 -> 0)
  double _normalizeAngle(double angle) {
    while (angle > 180) {
      angle -= 360;
    }
    while (angle <= -180) {
      angle += 360;
    }
    return angle;
  }

  String _formatTime(DateTime t) {
    int h = t.hour;
    String ampm = h >= 12 ? 'PM' : 'AM';
    if (h > 12) h -= 12;
    if (h == 0) h = 12;
    return '$h $ampm';
  }

  @override
  bool shouldRepaint(covariant _TrueARCylindricalPainter oldDelegate) {
    return oldDelegate.heading != heading ||
        oldDelegate.pitch != pitch ||
        oldDelegate.simulationDate != simulationDate;
  }
}

// -------------------------------------------------------------
// SOLAR POSITION ALGORITHM (Keplerian physics for exact Coordinates)
// -------------------------------------------------------------
class SunPosition {
  final double azimuth;
  final double elevation;
  SunPosition({required this.azimuth, required this.elevation});
}

class SunPositionCalculator {
  static SunPosition getPosition(
    DateTime time,
    double latitude,
    double longitude,
  ) {
    DateTime utc = time.toUtc();
    double jd = _getJulianDay(utc);
    double d = jd - 2451545.0;

    double w = 282.9404 + 4.70935e-5 * d;
    double e = 0.016709 - 1.151e-9 * d;
    double m = 356.0470 + 0.9856002585 * d;
    m = m % 360;
    if (m < 0) m += 360;

    double mRad = m * math.pi / 180.0;
    double eCenter =
        m + e * (180.0 / math.pi) * math.sin(mRad) * (1.0 + e * math.cos(mRad));
    double eCenterRad = eCenter * math.pi / 180.0;

    double x = math.cos(eCenterRad) - e;
    double y = math.sin(eCenterRad) * math.sqrt(1.0 - e * e);

    double r = math.sqrt(x * x + y * y);
    double v = math.atan2(y, x) * 180.0 / math.pi;

    double lon = v + w;
    double lonRad = lon * math.pi / 180.0;

    double oblecl = 23.4393 - 3.563e-7 * d;
    double obleclRad = oblecl * math.pi / 180.0;

    double xEcl = r * math.cos(lonRad);
    double yEcl = r * math.sin(lonRad);

    double xEq = xEcl;
    double yEq = yEcl * math.cos(obleclRad);
    double zEq = yEcl * math.sin(obleclRad);

    double ra = math.atan2(yEq, xEq) * 180.0 / math.pi;
    double dec =
        math.atan2(zEq, math.sqrt(xEq * xEq + yEq * yEq)) * 180.0 / math.pi;

    double ut = utc.hour + utc.minute / 60.0 + utc.second / 3600.0;
    double l = w + m;
    double gmst0 = l + 180;
    double gmst = gmst0 + ut * 15.0;

    double lst = gmst + longitude;
    lst = lst % 360;
    if (lst < 0) lst += 360;

    double ha = lst - ra;
    if (ha < -180) ha += 360;
    if (ha > 180) ha -= 360;

    double haRad = ha * math.pi / 180.0;
    double latRad = latitude * math.pi / 180.0;
    double decRad = dec * math.pi / 180.0;

    double sinElevation =
        math.sin(latRad) * math.sin(decRad) +
        math.cos(latRad) * math.cos(decRad) * math.cos(haRad);
    double elevationRad = math.asin(sinElevation);
    double elevation = elevationRad * 180.0 / math.pi;

    double cosAzimuth =
        (math.sin(decRad) - math.sin(latRad) * math.sin(elevationRad)) /
        (math.cos(latRad) * math.cos(elevationRad));
    cosAzimuth = cosAzimuth.clamp(-1.0, 1.0);

    double azimuthRad = math.acos(cosAzimuth);
    double azimuth = azimuthRad * 180.0 / math.pi;
    if (math.sin(haRad) > 0) azimuth = 360.0 - azimuth;

    return SunPosition(azimuth: azimuth, elevation: elevation);
  }

  static double _getJulianDay(DateTime utc) {
    int year = utc.year;
    int month = utc.month;
    int day = utc.day;
    if (month <= 2) {
      year -= 1;
      month += 12;
    }
    int a = year ~/ 100;
    int b = 2 - a + (a ~/ 4);
    double jd =
        (365.25 * (year + 4716)).floorToDouble() +
        (30.6001 * (month + 1)).floorToDouble() +
        day +
        b -
        1524.5;
    double time = utc.hour / 24.0 + utc.minute / 1440.0 + utc.second / 86400.0;
    return jd + time;
  }
}
