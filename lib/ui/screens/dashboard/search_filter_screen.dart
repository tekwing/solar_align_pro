import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart'; // Required for formatting the custom date

import '../../../models/project.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/theme_provider.dart';
import 'widget/site_card.dart';

class SearchFilterScreen extends ConsumerStatefulWidget {
  const SearchFilterScreen({super.key});

  @override
  ConsumerState<SearchFilterScreen> createState() => _SearchFilterScreenState();
}

class _SearchFilterScreenState extends ConsumerState<SearchFilterScreen> {
  String _searchQuery = '';
  String _selectedStatus = 'All';
  String _selectedDate = 'All Time';
  DateTime? _customSelectedDate; // State to hold the specific chosen date

  final List<String> _statusFilters = [
    'All',
    'Ready',
    'In Progress',
    'Pending',
  ];

  // Added 'Custom Date' to the filters list
  final List<String> _dateFilters = [
    'All Time',
    'Last 7 Days',
    'Last 30 Days',
    'Custom Date',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final allProjects = ref.watch(projectListProvider);

    // Apply active filters dynamically
    List<Project> filteredProjects = allProjects.where((p) {
      // 1. Search Query Match
      final query = _searchQuery.toLowerCase();
      final matchesSearch =
          p.customerName.toLowerCase().contains(query) ||
          p.address.toLowerCase().contains(query);

      // 2. Status Match
      int stepsCompleted = 0;
      if (p.latitude != null) stepsCompleted++;
      if (p.estimatedSystemKw != null) stepsCompleted++;
      if (p.finalAzimuth != null) stepsCompleted++;

      bool matchesStatus = true;
      if (_selectedStatus == 'Ready') {
        matchesStatus = stepsCompleted == 3;
      } else if (_selectedStatus == 'In Progress') {
        matchesStatus = stepsCompleted > 0 && stepsCompleted < 3;
      } else if (_selectedStatus == 'Pending') {
        matchesStatus = stepsCompleted == 0;
      }

      // 3. Date Match
      bool matchesDate = true;
      final now = DateTime.now();
      if (_selectedDate == 'Last 7 Days') {
        matchesDate = now.difference(p.createdAt).inDays <= 7;
      } else if (_selectedDate == 'Last 30 Days') {
        matchesDate = now.difference(p.createdAt).inDays <= 30;
      } else if (_selectedDate == 'Custom Date' &&
          _customSelectedDate != null) {
        // Compare exactly by Year, Month, and Day
        matchesDate =
            p.createdAt.year == _customSelectedDate!.year &&
            p.createdAt.month == _customSelectedDate!.month &&
            p.createdAt.day == _customSelectedDate!.day;
      }

      return matchesSearch && matchesStatus && matchesDate;
    }).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: theme.colorScheme.onSurface,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'All Sites', // CHANGED: Now acts as the master View All screen
          style: GoogleFonts.outfit(
            color: theme.colorScheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Dynamic Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: GoogleFonts.plusJakartaSans(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Search by client or address...',
                hintStyle: GoogleFonts.plusJakartaSans(
                  color: theme.iconTheme.color?.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: theme.colorScheme.primary,
                ),
                filled: true,
                fillColor: theme.cardColor,
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: theme.dividerColor),
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
          ),

          // Filter Chips (Stacked vertically, wraps if needed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFilterGroup(
                  'Status',
                  _statusFilters,
                  _selectedStatus,
                  (val) => setState(() => _selectedStatus = val),
                  theme,
                ),
                const SizedBox(height: 20),
                _buildFilterGroup('Date Created', _dateFilters, _selectedDate, (
                  val,
                ) async {
                  if (val == 'Custom Date') {
                    // Open Premium Date Picker
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _customSelectedDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialEntryMode: DatePickerEntryMode
                          .calendarOnly, // Forces modern calendar UI
                      helpText: 'SELECT SURVEY DATE',
                      cancelText: 'CANCEL',
                      confirmText: 'APPLY',
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: isDark
                                ? ColorScheme.dark(
                                    primary: theme.colorScheme.primary,
                                    onPrimary: Colors.white,
                                    surface: theme.cardColor,
                                    onSurface: theme.colorScheme.onSurface,
                                  )
                                : ColorScheme.light(
                                    primary: theme.colorScheme.primary,
                                    onPrimary: Colors.white,
                                    surface: theme.cardColor,
                                    onSurface: theme.colorScheme.onSurface,
                                  ),
                            datePickerTheme: DatePickerThemeData(
                              backgroundColor: theme.cardColor,
                              surfaceTintColor: Colors
                                  .transparent, // Prevents default Material 3 purple tint
                              elevation: 24,
                              headerBackgroundColor: theme.colorScheme.primary,
                              headerForegroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              dayShape: WidgetStateProperty.all(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ), // Modern rounded corners instead of circles
                              ),
                              todayBorder: BorderSide(
                                color: theme.colorScheme.primary,
                                width: 2,
                              ),
                              headerHeadlineStyle: GoogleFonts.outfit(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                              ),
                              headerHelpStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                color: Colors.white70,
                              ),
                              dayStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                              weekdayStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: theme.iconTheme.color?.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              yearStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(
                                foregroundColor: theme.colorScheme.primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                textStyle: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setState(() {
                        _customSelectedDate = picked;
                        _selectedDate = val;
                      });
                    }
                  } else {
                    // Standard filters like "Last 7 Days"
                    setState(() {
                      _selectedDate = val;
                      _customSelectedDate = null;
                    });
                  }
                }, theme),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Divider(height: 1, color: theme.dividerColor),
          ),

          // Results List
          Expanded(
            child: filteredProjects.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 64,
                          color: theme.iconTheme.color?.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No sites match your filters.',
                          style: GoogleFonts.plusJakartaSans(
                            color: theme.iconTheme.color?.withValues(
                              alpha: 0.6,
                            ),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 40),
                    itemCount: filteredProjects.length,
                    itemBuilder: (context, index) {
                      return SiteCard(project: filteredProjects[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterGroup(
    String title,
    List<String> options,
    String selectedValue,
    Function(String) onSelect,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: theme.iconTheme.color?.withValues(alpha: 0.5),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8.0, // Gap between adjacent chips
          runSpacing: 8.0, // Gap between lines
          children: options.map((opt) {
            final isSelected = opt == selectedValue;

            // Format dynamic display label for specific date
            String displayLabel = opt;
            if (opt == 'Custom Date') {
              if (isSelected && _customSelectedDate != null) {
                displayLabel = DateFormat(
                  'MMM d, yyyy',
                ).format(_customSelectedDate!);
              } else {
                displayLabel = 'Specific Date';
              }
            }

            return ChoiceChip(
              label: Text(
                displayLabel,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                // If it's a specific date, clicking it again should re-trigger the picker
                if (selected || opt == 'Custom Date') {
                  HapticFeedback.selectionClick();
                  onSelect(opt);
                }
              },
              backgroundColor: theme.cardColor,
              selectedColor: theme.colorScheme.primary,
              side: BorderSide(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.dividerColor,
                width: 1.5,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              showCheckmark: false,
            );
          }).toList(),
        ),
      ],
    );
  }
}
