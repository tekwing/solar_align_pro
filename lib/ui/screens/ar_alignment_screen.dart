import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Haptic and Sound
import 'package:camera/camera.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart'; // For Location Permissions and Data
import 'package:google_fonts/google_fonts.dart'; // Premium Fonts

import '../../providers/project_provider.dart';
import '../../providers/settings_provider.dart';
import '../../main.dart';

class ARAlignmentScreen extends ConsumerStatefulWidget {
  final String projectId;
  final double targetAzimuth;
  final double targetTilt;

  const ARAlignmentScreen({
    super.key,
    required this.projectId,
    required this.targetAzimuth,
    required this.targetTilt,
  });

  @override
  ConsumerState<ARAlignmentScreen> createState() => _ARAlignmentScreenState();
}

class _ARAlignmentScreenState extends ConsumerState<ARAlignmentScreen> {
  late CameraController _cameraController;
  bool _isCameraInitialized = false;

  // Sensor Data
  double? _currentHeading;
  double _currentTilt = 0.0;

  // Track if we are currently in the "Perfect" zone to prevent spamming the save/haptic functions
  bool _wasAlignedLastFrame = false;

  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initSensors();
    _initLocation();
  }

  Future<void> _initCamera() async {
    if (cameras.isEmpty) return;

    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _cameraController.initialize();
    if (mounted) {
      setState(() => _isCameraInitialized = true);
    }
  }

  void _initSensors() {
    // Listen to device tilt (Pitch) continuously
    _accelSubscription = accelerometerEventStream().listen((
      AccelerometerEvent event,
    ) {
      if (!mounted) return;
      setState(() {
        _currentTilt = math.atan2(event.y, event.z) * 180 / math.pi;
        if (_currentTilt < 0) _currentTilt += 360;
      });
      _checkAlignment();
    });

    // Listen to device heading (Azimuth) continuously
    _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
      if (!mounted) return;
      setState(() {
        _currentHeading = event.heading;
      });
      _checkAlignment();
    });
  }

  Future<void> _initLocation() async {
    final manualLat = ref.read(manualLatProvider);
    final manualLon = ref.read(manualLonProvider);
    final project = ref
        .read(projectListProvider)
        .firstWhere((p) => p.id == widget.projectId);

    // 1. Check for Global Manual Location Override FIRST
    if (manualLat != null && manualLon != null) {
      if (project.latitude != manualLat || project.longitude != manualLon) {
        await ref
            .read(projectListProvider.notifier)
            .updateProjectLocation(
              widget.projectId,
              manualLat,
              manualLon,
              project.suggestedTilt ?? 30.0,
            );
      }
      return;
    }

    // 2. Hardware GPS Fallback
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    if (project.latitude == null || project.longitude == null) {
      await ref
          .read(projectListProvider.notifier)
          .updateProjectLocation(
            widget.projectId,
            position.latitude,
            position.longitude,
            project.suggestedTilt ?? 30.0,
          );
    }
  }

  void _checkAlignment() {
    if (_currentHeading == null) return;

    bool isAzimuthAligned =
        (_currentHeading! - widget.targetAzimuth).abs() < 5.0;
    bool isTiltAligned = (_currentTilt - widget.targetTilt).abs() < 5.0;
    bool isPerfect = isAzimuthAligned && isTiltAligned;

    // Only trigger the save and haptic feedback the MOMENT we cross into the perfect zone
    if (isPerfect && !_wasAlignedLastFrame) {
      _wasAlignedLastFrame = true;
      _triggerFeedbackAndSave();
    } else if (!isPerfect && _wasAlignedLastFrame) {
      // If we drifted out of the perfect zone, reset the flag so it can trigger again later
      _wasAlignedLastFrame = false;
    }
  }

  Future<void> _triggerFeedbackAndSave() async {
    // Read Global Hardware Preferences
    final isSoundEnabled = ref.read(soundEnabledProvider);
    final isVibrationEnabled = ref.read(vibrationEnabledProvider);

    // Provide reliable physical/audio feedback
    if (isVibrationEnabled) {
      // Heavy impact is universally respected by Android & iOS hardware
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 150), () {
        HapticFeedback.heavyImpact(); // Double thump to confirm
      });
    }
    if (isSoundEnabled) {
      // Click is universally supported
      SystemSound.play(SystemSoundType.click);
    }

    // Auto-Save silently in the background
    await ref
        .read(projectListProvider.notifier)
        .saveAlignment(widget.projectId, _currentHeading!);

    if (mounted) {
      // Clear old snackbars to prevent stacking
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Target Aligned & Saved!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2), // Keep it brief
        ),
      );
    }
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    _accelSubscription?.cancel();
    if (_isCameraInitialized) {
      _cameraController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    final isManualOverride = ref.watch(manualLatProvider) != null;
    final project = ref
        .watch(projectListProvider)
        .firstWhere((p) => p.id == widget.projectId);

    bool isAzimuthAligned =
        _currentHeading != null &&
        (_currentHeading! - widget.targetAzimuth).abs() < 5.0;
    bool isTiltAligned = (_currentTilt - widget.targetTilt).abs() < 5.0;
    bool isPerfect = isAzimuthAligned && isTiltAligned;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Live Camera Background
          CameraPreview(_cameraController),

          // 2. Adaptive Vignette Overlay for HUD contrast
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.6),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.8),
                ],
                stops: const [0.0, 0.2, 0.6, 1.0],
              ),
            ),
          ),

          // 3. Location & Status HUD (Top Center)
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isManualOverride
                                ? Icons.edit_location_alt_rounded
                                : Icons.my_location_rounded,
                            color: Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            project.latitude != null
                                ? '${isManualOverride ? 'OVERRIDE' : 'GPS'}: ${project.latitude!.toStringAsFixed(4)}, ${project.longitude!.toStringAsFixed(4)}'
                                : 'Acquiring GPS...',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Fluid UI Status Target
                if (isPerfect) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.5),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'TARGET ALIGNED',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 4. The Compass & Tilt HUD
          _currentHeading == null
              ? Center(
                  child: Text(
                    'Calibrating Sensors...',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.amber,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),

                    // HUD Target Crosshair Box
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        color: isPerfect
                            ? Colors.greenAccent.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.05),
                        border: Border.all(
                          color: isPerfect
                              ? Colors.greenAccent
                              : Colors.white.withValues(alpha: 0.4),
                          width: isPerfect ? 4 : 2,
                        ),
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: isPerfect
                            ? [
                                BoxShadow(
                                  color: Colors.greenAccent.withValues(
                                    alpha: 0.5,
                                  ),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: Icon(
                          isPerfect ? Icons.check_rounded : Icons.add_rounded,
                          color: isPerfect
                              ? Colors.greenAccent
                              : Colors.white.withValues(alpha: 0.5),
                          size: 48,
                        ),
                      ),
                    ),
                    const SizedBox(height: 80),

                    // Live Telemetry Readout
                    ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: _buildTelemetryReadout(
                                  'Azimuth (Heading)',
                                  _currentHeading!,
                                  widget.targetAzimuth,
                                  isAzimuthAligned,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 60,
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                              Expanded(
                                child: _buildTelemetryReadout(
                                  'Panel Tilt (Pitch)',
                                  _currentTilt,
                                  widget.targetTilt,
                                  isTiltAligned,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 40), // Padding for bottom
                  ],
                ),

          // 5. Back Button (Top Left)
          Positioned(
            top: 50,
            left: 16,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 24,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryReadout(
    String label,
    double current,
    double target,
    bool isAligned,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${current.toStringAsFixed(1)}°',
          style: GoogleFonts.outfit(
            color: isAligned ? Colors.greenAccent : Colors.white,
            fontSize: 42,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'TARGET: ${target.toStringAsFixed(1)}°',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}
