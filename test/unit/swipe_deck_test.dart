import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/core/network/api_client.dart';
import 'package:pinorpinor_app/core/network/api_exception.dart';
import 'package:pinorpinor_app/core/network/session_store.dart';
import 'package:pinorpinor_app/core/providers.dart';
import 'package:pinorpinor_app/data/models/messaging.dart';
import 'package:pinorpinor_app/data/models/profile.dart';
import 'package:pinorpinor_app/data/repositories/discovery_repository.dart';
import 'package:pinorpinor_app/features/discovery/swipe_controller.dart';

import '../helpers/fake_secure_storage.dart';

/// The swipe deck's optimistic-with-rollback behaviour is the part worth
/// testing: a swipe is a *recorded decision*, and getting the failure path wrong
/// silently loses one.
class _FakeDiscovery extends DiscoveryRepository {
  _FakeDiscovery({this.pages = const <List<ProfileSummary>>[], this.swipeError})
    : super(
        ApiClient(sessionStore: SessionStore(storage: FakeSecureStorage())),
      );

  /// One entry per page, in order. Page 1 is `pages[0]`.
  final List<List<ProfileSummary>> pages;

  /// Thrown by [swipe] when set.
  final ApiException? swipeError;

  final List<(String, SwipeActionInput)> swipes =
      <(String, SwipeActionInput)>[];

  /// Returned by [swipe] when it succeeds.
  SwipeResult result = const SwipeResult(matched: false);

  @override
  Future<List<ProfileSummary>> deck({
    DiscoveryFilters filters = DiscoveryFilters.none,
    int page = 1,
    int limit = 10,
  }) async {
    final index = page - 1;
    if (index < 0 || index >= pages.length) return const <ProfileSummary>[];
    return pages[index];
  }

  @override
  Future<SwipeResult> swipe({
    required String targetUserId,
    required SwipeActionInput action,
  }) async {
    swipes.add((targetUserId, action));
    final error = swipeError;
    if (error != null) throw error;
    return result;
  }
}

ProfileSummary _profile(String id) => ProfileSummary.fromJson(<String, dynamic>{
  'id': id,
  'username': id,
  'displayName': id.toUpperCase(),
  'age': 25,
});

/// Builds a container with the deck wired to [discovery], and waits for the
/// controller's constructor load to settle.
Future<(ProviderContainer, SwipeDeckController)> _boot(
  _FakeDiscovery discovery,
) async {
  final container = ProviderContainer(
    overrides: <Override>[
      discoveryRepositoryProvider.overrideWithValue(discovery),
    ],
  );
  addTearDown(container.dispose);

  // The deck is autoDispose. A bare `read` would create it and tear it down in
  // the same turn, leaving the controller unmounted so no state ever lands â€”
  // which is exactly what the widget tree avoids by watching it. Hold a
  // subscription for the life of the test to reproduce that.
  final subscription = container.listen<SwipeDeckState>(
    swipeDeckProvider,
    (_, _) {},
    fireImmediately: true,
  );
  addTearDown(subscription.close);

  final controller = container.read(swipeDeckProvider.notifier);
  // The constructor kicks off load(); drain the queue rather than guessing at
  // a fixed number of microtask hops.
  await pumpEventQueue();
  return (container, controller);
}

