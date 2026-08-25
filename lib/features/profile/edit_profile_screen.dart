import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/countries.dart';
import '../../core/constants/live_sessions.dart';
import '../../core/constants/primary_services.dart';
import '../../core/constants/service_features.dart';
import '../../core/constants/services.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../core/utils/age.dart';
import '../../core/utils/money.dart';
import '../../core/utils/validators.dart';
import '../../data/models/account.dart';
import '../../data/models/enums.dart';
import '../../data/models/rates.dart';
import '../../shared/widgets/brand.dart';
import '../../shared/widgets/states.dart';
import '../auth/login_screen.dart';
import 'account_providers.dart';
import 'hookup_rates_form.dart';
import 'service_feature_picker.dart';
import 'primary_service_picker.dart';

/// Edits the member's own profile.
///
/// Only the fields `profileUpdateSchema` accepts are sent. Everything that
/// decides placement or visibility — boost tier, credit balance, featured
/// window, verification status — is absent by design: the schema whitelists,
/// so a client cannot promote itself even by inventing a field.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _displayNameController = TextEditingController();
  final _taglineController = TextEditingController();
  final _bioController = TextEditingController();
  final _cityController = TextEditingController();
  final _heightController = TextEditingController();
  final _ethnicityController = TextEditingController();
  final _birthYearController = TextEditingController();

  String? _countryCode;
  final Set<String> _services = <String>{};
  bool _availableToday = false;

  /// Null until chosen, and null is savable. A member who joined before
  /// 2026-08-21 has no primary service, and the picker must not invent one.
  String? _primaryService;

  /// What the member offers under [_primaryService]. Cleared whenever that
  /// changes, because the ids belong to the old catalogue and mean nothing
  /// under the new one — the server does the same on save.
  final List<String> _serviceFeatures = <String>[];

  /// What the member typed, in MAJOR units. Converted server-side, never here.
  final Map<String, String> _rates = <String, String>{};

  /// What the member typed, in whole CREDITS. A different unit from [_rates],
  /// a different payload key, and never the two mixed.
  final Map<String, String> _liveRates = <String, String>{};
  final Map<String, TextEditingController> _liveControllers =
      <String, TextEditingController>{};

  bool _showOnline = true;

  bool get _wantsHookup => offersHookup(_primaryService);

  bool _initialised = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final TextEditingController c in _liveControllers.values) {
      c.dispose();
    }
    _displayNameController.dispose();
    _taglineController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _heightController.dispose();
    _ethnicityController.dispose();
    _birthYearController.dispose();
    super.dispose();
  }

  void _hydrate(Account account) {
    if (_initialised) return;
    _initialised = true;
    _displayNameController.text = account.displayName;
    _taglineController.text = account.profile.tagline ?? '';
    _bioController.text = account.profile.bio ?? '';
    _cityController.text = account.profile.city ?? '';
    _heightController.text = account.profile.height ?? '';
    _ethnicityController.text = account.profile.ethnicity ?? '';
    _countryCode = normalizeCountryCode(
      account.profile.countryCode ?? account.profile.country,
    );
    _services
      ..clear()
      ..addAll(account.profile.services);
    _availableToday = account.profile.isAvailableToday;
    _showOnline = account.profile.showOnline;

    _primaryService = account.profile.primaryService;
    _serviceFeatures
      ..clear()
      ..addAll(account.profile.serviceFeatures);
    _birthYearController.text = account.profile.birthYear?.toString() ?? '';

    // Stored rates are integer MINOR units; the boxes take major units. The
    // conversion back is the only arithmetic this screen does on money, and it
    // uses the profile's own currency rather than assuming hundredths.
    final String currencyCode = account.profile.rates
        .resolvedCurrency(account.profile.countryCode)
        .code;
    for (final ({String field, String label}) f in kRateFields) {
      final int? minor = _storedRate(account, f.field);
      final num? major = toMajorUnits(minor, currencyCode: currencyCode);
      _rates[f.field] = major == null ? '' : _plain(major);
    }

    _liveRates.addAll(account.profile.liveSessions.toInput());
    for (final MapEntry<String, String> e in _liveRates.entries) {
      _liveControllers[e.key] = TextEditingController(text: e.value);
    }
  }

  /// The stored minor-unit value for a rate column.
  ///
  /// Keyed by column name so this screen and [kRateFields] cannot fall out of
  /// step; [MemberRates] exposes them as named fields.
  static int? _storedRate(Account account, String field) {
    final MemberRates r = account.profile.rates;
    return switch (field) {
      'rateShortIncall' => r.shortIncall,
      'rateShortOutcall' => r.shortOutcall,
      'rateNightIncall' => r.nightIncall,
      'rateNightOutcall' => r.nightOutcall,
      'rateWeekendIncall' => r.weekendIncall,
      'rateWeekendOutcall' => r.weekendOutcall,
      'rateAudioPerMin' => r.audioPerMin,
      'rateVideoPerMin' => r.videoPerMin,
      'rateCallPerMin' => r.callPerMin,
      _ => null,
    };
  }

  /// A major amount as a plain editable string: no grouping, and no trailing
  /// ".0" on whole numbers, which would otherwise be read back as typed input.
  static String _plain(num value) =>
      value == value.roundToDouble() ? value.round().toString() : '$value';

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref
          .read(profileRepositoryProvider)
          .updateProfile(
            displayName: _displayNameController.text,
            tagline: _taglineController.text,
            bio: _bioController.text,
            city: _cityController.text,
            height: _heightController.text,
            ethnicity: _ethnicityController.text,
            country: _countryCode,
            services: _services.toList(),
            isAvailableToday: _availableToday,
            showOnline: _showOnline,
            // Always sent, including as null: this screen shows the picker, so
            // an absent value here would mean "unchanged" when the member may
            // have just cleared it. The repository distinguishes the two.
            primaryService: _primaryService,
            // Sent whatever the badge, because the repository and the route
            // both gate it -- and on a switch of primary service the server
            // clears the column, which is the behaviour a member expects when
            // they change what they are here for.
            serviceFeatures: _serviceFeatures,
            birthYear: _birthYearController.text,
            rates: _rates,
            liveRates: _liveRates,
          );

      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
      if (context.canPop()) context.pop();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(myProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: account.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(myProfileProvider),
          ),
          data: (data) {
            _hydrate(data);
            return _buildForm(data);
          },
        ),
      ),
    );
  }

  Widget _buildForm(Account account) {
    return ContentContainer(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_error != null) ...<Widget>[
                InlineNotice.error(message: _error!),
                const SizedBox(height: AppSpacing.lg),
              ],

              TextFormField(
                controller: _displayNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Display name'),
                validator: Validators.displayName,
              ),
              const SizedBox(height: AppSpacing.lg),

              TextFormField(
                controller: _taglineController,
                maxLength: 80,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Tagline',
                  hintText: 'One line members see first',
                ),
              ),

              TextFormField(
                controller: _bioController,
                maxLines: 5,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'About you',
                  alignLabelWithHint: true,
                ),
                validator: Validators.bio,
              ),

              const SizedBox(height: AppSpacing.sm),
              Text(
                'Where you are',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _cityController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'City',
                  prefixIcon: Icon(Icons.location_city_rounded, size: 20),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<String>(
                initialValue: _countryCode,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Country',
                  prefixIcon: Icon(Icons.public_rounded, size: 20),
                  helperText:
                      'Changing this changes which members you can discover.',
                  helperMaxLines: 2,
                ),
                items: <DropdownMenuItem<String>>[
                  for (final country in kCountries)
                    DropdownMenuItem<String>(
                      value: country.code,
                      child: Text(
                        country.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _countryCode = value),
              ),

              const SizedBox(height: AppSpacing.xl),
              Text('About you', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _birthYearController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Year of birth',
                  hintText: '1998',
                  prefixIcon: Icon(Icons.cake_outlined, size: 20),
                  helperText:
                      'Your age is shown on your profile, never the year '
                      'itself. Leave it empty to show no age at all.',
                  helperMaxLines: 3,
                ),
                // Empty is allowed here, unlike at registration: an account
                // created before the question existed has no year, and forcing
                // one on the next unrelated save would be inventing a fact
                // about a person to satisfy a form.
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? null : birthYearError(value),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: _heightController,
                      decoration: const InputDecoration(
                        labelText: 'Height',
                        hintText: "5'7\"",
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextFormField(
                      controller: _ethnicityController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Ethnicity'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),
              Text(
                'What you are here for',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Pick one. This is the badge people see on your card in the '
                'member grid, and it is the first thing they read about you.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              PrimaryServicePicker(
                value: _primaryService,
                onChanged: (id) => setState(() {
                  // Clearing rather than keeping: the ids belong to the old
                  // catalogue and are dropped server-side anyway, so leaving
                  // them ticked would show a member a selection that will not
                  // survive their own save.
                  if (id != _primaryService) _serviceFeatures.clear();
                  _primaryService = id;
                }),
              ),

              // What the member offers, under whichever service they chose.
              //
              // Every one of the six has its own catalogue since 2026-08-22.
              // Switching service clears the selection, here and server-side:
              // the ids belong to the old catalogue and mean nothing under the
              // new one, so keeping them would leave a Relationship profile
              // holding Hookup selections.
              if (featuresFor(_primaryService).isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                ServiceFeaturePicker(
                  primaryService: _primaryService,
                  selected: _serviceFeatures,
                  onChanged: (next) => setState(() {
                    _serviceFeatures
                      ..clear()
                      ..addAll(next);
                  }),
                ),
              ],

              // The booking rates stay Hookup-only. They are money for a
              // meeting arranged over WhatsApp, and the other five services do
              // not describe a meeting that is charged for.
              if (_wantsHookup) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.bgSecondary,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: HookupRatesForm(
                    rates: _rates,
                    onRateChanged: (field, value) => _rates[field] = value,
                    currencyCode: account.profile.rates
                        .resolvedCurrency(account.profile.countryCode)
                        .code,
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.xl),
              Text(
                'Live sessions',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Priced per minute in credits, not money. Leave a box empty if '
                'you do not offer it, or enter 0 for free. Sessions cannot be '
                'started or paid for yet — see Get the App in the menu.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final LiveSessionOption option in kLiveSessions) ...<Widget>[
                TextFormField(
                  controller: _liveControllers[option.field],
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: option.label,
                    helperText: option.description,
                    helperMaxLines: 2,
                    suffixText: 'credits / min',
                  ),
                  validator: validateLiveSessionCredits,
                  onChanged: (value) => _liveRates[option.field] = value,
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              const SizedBox(height: AppSpacing.xl),
              Text(
                'What you offer',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'These appear on your profile and are how members find you in '
                'search.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              // Grouped, and rendered from the catalogue rather than from the
              // stored ids -- those are slugs and mean nothing to a reader.
              // Retired entries are absent here but still render on the
              // profile, so a member keeps what they already chose.
              for (final group in servicesByGroup()) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    group.group.label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    for (final option in group.options)
                      FilterChip(
                        label: Text(option.label),
                        selected: _services.contains(option.id),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _services.add(option.id);
                          } else {
                            _services.remove(option.id);
                          }
                        }),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: AppSpacing.lg),
              SwitchListTile(
                value: _availableToday,
                onChanged: (value) => setState(() => _availableToday = value),
                contentPadding: EdgeInsets.zero,
                title: const Text('Available today'),
                subtitle: Text(
                  'Shows an "Available today" badge and lifts you in the '
                  'discovery order.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),

              // The presence switch. Distinct from going undiscoverable, which
              // is what a member's only option used to be: publishing "she is
              // online right now" to strangers tells them when she is awake and
              // when she is alone, and withholding that should not cost her the
              // profile as well.
              SwitchListTile(
                value: _showOnline,
                onChanged: (value) => setState(() => _showOnline = value),
                contentPadding: EdgeInsets.zero,
                title: const Text('Show when I am online'),
                subtitle: Text(
                  _showOnline
                      ? 'Members can see that you are online now or how '
                            'recently you were active. Your profile stays '
                            'visible either way.'
                      : 'Nobody sees when you were last active, and you are '
                            'left out of Online Now. Your profile stays '
                            'visible and discoverable.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),

              if (account.gender == Gender.man) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                // Rewritten 2026-08-22. This used to say men's profiles are
                // never listed publicly, which stopped being true on
                // 2026-08-21: resolveVisibleGenders() shows men to signed-in
                // members whose own preference includes them, and only
                // anonymous visitors are hard-limited to women.
                const InlineNotice.info(
                  message:
                      "Men's profiles are shown to signed-in members only. "
                      'Visitors who are not signed in, and search engines, see '
                      'women only.',
                ),
              ],

              const SizedBox(height: AppSpacing.xxl),
              GradientButton(
                label: 'Save changes',
                isLoading: _saving,
                onPressed: _save,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
