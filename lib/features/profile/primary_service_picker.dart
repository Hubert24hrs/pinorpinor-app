import 'package:flutter/material.dart';

import '../../core/constants/primary_services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// The six-way choice of what a member is here for.
///
/// Mirrors `components/profile/PrimaryServicePicker.tsx`. All six show at once
/// with no search box: that is the point of a short list, where the 31-entry
/// activity catalogue needs grouping and a filter to be usable on a phone.
///
/// [value] may be null and that is a real state — a member who registered before
/// 2026-08-21 has never chosen. The picker shows nothing selected rather than
/// preselecting an option, because a preselected radio is an answer the member
/// did not give, and this one is published on their public profile.
class PrimaryServicePicker extends StatelessWidget {
  const PrimaryServicePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String? value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final PrimaryServiceOption option in kPrimaryServices)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: InkWell(
              onTap: enabled ? () => onChanged(option.id) : null,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                // 44px floor, met by the padding plus two lines of text.
                constraints: const BoxConstraints(
                  minHeight: AppSpacing.minTouchTarget,
                ),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: value == option.id
                      ? AppColors.badgeRoseBg
                      : AppColors.bgSecondary,
                  border: Border.all(
                    color: value == option.id
                        ? AppColors.rose
                        : AppColors.border,
                    width: value == option.id ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(option.glyph, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            option.label,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: value == option.id
                                  ? AppColors.rose
                                  : AppColors.textMain,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(option.hint, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Icon(
                      value == option.id
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: value == option.id
                          ? AppColors.rose
                          : AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
