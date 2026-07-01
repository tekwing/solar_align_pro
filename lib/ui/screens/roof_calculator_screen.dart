import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/project_provider.dart';
import '../../providers/service_providers.dart';
import '../../providers/theme_provider.dart';
import '../../providers/settings_provider.dart';

class RoofCalculatorScreen extends ConsumerStatefulWidget {
  final String projectId;
  final double? projectLatitude;

  const RoofCalculatorScreen({
    super.key,
    required this.projectId,
    this.projectLatitude,
  });

  @override
  ConsumerState<RoofCalculatorScreen> createState() =>
      _RoofCalculatorScreenState();
}

class _RoofCalculatorScreenState extends ConsumerState<RoofCalculatorScreen> {
  // Calculation State
  final TextEditingController _areaController = TextEditingController();

  // Custom Panel Specs Controllers
  final TextEditingController _wattageController = TextEditingController(
    text: '400',
  );
  final TextEditingController _vocController = TextEditingController(
    text: '40.5',
  );
  final TextEditingController _impController = TextEditingController(
    text: '9.5',
  );

  int _panelCount = 0;
  double _systemSizeKw = 0.0;
  double _annualGenerationKwh = 0.0;
  double _annualSavings = 0.0;

  // Electrical Topology State (List of possible string patterns)
  List<Map<String, dynamic>> _topologies = [];
  int _selectedTopologyIndex = 0; // Tracks the user's selected pattern

  // Constants for Solar Math
  final double panelSizeSqMeters = 2.0; // Standard 400W panel + clearance area
  final double electricityRatePerKwh = 0.15; // Example: $0.15 per kWh
  final double sqMetersToSqFeet = 10.7639; // Conversion factor

  @override
  void dispose() {
    _areaController.dispose();
    _wattageController.dispose();
    _vocController.dispose();
    _impController.dispose();
    super.dispose();
  }

  void _calculateSolar(bool isMetric) {
    double displayArea = double.tryParse(_areaController.text) ?? 0.0;

    if (displayArea <= 0) {
      setState(() {
        _panelCount = 0;
        _systemSizeKw = 0.0;
        _annualGenerationKwh = 0.0;
        _annualSavings = 0.0;
        _topologies = [];
        _selectedTopologyIndex = 0;
      });
      return;
    }

    // Parse custom panel specifications
    double panelPower = double.tryParse(_wattageController.text) ?? 400.0;
    double panelVoc = double.tryParse(_vocController.text) ?? 40.5;
    double panelImp = double.tryParse(_impController.text) ?? 9.5;

    // Convert back to Sq Meters for standard panel math if user is in Sq Feet
    double areaInSqMeters = isMetric
        ? displayArea
        : (displayArea / sqMetersToSqFeet);

    final solarCalc = ref.read(solarCalculatorProvider);
    double sunHours = widget.projectLatitude != null
        ? solarCalc.estimatePeakSunHours(widget.projectLatitude!)
        : 4.5;

    setState(() {
      _panelCount = (areaInSqMeters / panelSizeSqMeters).floor();
      _systemSizeKw = (_panelCount * panelPower) / 1000.0;

      // Explicitly Generate the 3 Requested Patterns
      _topologies = [];
      if (_panelCount > 0) {
        // Pattern 1: All Series
        _topologies.add({
          'parallelStrings': 1,
          'panelsInSeries': _panelCount,
          'unbalanced': 0,
          'voc': _panelCount * panelVoc,
          'imp': panelImp,
        });

        // Pattern 2: Series and Parallel (Only generates if we have enough panels to split)
        if (_panelCount >= 4) {
          int parallelStrings = 2;
          if (_panelCount >= 20) {
            parallelStrings = 4; // Scale up strings for very large roofs
          }

          _topologies.add({
            'parallelStrings': parallelStrings,
            'panelsInSeries': _panelCount ~/ parallelStrings,
            'unbalanced': _panelCount % parallelStrings,
            'voc': (_panelCount ~/ parallelStrings) * panelVoc,
            'imp': parallelStrings * panelImp,
          });
        }

        // Pattern 3: All Parallel (Microinverters)
        if (_panelCount > 1) {
          _topologies.add({
            'parallelStrings': _panelCount,
            'panelsInSeries': 1,
            'unbalanced': 0,
            'voc': panelVoc,
            'imp': _panelCount * panelImp,
          });
        }
      }

      // Reset selection if the list size changes drastically
      if (_selectedTopologyIndex >= _topologies.length) {
        _selectedTopologyIndex = 0;
      }

      // (System Size * GPS Sun Hours * 365 Days * 80% Efficiency)
      _annualGenerationKwh = _systemSizeKw * sunHours * 365 * 0.8;
      _annualSavings = _annualGenerationKwh * electricityRatePerKwh;
    });
  }

