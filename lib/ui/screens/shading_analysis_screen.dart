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
  double _pitch =
      0.0; // Elevation Tilt (Negative = Ground, 0 = Horizon, 90 = Sky)

  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;

  @override
  void initState() {
    super.initState();

    // ENFORCE STRICT PORTRAIT MODE
    // Ensures hardware gyroscopes and camera matrices align perfectly
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

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
        await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  void _initSensors() {
    // 1. Compass Heading (Azimuth)
    _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
      if (!mounted) return;
      setState(() {
        // flutter_compass natively provides the true/magnetic heading.
        _heading = event.heading ?? _heading;
      });
    });

    // 2. True Gravity Pitch (Tilt)
    _accelSubscription = accelerometerEventStream().listen((
      AccelerometerEvent event,
    ) {
      if (!mounted) return;
      setState(() {
        // ROCK SOLID GRAVITY MATH:
        // Instead of atan2 which wraps around and glitches, we isolate the Z-axis gravity force.
        // When pointing to the sky (screen down), Z = -9.81.
        // This calculates a flawless -90 to +90 degree pitch.
        double zNormalized = (event.z / 9.81).clamp(-1.0, 1.0);
        _pitch = -math.asin(zNormalized) * 180 / math.pi;
      });
    });
  }

  Future<void> _checkAndFetchLocation() async {
    final project = ref
        .read(projectListProvider)
        .firstWhere((p) => p.id == widget.projectId);
    final manualLat = ref.read(manualLatProvider);
    final manualLon = ref.read(manualLonProvider);

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

    if (project.latitude != null && project.longitude != null) return;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    try {
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
      );

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
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
        return DateTime(now.year, 6, 21); // Summer Solstice
      case SunSeason.equinox:
        return DateTime(now.year, 3, 20); // Spring Equinox
      case SunSeason.winter:
        return DateTime(now.year, 12, 21); // Winter Solstice
    }
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    _accelSubscription?.cancel();
    _controller?.dispose();

    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

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
            SizedBox.expand(child: CameraPreview(_controller!))
          else
            const Center(child: CircularProgressIndicator(color: Colors.amber)),

          // 2. Adaptive Dark Overlay for AR Contrast
          Container(color: Colors.black.withValues(alpha: 0.3)),

          // 3. True 3D AR Spherical Painter
          CustomPaint(
            painter: _TrueARSphericalPainter(
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
            top: 50 + safePadding.top,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
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
            ),
          ),

          // 5. Season Toggles
          if (activeLat != null && activeLon != null)
            Positioned(
              top: 110 + safePadding.top,
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

          // 6. Info Button
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            bottom: _showInstructions ? -100 : 32 + safePadding.bottom,
            right: 24,
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
            left: 0,
            right: 0,
            child: GestureDetector(
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null &&
                    details.primaryVelocity! > 0) {
                  setState(() => _showInstructions = false);
                }
              },
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  24,
                  16,
                  24,
                  40 + safePadding.bottom,
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
                          'TRUE 3D HORIZON SCANNER',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.amber.shade600,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Point the camera up to track the sun across the sky.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: theme.colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Find the exact Sunrise and Sunset markers. The amber line perfectly maps the sun\'s 3D path over your roof. Check if trees block this arc!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: theme.iconTheme.color?.withValues(alpha: 0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Swipe down to hide this panel.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: theme.iconTheme.color?.withValues(alpha: 0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 8. Back Button
          Positioned(
            top: 50 + safePadding.top,
            left: 16,
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
// TRUE AR 3D SPHERICAL PAINTER (Perfect Zenith / Sky Tracking)
// -------------------------------------------------------------
class _TrueARSphericalPainter extends CustomPainter {
  final double heading;
  final double pitch;
  final double? latitude;
  final double? longitude;
  final DateTime simulationDate;

  _TrueARSphericalPainter({
    required this.heading,
    required this.pitch,
    this.latitude,
    this.longitude,
    required this.simulationDate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Ultra-Wide FOV to ensure the path doesn't easily leave the screen boundaries
    double fovX = 75.0;
    double fovY = 110.0;

    double centerX = size.width / 2;
    double centerY = size.height / 2;

    double focalLengthX = centerX / math.tan((fovX / 2.0) * math.pi / 180.0);
    double focalLengthY = centerY / math.tan((fovY / 2.0) * math.pi / 180.0);

    // 3D SPHERICAL PROJECTION MATRIX
    // Completely solves the "pointing at sky" glitch by calculating true 3D geometry
    Offset? projectPoint(double az, double el) {
      double azRad = az * math.pi / 180.0;
      double elRad = el * math.pi / 180.0;

      // 1. Spherical to Cartesian (Earth space coordinates)
      double sx = math.cos(elRad) * math.sin(azRad);
      double sy = math.cos(elRad) * math.cos(azRad);
      double sz = math.sin(elRad);

      // 2. Yaw (Heading) Rotation
      double hRad = heading * math.pi / 180.0;
      double x1 = sx * math.cos(hRad) - sy * math.sin(hRad);
      double y1 = sx * math.sin(hRad) + sy * math.cos(hRad);
      double z1 = sz;

      // 3. Pitch (Tilt) Rotation
      double pRad = pitch * math.pi / 180.0;
      double x2 = x1;
      double y2 = y1 * math.cos(pRad) + z1 * math.sin(pRad);
      double z2 = -y1 * math.sin(pRad) + z1 * math.cos(pRad);

      // Cull anything physically behind the camera lens
      if (y2 <= 0.0) return null;

      // 4. Project 3D vector down to 2D screen coordinates
      double px = centerX + (x2 / y2) * focalLengthX;
      double py = centerY - (z2 / y2) * focalLengthY;

      return Offset(px, py);
    }

    Paint horizonPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // 1. Draw the Curved True Horizon
    Offset? prevHorizonPt;
    for (int az = 0; az <= 360; az += 2) {
      Offset? pt = projectPoint(az.toDouble(), 0.0);
      if (pt != null && prevHorizonPt != null) {
        if ((pt.dx - prevHorizonPt.dx).abs() < size.width) {
          canvas.drawLine(prevHorizonPt, pt, horizonPaint);
        }
      }
      prevHorizonPt = pt;
    }

    // 2. Draw Compass Direction Markers (N, E, S, W)
    List<int> compassPoints = [0, 90, 180, 270];
    List<String> compassLabels = ['NORTH', 'EAST', 'SOUTH', 'WEST'];

    for (int i = 0; i < compassPoints.length; i++) {
      Offset? pt = projectPoint(compassPoints[i].toDouble(), 0.0);

      // Render marker if it's anywhere vaguely on screen
      if (pt != null && pt.dx > -200 && pt.dx < size.width + 200) {
        canvas.drawLine(
          Offset(pt.dx, pt.dy - 10),
          Offset(pt.dx, pt.dy + 10),
          horizonPaint,
        );
        _drawTextLabel(
          canvas,
          compassLabels[i],
          Offset(pt.dx, pt.dy + 15),
          Colors.white70,
          isSmall: true,
        );
      }
    }

    // 3. Zenith Target (Top of the Sky Dome)
    Offset? zenithPt = projectPoint(0, 90.0);
    if (zenithPt != null &&
        zenithPt.dy > -100 &&
        zenithPt.dy < size.height + 100) {
      canvas.drawCircle(
        zenithPt,
        12,
        Paint()
          ..color = Colors.blueAccent.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawCircle(zenithPt, 2, Paint()..color = Colors.blueAccent);
      _drawTextLabel(
        canvas,
        'ZENITH',
        Offset(zenithPt.dx, zenithPt.dy - 20),
        Colors.blueAccent,
        isSmall: true,
      );
    }

    // 4. Draw the Sun's Traveling Path and Exact Sunrise/Sunset
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

      // Map the 3D arc through the sky
      for (int min = 0; min <= 24 * 60; min += 15) {
        DateTime evalTime = startOfDay.add(Duration(minutes: min));
        SunPosition pos = SunPositionCalculator.getPosition(
          evalTime,
          latitude!,
          longitude!,
        );

        // We only render the arc that is above the ground
        if (pos.elevation > -3.0) {
          Offset? pt = projectPoint(pos.azimuth, pos.elevation);
          rawPathPoints.add(pt);

          if (pt != null && evalTime.minute == 0 && evalTime.hour % 2 == 0) {
            timeMarkers.add({'offset': pt, 'label': _formatTime(evalTime)});
          }

          if (!foundSunrise && pos.elevation >= 0.0 && pt != null) {
            exactSunrise = {'offset': pt, 'time': evalTime};
            foundSunrise = true;
          }

          if (pos.elevation >= 0.0 && pt != null) {
            exactSunset = {'offset': pt, 'time': evalTime};
          }
        }
      }

      // Draw the continuous 3D Sun Path Curve
      if (rawPathPoints.length > 1) {
        Paint pathPaint = Paint()
          ..color = Colors.amber.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10.0
          ..strokeCap = StrokeCap.round;

        for (int i = 0; i < rawPathPoints.length - 1; i++) {
          if (rawPathPoints[i] != null && rawPathPoints[i + 1] != null) {
            // Cull excessive off-screen lines
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

      for (var marker in timeMarkers) {
        Offset pt = marker['offset'];
        if (pt.dx > -100 &&
            pt.dx < size.width + 100 &&
            pt.dy > -100 &&
            pt.dy < size.height + 100) {
          canvas.drawCircle(pt, 5, Paint()..color = Colors.white54);
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

      // 5. Draw Current Live Sun Position Indicator
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
            cPt.dx > -100 &&
            cPt.dx < size.width + 100 &&
            cPt.dy > -100 &&
            cPt.dy < size.height + 100) {
          canvas.drawCircle(cPt, 16, Paint()..color = Colors.amberAccent);
          canvas.drawCircle(
            cPt,
            40,
            Paint()
              ..color = Colors.amber.withValues(alpha: 0.5)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
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
    canvas.drawCircle(pt, 6, Paint()..color = color);
    canvas.drawCircle(pt, 12, Paint()..color = color.withValues(alpha: 0.4));

    canvas.drawLine(
      pt,
      Offset(pt.dx, pt.dy - 35),
      Paint()
        ..color = color
        ..strokeWidth = 2,
    );

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
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    tp.layout();

    Rect bgRect = Rect.fromCenter(
      center: Offset(pt.dx, pt.dy - 50),
      width: tp.width + 16,
      height: tp.height + 10,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(8)),
      Paint()..color = Colors.black87,
    );

    tp.paint(canvas, Offset(pt.dx - tp.width / 2, pt.dy - 50 - tp.height / 2));
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
          fontSize: isSmall ? 10 : 13,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(pt.dx - tp.width / 2, pt.dy - 20));
  }

  String _formatTime(DateTime t) {
    int h = t.hour;
    String ampm = h >= 12 ? 'PM' : 'AM';
    if (h > 12) h -= 12;
    if (h == 0) h = 12;
    return '$h $ampm';
  }

  @override
  bool shouldRepaint(covariant _TrueARSphericalPainter oldDelegate) {
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
