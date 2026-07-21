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
import '../../../main.dart';

class ShadingAnalysisScreen extends ConsumerStatefulWidget {
  final String projectId;
  const ShadingAnalysisScreen({super.key, required this.projectId});

  @override
  ConsumerState<ShadingAnalysisScreen> createState() =>
      _ShadingAnalysisScreenState();
}

class _ShadingAnalysisScreenState extends ConsumerState<ShadingAnalysisScreen> {
  CameraController? _controller;
  bool _showInstructions = true;

  // Sensor State
  double _heading = 0.0; // Compass Azimuth (0 to 360)
  double _pitch = 0.0; // Camera Elevation Angle (Clinometer)

  // Sun Tracker State
  double? _sunriseAzimuth;
  double? _noonAzimuth;
  double? _sunsetAzimuth;
  String _activeTarget = 'Noon'; // 'Morning', 'Noon', 'Evening'

  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;

  @override
  void initState() {
    super.initState();
    // Lock the UI to Portrait while using the Clinometer to prevent math errors
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _initCamera();
    _initSensors();

    // Check if we already have coordinates to calculate sun guides immediately
    final manualLat = ref.read(manualLatProvider);
    final manualLon = ref.read(manualLonProvider);
    final project = ref
        .read(projectListProvider)
        .firstWhere((p) => p.id == widget.projectId);
    final activeLat = manualLat ?? project.latitude;
    final activeLon = manualLon ?? project.longitude;

    if (activeLat != null && activeLon != null) {
      _calculateKeySunPositions(activeLat, activeLon);
    }

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
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  void _initSensors() {
    _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
      if (!mounted) return;
      setState(() {
        _heading = event.heading ?? 0.0;
        if (_heading < 0) _heading += 360;
      });
    });

    _accelSubscription = accelerometerEventStream().listen((
      AccelerometerEvent event,
    ) {
      if (!mounted) return;
      setState(() {
        // Pitch: Calculates the exact elevation angle of the camera lens
        _pitch = math.atan2(event.z, event.y) * 180 / math.pi;
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
      _calculateKeySunPositions(manualLat, manualLon);
      return;
    }

    if (project.latitude != null && project.longitude != null) {
      _calculateKeySunPositions(project.latitude!, project.longitude!);
      return;
    }

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
        _calculateKeySunPositions(position.latitude, position.longitude);
      }
    } catch (e) {}
  }

  // --- Core Clinometer Math ---

  DateTime _getWinterSolstice(double lat) {
    final now = DateTime.now();
    // If Southern Hemisphere, winter is in June
    if (lat < 0) return DateTime(now.year, 6, 21);
    // Northern Hemisphere winter is December
    return DateTime(now.year, 12, 21);
  }

  void _calculateKeySunPositions(double lat, double lon) {
    final winter = _getWinterSolstice(lat);
    final startOfDay = DateTime(winter.year, winter.month, winter.day, 0, 0);

    double maxElev = -90.0;
    double? srAz, snAz, nnAz;

    // Scan the winter day every 5 minutes to find Sunrise, Noon, and Sunset
    for (int min = 0; min <= 24 * 60; min += 5) {
      final evalTime = startOfDay.add(Duration(minutes: min));
      final pos = SunPositionCalculator.getPosition(evalTime, lat, lon);

      if (pos.elevation >= 0) {
        srAz ??= pos.azimuth; // The very first time it breaches 0 is Sunrise
        snAz = pos
            .azimuth; // Continuously overwriting gives us the very last point (Sunset)
      }

      if (pos.elevation > maxElev) {
        maxElev = pos.elevation;
        nnAz = pos.azimuth; // The highest elevation is Solar Noon
      }
    }

    // Safely update state if the widget is still alive
    Future.microtask(() {
      if (mounted) {
        setState(() {
          _sunriseAzimuth = srAz;
          _noonAzimuth = nnAz;
          _sunsetAzimuth = snAz;
        });
      }
    });
  }

