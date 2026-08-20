import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/features/auth/auth_controller.dart';
import 'package:pinorpinor_app/features/favorites/favorites_providers.dart';

import '../helpers/fake_auth_repository.dart';

/// A shortlist must not outlive the session that owns it.
///
/// `savedIdsProvider` is deliberately **not** `autoDispose`, because a heart
/// has to keep its state while the member moves between discovery, a profile
/// and back. That longevity is the hazard this file exists to pin down: on a
/// shared phone, the next person to sign in must not open discovery and find
/// the previous member's shortlist already hearted.
///
/// Favourites are private to their owner and the saved member is never told.
/// Leaking the list to whoever picks up the device next would defeat the point
/// of the feature entirely.
void main() {
  ProviderContainer makeContainer(FakeAuthRepository repository) {
    final container = ProviderContainer(
      overrides: fakeAuthOverrides(repository),
    );
    addTearDown(container.dispose);
    return container;
  }

  test('starts empty', () {
    final container = makeContainer(FakeAuthRepository());
    expect(container.read(savedIdsProvider), isEmpty);
  });

  test('seeding records ids', () {
    final container = makeContainer(FakeAuthRepository());
    // Hold a subscription so the notifier stays mounted for the assertions.
    final sub = container.listen(savedIdsProvider, (_, _) {});
    addTearDown(sub.close);

    container.read(savedIdsProvider.notifier).seed(<String>['u1', 'u2']);

    expect(container.read(savedIdsProvider), <String>{'u1', 'u2'});
    expect(container.read(savedIdsProvider.notifier).contains('u1'), isTrue);
    expect(container.read(savedIdsProvider.notifier).contains('u9'), isFalse);
  });

  test('signing out clears the shortlist', () async {
    final repository = FakeAuthRepository();
    final container = makeContainer(repository);
    final sub = container.listen(savedIdsProvider, (_, _) {});
    addTearDown(sub.close);

    // Sign in, then build up some hearts.
    await container
        .read(authControllerProvider.notifier)
        .signIn(identifier: 'member', password: 'password123');
    container.read(savedIdsProvider.notifier).seed(<String>['u1', 'u2']);
    expect(container.read(savedIdsProvider), isNotEmpty);

    await container.read(authControllerProvider.notifier).signOut();

    expect(
      container.read(savedIdsProvider),
      isEmpty,
      reason:
          'the next person to use this device must not inherit the previous '
          "member's private shortlist",
    );
  });

  test('a different account does not inherit the previous one', () async {
    final repository = FakeAuthRepository();
    final container = makeContainer(repository);
    final sub = container.listen(savedIdsProvider, (_, _) {});
    addTearDown(sub.close);

    await container
        .read(authControllerProvider.notifier)
        .signIn(identifier: 'first', password: 'password123');
    container.read(savedIdsProvider.notifier).seed(<String>['u1']);
    expect(container.read(savedIdsProvider), <String>{'u1'});

    await container.read(authControllerProvider.notifier).signOut();
    await container
        .read(authControllerProvider.notifier)
        .signIn(identifier: 'second', password: 'password123');

    expect(container.read(savedIdsProvider), isEmpty);
  });
}
