import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/account.dart';
import '../../data/models/credits.dart';
import '../../data/models/settings.dart';
import '../auth/auth_controller.dart';

/// The signed-in member's own profile.
///
/// Not `autoDispose`: it is read by the account tab, the media manager, the
/// editor and the verification screen, and re-fetching it on every navigation
/// would be a wasted round trip on a mobile connection. It is invalidated
/// explicitly after any write, and cleared on sign-out.
final myProfileProvider = FutureProvider<Account>((ref) async {
  // Rebuild whenever the session changes, so a new sign-in never shows the
  // previous member's data.
  ref.watch(authControllerProvider.select((auth) => auth.userId));
  return ref.watch(profileRepositoryProvider).myProfile();
});

final memberSettingsProvider = FutureProvider<SettingsBundle>((ref) async {
  ref.watch(authControllerProvider.select((auth) => auth.userId));
  return ref.watch(profileRepositoryProvider).settings();
});

final walletProvider = FutureProvider.autoDispose<Wallet>((ref) async {
  return ref.watch(creditsRepositoryProvider).wallet();
});

final boostTiersProvider = FutureProvider.autoDispose<List<BoostTier>>((
  ref,
) async {
  return ref.watch(creditsRepositoryProvider).boostTiers();
});

final creditPackagesProvider = FutureProvider.autoDispose<List<CreditPackage>>((
  ref,
) async {
  return ref.watch(creditsRepositoryProvider).packages();
});

final ledgerProvider = FutureProvider.autoDispose<List<LedgerEntry>>((
  ref,
) async {
  return ref.watch(creditsRepositoryProvider).ledger();
});
