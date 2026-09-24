import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// One bookable hour, as staff see it.
///
/// Shared by the two admin screens that pick a time — creating a booking and
/// moving one — because they are the same choice and should not look like two.
class AdminHourChip extends StatelessWidget {
  const AdminHourChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.isTaken,
    required this.onTap,
  });

  final String label;
  final bool isSelected;

  /// Occupied by somebody else. Staff are exempt from most rules, but not
  /// from a chair already having a person in it.
  final bool isTaken;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: isTaken ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.primaryGradient : null,
          color: isSelected
              ? null
              : isTaken
              ? AppColors.textTertiary.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : AppColors.textTertiary.withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? Colors.white
                : isTaken
                ? AppColors.textTertiary
                : AppColors.textPrimary,
            decoration: isTaken ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }
}
