import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart'; // NEW: For GPS checking
import '../../../../models/project.dart';
import '../../../../providers/project_provider.dart';
import '../../../../providers/settings_provider.dart'; // NEW: For manual override
import '../../site_workspace_screen.dart';

class SiteCard extends ConsumerWidget {
  final Project project;

  const SiteCard({super.key, required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // We keep this purely to drive the Status Badge at the top!
    int stepsCompleted = 0;
    if (project.latitude != null) stepsCompleted++;
    if (project.estimatedSystemKw != null) stepsCompleted++;
    if (project.finalAzimuth != null) stepsCompleted++;

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: theme.dividerColor),
      ),
      child: Dismissible(
        key: Key(project.id),
        direction: DismissDirection.endToStart,
        background: _buildDeleteBackground(theme),
        onDismissed: (_) =>
            ref.read(projectListProvider.notifier).removeProject(project.id),
        child: InkWell(
          // --- NAVIGATION GUARD LOGIC ---
          onTap: () async {
            final manualLat = ref.read(manualLatProvider);
            final manualLon = ref.read(manualLonProvider);

            // 1. Allow entry if we already have a location (Hardware or Manual Override)
            if (project.latitude != null ||
                (manualLat != null && manualLon != null)) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SiteWorkspaceScreen(projectId: project.id),
                ),
              );
              return;
            }

            // 2. We don't have location. Check Hardware GPS status.
            bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
            if (!serviceEnabled) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enable GPS to open this workspace.'),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
              return;
            }

            // 3. Check App Permissions
            LocationPermission permission = await Geolocator.checkPermission();
            if (permission == LocationPermission.denied) {
              permission = await Geolocator.requestPermission();
              if (permission == LocationPermission.denied) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Location Permission is required.'),
                      backgroundColor: theme.colorScheme.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                return;
              }
            }

            if (permission == LocationPermission.deniedForever) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Permission denied. Use Manual Override in Settings.',
                    ),
                    backgroundColor: theme.colorScheme.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
              return;
            }

            // 4. Everything is enabled, grab the GPS location!
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Acquiring GPS lock...'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 1),
                ),
              );
            }

            try {
              Position position = await Geolocator.getCurrentPosition(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.high,
                ),
              );

              if (context.mounted) {
                // Save it to the database so we never have to ask again for this site
                await ref
                    .read(projectListProvider.notifier)
                    .updateProjectLocation(
                      project.id,
                      position.latitude,
                      position.longitude,
                      project.suggestedTilt ?? 30.0,
                    );

                if (!context.mounted) return;

                // Now allow entry into the workspace
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SiteWorkspaceScreen(projectId: project.id),
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Failed to acquire GPS.'),
                    backgroundColor: theme.colorScheme.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader(stepsCompleted, project.createdAt, theme),
                const SizedBox(height: 16),
                Text(
                  project.customerName,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                _buildAddressRow(project.address, theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteBackground(ThemeData theme) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 28),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Icon(
        Icons.delete_outline_rounded,
        color: theme.colorScheme.error,
        size: 32,
      ),
    );
  }

  Widget _buildCardHeader(int steps, DateTime date, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStatusBadge(steps, theme),
        Text(
          DateFormat('MMM d, yyyy').format(date),
          style: GoogleFonts.plusJakartaSans(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildAddressRow(String address, ThemeData theme) {
    return Row(
      children: [
        Icon(
          Icons.location_on_rounded,
          size: 16,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            address,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(int steps, ThemeData theme) {
    String text = steps == 3
        ? "Ready to Install"
        : (steps > 0 ? "In Progress" : "Pending Data");

    Color color = steps == 3
        ? Colors.green
        : (steps > 0 ? theme.colorScheme.primary : Colors.orange);

    Color bg = color.withValues(alpha: 0.15);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
