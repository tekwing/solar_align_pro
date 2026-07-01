import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart'; // NEW: For permanent storage

import '../../providers/project_provider.dart';
import '../../main.dart'; // To access cameras

class SitePhotoScreen extends ConsumerStatefulWidget {
  final String projectId;

  const SitePhotoScreen({super.key, required this.projectId});

  @override
  ConsumerState<SitePhotoScreen> createState() => _SitePhotoScreenState();
}

class _SitePhotoScreenState extends ConsumerState<SitePhotoScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      cameras.first, // Uses the back camera
      ResolutionPreset.high,
      enableAudio: false, // Prevents asking for mic permission
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return CameraPreview(_controller);
              } else {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.amber),
                );
              }
            },
          ),

          // Back Button
          Positioned(
            top: 50,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 32),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Capture Button
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: InkWell(
                onTap: () async {
                  try {
                    await _initializeControllerFuture;

                    // 1. Take the picture (saves to phone's temp cache)
                    final image = await _controller.takePicture();

                    // --- NEW PERMANENT STORAGE LOGIC ---
                    // Get the permanent App Documents Directory
                    final directory = await getApplicationDocumentsDirectory();

                    // Create a unique file name using the current timestamp
                    final fileName =
                        'site_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
                    final savedImagePath = '${directory.path}/$fileName';

                    // Copy the image from the temp cache to the permanent path
                    await File(image.path).copy(savedImagePath);
                    // ------------------------------------

                    if (!mounted) return;

                    // 2. Save the PERMANENT string path into our Hive database
                    await ref
                        .read(projectListProvider.notifier)
                        .addPhotoToProject(widget.projectId, savedImagePath);

                    // 3. Show success and leave screen
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Photo securely attached to site survey!',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                    Navigator.pop(context);
                  } catch (e) {
                    debugPrint("Camera Error: $e");
                  }
                },
                child: Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.amber, width: 4),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.black,
                    size: 40,
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
