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

  // --- Structural State ---
  String _selectedRoof = 'Asphalt Shingle';
  String _selectedSpacing = '24" On Center';

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
  String _wireGauge = '10 AWG';

  final List<String> _wireSizes = [
    '12 AWG',
    '10 AWG',
    '8 AWG',
    '6 AWG',
    '4 AWG',
    'Other',
  ];

  // --- AC & Inverter State ---
  String _inverterType = 'String Inverter';
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

  @override
  void initState() {
    super.initState();
    // Load pre-existing project data after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProjectData();
    });
  }

  void _loadProjectData() {
    final project = ref
        .read(projectListProvider)
        .firstWhere((p) => p.id == widget.projectId);

    // 1. Pre-fill structural and checklist data if already saved
    if (project.roofMaterial != null &&
        _roofTypes.contains(project.roofMaterial)) {
      setState(() => _selectedRoof = project.roofMaterial!);
    }
    if (project.rafterSpacing != null &&
        _spacingOptions.contains(project.rafterSpacing)) {
      setState(() => _selectedSpacing = project.rafterSpacing!);
    }
    if (project.mainPanelAmps != null) {
      _breakerSizeController.text = project.mainPanelAmps.toString();
    }

    // 2. Pre-fill calculations from Roof Calculator
    if (project.estimatedPanels != null) {
      _totalPanelsController.text = project.estimatedPanels.toString();
    }

    // Reverse-calculate single Panel Voc and Imp from the saved String/Array totals
    if (project.stringVoc != null &&
        project.panelsInSeries != null &&
        project.panelsInSeries! > 0) {
      double singlePanelVoc = project.stringVoc! / project.panelsInSeries!;
      _panelVocController.text = singlePanelVoc
          .toStringAsFixed(1)
          .replaceAll(RegExp(r'\.0$'), ''); // Clean decimal
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
        padding: const EdgeInsets.all(24),
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
                    _buildDropdownField(
                      label: 'Roof Material',
                      value: _selectedRoof,
                      items: _roofTypes,
                      icon: Icons.roofing_rounded,
                      theme: theme,
                      onChanged: (val) => setState(() => _selectedRoof = val!),
                    ),
                    const SizedBox(height: 24),
                    _buildDropdownField(
                      label: 'Rafter Spacing',
                      value: _selectedSpacing,
                      items: _spacingOptions,
                      icon: Icons.format_line_spacing_rounded,
                      theme: theme,
                      onChanged: (val) =>
                          setState(() => _selectedSpacing = val!),
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
                    _buildDropdownField(
                      label: 'DC Home Run Wire Gauge',
                      value: _wireGauge,
                      items: _wireSizes,
                      icon: Icons.cable_rounded,
                      theme: theme,
                      onChanged: (val) => setState(() => _wireGauge = val!),
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
                    _buildDropdownField(
                      label: 'Inverter Type',
                      value: _inverterType,
                      items: _inverterTypes,
                      icon: Icons.account_tree_rounded,
                      theme: theme,
                      onChanged: (val) => setState(() => _inverterType = val!),
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                      controller: _inverterPowerController,
                      label: 'Inverter Rated Power',
                      hint: 'e.g. 7.6',
                      icon: Icons.bolt_rounded,
                      suffixText: 'kW',
                      theme: theme,
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                      controller: _inverterVoltageController,
                      label: 'Inverter Output Voltage',
                      hint: 'e.g. 240',
                      icon: Icons.power_rounded,
                      suffixText: 'V',
                      theme: theme,
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
                      // TODO: Update Project Model to accept all the new Engineering variables
                      await ref
                          .read(projectListProvider.notifier)
                          .saveChecklist(
                            widget.projectId,
                            _selectedRoof,
                            _selectedSpacing,
                            int.tryParse(_breakerSizeController.text) ?? 200,
                          );

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Engineering Checklist Saved!'),
                          backgroundColor: Colors.green,
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

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required ThemeData theme,
    required ValueChanged<String?> onChanged,
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
        DropdownButtonFormField<String>(
          value: value,
          icon: Icon(
            Icons.expand_more_rounded,
            color: theme.colorScheme.primary,
          ),
          dropdownColor: theme.cardColor,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: theme.iconTheme.color?.withValues(alpha: 0.5),
              size: 20,
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
          items: items
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: onChanged,
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
          validator: (value) =>
              (value == null || value.isEmpty) ? 'Required field' : null,
        ),
      ],
    );
  }
}
