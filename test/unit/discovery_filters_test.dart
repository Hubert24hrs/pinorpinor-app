import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/data/repositories/discovery_repository.dart';

/// `DiscoveryFilters.active` drives the per-filter chips on Discover. Each chip
/// carries its own removal, so the mapping from "what is shown" to "what
/// clearing it does" is worth pinning down.
void main() {
  group('active filters', () {
    test('the default filters have none', () {
      expect(DiscoveryFilters.none.active, isEmpty);
      expect(DiscoveryFilters.none.activeCount, 0);
      expect(DiscoveryFilters.none.isDefault, isTrue);
    });

    test('a city counts, but the ALL sentinel does not', () {
      // 'ALL' is what the picker uses for "any city"; it is not a narrowing and
      // must not appear as a chip the member is invited to remove.
      expect(const DiscoveryFilters(city: 'Lagos').active, hasLength(1));
      expect(const DiscoveryFilters(city: 'ALL').active, isEmpty);
      expect(const DiscoveryFilters(city: '').active, isEmpty);
    });

    test('age is one chip, not two', () {
      // "18–30" is the unit a person thinks in. Clearing half of a range is not
      // something anyone wants.
      final filters = const DiscoveryFilters(ageMin: 21, ageMax: 30).active;
      expect(filters, hasLength(1));
      expect(filters.single.label, '21–30 years');
    });

    test('the full age range is not a narrowing', () {
      expect(const DiscoveryFilters(ageMin: 18, ageMax: 99).active, isEmpty);
    });

    test('a half-open age range still counts', () {
      expect(const DiscoveryFilters(ageMin: 25).active, hasLength(1));
      expect(const DiscoveryFilters(ageMax: 40).active, hasLength(1));
    });

    test('the boolean filters each get a chip', () {
      expect(
        const DiscoveryFilters(verifiedOnly: true).active.single.label,
        'Verified',
      );
      expect(
        const DiscoveryFilters(availableTodayOnly: true).active.single.label,
        'Available today',
      );
    });

    test('activeCount agrees with the chips', () {
      const filters = DiscoveryFilters(
        city: 'Abuja',
        ageMin: 25,
        ageMax: 35,
        verifiedOnly: true,
        availableTodayOnly: true,
      );
      expect(filters.active, hasLength(4));
      expect(filters.activeCount, 4);
    });
  });

  group('clearing', () {
    test('dropping the city leaves the rest intact', () {
      const filters = DiscoveryFilters(
        city: 'Lagos',
        ageMin: 25,
        verifiedOnly: true,
      );
      final cleared = filters.active
          .firstWhere((f) => f.label == 'Lagos')
          .clear();

      expect(cleared.city, isNull);
      expect(cleared.ageMin, 25);
      expect(cleared.verifiedOnly, isTrue);
    });

    test('dropping the age range restores the full span', () {
      const filters = DiscoveryFilters(ageMin: 25, ageMax: 30, city: 'Lagos');
      final cleared = filters.active
          .firstWhere((f) => f.label.contains('years'))
          .clear();

      expect(cleared.ageMin, 18);
      expect(cleared.ageMax, 99);
      expect(cleared.city, 'Lagos');
    });

    test('dropping verified leaves availability alone', () {
      const filters = DiscoveryFilters(
        verifiedOnly: true,
        availableTodayOnly: true,
      );
      final cleared = filters.active
          .firstWhere((f) => f.label == 'Verified')
          .clear();

      expect(cleared.verifiedOnly, isFalse);
      expect(cleared.availableTodayOnly, isTrue);
    });

    test('clearing every chip one by one reaches the default', () {
      var filters = const DiscoveryFilters(
        city: 'Lagos',
        ageMin: 25,
        ageMax: 35,
        verifiedOnly: true,
        availableTodayOnly: true,
      );

      // Always drop the first — the list shrinks as it goes.
      while (filters.active.isNotEmpty) {
        filters = filters.active.first.clear();
      }

      expect(filters.isDefault, isTrue);
      expect(filters.activeCount, 0);
    });
  });

  group('query building', () {
    test('never sends an age below 18, whatever is set locally', () {
      // The server clamps too, but the client must not be the thing asking.
      final query = const DiscoveryFilters(
        ageMin: 13,
      ).toQuery(page: 1, limit: 12);
      expect(query['ageMin'], 18);
    });

    test('omits the ALL city sentinel', () {
      final query = const DiscoveryFilters(
        city: 'ALL',
      ).toQuery(page: 1, limit: 12);
      expect(query.containsKey('city'), isFalse);
    });

    test('sends the flags only when set', () {
      final off = DiscoveryFilters.none.toQuery(page: 1, limit: 12);
      expect(off.containsKey('verified'), isFalse);
      expect(off.containsKey('available'), isFalse);

      final on = const DiscoveryFilters(
        verifiedOnly: true,
        availableTodayOnly: true,
      ).toQuery(page: 1, limit: 12);
      expect(on['verified'], 'true');
      expect(on['available'], 'true');
    });
  });
}