  void _toggleUnit(bool toSqMeters, bool isCurrentlyMetric) {
    if (isCurrentlyMetric == toSqMeters) return;
    HapticFeedback.selectionClick();

    double currentVal = double.tryParse(_areaController.text) ?? 0.0;

    // Update global provider
    ref.read(unitProvider.notifier).state = toSqMeters
        ? MeasurementUnit.metric
        : MeasurementUnit.imperial;

    setState(() {
      if (currentVal > 0) {
        // Convert the existing input value to the new unit
        double newVal = toSqMeters
            ? (currentVal / sqMetersToSqFeet)
            : (currentVal * sqMetersToSqFeet);

        _areaController.value = TextEditingValue(
          text: newVal.toStringAsFixed(1),
          selection: TextSelection.collapsed(
            offset: newVal.toStringAsFixed(1).length,
          ),
        );
      }
    });

    // Recalculate explicitly so UI stays in sync
    _calculateSolar(toSqMeters);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    // Watch Global Providers
    final unit = ref.watch(unitProvider);
    final isMetric = unit == MeasurementUnit.metric;
    final currency = ref.watch(currencyProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'System Sizing & Topology',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            fontSize: 22,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: theme.colorScheme.onSurface,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      // SAFEAERA WRAPPER: Ensures content never clips under the system navigation bars
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Instructions
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.architecture_rounded,
                        color: theme.colorScheme.primary,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Manual Roof Area',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Enter the usable roof area below to calculate optimal panel placement and electrical topology.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: theme.iconTheme.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // 2. Input Dimension Area
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'USABLE ROOF AREA',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: theme.iconTheme.color?.withValues(alpha: 0.5),
                        letterSpacing: 1.5,
                      ),
                    ),

