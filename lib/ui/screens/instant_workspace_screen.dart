import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/project_provider.dart';
import 'ar_alignment_screen.dart';
import 'roof_calculator_screen.dart';
import 'shading_analysis_screen.dart';

class InstantWorkspaceScreen extends ConsumerWidget {
  final String projectId;

  const InstantWorkspaceScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectListProvider);
    final projectIndex = projects.indexWhere((p) => p.id == projectId);

    if (projectIndex == -1) {
      return const Scaffold(body: Center(child: Text('Session Expired.')));
    }

    final project = projects[projectIndex];
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Instant Tools',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w800,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFF0B131E),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instant Mode Warning Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.flash_on_rounded,
                    color: Colors.amber,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Instant Mode',
                          style: GoogleFonts.outfit(
                            color: Colors.amber,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Data will not be saved. Use these tools for quick, on-the-fly field estimations.',
                          style: GoogleFonts.plusJakartaSans(
                            color: theme.colorScheme.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            Text(
              'FIELD TOOLS',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: theme.iconTheme.color?.withOpacity(0.6),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),

            // Tools Menu (No PDF export, No Client Checklist!)
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.dividerColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
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
                    iconBg: const Color(0xFF3B82F6).withOpacity(0.15),
                    theme: theme,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ARAlignmentScreen(
                          projectId: project.id,
                          targetAzimuth: 180.0,
                          targetTilt: 30.0,
                        ),
                      ),
                    ),
                  ),
                  Divider(height: 1, indent: 64, color: theme.dividerColor),
                  _buildActionTile(
                    title: 'System Sizing & Topology',
                    subtitle: 'Calculate panels, strings, and ROI',
                    icon: Icons.architecture_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    iconBg: const Color(0xFFF59E0B).withOpacity(0.15),
                    theme: theme,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            RoofCalculatorScreen(projectId: project.id),
                      ),
                    ),
                  ),
                  Divider(height: 1, indent: 64, color: theme.dividerColor),
                  _buildActionTile(
                    title: 'Shading Analysis',
                    subtitle: 'Check for horizon obstacles',
                    icon: Icons.wb_sunny_rounded,
                    iconColor: const Color(0xFF10B981),
                    iconBg: const Color(0xFF10B981).withOpacity(0.15),
                    theme: theme,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ShadingAnalysisScreen(projectId: project.id),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
                      color: theme.iconTheme.color?.withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.iconTheme.color?.withOpacity(0.3),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
