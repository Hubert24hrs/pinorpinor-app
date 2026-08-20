import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/data/repositories/favorites_repository.dart';

/// The shortlist's parsing and its one privacy-shaped property.
void main() {
  group('FavoritesPage', () {
    test('reads profiles and pagination', () {
      final page = FavoritesPage.fromJson(<String, dynamic>{
        'favorites': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'u1',
            'username': 'zainab',
            'displayName': 'Zainab',
            'age': 26,
            'savedAt': '2026-08-18T10:00:00.000Z',
            'presence': 'ONLINE',
            'datingProfile': <String, dynamic>{'city': 'Lagos'},
          },
        ],
        'pagination': <String, dynamic>{
          'total': 1,
          'page': 1,
          'limit': 24,
          'totalPages': 1,
        },
      });

      expect(page.profiles, hasLength(1));
      expect(page.profiles.single.username, 'zainab');
      expect(page.total, 1);
      expect(page.hasMore, isFalse);
    });

    test('savedAt is keyed by user id, not carried on the profile', () {
      // When a viewer saved someone is a fact about the *viewer's* shortlist,
      // not about the member. Keeping it off ProfileSummary is what stops it
      // leaking onto a surface that renders a profile from anywhere else.
      final page = FavoritesPage.fromJson(<String, dynamic>{
        'favorites': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'u1',
            'username': 'zainab',
            'savedAt': '2026-08-18T10:00:00.000Z',
          },
        ],
      });

      // Compared as an instant: the parser returns local time, so a bare
      // equality here would pass or fail depending on the machine's zone.
      expect(page.savedAt['u1']?.toUtc(), DateTime.utc(2026, 8, 18, 10));
    });

    test('hasMore is true while pages remain', () {
      final page = FavoritesPage.fromJson(<String, dynamic>{
        'favorites': <Map<String, dynamic>>[],
        'pagination': <String, dynamic>{'page': 1, 'totalPages': 3},
      });

      expect(page.hasMore, isTrue);
    });

    test('an empty or malformed response is an empty page, not a crash', () {
      final page = FavoritesPage.fromJson(<String, dynamic>{});
      expect(page.profiles, isEmpty);
      expect(page.total, 0);
      expect(page.hasMore, isFalse);
    });

    test('a row missing savedAt still yields the profile', () {
      final page = FavoritesPage.fromJson(<String, dynamic>{
        'favorites': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'u1', 'username': 'zainab'},
        ],
      });

      expect(page.profiles, hasLength(1));
      expect(page.savedAt, isEmpty);
    });
  });
}