                    // UNIT TOGGLE UI
                    Container(
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => _toggleUnit(true, isMetric),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isMetric
                                    ? theme.colorScheme.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'sq.m',
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
                            onTap: () => _toggleUnit(false, isMetric),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: !isMetric
                                    ? theme.colorScheme.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'sq.ft',
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
                const SizedBox(height: 12),

                TextField(
                  controller: _areaController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => _calculateSolar(isMetric),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter area...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: theme.iconTheme.color?.withValues(alpha: 0.3),
                      fontWeight: FontWeight.w600,
                    ),
                    contentPadding: const EdgeInsets.all(24),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.onSurface.withValues(
                      alpha: 0.04,
                    ),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: Icon(
                        Icons.square_foot_rounded,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // 3. Panel Specifications (Dynamic Options)
                Text(
                  'PANEL SPECIFICATIONS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: theme.iconTheme.color?.withValues(alpha: 0.5),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildCompactTextField(
                        controller: _wattageController,
                        label: 'Power (W)',
                        icon: Icons.bolt_rounded,
                        theme: theme,
                        onChanged: (_) => _calculateSolar(isMetric),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCompactTextField(
                        controller: _vocController,
                        label: 'Voc (V)',
                        icon: Icons.speed_rounded,
                        theme: theme,
                        onChanged: (_) => _calculateSolar(isMetric),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCompactTextField(
                        controller: _impController,
                        label: 'Imp (A)',
                        icon: Icons.electric_meter_rounded,
                        theme: theme,
                        onChanged: (_) => _calculateSolar(isMetric),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // 4. Calculation Results Cards
                Text(
                  'SYSTEM CAPABILITIES',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: theme.iconTheme.color?.withValues(alpha: 0.5),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildResultCard(
                        'Panels Fit',
                        '$_panelCount',
                        Icons.grid_on_rounded,
                        const Color(0xFF3B82F6),
                        theme,
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildResultCard(
                        'System Size',
                        '${_systemSizeKw.toStringAsFixed(1)} kW',
                        Icons.bolt_rounded,
                        const Color(0xFFF59E0B),
                        theme,
                        isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildResultCard(
                        'Annual Gen.',
                        '${_annualGenerationKwh.toStringAsFixed(0)} kWh',
                        Icons.solar_power_rounded,
                        const Color(0xFF8B5CF6),
                        theme,
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildResultCard(
                        'Est. Savings',
                        '$currency${_annualSavings.toStringAsFixed(0)}/yr',
                        Icons.savings_rounded,
                        const Color(0xFF10B981),
                        theme,
                        isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),

                // 5. Electrical Topologies List (Multiple Options)
                if (_topologies.isNotEmpty) ...[
                  Text(
                    'AVAILABLE ELECTRICAL TOPOLOGIES',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: theme.iconTheme.color?.withValues(alpha: 0.5),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Dynamically build an interactive card for every possible topology pattern
                  ..._topologies.asMap().entries.map(
                    (entry) => _buildTopologyCard(
                      theme: theme,
                      isDark: isDark,
                      topology: entry.value,
                      index: entry.key,
                      isSelected: _selectedTopologyIndex == entry.key,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedTopologyIndex = entry.key);
                      },
                    ),
                  ),

                  const SizedBox(height: 32),
                ],

                // 6. Premium Save Button
                Container(
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
                        color: (isDark ? Colors.black : const Color(0xFF1E3A8A))
                            .withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      double displayArea =
                          double.tryParse(_areaController.text) ?? 0.0;
                      if (displayArea <= 0) return;

                      // Ensure we always save standard Sq Meters to the database!
                      double areaInSqMeters = isMetric
                          ? displayArea
                          : (displayArea / sqMetersToSqFeet);

                      await ref
                          .read(projectListProvider.notifier)
                          .saveRoofEstimations(
                            widget.projectId,
                            areaInSqMeters,
                            _panelCount,
                            _systemSizeKw,
                            _annualGenerationKwh,
                            _annualSavings,
                            topology: _topologies.isNotEmpty
                                ? _topologies[_selectedTopologyIndex]
                                : null,
                          );

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Saved: Pattern ${_selectedTopologyIndex + 1} Selected!',
                          ),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );

                      Navigator.pop(context);
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
                    child: Text(
                      'SAVE ESTIMATION',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 32,
                ), // EXTRA BREATHING ROOM BELOW THE BUTTON
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildCompactTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ThemeData theme,
    required void Function(String) onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: theme.colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.plusJakartaSans(
          color: theme.iconTheme.color?.withValues(alpha: 0.8),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        prefixIcon: Icon(
          icon,
          color: theme.iconTheme.color?.withValues(alpha: 0.5),
          size: 18,
        ),
        filled: true,
        fillColor: theme.colorScheme.onSurface.withValues(alpha: 0.04),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildResultCard(
    String title,
    String value,
    IconData icon,
    Color iconColor,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: isDark ? 0.05 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: theme.iconTheme.color?.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopologyCard({
    required ThemeData theme,
    required bool isDark,
    required Map<String, dynamic> topology,
    required int index,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    int parallel = topology['parallelStrings'] as int;
    int series = topology['panelsInSeries'] as int;

    // Dynamically label the configuration type
    String configurationType = "Custom Configuration";
    if (parallel == 1 && series > 1) {
      configurationType = "All Series Configuration";
    } else if (series == 1 && parallel > 1) {
      configurationType = "All Parallel Configuration";
    } else if (parallel > 1 && series > 1) {
      configurationType = "Series and Parallel Configuration";
    } else if (parallel == 1 && series == 1) {
      configurationType = "Single Panel Configuration";
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.05)
              : theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: isSelected ? 30 : 24,
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
                    color: const Color(0xFFE11D48).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cable_rounded,
                    color: Color(0xFFE11D48),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pattern ${index + 1}',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.onSurface,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        configurationType,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: theme.iconTheme.color?.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Divider(height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTopologyItem(theme, 'Parallel Strings', '$parallel'),
                _buildTopologyItem(
                  theme,
                  'Panels in Series',
                  '$series / string',
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTopologyItem(
                  theme,
                  'String Voltage (Voc)',
                  '${(topology['voc'] as double).toStringAsFixed(1)} V',
                ),
                _buildTopologyItem(
                  theme,
                  'Array Current (Imp)',
                  '${(topology['imp'] as double).toStringAsFixed(1)} A',
                ),
              ],
            ),
            if (topology['unbalanced'] > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Layout has ${topology['unbalanced']} unbalanced panel(s).',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.orange.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopologyItem(ThemeData theme, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.iconTheme.color?.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