void main() {
  group('SwipeDeckState', () {
    test('top and next read the front of the queue', () {
      final state = SwipeDeckState(
        queue: <ProfileSummary>[_profile('a'), _profile('b'), _profile('c')],
        isLoading: false,
      );
      expect(state.top?.id, 'a');
      expect(state.next?.id, 'b');
    });

    test('next is null with a single card left', () {
      final state = SwipeDeckState(
        queue: <ProfileSummary>[_profile('a')],
        isLoading: false,
      );
      expect(state.top?.id, 'a');
      expect(state.next, isNull);
    });

    test('an empty queue while loading is not "empty"', () {
      // Otherwise the deck flashes its end-of-list state on every cold start.
      const loading = SwipeDeckState();
      expect(loading.isEmpty, isFalse);

      const settled = SwipeDeckState(isLoading: false);
      expect(settled.isEmpty, isTrue);
    });
  });

  group('loading', () {
    test('fills the queue from page 1', () async {
      final discovery = _FakeDiscovery(
        pages: <List<ProfileSummary>>[
          <ProfileSummary>[_profile('a'), _profile('b')],
        ],
      );
      final (container, _) = await _boot(discovery);

      final state = container.read(swipeDeckProvider);
      expect(state.isLoading, isFalse);
      expect(state.queue, hasLength(2));
      expect(state.exhausted, isFalse);
    });

    test('an empty first page is exhausted, not an error', () async {
      final discovery = _FakeDiscovery(
        pages: <List<ProfileSummary>>[<ProfileSummary>[]],
      );
      final (container, _) = await _boot(discovery);

      final state = container.read(swipeDeckProvider);
      expect(state.exhausted, isTrue);
      expect(state.error, isNull);
      expect(state.isEmpty, isTrue);
    });
  });

  group('swiping', () {
    test('removes the top card and posts the action', () async {
      final discovery = _FakeDiscovery(
        pages: <List<ProfileSummary>>[
          <ProfileSummary>[_profile('a'), _profile('b')],
        ],
      );
      final (container, controller) = await _boot(discovery);

      await controller.like();

      expect(discovery.swipes.single.$1, 'a');
      expect(discovery.swipes.single.$2, SwipeActionInput.like);
      expect(container.read(swipeDeckProvider).top?.id, 'b');
    });

    test('pass and superlike send their own actions', () async {
      final discovery = _FakeDiscovery(
        pages: <List<ProfileSummary>>[
          <ProfileSummary>[_profile('a'), _profile('b'), _profile('c')],
        ],
      );
      final (_, controller) = await _boot(discovery);

      await controller.pass();
      await controller.superlike();

      expect(discovery.swipes[0].$2, SwipeActionInput.pass);
      expect(discovery.swipes[1].$2, SwipeActionInput.superlike);
    });

    test('surfaces a match so the UI can offer the conversation', () async {
      final discovery =
          _FakeDiscovery(
              pages: <List<ProfileSummary>>[
                <ProfileSummary>[_profile('a')],
              ],
            )
            ..result = const SwipeResult(
              matched: true,
              matchId: 'm1',
              conversationId: 'c1',
            );
      final (container, controller) = await _boot(discovery);

      await controller.like();

      final match = container.read(swipeDeckProvider).lastMatch;
      expect(match?.matched, isTrue);
      expect(match?.conversationId, 'c1');

      controller.clearMatch();
      expect(container.read(swipeDeckProvider).lastMatch, isNull);
    });

    test('a plain like does not raise a match', () async {
      final discovery = _FakeDiscovery(
        pages: <List<ProfileSummary>>[
          <ProfileSummary>[_profile('a')],
        ],
      );
      final (container, controller) = await _boot(discovery);

      await controller.like();
      expect(container.read(swipeDeckProvider).lastMatch, isNull);
    });

    test('does nothing on an empty deck', () async {
      final discovery = _FakeDiscovery(
        pages: <List<ProfileSummary>>[<ProfileSummary>[]],
      );
      final (_, controller) = await _boot(discovery);

      await controller.like();
      expect(discovery.swipes, isEmpty);
    });
  });

  group('failure handling', () {
    test('a network failure puts the card back at the front', () async {
      // The important one. If a failed swipe were dropped, the member would
      // believe they had passed on someone the server never recorded â€” and
      // would then see them again, with no explanation.
      final discovery = _FakeDiscovery(
        pages: <List<ProfileSummary>>[
          <ProfileSummary>[_profile('a'), _profile('b')],
        ],
        swipeError: const ApiException(
          kind: ApiErrorKind.network,
          message: "You're offline. Reconnect and try again.",
        ),
      );
      final (container, controller) = await _boot(discovery);

      await controller.like();

      final state = container.read(swipeDeckProvider);
      expect(state.top?.id, 'a', reason: 'the card must come back');
      expect(state.queue, hasLength(2));
      expect(state.actionError, contains('offline'));
    });

    test(
      'a 403 keeps the card gone â€” retrying would fail identically',
      () async {
        final discovery = _FakeDiscovery(
          pages: <List<ProfileSummary>>[
            <ProfileSummary>[_profile('a'), _profile('b')],
          ],
          swipeError: const ApiException(
            kind: ApiErrorKind.forbidden,
            message: 'Cannot swipe on this user',
          ),
        );
        final (container, controller) = await _boot(discovery);

        await controller.like();

        final state = container.read(swipeDeckProvider);
        expect(state.top?.id, 'b', reason: 'a blocked pairing must not return');
        expect(state.actionError, isNotNull);
      },
    );

    test('a 404 also keeps the card gone', () async {
      final discovery = _FakeDiscovery(
        pages: <List<ProfileSummary>>[
          <ProfileSummary>[_profile('a'), _profile('b')],
        ],
        swipeError: const ApiException(
          kind: ApiErrorKind.notFound,
          message: 'User not found',
        ),
      );
      final (container, controller) = await _boot(discovery);

      await controller.like();
      expect(container.read(swipeDeckProvider).top?.id, 'b');
    });

    test('the error clears on the next swipe', () async {
      final discovery = _FakeDiscovery(
        pages: <List<ProfileSummary>>[
          <ProfileSummary>[_profile('a'), _profile('b')],
        ],
        swipeError: const ApiException(
          kind: ApiErrorKind.forbidden,
          message: 'nope',
        ),
      );
      final (container, controller) = await _boot(discovery);

      await controller.like();
      expect(container.read(swipeDeckProvider).actionError, isNotNull);

      controller.clearActionError();
      expect(container.read(swipeDeckProvider).actionError, isNull);
    });
  });

  group('prefetch', () {
    test('pulls the next page as the queue runs low', () async {
      final discovery = _FakeDiscovery(
        pages: <List<ProfileSummary>>[
          <ProfileSummary>[_profile('a'), _profile('b'), _profile('c')],
          <ProfileSummary>[_profile('d'), _profile('e')],
        ],
      );
      final (container, controller) = await _boot(discovery);

      // Threshold is 3, so the first swipe (leaving 2) triggers it.
      await controller.like();
      await pumpEventQueue();

      expect(
        container.read(swipeDeckProvider).queue.map((p) => p.id),
        containsAll(<String>['d', 'e']),
      );
    });

    test('does not queue a profile twice', () async {
      // The server builds its exclusion list per request, so a swipe in flight
      // during a prefetch can produce an overlapping page.
      final discovery = _FakeDiscovery(
        pages: <List<ProfileSummary>>[
          <ProfileSummary>[_profile('a'), _profile('b')],
          <ProfileSummary>[_profile('b'), _profile('c')],
        ],
      );
      final (container, controller) = await _boot(discovery);

      await controller.like();
      await pumpEventQueue();

      final ids = container
          .read(swipeDeckProvider)
          .queue
          .map((p) => p.id)
          .toList();
      expect(ids.toSet().length, ids.length, reason: 'no duplicates');
    });

    test('an empty next page marks the deck exhausted', () async {
      final discovery = _FakeDiscovery(
        pages: <List<ProfileSummary>>[
          <ProfileSummary>[_profile('a'), _profile('b')],
        ],
      );
      final (container, controller) = await _boot(discovery);

      await controller.like();
      await pumpEventQueue();

      expect(container.read(swipeDeckProvider).exhausted, isTrue);
    });
  });
}
