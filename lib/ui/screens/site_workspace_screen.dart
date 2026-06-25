import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/project.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/service_providers.dart';
import '../../../providers/settings_provider.dart';
import 'ar_alignment_screen.dart';
import 'site_photo_screen.dart';
import 'shading_analysis_screen.dart';
import 'site_checklist_screen.dart';
import 'roof_calculator_screen.dart'; // NEW: Bypasses the camera/AR screens

class SiteWorkspaceScreen extends ConsumerWidget {
  final String projectId;

  const SiteWorkspaceScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final projects = ref.watch(projectListProvider);
    final projectIndex = projects.indexWhere((p) => p.id == projectId);

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
    final bool hasGps = project.latitude != null;
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
                        'GPS Coordinates',
                        hasGps
                            ? '${project.latitude!.toStringAsFixed(4)}, ${project.longitude!.toStringAsFixed(4)}'
                            : 'Pending Capture',
                        theme: theme,
                        highlight: !hasGps,
                      ),
                      const SizedBox(height: 16),
                      _buildDataRow(
                        'Target Roof Tilt',
                        project.suggestedTilt != null
                            ? '${project.suggestedTilt!.toStringAsFixed(1)}°'
                            : 'Awaiting GPS...',
                        theme: theme,
                        highlight: project.suggestedTilt == null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 3. System Estimation Card (NOW USES GLOBAL UNIT/CURRENCY)
                  if (project.estimatedSystemKw != null) ...[
                    _buildModernCard(
                      title: 'System Estimation',
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
                                targetTilt: project.suggestedTilt ?? 30.0,
                              ),
                            ),
                          ),
                        ),
                        Divider(
                          height: 1,
                          indent: 64,
                          color: theme.dividerColor,
                        ),
                        // REPLACED: Consolidates Area & Topology into one easy manual entry screen
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
                                projectLatitude: project.latitude,
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
                      onPressed: () async {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Generating Report...'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        final pdfService = ref.read(pdfServiceProvider);
                        await pdfService.generateAndShareReport(project);
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
    return SliverToBoxAdapter(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF020617)]
                : [const Color(0xFF1E3A8A), const Color(0xFF312E81)],
          ),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(40),
          ),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : const Color(0xFF1E3A8A))
                  .withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Ambient Geometric Glows (Orange removed)
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
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back Button & Label
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Text(
                          'WORKSPACE DETAILS',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.only(left: 12.0),
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
          ],
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
}
