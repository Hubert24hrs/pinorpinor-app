import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/countries.dart';
import '../../core/constants/primary_services.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../core/utils/money.dart';
import '../../core/utils/validators.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/auth_repository.dart';
import '../profile/hookup_details_form.dart';
import '../profile/primary_service_picker.dart';
import '../../shared/utils/legal_links.dart';
import '../../shared/widgets/brand.dart';
import 'auth_controller.dart';

/// Registration, reproducing `/join` on the website.
///
/// The rules it enforces are the backend's, not invented here.
///
///   * **18+ is a tickbox, not a date of birth.** `birthDate` stays null, so
///     nothing downstream may assume an age exists. It is an assertion by the
///     member; the record that the question was asked and answered is the whole
///     of what it provides.
///   * **A WhatsApp number is mandatory and must be E.164.** It is also what the
///     country is derived from, server-side, and discovery scopes on country -
///     so a number that does not resolve leaves the member discoverable by
///     nobody until they set a location in Edit Profile.
///   * **Gender is asked again, and it is load-bearing.** It was dropped from
///     this form in August and hardcoded to WOMAN server-side, because only
///     women could list. Both are accepted since 2026-08-21. The answer is not
///     demographic: `role` and `interestedIn` are derived from it and discovery
///     filters on it, so a wrong answer here means a profile that looks
///     perfectly fine to its owner and appears in nobody else's browsing.
///   * **One primary service, required.** Six options, exactly one choice. It is
///     the badge on the member's card, and it decides whether the hookup block
///     is stored at all.
///   * **Username is unique, lowercase and format-checked** in three layers;
///     the live check here is the advisory one.
///
/// **The activity catalogue is no longer asked for here.** The website moved it
/// to Edit Profile on 2026-08-21 so signup stays short, and the route made
/// `services` optional in the same commit. Asking for both a required single
/// choice and 31 optional chips on the same screen is how a signup form gets
/// abandoned.
///
/// **There is no password reset for accounts made here.** No address is
/// collected, and `/api/forgot-password` looks members up by address. The screen
/// says so plainly before the member commits, because the alternative is
/// discovering it at the moment it can no longer be fixed.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key});

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  final _pageController = PageController();
  final _accountFormKey = GlobalKey<FormState>();
  final _detailsFormKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _referralController = TextEditingController();

  Gender? _gender;
  String? _primaryService;
  final List<String> _hookupServices = <String>[];
  final Map<String, String> _rates = <String, String>{};
  bool _isAdult = false;

  /// Whether the hookup branch is mounted. Named rather than compared inline at
  /// four call sites, for the same reason the website names `HOOKUP_ID`.
  bool get _wantsHookup => offersHookup(_primaryService);

  int _step = 0;
  bool _submitting = false;
  String? _error;
  bool _obscure = true;

  Timer? _usernameDebounce;
  UsernameAvailability? _usernameStatus;
  bool _checkingUsername = false;

  static const int _stepCount = 3;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onUsernameChanged);
    // The rate boxes are denominated in the currency of the number being typed,
    // resolved exactly as the server will resolve it. Without this a member
    // enters a figure against a placeholder currency and finds out afterwards
    // what it was actually stored as.
    _phoneController.addListener(_onPhoneChanged);
  }

  void _onPhoneChanged() {
    if (!_wantsHookup) return;
    setState(() {});
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _phoneController.removeListener(_onPhoneChanged);
    _pageController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _phoneController.dispose();
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

    if (_gender == null) {
      setState(
        () => _error = 'Tell us whether you are joining as a woman or a man.',
      );
      return;
    }
    if (_primaryService == null) {
      setState(() => _error = 'Choose the one service you are here for.');
      return;
    }
    if (!_isAdult) {
      setState(
        () => _error =
            'You must confirm that you are 18 or over to create a profile.',
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
            username: _usernameController.text,
            password: _passwordController.text,
            phone: _phoneController.text,
            bio: _bioController.text,
            gender: _gender!,
            primaryService: _primaryService!,
            isAdult: _isAdult,
            // Sent only under the hookup badge. The repository gates them again
            // and so does the route; this is the first of the three, and the
            // one that stops a form's leftover state reaching the wire at all.
            hookupServices: _wantsHookup ? _hookupServices : const <String>[],
            rates: _wantsHookup ? _rates : const <String, String>{},
            referralCode: _referralController.text,
          );

      if (!mounted) return;
      // Straight to verification: the number is unproven until a code is
      // confirmed, and saying so immediately beats letting the member wonder
      // why nothing has happened.
      context.go(AppRoutes.verification);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        // Send the member back to the step that owns the rejected field.
        if (error.field == 'username' || error.field == 'password') {
          _goToStep(0);
        } else if (error.field == 'phone' || error.field == 'bio') {
          _goToStep(1);
        } else if (error.field == 'gender' || error.field == 'primaryService') {
          _goToStep(2);
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
              value: (_step + 1) / _stepCount,
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
                _buildAccountStep(),
                _buildDetailsStep(),
                _buildServiceStep(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Step 1 — username and password ────────────────────────────────────

  Widget _buildAccountStep() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Form(
        key: _accountFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const BrandMark(),
            const SizedBox(height: AppSpacing.xl),
            Text('Choose your name', style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Your username is how members find you, and how you sign in.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),

            if (_error != null && _step == 0) ...<Widget>[
              _ErrorBanner(message: _error!),
              const SizedBox(height: AppSpacing.lg),
            ],

            TextFormField(
              controller: _usernameController,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              autofillHints: const <String>[AutofillHints.newUsername],
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
              controller: _passwordController,
              obscureText: _obscure,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Password',
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
                prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
              ),
              validator: (value) =>
                  Validators.confirmPassword(value, _passwordController.text),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Said before the member commits, not after. Registration collects
            // no email address, so there is genuinely nothing to send a reset
            // link to — this is the one warning on the screen that describes an
            // outcome nobody can undo.
            const _NoticeCard(
              icon: Icons.key_off_rounded,
              title: 'Keep your password safe',
              body:
                  'We do not ask for an email address, so there is no way to '
                  'reset a forgotten password. Save it somewhere you trust '
                  'before you continue.',
            ),

            const SizedBox(height: AppSpacing.xxl),
            GradientButton(
              label: 'Continue',
              onPressed: () {
                setState(() => _error = null);
                if (_validateAccountStep()) _goToStep(1);
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  'Already have an account?',
                  style: theme.textTheme.bodyMedium,
                ),
                TextButton(
                  onPressed: () => context.go(AppRoutes.login),
                  child: const Text('Sign in'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
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

  // ── Step 2 — WhatsApp number and bio ──────────────────────────────────

  Widget _buildDetailsStep() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Form(
        key: _detailsFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('How members reach you', style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Your number stays private until you accept a contact request.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),

            if (_error != null && _step == 1) ...<Widget>[
              _ErrorBanner(message: _error!),
              const SizedBox(height: AppSpacing.lg),
            ],

            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'WhatsApp number',
                hintText: '+2348012345678',
                prefixIcon: Icon(Icons.chat_rounded, size: 20),
                // The country note is not decoration: discovery scopes on the
                // country resolved from this number, so one in the wrong format
                // leaves the member unlisted rather than merely unverified.
                helperText:
                    'International format, starting with +. We use the country '
                    'code to place you in local discovery. Your number is never '
                    'shown to other members.',
                helperMaxLines: 4,
              ),
              validator: Validators.phone,
            ),
            const SizedBox(height: AppSpacing.lg),

            TextFormField(
              controller: _bioController,
              maxLines: 5,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'About you',
                alignLabelWithHint: true,
                helperText: 'A short introduction members will read first.',
                helperMaxLines: 2,
              ),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Please write a short bio.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),

            TextFormField(
              controller: _referralController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Referral code (optional)',
                prefixIcon: Icon(Icons.card_giftcard_rounded, size: 20),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),
            GradientButton(
              label: 'Continue',
              onPressed: () {
                setState(() => _error = null);
                if (_detailsFormKey.currentState?.validate() ?? false) {
                  _goToStep(2);
                }
              },
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  // -- Step 3: gender, the one service, and the 18+ confirmation --------

  Widget _buildServiceStep() {
    final theme = Theme.of(context);
    // Resolved from what has been typed so far, the same way the server will
    // resolve it. Null - an unrecognised dialling code - falls back to the
    // default currency rather than guessing a country.
    final String currencyCode = resolveCurrency(
      countryCode: countryFromPhone(_phoneController.text),
    ).code;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('What you are here for', style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Two questions, and you are done. You can change both at any time '
            'from your profile.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),

          if (_error != null && _step == 2) ...<Widget>[
            _ErrorBanner(message: _error!),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Gender. Not decoration: discovery filters on it, so a wrong answer
          // here leaves a profile that looks right to its owner and appears in
          // nobody else's browsing.
          Text('I am joining as', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              for (final Gender option in Gender.values) ...<Widget>[
                Expanded(
                  child: _ChoiceCard(
                    label: option == Gender.woman ? 'A woman' : 'A man',
                    selected: _gender == option,
                    onTap: () => setState(() {
                      _gender = option;
                      _error = null;
                    }),
                  ),
                ),
                if (option != Gender.values.last)
                  const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),

          const SizedBox(height: AppSpacing.xl),
          Text('What are you here for?', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Pick one. This is the badge people see on your card.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          PrimaryServicePicker(
            value: _primaryService,
            onChanged: (id) => setState(() {
              // Choosing something else discards whatever was typed into the
              // hookup branch, rather than keeping it in state where it would
              // eventually be submitted alongside a badge that contradicts it.
              if (!offersHookup(id)) {
                _hookupServices.clear();
                _rates.clear();
              }
              _primaryService = id;
              _error = null;
            }),
          ),

          if (_wantsHookup) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.bgSecondary,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: HookupDetailsForm(
                rates: _rates,
                onRateChanged: (field, value) => _rates[field] = value,
                services: _hookupServices,
                onServicesChanged: (next) => setState(() {
                  _hookupServices
                    ..clear()
                    ..addAll(next);
                }),
                currencyCode: currencyCode,
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),
          CheckboxListTile(
            value: _isAdult,
            onChanged: (value) => setState(() {
              _isAdult = value ?? false;
              _error = null;
            }),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Text(
              'I confirm that I am 18 years of age or older, and I accept the '
              'Terms and Privacy Policy.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Wrap(
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
            onPressed: _isAdult && _gender != null && _primaryService != null
                ? _submit
                : null,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Future<void> _openLegal(String url) async {
    await LegalLinks.open(context, url);
  }
}

/// A validation or API failure, shown inline above the fields it concerns.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: AppColors.error,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

/// A standing note about how the platform works — not an error.
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(body, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A two-up radio card, for the gender question.
///
/// A pair of cards rather than a dropdown or a Radio row: it is two options, the
/// answer is load-bearing, and both need to be visible without a tap. The 44px
/// floor is met by the padding.
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? AppColors.badgeRoseBg : AppColors.bgSecondary,
          border: Border.all(
            color: selected ? AppColors.rose : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: selected ? AppColors.rose : AppColors.textMain,
          ),
        ),
      ),
    );
  }
}
