import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../providers/theme_provider.dart';
import '../../../../providers/settings_provider.dart';

class SettingsModal extends ConsumerStatefulWidget {
  const SettingsModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SettingsModal(),
    );
  }

  @override
  ConsumerState<SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends ConsumerState<SettingsModal> {
  final _formKey = GlobalKey<FormState>();
  final latCtrl = TextEditingController();
  final lonCtrl = TextEditingController();

  final List<String> _currencies = ['\$', '€', '£', '₹', '¥', 'A\$', 'C\$'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentLat = ref.read(manualLatProvider);
      final currentLon = ref.read(manualLonProvider);
      if (currentLat != null) latCtrl.text = currentLat.toString();
      if (currentLon != null) lonCtrl.text = currentLon.toString();
    });
  }

  @override
  void dispose() {
    latCtrl.dispose();
    lonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = ref.watch(themeModeProvider) == ThemeMode.dark;

    final isScreenActive = ref.watch(keepScreenActiveProvider);
    final isSoundEnabled = ref.watch(soundEnabledProvider);
    final isVibrationEnabled = ref.watch(vibrationEnabledProvider);

    final unit = ref.watch(unitProvider);
    final isMetric = unit == MeasurementUnit.metric;
    final currency = ref.watch(currencyProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          _buildDragHandle(theme),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              children: [
                _buildHeader(theme),
                const SizedBox(height: 40),

                // --- TOGGLES SECTION ---
                Text(
                  'APP PREFERENCES',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: theme.iconTheme.color?.withValues(alpha: 0.5),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Column(
                    children: [
                      // 1. Theme Toggle
                      _buildSettingTile(
                        theme: theme,
                        title: 'Dark Appearance',
                        subtitle: 'Use dark color palette',
                        icon: Icons.dark_mode_rounded,
                        value: isDarkMode,
                        onChanged: (val) {
                          // FIX: Uses public custom method now
                          ref
                              .read(themeModeProvider.notifier)
                              .setThemeMode(
                                val ? ThemeMode.dark : ThemeMode.light,
                              );
                        },
                      ),
                      Divider(height: 1, indent: 60, color: theme.dividerColor),

                      // 2. Keep Screen Active Toggle
                      _buildSettingTile(
                        theme: theme,
                        title: 'Keep Screen Active',
                        subtitle: 'Prevent sleep during surveys',
                        icon: Icons.stay_current_portrait_rounded,
                        value: isScreenActive,
                        onChanged: (val) {
                          // FIX: Uses public set method now
                          ref.read(keepScreenActiveProvider.notifier).set(val);
                        },
                      ),
                      Divider(height: 1, indent: 60, color: theme.dividerColor),

                      // 3. Sound Toggle
                      _buildSettingTile(
                        theme: theme,
                        title: 'Sound Effects',
                        subtitle: 'In-app audio cues',
                        icon: Icons.volume_up_rounded,
                        value: isSoundEnabled,
                        onChanged: (val) {
                          // FIX: Uses public set method now
                          ref.read(soundEnabledProvider.notifier).set(val);
                        },
                      ),
                      Divider(height: 1, indent: 60, color: theme.dividerColor),

                      // 4. Vibration Toggle
                      _buildSettingTile(
                        theme: theme,
                        title: 'Haptic Feedback',
                        subtitle: 'Vibrate on major actions',
                        icon: Icons.vibration_rounded,
                        value: isVibrationEnabled,
                        onChanged: (val) {
                          // FIX: Uses public set method now
                          ref.read(vibrationEnabledProvider.notifier).set(val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // --- LOCALIZATION & UNITS SECTION ---
                Text(
                  'LOCALIZATION & UNITS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: theme.iconTheme.color?.withValues(alpha: 0.5),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Column(
                    children: [
                      _buildUnitToggle(theme, isMetric),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0),
                        child: Divider(height: 1, color: theme.dividerColor),
                      ),
                      _buildCurrencyDropdown(theme, currency),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // --- MANUAL LOCATION SECTION ---
                Text(
                  'LOCATION OVERRIDE',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: theme.iconTheme.color?.withValues(alpha: 0.5),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.gps_fixed_rounded,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Manual Coordinates',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Use this if GPS is inaccurate or unavailable. This will override hardware location across the app.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: theme.iconTheme.color?.withValues(
                              alpha: 0.7,
                            ),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildCoordinateField(
                                ctrl: latCtrl,
                                label: 'Latitude',
                                hint: 'e.g. 34.0522',
                                theme: theme,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    if (lonCtrl.text.isNotEmpty) {
                                      return 'Required';
                                    }
                                    return null;
                                  }
                                  final num = double.tryParse(value);
                                  if (num == null) return 'Invalid number';
                                  if (num < -90 || num > 90) {
                                    return 'Must be -90 to 90';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildCoordinateField(
                                ctrl: lonCtrl,
                                label: 'Longitude',
                                hint: 'e.g. -118.2437',
                                theme: theme,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    if (latCtrl.text.isNotEmpty) {
                                      return 'Required';
                                    }
                                    return null;
                                  }
                                  final num = double.tryParse(value);
                                  if (num == null) return 'Invalid number';
                                  if (num < -180 || num > 180) {
                                    return 'Must be -180 to 180';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildSaveLocationButton(theme, isDarkMode),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitToggle(ThemeData theme, bool isMetric) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.straighten_rounded,
            color: theme.colorScheme.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Measurement Unit',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  color: theme.dividerColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      // FIX: Uses public set method now
                      onTap: () => ref
                          .read(unitProvider.notifier)
                          .set(MeasurementUnit.metric),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isMetric
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Metric (sq.m)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isMetric
                                ? Colors.white
                                : theme.iconTheme.color,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      // FIX: Uses public set method now
                      onTap: () => ref
                          .read(unitProvider.notifier)
                          .set(MeasurementUnit.imperial),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: !isMetric
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Imperial (sq.ft)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: !isMetric
                                ? Colors.white
                                : theme.iconTheme.color,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurrencyDropdown(ThemeData theme, String currentCurrency) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.payments_rounded,
            color: Color(0xFF10B981),
            size: 22,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Display Currency',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Symbol used for savings',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.iconTheme.color?.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButton<String>(
            value: currentCurrency,
            underline: const SizedBox(),
            icon: Icon(
              Icons.expand_more_rounded,
              color: theme.colorScheme.primary,
            ),
            dropdownColor: theme.cardColor,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
            items: _currencies.map((String value) {
              return DropdownMenuItem<String>(value: value, child: Text(value));
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                // FIX: Uses public set method now
                ref.read(currencyProvider.notifier).set(val);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDragHandle(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 20),
      height: 5,
      width: 48,
      decoration: BoxDecoration(
        color: theme.dividerColor,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.tune_rounded,
            color: theme.colorScheme.primary,
            size: 32,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'App Preferences',
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Manage your field tools and hardware settings.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: theme.iconTheme.color,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingTile({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(
                alpha: value ? 0.15 : 0.05,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: value
                  ? theme.colorScheme.primary
                  : theme.iconTheme.color?.withValues(alpha: 0.5),
              size: 22,
            ),
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
                    fontWeight: FontWeight.w600,
                    color: theme.iconTheme.color?.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildCoordinateField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required ThemeData theme,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(
              color: theme.iconTheme.color?.withValues(alpha: 0.4),
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: theme.colorScheme.onSurface.withValues(alpha: 0.04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 2,
              ),
            ),
            errorStyle: GoogleFonts.plusJakartaSans(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.error,
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.error, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveLocationButton(ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF0F172A), const Color(0xFF020617)]
              : [const Color(0xFF1E3A8A), const Color(0xFF312E81)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFF1E3A8A)).withValues(
              alpha: 0.3,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            final lat = double.tryParse(latCtrl.text);
            final lon = double.tryParse(lonCtrl.text);

            if (lat != null && lon != null) {
              // StateProvider allows direct access to .state
              ref.read(manualLatProvider.notifier).state = lat;
              ref.read(manualLonProvider.notifier).state = lon;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Manual Location Override Active!'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              Navigator.pop(context);
            } else if (latCtrl.text.isEmpty && lonCtrl.text.isEmpty) {
              ref.read(manualLatProvider.notifier).state = null;
              ref.read(manualLonProvider.notifier).state = null;
              Navigator.pop(context);
            }
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: Text(
          'APPLY OVERRIDE',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
