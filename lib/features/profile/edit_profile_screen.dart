import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/countries.dart';
import '../../core/network/api_exception.dart';
import '../../core/constants/services.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../core/utils/validators.dart';
import '../../data/models/account.dart';
import '../../data/models/enums.dart';
import '../../shared/widgets/brand.dart';
import '../../shared/widgets/states.dart';
import '../auth/login_screen.dart';
import 'account_providers.dart';

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

  String? _countryCode;
  RelationshipIntent? _intent;
  final Set<String> _services = <String>{};
  bool _availableToday = false;

  bool _initialised = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _displayNameController.dispose();
    _taglineController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _heightController.dispose();
    _ethnicityController.dispose();
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
    _intent = account.profile.relationshipIntent;
    _services
      ..clear()
      ..addAll(account.profile.services);
    _availableToday = account.profile.isAvailableToday;
  }

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
            relationshipIntent: _intent,
            services: _services.toList(),
            isAvailableToday: _availableToday,
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
                'Looking for',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final intent in RelationshipIntent.values)
                    ChoiceChip(
                      label: Text(intent.label),
                      selected: _intent == intent,
                      onSelected: (selected) =>
                          setState(() => _intent = selected ? intent : null),
                    ),
                ],
              ),

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

              if (account.gender == Gender.man) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                const InlineNotice.info(
                  message:
                      "Men's profiles are private on Pinorpinor and are "
                      'not listed publicly. Your details are visible to members '
                      'you match or converse with.',
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
