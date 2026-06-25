import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';

import '../../../providers/project_provider.dart';
import '../../../providers/settings_provider.dart';

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
  double _pitch = 0.0;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;

  @override
  void initState() {
    super.initState();
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
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  void _initSensors() {
    _accelSubscription = accelerometerEventStream().listen((
      AccelerometerEvent event,
    ) {
      if (!mounted) return;
      setState(() {
        _pitch = -(math.atan2(event.z, event.y) * 180 / math.pi);
        if (_pitch < -90) _pitch = 360 + _pitch;
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

    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return;

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
        return DateTime(now.year, 6, 21);
      case SunSeason.equinox:
        return DateTime(now.year, 3, 20);
      case SunSeason.winter:
        return DateTime(now.year, 12, 21);
    }
  }

  @override
  void dispose() {
    _accelSubscription?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = ref
        .watch(projectListProvider)
        .firstWhere((p) => p.id == widget.projectId);
    final activeLat = project.latitude;
    final activeLon = project.longitude;
    final simulationDate = _getDateForSeason(_selectedSeason);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_controller?.value.isInitialized ?? false)
            CameraPreview(_controller!)
          else
            const Center(child: CircularProgressIndicator(color: Colors.amber)),

          Container(color: Colors.black.withValues(alpha: 0.3)),

          CustomPaint(
            painter: _StableSunPathPainter(
              pitch: _pitch,
              latitude: activeLat,
              longitude: activeLon,
              simulationDate: simulationDate,
            ),
            size: Size.infinite,
          ),

          // ... (Rest of UI components remain identical to previous iteration)
          Positioned(
            top: 60,
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
                ),
                child: Text(
                  'TILT: ${_pitch.clamp(0, 180).toStringAsFixed(0)}°',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ... (_StableSunPathPainter and SunPositionCalculator classes remain unchanged)
class _StableSunPathPainter extends CustomPainter {
  final double pitch;
  final double? latitude;
  final double? longitude;
  final DateTime simulationDate;

  _StableSunPathPainter({
    required this.pitch,
    this.latitude,
    this.longitude,
    required this.simulationDate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ... (Logic from previous code block)
  }

  @override
  bool shouldRepaint(covariant _StableSunPathPainter oldDelegate) => true;
}

class SunPositionCalculator {
  // ... (Keep existing algorithm)
}
