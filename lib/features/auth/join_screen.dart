import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/countries.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../core/utils/validators.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/auth_repository.dart';
import '../../shared/utils/legal_links.dart';
import '../../shared/widgets/brand.dart';
import 'auth_controller.dart';
import 'login_screen.dart';

/// Registration, reproducing `/join` on the website.
///
/// The rules it enforces are the backend's, not invented here:
///   * **18+ is mandatory** and checked server-side from `birthDate`. The
///     picker below cannot even open on a date under 18 years ago, and the
///     value is re-validated before submit — but the server is the gate.
///   * **Women must supply a WhatsApp number.** Women's profiles list publicly
///     and contact runs through phone verification, so `/api/member/join`
///     rejects a woman without a valid E.164 number. Men's profiles are created
///     private (`isPublic: false`) and never listed.
///   * **Country is required and must be one the backend knows**, because
///     discovery is scoped by `countryCode` and never crosses borders.
///   * **Username is unique, lowercase and format-checked** in three layers;
///     the live check here is the advisory one.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key});

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  final _pageController = PageController();
  final _accountFormKey = GlobalKey<FormState>();
  final _profileFormKey = GlobalKey<FormState>();

  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _taglineController = TextEditingController();
  final _bioController = TextEditingController();
  final _referralController = TextEditingController();

  Gender? _gender;
  DateTime? _birthDate;
  String _countryCode = kDefaultCountryCode;
  InterestedIn? _interestedIn;
  final Set<String> _dateTypes = <String>{};
  bool _acceptedTerms = false;

  int _step = 0;
  bool _submitting = false;
  String? _error;
  bool _obscure = true;

  Timer? _usernameDebounce;
  UsernameAvailability? _usernameStatus;
  bool _checkingUsername = false;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _pageController.dispose();
    _displayNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _taglineController.dispose();
    _bioController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    _usernameDebounce?.cancel();
    final value = UsernameRules.normalize(_usernameController.text);
    if (_usernameStatus != null) setState(() => _usernameStatus = null);
    if (UsernameRules.validate(value) != null) return;

    // Debounced so typing does not spend the endpoint's 40-checks-a-minute
    // budget, and so a half-typed name is never queried.
    _usernameDebounce = Timer(const Duration(milliseconds: 450), () async {
      if (!mounted) return;
      setState(() => _checkingUsername = true);
      try {
        final status = await ref
            .read(authRepositoryProvider)
            .checkUsername(value);
        if (!mounted) return;
        if (UsernameRules.normalize(_usernameController.text) != value) return;
        setState(() => _usernameStatus = status);
      } on ApiException {
        // Availability is advisory; a failure here must not block the form.
      } finally {
        if (mounted) setState(() => _checkingUsername = false);
      }
    });
  }

  void _goToStep(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    // The latest legal date of birth. Opening on it makes the 18+ rule visible
    // rather than something the member discovers by being rejected.
    final latestAllowed = DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: latestAllowed,
      helpText: 'Your date of birth',
      errorInvalidText: 'You must be 18 or older to join Pinorpinor.',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  bool _validateAccountStep() {
    if (!(_accountFormKey.currentState?.validate() ?? false)) return false;
    if (_usernameStatus?.isTaken ?? false) {
      setState(() => _error = 'That username is already taken.');
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();

    if (!(_profileFormKey.currentState?.validate() ?? false)) return;

    final birthDateError = Validators.birthDate(_birthDate);
    if (birthDateError != null) {
      setState(() => _error = birthDateError);
      return;
    }
    if (!_acceptedTerms) {
      setState(
        () => _error =
            'Please accept the Terms and Privacy Policy to create an account.',
      );
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .join(
            email: _emailController.text,
            password: _passwordController.text,
            displayName: _displayNameController.text,
            username: _usernameController.text,
            birthDate: _birthDate!,
            gender: _gender!,
            countryCode: _countryCode,
            city: _cityController.text,
            phone: _gender == Gender.woman ? _phoneController.text : null,
            bio: _bioController.text,
            tagline: _taglineController.text,
            dateTypes: _dateTypes.toList(),
            interestedIn: _interestedIn,
            referralCode: _referralController.text,
          );

      if (!mounted) return;
      // Straight to verification: the account exists but is PENDING until a
      // code is confirmed, and saying so immediately beats letting the member
      // wonder why their profile is not live.
      context.go(AppRoutes.verification);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        // Send the member back to the step that owns the rejected field.
        if (error.field == 'username' ||
            error.field == 'email' ||
            error.field == 'password') {
          _goToStep(1);
        }
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0) _goToStep(_step - 1);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create your account'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              if (_step > 0) {
                _goToStep(_step - 1);
              } else if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppRoutes.home);
              }
            },
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: LinearProgressIndicator(
              value: (_step + 1) / 3,
              minHeight: 3,
              backgroundColor: AppColors.bgMuted,
            ),
          ),
        ),
        body: SafeArea(
          child: ContentContainer(
            maxWidth: 520,
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: <Widget>[
                _buildIdentityStep(),
                _buildAccountStep(),
                _buildProfileStep(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Step 1 — who you are ──────────────────────────────────────────────

  Widget _buildIdentityStep() {
    final age = _birthDate == null ? null : Validators.ageOn(_birthDate!);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'First, the basics',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Pinorpinor is an 18+ platform. Your date of birth is verified '
            'against this on our servers and cannot be changed later.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),

          Text('I am a', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: _ChoiceTile(
                  label: 'Woman',
                  description: 'Your profile is public and discoverable',
                  icon: Icons.female_rounded,
                  selected: _gender == Gender.woman,
                  onTap: () => setState(() {
                    _gender = Gender.woman;
                    _interestedIn ??= InterestedIn.defaultFor(Gender.woman);
                  }),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _ChoiceTile(
                  label: 'Man',
                  description: 'Your profile stays private',
                  icon: Icons.male_rounded,
                  selected: _gender == Gender.man,
                  onTap: () => setState(() {
                    _gender = Gender.man;
                    _interestedIn ??= InterestedIn.defaultFor(Gender.man);
                  }),
                ),
              ),
            ],
          ),

          if (_gender == Gender.man) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            const InlineNotice.info(
              message:
                  "Men's profiles are private on Pinorpinor — they are "
                  'never listed publicly. You can browse, message and request '
                  'contact with members.',
            ),
          ],
          if (_gender == Gender.woman) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            const InlineNotice.info(
              message:
                  'Your profile will be featured for its first 24 hours. '
                  'Photos and videos are reviewed by a moderator before they '
                  'appear publicly.',
            ),
          ],

          const SizedBox(height: AppSpacing.xl),
          Text('Date of birth', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            onTap: _pickBirthDate,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: InputDecorator(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.cake_outlined, size: 20),
                suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                errorText: _birthDate == null
                    ? null
                    : Validators.birthDate(_birthDate),
              ),
              child: Text(
                _birthDate == null
                    ? 'Select your date of birth'
                    : '${_birthDate!.day.toString().padLeft(2, '0')}/'
                          '${_birthDate!.month.toString().padLeft(2, '0')}/'
                          '${_birthDate!.year}'
                          '${age == null ? '' : '  ·  $age years old'}',
                style: TextStyle(
                  fontFamily: AppTheme.sansFamily,
                  fontSize: 16,
                  color: _birthDate == null
                      ? AppColors.textMuted
                      : AppColors.textMain,
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          Text('Country', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: _countryCode,
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.public_rounded, size: 20),
            ),
            items: <DropdownMenuItem<String>>[
              for (final country in kCountries)
                DropdownMenuItem<String>(
                  value: country.code,
                  child: Text(country.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) =>
                setState(() => _countryCode = value ?? kDefaultCountryCode),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Discovery is scoped by country — you will see, and be seen by, '
            'members in the country you choose.',
            style: Theme.of(context).textTheme.bodySmall,
          ),

          const SizedBox(height: AppSpacing.xxl),
          GradientButton(
            label: 'Continue',
            onPressed:
                (_gender != null &&
                    _birthDate != null &&
                    Validators.birthDate(_birthDate) == null)
                ? () => _goToStep(1)
                : null,
          ),
        ],
      ),
    );
  }

  // ── Step 2 — account credentials ──────────────────────────────────────

  Widget _buildAccountStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Form(
        key: _accountFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Your account',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.xl),

            if (_error != null) ...<Widget>[
              InlineNotice.error(message: _error!),
              const SizedBox(height: AppSpacing.lg),
            ],

            TextFormField(
              controller: _displayNameController,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Display name',
                hintText: 'The name members will see',
                prefixIcon: Icon(Icons.badge_outlined, size: 20),
              ),
              validator: Validators.displayName,
            ),
            const SizedBox(height: AppSpacing.lg),

            TextFormField(
              controller: _usernameController,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              inputFormatters: <TextInputFormatter>[
                // The stored form is lowercase, so type it that way rather than
                // silently rewriting the member's input on submit.
                TextInputFormatter.withFunction(
                  (oldValue, newValue) =>
                      newValue.copyWith(text: newValue.text.toLowerCase()),
                ),
                LengthLimitingTextInputFormatter(UsernameRules.maxLength),
              ],
              decoration: InputDecoration(
                labelText: 'Username',
                hintText: 'zainab_lagos',
                prefixText: '@',
                prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
                helperText: UsernameRules.hint,
                helperMaxLines: 2,
                suffixIcon: _usernameSuffix(),
              ),
              validator: UsernameRules.validate,
            ),
            if ((_usernameStatus?.suggestions ?? const <String>[])
                .isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: <Widget>[
                  for (final suggestion in _usernameStatus!.suggestions)
                    ActionChip(
                      label: Text('@$suggestion'),
                      onPressed: () {
                        _usernameController.text = suggestion;
                        _usernameController.selection = TextSelection.collapsed(
                          offset: suggestion.length,
                        );
                      },
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),

            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              autofillHints: const <String>[AutofillHints.newUsername],
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'you@example.com',
                prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                helperText: 'We send your verification code here.',
              ),
              validator: Validators.email,
            ),
            const SizedBox(height: AppSpacing.lg),

            TextFormField(
              controller: _passwordController,
              obscureText: _obscure,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Password',
                helperText: 'At least 8 characters.',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: Validators.password,
            ),
            const SizedBox(height: AppSpacing.lg),

            TextFormField(
              controller: _confirmController,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: Icon(Icons.lock_reset_rounded, size: 20),
              ),
              validator: (value) =>
                  Validators.confirmPassword(value, _passwordController.text),
            ),

            if (_gender == Gender.woman) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp number',
                  hintText: '+2348012345678',
                  prefixIcon: Icon(Icons.chat_rounded, size: 20),
                  helperText:
                      'Required for verification. Your number is never '
                      'shown to other members — they must request contact and '
                      'you decide.',
                  helperMaxLines: 3,
                ),
                validator: (value) => Validators.phone(value),
              ),
            ],

            const SizedBox(height: AppSpacing.xxl),
            GradientButton(
              label: 'Continue',
              onPressed: () {
                setState(() => _error = null);
                if (_validateAccountStep()) _goToStep(2);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget? _usernameSuffix() {
    if (_checkingUsername) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final status = _usernameStatus;
    if (status == null) return null;
    if (status.isFree) {
      return const Icon(
        Icons.check_circle_rounded,
        size: 20,
        color: AppColors.success,
      );
    }
    if (status.isTaken) {
      return const Icon(Icons.cancel_rounded, size: 20, color: AppColors.error);
    }
    return null;
  }

  // ── Step 3 — profile and consent ──────────────────────────────────────

  Widget _buildProfileStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Form(
        key: _profileFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Your profile',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'You can change any of this later.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),

            if (_error != null) ...<Widget>[
              InlineNotice.error(message: _error!),
              const SizedBox(height: AppSpacing.lg),
            ],

            TextFormField(
              controller: _cityController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'City',
                hintText: 'Lagos',
                prefixIcon: Icon(Icons.location_city_rounded, size: 20),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            TextFormField(
              controller: _taglineController,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Tagline',
                hintText: 'One line about you',
                prefixIcon: Icon(Icons.format_quote_rounded, size: 20),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            TextFormField(
              controller: _bioController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'About you',
                alignLabelWithHint: true,
              ),
              validator: Validators.bio,
            ),
            const SizedBox(height: AppSpacing.sm),

            Text(
              'Interested in',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<InterestedIn>(
              segments: const <ButtonSegment<InterestedIn>>[
                ButtonSegment<InterestedIn>(
                  value: InterestedIn.women,
                  label: Text('Women'),
                ),
                ButtonSegment<InterestedIn>(
                  value: InterestedIn.men,
                  label: Text('Men'),
                ),
                ButtonSegment<InterestedIn>(
                  value: InterestedIn.both,
                  label: Text('Everyone'),
                ),
              ],
              selected: <InterestedIn>{
                _interestedIn ?? InterestedIn.defaultFor(_gender),
              },
              onSelectionChanged: (selection) =>
                  setState(() => _interestedIn = selection.first),
            ),
            const SizedBox(height: AppSpacing.xl),

            Text(
              'Date ideas you enjoy',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final type in kDateTypeOptions)
                  FilterChip(
                    label: Text(type),
                    selected: _dateTypes.contains(type),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _dateTypes.add(type);
                      } else {
                        _dateTypes.remove(type);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            TextFormField(
              controller: _referralController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Referral code (optional)',
                prefixIcon: Icon(Icons.card_giftcard_rounded, size: 20),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            CheckboxListTile(
              value: _acceptedTerms,
              onChanged: (value) =>
                  setState(() => _acceptedTerms = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: Text(
                'I am at least 18 years old and I accept the Terms and '
                'Privacy Policy.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Row(
              children: <Widget>[
                TextButton(
                  onPressed: () => _openLegal(AppConfig.termsUrl),
                  child: const Text('Terms'),
                ),
                TextButton(
                  onPressed: () => _openLegal(AppConfig.privacyPolicyUrl),
                  child: const Text('Privacy'),
                ),
                TextButton(
                  onPressed: () => _openLegal(AppConfig.safetyUrl),
                  child: const Text('Safety'),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),
            GradientButton(
              label: 'Create my account',
              isLoading: _submitting,
              onPressed: _acceptedTerms ? _submit : null,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Future<void> _openLegal(String url) async {
    await LegalLinks.open(context, url);
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(AppSpacing.lg),
          constraints: const BoxConstraints(minHeight: 118),
          decoration: BoxDecoration(
            color: selected ? AppColors.badgeRoseBg : AppColors.bgSecondary,
            border: Border.all(
              color: selected ? AppColors.rose : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 22,
                color: selected ? AppColors.rose : AppColors.textMuted,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(label, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(description, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
