import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart'; // Added Google Fonts
import '../../../../providers/project_provider.dart';

class NewSiteModal extends ConsumerStatefulWidget {
  const NewSiteModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NewSiteModal(),
    );
  }

  @override
  ConsumerState<NewSiteModal> createState() => _NewSiteModalState();
}

class _NewSiteModalState extends ConsumerState<NewSiteModal> {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final addressCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    // Watch the active theme to adapt colors dynamically
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor, // Adapts to Light/Dark mode
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
                _buildField(
                  nameCtrl,
                  'Client Name',
                  'e.g. John Doe Residence',
                  Icons.person_outline,
                  theme,
                ),
                const SizedBox(height: 24),
                _buildField(
                  phoneCtrl,
                  'Contact Number',
                  '+1 (555) 000-0000',
                  Icons.phone_outlined,
                  theme,
                  isPhone: true,
                ),
                const SizedBox(height: 24),
                _buildField(
                  addressCtrl,
                  'Site Address',
                  '123 Solar Way, Sunnyville',
                  Icons.location_on_outlined,
                  theme,
                ),
                const SizedBox(height: 48),
                _buildSubmitButton(context, theme),
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 40),
              ],
            ),
          ),
        ],
      ),
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
            color: Colors.amber.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.add_location_alt,
            color: Colors.amber.shade700,
            size: 32,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Initialize New Site',
          style: GoogleFonts.outfit(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the client details to create a new workspace.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color:
                theme.iconTheme.color?.withValues(alpha: 0.7) ??
                Colors.grey.shade500,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    String hint,
    IconData icon,
    ThemeData theme, {
    bool isPhone = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(
              color: theme.iconTheme.color?.withValues(alpha: 0.5),
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(
              icon,
              color:
                  theme.iconTheme.color?.withValues(alpha: 0.5) ??
                  Colors.grey.shade400,
              size: 20,
            ),
            filled: true,
            // Adaptive input background based on Light/Dark mode
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
        ),
      ],
    );
  }

  Widget _buildSubmitButton(BuildContext context, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

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
      child: ElevatedButton(
        onPressed: () {
          if (nameCtrl.text.isNotEmpty) {
            ref
                .read(projectListProvider.notifier)
                .createProject(nameCtrl.text, phoneCtrl.text, addressCtrl.text);
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
          shadowColor: Colors
              .transparent, // Prevents default shadow from overriding ours
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'CREATE WORKSPACE',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
