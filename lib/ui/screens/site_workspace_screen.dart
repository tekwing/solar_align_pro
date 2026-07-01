import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart'; // NEW: For GPS Requests

import '../../../models/project.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/service_providers.dart';
import '../../../providers/settings_provider.dart';
import 'ar_alignment_screen.dart';
import 'site_photo_screen.dart';
import 'shading_analysis_screen.dart';
import 'site_checklist_screen.dart';
import 'roof_calculator_screen.dart';

class SiteWorkspaceScreen extends ConsumerStatefulWidget {
  final String projectId;

  const SiteWorkspaceScreen({super.key, required this.projectId});

  @override
  ConsumerState<SiteWorkspaceScreen> createState() =>
      _SiteWorkspaceScreenState();
}

class _SiteWorkspaceScreenState extends ConsumerState<SiteWorkspaceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndFetchLocation();
    });
  }

  Future<void> _checkAndFetchLocation() async {
    final manualLat = ref.read(manualLatProvider);
    final manualLon = ref.read(manualLonProvider);

    final projects = ref.read(projectListProvider);
    final projectIndex = projects.indexWhere((p) => p.id == widget.projectId);
    if (projectIndex == -1) return;
    final project = projects[projectIndex];

    // If manual override exists and it differs from the project, update it.
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

    // Already have GPS? No need to ask again.
    if (project.latitude != null && project.longitude != null) return;

    // Check Hardware GPS and Ask User
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please enable GPS/Location Services for accurate telemetry.',
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    // Fetch and save actual GPS
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final projects = ref.watch(projectListProvider);
    final projectIndex = projects.indexWhere((p) => p.id == widget.projectId);

    // Watch Global Localization Settings
    final unit = ref.watch(unitProvider);
    final isMetric = unit == MeasurementUnit.metric;
    final currency = ref.watch(currencyProvider);

    if (projectIndex == -1) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Text(
            'Workspace not found.',
            style: GoogleFonts.plusJakartaSans(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      );
    }

    final project = projects[projectIndex];

    // Determine the active coordinates (Manual takes priority over GPS)
    final manualLat = ref.watch(manualLatProvider);
    final manualLon = ref.watch(manualLonProvider);

    final activeLat = manualLat ?? project.latitude;
    final activeLon = manualLon ?? project.longitude;

    final bool hasLocation = activeLat != null && activeLon != null;
    final bool isManual = manualLat != null;

    // Solar Rule of Thumb: Ideal tilt is roughly equal to absolute latitude
    // FIX: Force re-evaluation using activeLat if suggestedTilt gets stuck or is invalid.
    final suggestedTilt = project.suggestedTilt;

    final double? displayTilt = (suggestedTilt != null && suggestedTilt > 0)
        ? suggestedTilt
        : activeLat?.abs();

    final List<String> photos = project.photoPaths ?? [];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverHeader(context, project, isDark),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Modern Client Details Card
                  _buildModernCard(
                    title: 'Contact Information',
                    icon: Icons.person_outline_rounded,
                    iconColor: const Color(0xFF3B82F6), // Soft Blue
                    iconBgColor: const Color(
                      0xFF3B82F6,
                    ).withValues(alpha: 0.15),
                    theme: theme,
                    isDark: isDark,
                    children: [
                      _buildInfoRow(Icons.phone_outlined, project.phone, theme),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 2. Solar Telemetry Card
                  _buildModernCard(
                    title: 'Calculated Telemetry',
                    icon: Icons.satellite_alt_rounded,
                    iconColor: const Color(0xFFF59E0B), // Amber
                    iconBgColor: const Color(
                      0xFFF59E0B,
                    ).withValues(alpha: 0.15),
                    theme: theme,
                    isDark: isDark,
                    children: [
                      _buildDataRow(
                        'Coordinates',
                        hasLocation
                            ? '${isManual ? 'Manual: ' : ''}${activeLat.toStringAsFixed(4)}, ${activeLon.toStringAsFixed(4)}'
                            : 'Pending Capture',
                        theme: theme,
                        highlight: !hasLocation,
                      ),
                      const SizedBox(height: 16),
                      _buildDataRow(
                        'Target Roof Tilt',
                        displayTilt != null
                            ? '${displayTilt.toStringAsFixed(1)}°'
                            : 'Awaiting Location...',
                        theme: theme,
                        highlight: displayTilt == null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 3. System Estimation & Topology Card (MERGED)
                  if (project.estimatedSystemKw != null) ...[
                    _buildModernCard(
                      title: 'System Estimation & Topology',
                      icon: Icons.bolt_rounded,
                      iconColor: const Color(0xFF10B981), // Emerald
                      iconBgColor: const Color(
                        0xFF10B981,
                      ).withValues(alpha: 0.15),
                      theme: theme,
                      isDark: isDark,
                      children: [
                        _buildDataRow(
                          'Usable Area',
                          isMetric
                              ? '${project.estimatedAreaSqM?.toStringAsFixed(1)} sq.m'
                              : '${(project.estimatedAreaSqM! * 10.7639).toStringAsFixed(1)} sq.ft',
                          theme: theme,
                        ),
                        const SizedBox(height: 12),
                        _buildDataRow(
                          'Panel Count',
                          '${project.estimatedPanels} panels',
                          theme: theme,
                        ),
                        const SizedBox(height: 12),
                        _buildDataRow(
                          'System Size',
                          '${project.estimatedSystemKw?.toStringAsFixed(1)} kW',
                          theme: theme,
                          isBold: true,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Divider(height: 1, color: theme.dividerColor),
                        ),
                        _buildDataRow(
                          'Est. Generation',
                          '${project.estimatedGenerationKwh?.toStringAsFixed(0)} kWh/yr',
                          theme: theme,
                        ),
                        const SizedBox(height: 12),
                        _buildDataRow(
                          'Est. Savings',
                          '$currency${project.estimatedSavings?.toStringAsFixed(0)}/yr',
                          theme: theme,
                          isBold: true,
                          valueColor: const Color(0xFF10B981),
                        ),

                        // TOPOLOGY DETAILS (Forced to show even if null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Divider(height: 1, color: theme.dividerColor),
                        ),
                        _buildDataRow(
                          'Pattern Type',
                          project.selectedTopologyName ?? 'Pending Selection',
                          theme: theme,
                          isBold: true,
                          valueColor: const Color(0xFFE11D48),
                        ),
                        const SizedBox(height: 12),
                        _buildDataRow(
                          'String Layout',
                          project.parallelStrings != null
                              ? '${project.parallelStrings} Parallel, ${project.panelsInSeries} Series'
                              : 'Pending Selection',
                          theme: theme,
                        ),
                        const SizedBox(height: 12),
                        _buildDataRow(
                          'Array Voltage (Voc)',
                          project.stringVoc != null
                              ? '${project.stringVoc?.toStringAsFixed(1)} V'
                              : 'Pending Selection',
                          theme: theme,
                        ),
                        const SizedBox(height: 12),
                        _buildDataRow(
                          'Array Current (Imp)',
                          project.arrayImp != null
                              ? '${project.arrayImp?.toStringAsFixed(1)} A'
                              : 'Pending Selection',
                          theme: theme,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 4. Site Variables (Checklist & Shading)
                  if (project.roofMaterial != null ||
                      project.shadingLossPercentage != null) ...[
                    _buildModernCard(
                      title: 'Site Variables',
                      icon: Icons.home_work_outlined,
                      iconColor: const Color(0xFF8B5CF6), // Purple
                      iconBgColor: const Color(
                        0xFF8B5CF6,
                      ).withValues(alpha: 0.15),
                      theme: theme,
                      isDark: isDark,
                      children: [
                        if (project.roofMaterial != null) ...[
                          _buildDataRow(
                            'Roof Material',
                            project.roofMaterial!,
                            theme: theme,
                          ),
                          const SizedBox(height: 12),
                          _buildDataRow(
                            'Electrical Panel',
                            '${project.mainPanelAmps} A',
                            theme: theme,
                          ),
                        ],
                        if (project.roofMaterial != null &&
                            project.shadingLossPercentage != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Divider(
                              height: 1,
                              color: theme.dividerColor,
                            ),
                          ),
                        if (project.shadingLossPercentage != null)
                          _buildDataRow(
                            'Shading Impact',
                            '${project.shadingLossPercentage!.toInt()}% Loss',
                            theme: theme,
                            highlight: project.shadingLossPercentage! > 20,
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 5. Site Photos Gallery
                  _buildModernCard(
                    title: 'Site Photos (${photos.length})',
                    icon: Icons.photo_library_outlined,
                    iconColor: const Color(0xFF6366F1), // Indigo
                    iconBgColor: const Color(
                      0xFF6366F1,
                    ).withValues(alpha: 0.15),
                    theme: theme,
                    isDark: isDark,
                    children: [
                      if (photos.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: theme.iconTheme.color?.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'No photos captured yet.',
                                style: GoogleFonts.plusJakartaSans(
                                  color: theme.iconTheme.color?.withValues(
                                    alpha: 0.7,
                                  ),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: photos.length,
                            itemBuilder: (context, index) {
                              final photoPath = photos[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 12.0),
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => FullScreenGalleryScreen(
                                          photoPaths: photos,
                                          initialIndex: index,
                                        ),
                                      ),
                                    );
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.file(
                                      File(photoPath),
                                      height: 100,
                                      width: 100,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                                height: 100,
                                                width: 100,
                                                color: theme.dividerColor
                                                    .withValues(alpha: 0.5),
                                                child: Icon(
                                                  Icons.broken_image_rounded,
                                                  color: theme.iconTheme.color
                                                      ?.withValues(alpha: 0.5),
                                                ),
                                              ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // 6. Field Tools Section
                  Text(
                    'WORKSPACE TOOLS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: theme.iconTheme.color?.withValues(alpha: 0.6),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Menu of Action Cards
                  Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: theme.dividerColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.2 : 0.02,
                          ),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildActionTile(
                          title: 'AR Panel Alignment',
                          subtitle: 'Calibrate panel tilt & azimuth',
                          icon: Icons.view_in_ar_rounded,
                          iconColor: const Color(0xFF3B82F6),
                          iconBg: const Color(
                            0xFF3B82F6,
                          ).withValues(alpha: 0.15),
                          theme: theme,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ARAlignmentScreen(
                                projectId: project.id,
                                targetAzimuth: project.finalAzimuth ?? 180.0,
                                targetTilt: displayTilt ?? 30.0,
                              ),
                            ),
                          ),
                        ),
                        Divider(
                          height: 1,
                          indent: 64,
                          color: theme.dividerColor,
                        ),
                        _buildActionTile(
                          title: 'System Sizing & Topology',
                          subtitle: 'Calculate panels, strings, and ROI',
                          icon: Icons.architecture_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          iconBg: const Color(
                            0xFFF59E0B,
                          ).withValues(alpha: 0.15),
                          theme: theme,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RoofCalculatorScreen(
                                projectId: project.id,
                                projectLatitude:
                                    activeLat, // Use active/manual latitude
                              ),
                            ),
                          ),
                        ),
                        Divider(
                          height: 1,
                          indent: 64,
                          color: theme.dividerColor,
                        ),
                        _buildActionTile(
                          title: 'Take Site Photos',
                          subtitle: 'Document roof and electrical',
                          icon: Icons.camera_alt_rounded,
                          iconColor: theme.colorScheme.primary,
                          iconBg: theme.colorScheme.primary.withValues(
                            alpha: 0.15,
                          ),
                          theme: theme,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  SitePhotoScreen(projectId: project.id),
                            ),
                          ),
                        ),
                        Divider(
                          height: 1,
                          indent: 64,
                          color: theme.dividerColor,
                        ),
                        _buildActionTile(
                          title: 'Shading Analysis',
                          subtitle: 'Check for horizon obstacles',
                          icon: Icons.wb_sunny_rounded,
                          iconColor: theme.colorScheme.primary,
                          iconBg: theme.colorScheme.primary.withValues(
                            alpha: 0.15,
                          ),
                          theme: theme,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ShadingAnalysisScreen(projectId: project.id),
                            ),
                          ),
                        ),
                        Divider(
                          height: 1,
                          indent: 64,
                          color: theme.dividerColor,
                        ),
                        _buildActionTile(
                          title: 'Site Analysis Checklist',
                          subtitle: 'Complete physical inspection',
                          icon: Icons.checklist_rtl_rounded,
                          iconColor: theme.colorScheme.primary,
                          iconBg: theme.colorScheme.primary.withValues(
                            alpha: 0.15,
                          ),
                          theme: theme,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  SiteChecklistScreen(projectId: project.id),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 7. Premium Gradient Export Button
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [const Color(0xFF0F172A), const Color(0xFF020617)]
                            : [
                                const Color(0xFF1E3A8A),
                                const Color(0xFF312E81),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (isDark ? Colors.black : const Color(0xFF1E3A8A))
                                  .withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        _showPdfOptionsModal(context, project, isDark, theme);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.picture_as_pdf_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'GENERATE REPORT',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI HELPERS ---

  Widget _buildSliverHeader(
    BuildContext context,
    Project project,
    bool isDark,
  ) {
    // Defines the solid bar color that remains when scrolled/collapsed
    final topGradientColors = isDark
        ? [const Color(0xFF0F172A), const Color(0xFF020617)]
        : [const Color(0xFF1E3A8A), const Color(0xFF312E81)];

    return SliverAppBar(
      pinned:
          true, // Forces the top bar to remain fixed and not scroll under the status icons
      expandedHeight: 240.0,
      backgroundColor: Colors.transparent, // Controlled by flexible space
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'WORKSPACE DETAILS',
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white.withValues(alpha: 0.8),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
      centerTitle: false,

      // Flexible Space handles the beautiful edge-to-edge gradient and fade-out scrolling
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: topGradientColors,
          ),
          // We intentionally drop the bottom radius here so it sits perfectly flush with
          // the status bar when collapsed, preventing scrolling overlap.
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : const Color(0xFF1E3A8A))
                  .withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: FlexibleSpaceBar(
          background: Stack(
            children: [
              // Ambient Geometric Glows
              Positioned(
                bottom: -50,
                left: -50,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(
                          0xFF38BDF8,
                        ).withValues(alpha: isDark ? 0.08 : 0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -40,
                left: -100,
                child: Transform.rotate(
                  angle: -0.2,
                  child: Container(
                    width: 500,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(alpha: isDark ? 0.02 : 0.06),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Main Title Content (Pushed to bottom, gracefully fades out on scroll)
              Positioned(
                bottom: 32,
                left: 24,
                right: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.customerName,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w900,
                        fontSize: 32,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 14,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            project.address,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required ThemeData theme,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 18,
          color: theme.iconTheme.color?.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataRow(
    String label,
    String value, {
    required ThemeData theme,
    bool highlight = false,
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: theme.iconTheme.color?.withValues(alpha: 0.8),
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: isBold || highlight ? FontWeight.w800 : FontWeight.w700,
            color: highlight
                ? theme.colorScheme.error
                : (valueColor ?? theme.colorScheme.onSurface),
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required ThemeData theme,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: theme.iconTheme.color?.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.iconTheme.color?.withValues(alpha: 0.3),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  void _showPdfOptionsModal(
    BuildContext context,
    Project project,
    bool isDark,
    ThemeData theme,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Text(
              'EXPORT REPORT',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: theme.iconTheme.color?.withValues(alpha: 0.5),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              onTap: () async {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Downloading Report...'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                final pdfService = ref.read(pdfServiceProvider);
                bool success = await pdfService.generateAndShareReport(
                  project,
                  downloadOnly: true,
                );
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('PDF Saved to Downloads Folder!'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.download_rounded, color: Colors.blue),
              ),
              title: Text(
                'Download to Device',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                'Save PDF locally',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: theme.iconTheme.color?.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              onTap: () async {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Preparing Report...'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                final pdfService = ref.read(pdfServiceProvider);
                await pdfService.generateAndShareReport(
                  project,
                  downloadOnly: false,
                );
              },
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.share_rounded, color: Colors.green),
              ),
              title: Text(
                'Share Report',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                'Send via Email, Msg, etc.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: theme.iconTheme.color?.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// FULL SCREEN PHOTO GALLERY WIDGET
// -------------------------------------------------------------
class FullScreenGalleryScreen extends StatefulWidget {
  final List<String> photoPaths;
  final int initialIndex;

  const FullScreenGalleryScreen({
    super.key,
    required this.photoPaths,
    required this.initialIndex,
  });

  @override
  State<FullScreenGalleryScreen> createState() =>
      _FullScreenGalleryScreenState();
}

class _FullScreenGalleryScreenState extends State<FullScreenGalleryScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.photoPaths.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: Center(
                  child: Image.file(
                    File(widget.photoPaths[index]),
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.photoPaths.length}',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
