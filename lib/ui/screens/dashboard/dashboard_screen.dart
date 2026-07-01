import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart'; // REQUIRED FOR REAL-TIME GPS

import '../../../models/project.dart';
import '../../../providers/project_provider.dart';
import 'widgets/site_card.dart';
import 'widgets/new_site_modal.dart';
import 'widgets/settings_modal.dart';
import 'search_filter_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _sunrise = '--:--';
  String _sunset = '--:--';
  String _peakSun = '--:--';
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _fetchLocationAndCalculateSunTimes();
  }

  Future<void> _fetchLocationAndCalculateSunTimes() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _calculateSunTimes(34.0522, -118.2437); // Fallback to Los Angeles
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _calculateSunTimes(34.0522, -118.2437); // Fallback
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _calculateSunTimes(34.0522, -118.2437); // Fallback
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low, // same idea as before
        ),
      );
      _calculateSunTimes(position.latitude, position.longitude);
    } catch (e) {
      _calculateSunTimes(34.0522, -118.2437); // Fallback
    }
  }

  // Astronomical mathematical formula to calculate true Sunrise & Sunset times
  void _calculateSunTimes(double lat, double lng) {
    final now = DateTime.now();
    int dayOfYear = int.parse(DateFormat("D").format(now));

    // Equation of time approximation (in minutes)
    double b = 2 * math.pi / 365 * (dayOfYear - 81);
    double eot =
        9.87 * math.sin(2 * b) - 7.53 * math.cos(b) - 1.5 * math.sin(b);

    // Solar declination
    double dec = 23.45 * math.sin(2 * math.pi / 365 * (dayOfYear - 81));

    // Hour angle at sunrise/sunset
    double latRad = lat * math.pi / 180;
    double decRad = dec * math.pi / 180;
    double cosHourAngle = -math.tan(latRad) * math.tan(decRad);

    // Clamp prevents NaN errors in extreme polar latitudes
    cosHourAngle = cosHourAngle.clamp(-1.0, 1.0);
    double hourAngle = math.acos(cosHourAngle) * 180 / math.pi;

    // Convert angles to hours (Earth rotates 15 degrees per hour)
    double sunsetOffset = hourAngle / 15;
    double solarNoon = 12 - (lng / 15) - (eot / 60);

    // Apply Local Timezone Offset
    double tzOffset = now.timeZoneOffset.inMinutes / 60.0;
    solarNoon += tzOffset;

    // Wrap into 24-hour constraints
    solarNoon = solarNoon % 24;
    if (solarNoon < 0) solarNoon += 24;

    double sunriseHour = solarNoon - sunsetOffset;
    double sunsetHour = solarNoon + sunsetOffset;

    String formatTime(double timeInHours) {
      int h = timeInHours.floor();
      int m = ((timeInHours - h) * 60).round();
      if (m == 60) {
        h += 1;
        m = 0;
      }
      h = h % 24;
      if (h < 0) h += 24;
      final dummyDate = DateTime(now.year, now.month, now.day, h, m);
      return DateFormat('hh:mm a').format(dummyDate);
    }

    if (mounted) {
      setState(() {
        _sunrise = formatTime(sunriseHour);
        _sunset = formatTime(sunsetHour);
        _peakSun = formatTime(solarNoon);
        _isLoadingLocation = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Explicitly sort projects by creation date, showing the newest ones first
    final projects = ref.watch(projectListProvider).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final total = projects.length;
    final completed = projects.where((p) => p.finalAzimuth != null).length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildHeader(context),
          _buildStatsRow(context, completed, total),
          _buildActiveSitesTitle(context),
          _buildSiteList(projects),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0F172A),
                    const Color(0xFF020617),
                  ] // Premium Dark Slate
                : [
                    const Color(0xFF1E3A8A),
                    const Color(0xFF312E81),
                  ], // Rich Royal Blue to Indigo
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : const Color(0xFF1E3A8A))
                  .withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          backgroundColor: Colors.transparent,
          elevation: 0,
          hoverElevation: 0,
          focusElevation: 0,
          highlightElevation: 0,
          onPressed: () {
            HapticFeedback.selectionClick();
            NewSiteModal.show(context);
          },
          icon: const Icon(Icons.add, color: Colors.amber),
          label: Text(
            'New Site',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final topGradientColors = isDark
        ? [const Color(0xFF0F172A), const Color(0xFF020617)]
        : [const Color(0xFF1E3A8A), const Color(0xFF312E81)];

    return SliverAppBar(
      pinned: true,
      expandedHeight: 320.0,
      backgroundColor:
          Colors.transparent, // Background handled by flexibleSpace
      elevation: 0,
      toolbarHeight: 72.0, // Taller to fit the large logo box
      titleSpacing: 24.0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.1),
                  Colors.white.withValues(alpha: 0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.solar_power_rounded,
              color: Color(0xFFF59E0B),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Solar Align',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'PROFESSIONAL EDITION',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 24.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.settings_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    SettingsModal.show(context);
                  },
                ),
              ),
            ),
          ),
        ),
      ],
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: topGradientColors,
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
              // Content anchored from the top so it doesn't crush into the pinned toolbar on scroll
              Positioned(
                top: MediaQuery.of(context).padding.top + 90,
                left: 24,
                right: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGreeting(),
                    const SizedBox(height: 28),
                    _buildSolarWindowMetrics(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    final hour = DateTime.now().hour;
    String greeting = 'Good Evening';
    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: Text(
                DateFormat('EEE, MMM d').format(DateTime.now()).toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '•  $greeting',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Installation Hub',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildSolarWindowMetrics() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.2,
            ),
          ),
          child: _isLoadingLocation
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: CircularProgressIndicator(color: Colors.amber),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _metric(
                      'Sunrise',
                      _sunrise,
                      const Color(0xFFFBBF24),
                      Icons.wb_twilight_rounded,
                    ),
                    _buildVerticalDivider(),
                    _metric(
                      'Peak Sun',
                      _peakSun,
                      const Color(0xFFF59E0B),
                      Icons.wb_sunny_rounded,
                    ),
                    _buildVerticalDivider(),
                    _metric(
                      'Sunset',
                      _sunset,
                      const Color(0xFF818CF8),
                      Icons.nights_stay_rounded,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 32,
      width: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.25),
            Colors.white.withValues(alpha: 0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  Widget _metric(String label, String val, Color color, IconData icon) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color.withValues(alpha: 0.9), size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            val,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, int completed, int total) {
    final progress = total == 0 ? 0.0 : completed / total;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Row(
          children: [
            _statBox(
              context,
              'Aligned',
              '$completed',
              '$total Total',
              progress,
            ),
            const SizedBox(width: 16),
            _statBox(
              context,
              'Pending',
              '${total - completed}',
              'Action Req',
              0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBox(
    BuildContext context,
    String title,
    String val,
    String sub,
    double prog,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isPending = title.toLowerCase().contains('pending');
    final accentColor = isPending
        ? const Color(0xFFF59E0B)
        : const Color(0xFF10B981);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.04),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: isDark ? 0.05 : 0.08),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    color: theme.iconTheme.color?.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.6),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              val,
              style: GoogleFonts.outfit(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sub,
              style: GoogleFonts.plusJakartaSans(
                color: theme.iconTheme.color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: prog,
                minHeight: 6,
                backgroundColor: theme.dividerColor.withValues(
                  alpha: isDark ? 0.1 : 0.5,
                ),
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSitesTitle(BuildContext context) {
    final theme = Theme.of(context);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Active Sites',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchFilterScreen()),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style: GoogleFonts.plusJakartaSans(
                        color: theme.colorScheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: theme.colorScheme.primary,
                      size: 16,
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

  Widget _buildSiteList(List<Project> projects) {
    // Limits the dashboard to only show the 5 most recent projects. The rest are in "View All"
    final displayCount = projects.length > 5 ? 5 : projects.length;

    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) => SiteCard(project: projects[i]),
          childCount: displayCount,
        ),
      ),
    );
  }
}