  double? _getWinterSunElevationAtCurrentHeading(double lat, double lon) {
    final winter = _getWinterSolstice(lat);
    final startOfDay = DateTime(winter.year, winter.month, winter.day, 0, 0);

    double? closestElevation;
    double minDiff = 360.0;

    for (int min = 0; min <= 24 * 60; min += 15) {
      final evalTime = startOfDay.add(Duration(minutes: min));
      final pos = SunPositionCalculator.getPosition(evalTime, lat, lon);

      if (pos.elevation >= 0) {
        double diff = (pos.azimuth - _heading).abs();
        if (diff > 180) diff = 360 - diff;

        if (diff < minDiff) {
          minDiff = diff;
          closestElevation = pos.elevation;
        }
      }
    }

    if (minDiff > 15.0) return null;
    return closestElevation;
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    _accelSubscription?.cancel();
    _controller?.dispose();

    // Release the screen orientation lock when leaving the screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

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

    // --- CLINOMETER LOGIC ---
    Color statusColor = Colors.grey;

    if (activeLat != null && activeLon != null) {
      double? winterSunElevation = _getWinterSunElevationAtCurrentHeading(
        activeLat,
        activeLon,
      );

      if (winterSunElevation == null) {
        statusColor = const Color(0xFF64748B); // Slate (Sun doesn't reach here)
      } else {
        if (_pitch > winterSunElevation) {
          statusColor = const Color(0xFFEF4444); // Red (Obstructed)
        } else {
          statusColor = const Color(0xFF10B981); // Emerald (Clear)
        }
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Feed (Wrapped to prevent stretching bugs on Android)
          if (_controller?.value.isInitialized ?? false)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: 100,
                  height: 100 * _controller!.value.aspectRatio,
                  child: CameraPreview(_controller!),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.amber)),

          // 2. Camera Vignette
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
              ),
            ),
          ),

          // 3. Sniper Crosshair (Center)
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                border: Border.all(
                  color: statusColor.withOpacity(0.8),
                  width: 2.0,
                ),
                shape: BoxShape.circle,
              ),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(width: 2, height: 10, color: statusColor),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(width: 2, height: 10, color: statusColor),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(width: 10, height: 2, color: statusColor),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(width: 10, height: 2, color: statusColor),
                  ),
                  Center(
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- NEW: DIRECTIONAL ARROWS ---
          _buildDirectionalGuide(),

          // 4. Instructions Button
          Positioned(
            top: 50,
            right: 16,
            child: IconButton(
              icon: const Icon(
                Icons.help_outline_rounded,
                color: Colors.white,
                size: 28,
              ),
              onPressed: () {
                setState(() => _showInstructions = true);
              },
            ),
          ),

          // 5. Back Button
          Positioned(
            top: 50,
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

          // --- NEW: SUN TRACKER HUD (Top Center) ---
          if (activeLat != null && activeLon != null && _noonAzimuth != null)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(child: _buildTargetSelector()),
            ),

          // 6. Instructions Overlay
          if (_showInstructions)
            Container(
              color: Colors.black87,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(32),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.track_changes_rounded,
                        color: Colors.amber,
                        size: 48,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'DIGITAL CLINOMETER',
                        style: GoogleFonts.outfit(
                          color: Colors.amber,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Select Morning, Noon, or Evening from the tracker to find the sun\'s exact location. Then, point the crosshair at the tallest obstacle in that direction to check for shading!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () =>
                              setState(() => _showInstructions = false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'START SCANNING',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- NEW: SUN TRACKER WIDGETS ---

  Widget _buildTargetSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTargetChip('🌅 MORNING', 'Morning'),
          _buildTargetChip('☀️ NOON', 'Noon'),
          _buildTargetChip('🌇 EVENING', 'Evening'),
        ],
      ),
    );
  }

  Widget _buildTargetChip(String label, String target) {
    final isSelected = _activeTarget == target;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _activeTarget = target);
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

  Widget _buildDirectionalGuide() {
    double? targetAzimuth;
    if (_activeTarget == 'Morning') targetAzimuth = _sunriseAzimuth;
    if (_activeTarget == 'Noon') targetAzimuth = _noonAzimuth;
    if (_activeTarget == 'Evening') targetAzimuth = _sunsetAzimuth;

    if (targetAzimuth == null) return const SizedBox.shrink();

    // Calculate how far off the user is from the target
    double diff = targetAzimuth - _heading;

    // Normalize to prevent glitching when turning across North (360 -> 0)
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;

    // If within 10 degrees, the user is looking directly at the sun's location!
    if (diff.abs() <= 10.0) {
      return Positioned(
        top: 180,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.greenAccent, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '$_activeTarget Sun Aligned!'.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    bool turnRight = diff > 0;

    return Positioned(
      top: MediaQuery.of(context).size.height / 2 - 40,
      left: turnRight ? null : 16,
      right: turnRight ? 16 : null,
      child: Column(
        children: [
          Icon(
            turnRight
                ? Icons.arrow_forward_ios_rounded
                : Icons.arrow_back_ios_new_rounded,
            color: Colors.amber,
            size: 48,
          ),
          const SizedBox(height: 8),
          Text(
            'TURN\n${turnRight ? 'RIGHT' : 'LEFT'}',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: Colors.amber,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// SOLAR POSITION ALGORITHM
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
    double jc = (jd - 2451545.0) / 36525.0;

    double geomMeanLongSun =
        (280.46646 + jc * (36000.76983 + jc * 0.0003032)) % 360;
    double geomMeanAnomSun = 357.52911 + jc * (35999.05029 - 0.0001537 * jc);

    double eccentEarthOrbit =
        0.016708634 - jc * (0.000042037 + 0.0000001267 * jc);
    double sunEqOfCtr =
        math.sin(geomMeanAnomSun * math.pi / 180) *
            (1.914602 - jc * (0.004817 + 0.000014 * jc)) +
        math.sin(2 * geomMeanAnomSun * math.pi / 180) *
            (0.019993 - 0.000101 * jc) +
        math.sin(3 * geomMeanAnomSun * math.pi / 180) * 0.000289;

    double sunTrueLong = geomMeanLongSun + sunEqOfCtr;
    double sunAppLong =
        sunTrueLong -
        0.00569 -
        0.00478 * math.sin((125.04 - 1934.136 * jc) * math.pi / 180);

    double meanObliqEcliptic =
        23 +
        (26 +
                ((21.448 - jc * (46.815 + jc * (0.00059 - jc * 0.001813)))) /
                    60) /
            60;
    double obliqCorr =
        meanObliqEcliptic +
        0.00256 * math.cos((125.04 - 1934.136 * jc) * math.pi / 180);

    double sunDeclination =
        math.asin(
          math.sin(obliqCorr * math.pi / 180) *
              math.sin(sunAppLong * math.pi / 180),
        ) *
        180 /
        math.pi;

    double varY =
        math.tan(obliqCorr / 2 * math.pi / 180) *
        math.tan(obliqCorr / 2 * math.pi / 180);
    double eqOfTime =
        4 *
        (varY * math.sin(2 * geomMeanLongSun * math.pi / 180) -
            2 * eccentEarthOrbit * math.sin(geomMeanAnomSun * math.pi / 180) +
            4 *
                eccentEarthOrbit *
                varY *
                math.sin(geomMeanAnomSun * math.pi / 180) *
                math.cos(2 * geomMeanLongSun * math.pi / 180) -
            0.5 * varY * varY * math.sin(4 * geomMeanLongSun * math.pi / 180) -
            1.25 *
                eccentEarthOrbit *
                eccentEarthOrbit *
                math.sin(2 * geomMeanAnomSun * math.pi / 180)) *
        180 /
        math.pi;

    double trueSolarTime =
        (utc.hour * 60 +
            utc.minute +
            utc.second / 60.0 +
            eqOfTime +
            4 * longitude) %
        1440;
    if (trueSolarTime < 0) trueSolarTime += 1440;

    double hourAngle = trueSolarTime / 4 < 0
        ? trueSolarTime / 4 + 180
        : trueSolarTime / 4 - 180;

    double zenithAngle =
        math.acos(
          math.sin(latitude * math.pi / 180) *
                  math.sin(sunDeclination * math.pi / 180) +
              math.cos(latitude * math.pi / 180) *
                  math.cos(sunDeclination * math.pi / 180) *
                  math.cos(hourAngle * math.pi / 180),
        ) *
        180 /
        math.pi;

    double elevation = 90 - zenithAngle;

    // Simplistic refraction
    double refraction = 0;
    if (elevation > 85)
      refraction = 0;
    else if (elevation > 5)
      refraction =
          58.1 / math.tan(elevation * math.pi / 180) -
          0.07 / math.pow(math.tan(elevation * math.pi / 180), 3);
    refraction /= 3600;
    elevation += refraction;

    double azimuth = 0;
    if (hourAngle > 0) {
      azimuth =
          (math.acos(
                    ((math.sin(latitude * math.pi / 180) *
                                math.cos(zenithAngle * math.pi / 180)) -
                            math.sin(sunDeclination * math.pi / 180)) /
                        (math.cos(latitude * math.pi / 180) *
                            math.sin(zenithAngle * math.pi / 180)),
                  ) *
                  180 /
                  math.pi +
              180) %
          360;
    } else {
      azimuth =
          (540 -
              math.acos(
                    ((math.sin(latitude * math.pi / 180) *
                                math.cos(zenithAngle * math.pi / 180)) -
                            math.sin(sunDeclination * math.pi / 180)) /
                        (math.cos(latitude * math.pi / 180) *
                            math.sin(zenithAngle * math.pi / 180)),
                  ) *
                  180 /
                  math.pi) %
          360;
    }

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
