import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/project_provider.dart';
import '../../providers/theme_provider.dart';

class SiteChecklistScreen extends ConsumerStatefulWidget {
  final String projectId;

  const SiteChecklistScreen({super.key, required this.projectId});

  @override
  ConsumerState<SiteChecklistScreen> createState() =>
      _SiteChecklistScreenState();
}

class _SiteChecklistScreenState extends ConsumerState<SiteChecklistScreen> {
  final _formKey = GlobalKey<FormState>();

  // --- Hybrid Editable Dropdown Controllers ---
  final TextEditingController _roofController = TextEditingController(
    text: 'Asphalt Shingle',
  );
  final TextEditingController _spacingController = TextEditingController(
    text: '24" On Center',
  );
  final TextEditingController _wireGaugeController = TextEditingController(
    text: '10 AWG',
  );
  final TextEditingController _inverterController = TextEditingController(
    text: 'String Inverter',
  );
  final TextEditingController _batteryTypeController = TextEditingController(
    text: 'None',
  );
  final TextEditingController _notesController = TextEditingController();

  final List<String> _roofTypes = [
    'Asphalt Shingle',
    'Spanish Tile',
    'Metal Standing Seam',
    'Flat/Membrane',
    'Corrugated Iron',
  ];

  final List<String> _spacingOptions = [
    '16" On Center',
    '24" On Center',
    'Custom/Other',
  ];

  // --- DC Array State ---
  final TextEditingController _totalPanelsController = TextEditingController();
  final TextEditingController _panelVocController = TextEditingController();
  final TextEditingController _panelImpController = TextEditingController();

  final List<String> _wireSizes = [
    '12 AWG',
    '10 AWG',
    '8 AWG',
    '6 AWG',
    '4 AWG',
  ];

  // --- AC & Inverter State ---
  final TextEditingController _inverterPowerController =
      TextEditingController();
  final TextEditingController _inverterVoltageController =
      TextEditingController();
  final TextEditingController _breakerSizeController = TextEditingController();

  final List<String> _inverterTypes = [
    'String Inverter',
    'Microinverters',
    'Hybrid Inverter',
    'String w/ Optimizers',
  ];

  // --- Battery State ---
  final TextEditingController _batteryCapacityController =
      TextEditingController();
  final TextEditingController _batteryVoltageController =
      TextEditingController();

