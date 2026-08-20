import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinorpinor_app/core/network/api_client.dart';
import 'package:pinorpinor_app/core/network/session_store.dart';
import 'package:pinorpinor_app/core/providers.dart';
import 'package:pinorpinor_app/data/models/profile.dart';
import 'package:pinorpinor_app/data/models/settings.dart';
import 'package:pinorpinor_app/data/repositories/discovery_repository.dart';

import 'fake_secure_storage.dart';

/// A scripted discovery backend.
///
/// Extends the real repository rather than implementing an interface, so if a
/// method gains a parameter this fails to compile instead of silently testing
/// an obsolete shape.
class FakeDiscoveryRepository extends DiscoveryRepository {
  FakeDiscoveryRepository({
    this.onlinePage,
    this.browsePages = const <ProfilePage>[],
    this.cities = const <LocationCount>[],
    this.error,
  }) : super(
         ApiClient(sessionStore: SessionStore(storage: FakeSecureStorage())),
       );

  final ProfilePage? onlinePage;

  /// Returned in order by successive [browse] calls; the last is reused once
  /// exhausted, which is what the videos sweep walks through.
  final List<ProfilePage> browsePages;

  final List<LocationCount> cities;

  /// Thrown by every method when set.
  final Object? error;

  int onlineCalls = 0;
  int browseCalls = 0;
  bool? lastStrict;

  static ProfilePage page(
    List<ProfileSummary> profiles, {
    int totalPages = 1,
    int pageNumber = 1,
  }) => ProfilePage(
    profiles: profiles,
    page: pageNumber,
    totalPages: totalPages,
    total: profiles.length,
    countryCode: 'NG',
    countryName: 'Nigeria',
  );

  static ProfileSummary profile(
    String username, {
    String? presence,
    List<Map<String, dynamic>> media = const <Map<String, dynamic>>[],
  }) => ProfileSummary.fromJson(<String, dynamic>{
    'id': 'id-$username',
    'username': username,
    'displayName': username,
    'age': 26,
    'presence': ?presence,
    'datingProfile': <String, dynamic>{'city': 'Lagos', 'country': 'Nigeria'},
    'media': media,
  });

  /// A video row shaped the way `/api/public/profiles` serialises one.
  static Map<String, dynamic> video(String id) => <String, dynamic>{
    'id': id,
    'mediaType': 'VIDEO',
    'storageUrl': 'https://example.test/$id.mp4',
  };

  @override
  Future<ProfilePage> online({
    bool strictlyOnline = false,
    String? countryCode,
    int page = 1,
    int limit = 24,
  }) async {
    onlineCalls++;
    lastStrict = strictlyOnline;
    if (error != null) throw error!;
    return onlinePage ?? emptyPage;
  }

  @override
  Future<ProfilePage> browse({
    DiscoveryFilters filters = DiscoveryFilters.none,
    int page = 1,
    int limit = 12,
  }) async {
    browseCalls++;
    if (error != null) throw error!;
    if (browsePages.isEmpty) return emptyPage;
    final index = (page - 1).clamp(0, browsePages.length - 1);
    return browsePages[index];
  }

  @override
  Future<List<LocationCount>> locations() async {
    if (error != null) throw error!;
    return cities;
  }

  static final ProfilePage emptyPage = page(const <ProfileSummary>[]);
}

/// Wires the fake into the provider graph.
List<Override> fakeDiscoveryOverrides(FakeDiscoveryRepository repository) =>
    <Override>[discoveryRepositoryProvider.overrideWithValue(repository)];
