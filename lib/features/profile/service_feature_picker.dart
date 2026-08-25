import 'package:flutter/material.dart';

import '../../core/constants/service_features.dart';
import '../../core/theme/app_theme.dart';
import '../auth/login_screen.dart' show InlineNotice;

/// What a member offers, under whichever primary service they chose.
///
/// Mirrors the website's per-service selector. Until 2026-08-22 only Hookup had
/// a detail list; every other service was a bare badge, so a profile saying
/// "Relationship" told a visitor nothing beyond the word while a Hookup profile
/// carried thirty specifics. That asymmetry made the explicit list look like the
/// point of the platform rather than one option on it.
///
/// ## The gate is the service, not a flag
///
/// The catalogue comes from [featuresFor], and ids are prefixed per service so
/// none can be valid under two. **Switching primary service clears the
/// selection** — the parent does that, and the server does it again on save,
/// because ids from the old catalogue mean nothing under the new one and a
/// forgotten read path would publish them.
///
/// The search box only appears for a long catalogue: the explicit list is 36
/// entries and needs one on a 320px screen, and the others are sixteen and do
/// not.
class ServiceFeaturePicker extends StatefulWidget {
  const ServiceFeaturePicker({
    super.key,
    required this.primaryService,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  final String? primaryService;

  /// Selected ids. Controlled by the parent.
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  final bool enabled;

  /// Above this many options, a filter earns its place.
  static const int searchThreshold = 20;

  @override
  State<ServiceFeaturePicker> createState() => _ServiceFeaturePickerState();
}

class _ServiceFeaturePickerState extends State<ServiceFeaturePicker> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ServiceFeaturePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A query typed against one catalogue is meaningless against the next.
    if (oldWidget.primaryService != widget.primaryService) _search.clear();
  }

  void _toggle(String id, bool wanted) {
    final Set<String> next = widget.selected.toSet();
    if (wanted) {
      next.add(id);
    } else {
      next.remove(id);
    }
    // Catalogue order is imposed here as well as server-side, so the chips read
    // the same however they were tapped.
    widget.onChanged(
      sanitizeServiceFeatures(next, primaryService: widget.primaryService),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<ServiceFeature> all = featuresFor(widget.primaryService);
    if (all.isEmpty) return const SizedBox.shrink();

    final Set<String> selected = widget.selected.toSet();
    final String query = _search.text.trim().toLowerCase();

    final List<ServiceFeatureGrouping> groups = <ServiceFeatureGrouping>[
      for (final ServiceFeatureGrouping g in featuresByGroup(
        widget.primaryService,
      ))
        if (query.isEmpty)
          g
        else
          (
            group: g.group,
            options: <ServiceFeature>[
              for (final ServiceFeature o in g.options)
                if (o.label.toLowerCase().contains(query)) o,
            ],
          ),
    ].where((ServiceFeatureGrouping g) => g.options.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // The heading differs per service on purpose: what someone *offers*
        // under Hookup, what they *want* under Relationship. One generic word
        // over both would make the Relationship list read as a menu.
        Text(
          featuresHeading(widget.primaryService),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Optional. Only what you tick appears on your profile, and it is '
          'cleared if you change what you are here for.',
          style: theme.textTheme.bodySmall,
        ),

        if (isExplicitCatalogue(widget.primaryService)) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          const InlineNotice.warning(
            message:
                'This list is explicit and appears on your public profile, '
                'which anyone can read.',
          ),
        ],

        const SizedBox(height: AppSpacing.md),

        if (all.length > ServiceFeaturePicker.searchThreshold) ...<Widget>[
          TextField(
            controller: _search,
            enabled: widget.enabled,
            decoration: InputDecoration(
              hintText: 'Search the list',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      tooltip: 'Clear search',
                      onPressed: () => setState(_search.clear),
                    ),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        if (groups.isEmpty)
          Text('Nothing matches that.', style: theme.textTheme.bodySmall)
        else
          for (final ServiceFeatureGrouping g in groups) ...<Widget>[
            Text(g.group, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final ServiceFeature o in g.options)
                  FilterChip(
                    label: Text(o.label),
                    selected: selected.contains(o.id),
                    onSelected: widget.enabled
                        ? (bool value) => _toggle(o.id, value)
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }
}