  final List<String> _batteryTypes = [
    'None',
    'Lithium Iron Phosphate (LFP)',
    'Lithium Ion (NMC)',
    'Lead Acid (AGM)',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProjectData();
    });
  }

  void _loadProjectData() {
    final project = ref
        .read(projectListProvider)
        .firstWhere((p) => p.id == widget.projectId);

    // 1. Pre-fill structural and checklist data if already saved
    if (project.roofMaterial != null) {
      _roofController.text = project.roofMaterial!;
    }
    if (project.rafterSpacing != null) {
      _spacingController.text = project.rafterSpacing!;
    }
    if (project.wireGauge != null) {
      _wireGaugeController.text = project.wireGauge!;
    }
    if (project.inverterType != null) {
      _inverterController.text = project.inverterType!;
    }
    if (project.additionalNotes != null) {
      _notesController.text = project.additionalNotes!;
    }
    if (project.mainPanelAmps != null) {
      _breakerSizeController.text = project.mainPanelAmps.toString();
    }

    // NEW: Load the new inverter specs!
    if (project.inverterPowerKw != null) {
      _inverterPowerController.text = project.inverterPowerKw.toString();
    }
    if (project.inverterVoltage != null) {
      _inverterVoltageController.text = project.inverterVoltage.toString();
    }

    // Load Battery Data
    if (project.batteryType != null) {
      _batteryTypeController.text = project.batteryType!;
    }
    if (project.batteryCapacityKwh != null) {
      _batteryCapacityController.text = project.batteryCapacityKwh.toString();
    }
    if (project.batteryVoltage != null) {
      _batteryVoltageController.text = project.batteryVoltage.toString();
    }

    // 2. Pre-fill calculations from Roof Calculator
    if (project.estimatedPanels != null) {
      _totalPanelsController.text = project.estimatedPanels.toString();
    }

    if (project.stringVoc != null &&
        project.panelsInSeries != null &&
        project.panelsInSeries! > 0) {
      double singlePanelVoc = project.stringVoc! / project.panelsInSeries!;
      _panelVocController.text = singlePanelVoc
          .toStringAsFixed(1)
          .replaceAll(RegExp(r'\.0$'), '');
    }

    if (project.arrayImp != null &&
        project.parallelStrings != null &&
        project.parallelStrings! > 0) {
      double singlePanelImp = project.arrayImp! / project.parallelStrings!;
      _panelImpController.text = singlePanelImp
          .toStringAsFixed(1)
          .replaceAll(RegExp(r'\.0$'), '');
    }
  }

  @override
  void dispose() {
    _roofController.dispose();
    _spacingController.dispose();
    _wireGaugeController.dispose();
    _inverterController.dispose();
    _batteryTypeController.dispose();
    _batteryCapacityController.dispose();
    _batteryVoltageController.dispose();
    _notesController.dispose();
    _totalPanelsController.dispose();
    _panelVocController.dispose();
    _panelImpController.dispose();
    _inverterPowerController.dispose();
    _inverterVoltageController.dispose();
    _breakerSizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Engineering Checklist',
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
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Premium Header
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
                      Icons.engineering_rounded,
                      color: theme.colorScheme.primary,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'System Engineering',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Document physical and electrical specifications.',
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

              _buildSectionHeader('STRUCTURAL DATA', theme),
              const SizedBox(height: 12),
              _buildCardWrapper(
                theme: theme,
                isDark: isDark,
                child: Column(
                  children: [
                    _buildEditableDropdownField(
                      controller: _roofController,
                      label: 'Roof Material',
                      items: _roofTypes,
                      icon: Icons.roofing_rounded,
                      theme: theme,
                    ),
                    const SizedBox(height: 24),
                    _buildEditableDropdownField(
                      controller: _spacingController,
                      label: 'Rafter Spacing',
                      items: _spacingOptions,
                      icon: Icons.format_line_spacing_rounded,
                      theme: theme,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              _buildSectionHeader('SOLAR ARRAY (DC)', theme),
              const SizedBox(height: 12),
              _buildCardWrapper(
                theme: theme,
                isDark: isDark,
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _totalPanelsController,
                      label: 'Total Number of Panels',
                      hint: 'e.g. 24',
                      icon: Icons.grid_view_rounded,
                      suffixText: 'panels',
                      theme: theme,
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                      controller: _panelVocController,
                      label: 'Panel Output Voltage (Voc)',
                      hint: 'e.g. 40.5',
                      icon: Icons.speed_rounded,
                      suffixText: 'V',
                      theme: theme,
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                      controller: _panelImpController,
                      label: 'Max Panel Current (Imp)',
                      hint: 'e.g. 9.5',
                      icon: Icons.electric_meter_rounded,
                      suffixText: 'A',
                      theme: theme,
                    ),
                    const SizedBox(height: 24),
                    _buildEditableDropdownField(
                      controller: _wireGaugeController,
                      label: 'DC Home Run Wire Gauge',
                      items: _wireSizes,
                      icon: Icons.cable_rounded,
                      theme: theme,
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                      controller: _breakerSizeController,
                      label: 'Main Breaker Size',
                      hint: 'e.g. 40',
                      icon: Icons.electrical_services_rounded,
                      suffixText: 'A',
                      theme: theme,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              _buildSectionHeader('INVERTER & AC OUTPUT', theme),
              const SizedBox(height: 12),
              _buildCardWrapper(
                theme: theme,
                isDark: isDark,
                child: Column(
                  children: [
                    _buildEditableDropdownField(
                      controller: _inverterController,
                      label: 'Inverter Type',
                      items: _inverterTypes,
                      icon: Icons.account_tree_rounded,
                      theme: theme,
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                      controller: _inverterPowerController,
                      label: 'Inverter Rated Power',
                      hint: 'e.g. 7.6',
                      icon: Icons.bolt_rounded,
                      suffixText: 'kW',
                      theme: theme,
                      isRequired: false,
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                      controller: _inverterVoltageController,
                      label: 'Inverter Output Voltage',
                      hint: 'e.g. 240',
                      icon: Icons.power_rounded,
                      suffixText: 'V',
                      theme: theme,
                      isRequired: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              _buildSectionHeader('ENERGY STORAGE (BATTERY)', theme),
              const SizedBox(height: 12),
              _buildCardWrapper(
                theme: theme,
                isDark: isDark,
                child: Column(
                  children: [
                    _buildEditableDropdownField(
                      controller: _batteryTypeController,
                      label: 'Battery Chemistry / Type',
                      items: _batteryTypes,
                      icon: Icons.battery_charging_full_rounded,
                      theme: theme,
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                      controller: _batteryCapacityController,
                      label: 'Total Capacity',
                      hint: 'e.g. 13.5',
                      icon: Icons.battery_saver_rounded,
                      suffixText: 'kWh',
                      theme: theme,
                      isRequired: false,
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                      controller: _batteryVoltageController,
                      label: 'Battery Bank Voltage',
                      hint: 'e.g. 48',
                      icon: Icons.electrical_services_rounded,
                      suffixText: 'V',
                      theme: theme,
                      isRequired: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              _buildSectionHeader('ADDITIONAL INFORMATION', theme),
              const SizedBox(height: 12),
              _buildCardWrapper(
                theme: theme,
                isDark: isDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Site Notes & Hazards',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 4,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Type any extra site details, hazards, access codes, or requirements here...',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          color: theme.iconTheme.color?.withValues(alpha: 0.4),
                          fontWeight: FontWeight.w500,
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.onSurface.withValues(
                          alpha: 0.04,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

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
                    if (_formKey.currentState!.validate()) {
                      await ref
                          .read(projectListProvider.notifier)
                          .saveChecklist(
                            widget.projectId,
                            _roofController.text,
                            _spacingController.text,
                            int.tryParse(_breakerSizeController.text) ?? 200,
                            _inverterController.text,
                            _wireGaugeController.text,
                            _notesController.text,
                            _batteryTypeController.text,
                            double.tryParse(_batteryCapacityController.text),
                            double.tryParse(_batteryVoltageController.text),
                            // IMPORTANT: Passing the new parameters to the provider!
                            double.tryParse(_inverterPowerController.text),
                            double.tryParse(_inverterVoltageController.text),
                          );

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.engineering_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Engineering Data Saved',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      'Checklist updated successfully.',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: const Color(0xFF10B981),
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.only(
                            bottom: 24,
                            left: 24,
                            right: 24,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 10,
                        ),
                      );
                      Navigator.pop(context);
                    }
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
                      const Icon(Icons.check_circle_outline_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'SAVE ENGINEERING DATA',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
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
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: theme.iconTheme.color?.withValues(alpha: 0.5),
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildCardWrapper({
    required ThemeData theme,
    required bool isDark,
    required Widget child,
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
      child: child,
    );
  }

  // --- Hybrid Editable Dropdown ---
  Widget _buildEditableDropdownField({
    required TextEditingController controller,
    required String label,
    required List<String> items,
    required IconData icon,
    required ThemeData theme,
    bool isRequired = true,
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
          controller: controller,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            hintText: 'Type or select...',
            hintStyle: GoogleFonts.plusJakartaSans(
              color: theme.iconTheme.color?.withValues(alpha: 0.4),
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(
              icon,
              color: theme.iconTheme.color?.withValues(alpha: 0.5),
              size: 20,
            ),
            suffixIcon: PopupMenuButton<String>(
              icon: Icon(
                Icons.expand_more_rounded,
                color: theme.colorScheme.primary,
              ),
              color: theme.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onSelected: (String value) {
                controller.text = value;
              },
              itemBuilder: (BuildContext context) {
                return items.map((String choice) {
                  return PopupMenuItem<String>(
                    value: choice,
                    child: Text(
                      choice,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  );
                }).toList();
              },
            ),
            filled: true,
            fillColor: theme.colorScheme.onSurface.withValues(alpha: 0.04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 2,
              ),
            ),
          ),
          validator: isRequired
              ? (value) =>
                    (value == null || value.isEmpty) ? 'Required field' : null
              : null,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required ThemeData theme,
    String? suffixText,
    bool isRequired = true,
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
          controller: controller,
          keyboardType: TextInputType.number,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(
              color: theme.iconTheme.color?.withValues(alpha: 0.4),
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(
              icon,
              color: theme.iconTheme.color?.withValues(alpha: 0.5),
              size: 20,
            ),
            suffixText: suffixText,
            suffixStyle: suffixText != null
                ? GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  )
                : null,
            filled: true,
            fillColor: theme.colorScheme.onSurface.withValues(alpha: 0.04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
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
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: theme.colorScheme.error,
                width: 1.5,
              ),
            ),
          ),
          validator: isRequired
              ? (value) =>
                    (value == null || value.isEmpty) ? 'Required field' : null
              : null,
        ),
      ],
    );
  }
}
