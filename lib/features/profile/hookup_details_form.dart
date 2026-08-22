import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/hookup_services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../data/models/rates.dart';

/// The extra form that appears **only** when the primary service is Hookup.
///
/// Mirrors `components/profile/HookupDetailsForm.tsx`. Two blocks, both of which
/// used to live elsewhere: the short time / overnight / weekend booking rates,
/// and the explicit service list that was taken off the platform on 2026-08-20
/// and restored on 2026-08-21 behind this gate.
///
/// ## What this widget does NOT do
///
/// It does not decide whether it should be shown, and it does not decide whether
/// its values may be stored. The parent mounts it on the Hookup branch, and the
/// server independently re-derives that from the stored primary service in four
/// places. **A form is not a gate** — anyone can post these fields whether or not
/// this widget ever built.
///
/// It also does no arithmetic on money. Values here are MAJOR units, exactly what
/// the member typed, and the conversion to the integer minor units the database
/// stores happens once, server-side, in `parseRateInput`. Converting in the
/// client as well gives two places to get it wrong, and getting it wrong means a
/// rate published at a hundred times its real value.
class HookupDetailsForm extends StatefulWidget {
  const HookupDetailsForm({
    super.key,
    required this.rates,
    required this.onRateChanged,
    required this.services,
    required this.onServicesChanged,
    required this.currencyCode,
    this.showRates = true,
    this.enabled = true,
  });

  /// Rate field name to what the member typed, in MAJOR units.
  final Map<String, String> rates;
  final void Function(String field, String value) onRateChanged;

  /// Selected explicit service ids. Controlled by the parent.
  final List<String> services;
  final ValueChanged<List<String>> onServicesChanged;

  final String currencyCode;

  /// Whether to render the booking-rate block.
  ///
  /// True on signup, where there is no other rates control in the form. False in
  /// Edit Profile, which has its own rates editor over the same columns: two
  /// live editors over one set of values is how a member changes a price in one
  /// place, saves from the other, and watches the old figure come back.
  final bool showRates;

  final bool enabled;

  @override
  State<HookupDetailsForm> createState() => _HookupDetailsFormState();
}

class _HookupDetailsFormState extends State<HookupDetailsForm> {
  final TextEditingController _search = TextEditingController();
  final Map<String, TextEditingController> _rateControllers =
      <String, TextEditingController>{};

  /// The three durations, matching `RATE_DURATIONS`. The per-minute fields are
  /// deliberately absent: those are money for arrangements made over WhatsApp
  /// and belong with the rest of the rates in Edit Profile, not in signup.
  static const List<({String label, String incall, String outcall})>
  _durations = <({String label, String incall, String outcall})>[
    (
      label: 'Short time',
      incall: 'rateShortIncall',
      outcall: 'rateShortOutcall',
    ),
    (
      label: 'Overnight',
      incall: 'rateNightIncall',
      outcall: 'rateNightOutcall',
    ),
    (
      label: 'Weekend',
      incall: 'rateWeekendIncall',
      outcall: 'rateWeekendOutcall',
    ),
  ];

  @override
  void dispose() {
    _search.dispose();
    for (final TextEditingController c in _rateControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String field) =>
      _rateControllers.putIfAbsent(
        field,
        () => TextEditingController(text: widget.rates[field] ?? ''),
      );

  void _toggle(String id, bool selected) {
    final Set<String> next = widget.services.toSet();
    if (selected) {
      next.add(id);
    } else {
      next.remove(id);
    }
    // Catalogue order is imposed here as well as server-side, so the chips read
    // the same however they were tapped.
    widget.onServicesChanged(sanitizeHookupServices(next, offersHookup: true));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Currency currency = currencyByCode(widget.currencyCode);
    final Set<String> selected = widget.services.toSet();
    final String query = _search.text.trim().toLowerCase();

    final List<HookupServiceGrouping> groups = <HookupServiceGrouping>[
      for (final HookupServiceGrouping g in hookupServicesByGroup())
        if (query.isEmpty)
          g
        else
          (
            group: g.group,
            options: <HookupServiceOption>[
              for (final HookupServiceOption o in g.options)
                if (o.label.toLowerCase().contains(query)) o,
            ],
          ),
    ].where((HookupServiceGrouping g) => g.options.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.showRates) ...<Widget>[
          Text('Your booking rates', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Optional. Leave a box empty if you do not offer it. Amounts are in '
            '${currency.code} (${currency.symbol}), taken from your WhatsApp '
            'number.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final duration in _durations) ...<Widget>[
            Text(duration.label, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: <Widget>[
                Expanded(
                  child: _RateField(
                    controller: _controllerFor(duration.incall),
                    label: 'Incall',
                    symbol: currency.symbol,
                    enabled: widget.enabled,
                    onChanged: (v) => widget.onRateChanged(duration.incall, v),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _RateField(
                    controller: _controllerFor(duration.outcall),
                    label: 'Outcall',
                    symbol: currency.symbol,
                    enabled: widget.enabled,
                    onChanged: (v) => widget.onRateChanged(duration.outcall, v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.sm),
        ],

        Text('What you offer', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Optional, and only shown on your profile while Hookup is your '
          'chosen service. Switching to anything else clears this list.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),

        // A filter, because 36 chips on a 320px screen is four screenfuls of
        // scrolling to find one entry.
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

        if (groups.isEmpty)
          Text('Nothing matches that.', style: theme.textTheme.bodySmall)
        else
          for (final HookupServiceGrouping g in groups) ...<Widget>[
            Text(g.group.label, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final HookupServiceOption o in g.options)
                  FilterChip(
                    label: Text(o.label),
                    selected: selected.contains(o.id),
                    onSelected: widget.enabled
                        ? (value) => _toggle(o.id, value)
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

/// One rate box. Digits and separators only, and never converted here.
class _RateField extends StatelessWidget {
  const _RateField({
    required this.controller,
    required this.label,
    required this.symbol,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String symbol;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        // People paste "50,000". Allowed through and stripped server-side by
        // parseRateInput, which is also where the ceiling is enforced.
        FilteringTextInputFormatter.allow(RegExp(r'[0-9,\. ]')),
        LengthLimitingTextInputFormatter(12),
      ],
      decoration: InputDecoration(
        labelText: label,
        prefixText: '$symbol ',
        isDense: true,
      ),
      validator: (value) {
        final String raw = (value ?? '').replaceAll(RegExp(r'[\s,]'), '');
        if (raw.isEmpty) return null;
        final num? parsed = num.tryParse(raw);
        if (parsed == null) return 'Enter a number.';
        if (parsed < 0) return 'A price cannot be negative.';
        if (parsed > kMaxRateMajor) return 'That is too high.';
        return null;
      },
      onChanged: onChanged,
    );
  }
}
