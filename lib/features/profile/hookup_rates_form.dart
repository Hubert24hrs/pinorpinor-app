import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../data/models/rates.dart';

/// The booking rates, which appear **only** when the primary service is Hookup.
///
/// Short time / overnight / weekend, incall and outcall. These stay gated on
/// Hookup after 2026-08-22, when the *feature list* beside them was generalised
/// to all six services and moved to `service_feature_picker.dart`: the other
/// five do not describe a meeting that is charged for.
///
/// ## What this widget does NOT do
///
/// It does not decide whether it should be shown, and it does not decide whether
/// its values may be stored. The parent mounts it on the Hookup branch and the
/// server independently re-derives that from the stored primary service. **A
/// form is not a gate** — anyone can post these fields whether or not this
/// widget ever built.
///
/// It also does no arithmetic on money. Values here are MAJOR units, exactly
/// what the member typed, and the conversion to the integer minor units the
/// database stores happens once, server-side, in `parseRateInput`. Converting in
/// the client as well gives two places to get it wrong, and getting it wrong
/// means a rate published at a hundred times its real value.
class HookupRatesForm extends StatefulWidget {
  const HookupRatesForm({
    super.key,
    required this.rates,
    required this.onRateChanged,
    required this.currencyCode,
    this.enabled = true,
  });

  /// Rate field name to what the member typed, in MAJOR units.
  final Map<String, String> rates;
  final void Function(String field, String value) onRateChanged;

  final String currencyCode;

  final bool enabled;

  @override
  State<HookupRatesForm> createState() => _HookupRatesFormState();
}

class _HookupRatesFormState extends State<HookupRatesForm> {
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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Currency currency = currencyByCode(widget.currencyCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Your booking rates', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Optional. Leave a box empty if you do not offer it. Amounts are in '
          '${currency.code} (${currency.symbol}), and are arranged directly '
          'with the member — Pinorpinor never handles this money.',
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
