import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/data/models/account.dart';
import 'package:pinorpinor_app/data/models/credits.dart';
import 'package:pinorpinor_app/data/models/enums.dart';
import 'package:pinorpinor_app/data/models/media_item.dart';
import 'package:pinorpinor_app/data/models/messaging.dart';
import 'package:pinorpinor_app/data/models/notifications.dart';
import 'package:pinorpinor_app/data/models/profile.dart';
import 'package:pinorpinor_app/data/models/settings.dart';

/// Parsing tests written against the shapes the Pinorpinor API actually
/// returns, including the ones that differ between routes.
void main() {
  group('Enums', () {
    test('parse the exact strings Prisma stores', () {
      expect(UserRole.parse('SUPER_ADMIN'), UserRole.superAdmin);
      expect(Gender.parse('WOMAN'), Gender.woman);
      expect(InterestedIn.parse('BOTH'), InterestedIn.both);
      expect(VerificationStatus.parse('VERIFIED'), VerificationStatus.verified);
      expect(MediaType.parse('PROFILE_PHOTO'), MediaType.profilePhoto);
    });

    test('degrade gracefully on an unknown value', () {
      // A newer backend must not crash an older client.
      expect(UserRole.parse('DEITY'), UserRole.unknown);
      expect(Gender.parse(null), isNull);
      expect(VerificationStatus.parse('???'), VerificationStatus.none);
      expect(NotificationType.parse('BRAND_NEW'), NotificationType.system);
    });

    test('only lady accounts may upload media', () {
      expect(UserRole.woman.canUploadMedia, isTrue);
      expect(UserRole.man.canUploadMedia, isFalse);
      expect(UserRole.admin.canUploadMedia, isFalse);
    });

    test('staff roles match the backend ADMIN_ROLES set', () {
      expect(UserRole.moderator.isStaff, isTrue);
      expect(UserRole.admin.isStaff, isTrue);
      expect(UserRole.superAdmin.isStaff, isTrue);
      expect(UserRole.woman.isStaff, isFalse);
    });

    test('default interest matches lib/visibility.ts', () {
      expect(InterestedIn.defaultFor(Gender.woman), InterestedIn.both);
      expect(InterestedIn.defaultFor(Gender.man), InterestedIn.women);
      expect(InterestedIn.defaultFor(null), InterestedIn.women);
    });
  });

  group('ProfileSummary', () {
    test('parses the /api/public/profiles shape', () {
      final profile = ProfileSummary.fromJson(<String, dynamic>{
        'id': 'u1',
        'username': 'zainab',
        'displayName': 'Zainab',
        'age': 26,
        'verificationStatus': 'VERIFIED',
        'datingProfile': <String, dynamic>{
          'tagline': 'Lover of jollof and jazz',
          'city': 'Lagos',
          'country': 'Nigeria',
          'countryCode': 'NG',
          'isAvailableToday': true,
          'isRedHot': true,
          'dateTypes': <String>['Dinner Dates', 'Live Music'],
        },
        'media': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'm1',
            'mediaType': 'PROFILE_PHOTO',
            'storageUrl': 'https://cdn.example/signed-1',
            'order': 0,
          },
        ],
      });

      expect(profile.username, 'zainab');
      expect(profile.age, 26);
      expect(profile.isVerified, isTrue);
      expect(profile.isAvailableToday, isTrue);
      expect(profile.isRedHot, isTrue);
      expect(profile.dateTypes, hasLength(2));
      expect(profile.primaryPhoto?.url, 'https://cdn.example/signed-1');
    });

    test('parses the /api/ladies shape, which renames the relation', () {
      // That route maps `datingProfile` to `ladyProfile` for the home rail.
      final profile = ProfileSummary.fromJson(<String, dynamic>{
        'id': 'u2',
        'username': 'ada',
        'displayName': 'Ada',
        'ladyProfile': <String, dynamic>{'city': 'Abuja', 'isLiveNow': true},
      });

      expect(profile.city, 'Abuja');
      expect(profile.isLiveNow, isTrue);
    });

    test('survives a payload with nothing but an id', () {
      final profile = ProfileSummary.fromJson(<String, dynamic>{'id': 'u3'});
      expect(profile.age, isNull);
      expect(profile.media, isEmpty);
      expect(profile.placeLabel, isNull);
      expect(profile.isVerified, isFalse);
    });

    test('builds a place label from whichever fields exist', () {
      ProfileSummary build(Map<String, dynamic> dating) =>
          ProfileSummary.fromJson(<String, dynamic>{
            'id': 'x',
            'datingProfile': dating,
          });

      expect(
        build(<String, dynamic>{'location': 'Ikeja, Lagos'}).placeLabel,
        'Ikeja, Lagos',
      );
      expect(
        build(<String, dynamic>{
          'city': 'Lagos',
          'country': 'Nigeria',
        }).placeLabel,
        'Lagos, Nigeria',
      );
      expect(build(<String, dynamic>{'city': 'Lagos'}).placeLabel, 'Lagos');
      expect(build(<String, dynamic>{}).placeLabel, isNull);
    });

    test('separates photos from videos', () {
      final profile = ProfileSummary.fromJson(<String, dynamic>{
        'id': 'u4',
        'media': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'a',
            'mediaType': 'GALLERY_PHOTO',
            'storageUrl': 'https://x/1',
          },
          <String, dynamic>{
            'id': 'b',
            'mediaType': 'VIDEO',
            'storageUrl': 'https://x/2',
          },
          // An object that could not be signed comes back with an empty URL,
          // which the API means as "no media" rather than an error.
          <String, dynamic>{
            'id': 'c',
            'mediaType': 'GALLERY_PHOTO',
            'storageUrl': '',
          },
        ],
      });

      expect(profile.photos, hasLength(1));
      expect(profile.videos, hasLength(1));
    });
  });

  group('ProfilePage', () {
    test('reads pagination and country scope', () {
      final page = ProfilePage.fromJson(<String, dynamic>{
        'profiles': <Map<String, dynamic>>[
          <String, dynamic>{'id': '1', 'username': 'a'},
        ],
        'scope': <String, dynamic>{
          'countryCode': 'NG',
          'countryName': 'Nigeria',
          'pinned': true,
        },
        'pagination': <String, dynamic>{
          'total': 40,
          'page': 2,
          'limit': 12,
          'totalPages': 4,
        },
      });

      expect(page.profiles, hasLength(1));
      expect(page.countryName, 'Nigeria');
      // `pinned` is what tells the UI not to offer a country picker: a
      // signed-in member is scoped to their own country server-side.
      expect(page.pinned, isTrue);
      expect(page.hasMore, isTrue);
    });

    test('has no more pages on the last page', () {
      final page = ProfilePage.fromJson(<String, dynamic>{
        'profiles': <Map<String, dynamic>>[],
        'pagination': <String, dynamic>{'page': 4, 'totalPages': 4},
      });
      expect(page.hasMore, isFalse);
    });

    test('merge appends without losing the newer scope', () {
      final first = ProfilePage.fromJson(<String, dynamic>{
        'profiles': <Map<String, dynamic>>[
          <String, dynamic>{'id': '1'},
        ],
        'pagination': <String, dynamic>{'page': 1, 'totalPages': 2},
      });
      final second = ProfilePage.fromJson(<String, dynamic>{
        'profiles': <Map<String, dynamic>>[
          <String, dynamic>{'id': '2'},
        ],
        'pagination': <String, dynamic>{'page': 2, 'totalPages': 2},
      });

      final merged = first.merge(second);
      expect(merged.profiles, hasLength(2));
      expect(merged.page, 2);
      expect(merged.hasMore, isFalse);
    });
  });

  group('Account', () {
    Map<String, dynamic> payload({
      String gender = 'WOMAN',
      String? emailVerified,
      String? phoneVerified,
    }) => <String, dynamic>{
      'user': <String, dynamic>{
        'id': 'me',
        'email': 'me@example.com',
        'username': 'me_user',
        'displayName': 'Me',
        'role': gender,
        'gender': gender,
        'verificationStatus': 'PENDING',
        'emailVerified': emailVerified,
        'phoneVerified': phoneVerified,
        'datingProfile': <String, dynamic>{'city': 'Lagos', 'bio': 'Hello'},
        'media': <Map<String, dynamic>>[],
      },
    };

    test('unwraps the `user` envelope', () {
      final account = Account.fromJson(payload());
      expect(account.username, 'me_user');
      expect(account.profile.city, 'Lagos');
    });

    test('women need both channels; men need only email', () {
      final woman = Account.fromJson(
        payload(emailVerified: '2026-08-01T10:00:00.000Z'),
      );
      expect(woman.requiresPhoneVerification, isTrue);
      expect(woman.fullyVerified, isFalse);

      final womanDone = Account.fromJson(
        payload(
          emailVerified: '2026-08-01T10:00:00.000Z',
          phoneVerified: '2026-08-01T10:05:00.000Z',
        ),
      );
      expect(womanDone.fullyVerified, isTrue);

      final man = Account.fromJson(
        payload(gender: 'MAN', emailVerified: '2026-08-01T10:00:00.000Z'),
      );
      expect(man.requiresPhoneVerification, isFalse);
      expect(man.fullyVerified, isTrue);
    });

    test('flags media still awaiting moderation', () {
      final account = Account.fromJson(<String, dynamic>{
        'user': <String, dynamic>{
          'id': 'me',
          'username': 'me_user',
          'media': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'm1',
              'mediaType': 'PROFILE_PHOTO',
              'storageUrl': 'https://x/1',
              'isApproved': false,
            },
          ],
        },
      });

      expect(account.hasPendingMedia, isTrue);
      // A pending photo has no approved avatar to show anyone else.
      expect(account.avatar, isNull);
    });

    test('completeness is bounded and rises with a fuller profile', () {
      final sparse = Account.fromJson(<String, dynamic>{
        'user': <String, dynamic>{'id': 'a', 'username': 'a_user'},
      });
      final full = Account.fromJson(<String, dynamic>{
        'user': <String, dynamic>{
          'id': 'b',
          'username': 'b_user',
          'displayName': 'Bee',
          'gender': 'MAN',
          'emailVerified': '2026-01-01T00:00:00.000Z',
          'datingProfile': <String, dynamic>{
            'bio': 'A bio comfortably past twenty characters long.',
            'city': 'Lagos',
            'countryCode': 'NG',
            'dateTypes': <String>['Dinner Dates'],
          },
          'media': <Map<String, dynamic>>[
            <String, dynamic>{'id': 'm', 'mediaType': 'PROFILE_PHOTO'},
          ],
        },
      });

      expect(sparse.completeness, inInclusiveRange(0, 1));
      expect(full.completeness, greaterThan(sparse.completeness));
      expect(full.completeness, 1.0);
    });
  });

  group('MediaItem', () {
    test('never exposes a storage key, because the API strips it', () {
      final item = MediaItem.fromJson(<String, dynamic>{
        'id': 'm1',
        'mediaType': 'VIDEO',
        'storageUrl': 'https://cdn/signed',
        'duration': 12.5,
      });

      expect(item.isVideo, isTrue);
      expect(item.durationSeconds, 12.5);
      expect(item.stableUrl, endsWith('/api/media/m1'));
    });

    test('treats an empty URL as "no media"', () {
      final item = MediaItem.fromJson(<String, dynamic>{
        'id': 'm',
        'storageUrl': '',
      });
      expect(item.hasUrl, isFalse);
    });
  });

  group('ConversationSummary', () {
    ConversationSummary build({
      String? lastSender,
      String? lastAt,
      String? lastReadAt,
    }) => ConversationSummary.fromJson(<String, dynamic>{
      'conversationId': 'c1',
      'updatedAt': '2026-08-13T10:00:00.000Z',
      'lastReadAt': lastReadAt,
      'partner': <String, dynamic>{'id': 'them', 'username': 'them'},
      'lastMessage': <String, dynamic>{
        'content': 'hello',
        'senderId': lastSender,
        'createdAt': lastAt,
      },
    });

    test('is unread when the partner wrote after my last read', () {
      final conversation = build(
        lastSender: 'them',
        lastAt: '2026-08-13T10:00:00.000Z',
        lastReadAt: '2026-08-13T09:00:00.000Z',
      );
      expect(conversation.unreadFor('me'), isTrue);
    });

    test('is read once lastReadAt passes the message', () {
      final conversation = build(
        lastSender: 'them',
        lastAt: '2026-08-13T09:00:00.000Z',
        lastReadAt: '2026-08-13T10:00:00.000Z',
      );
      expect(conversation.unreadFor('me'), isFalse);
    });

    test('my own message never marks the thread unread', () {
      final conversation = build(
        lastSender: 'me',
        lastAt: '2026-08-13T10:00:00.000Z',
        lastReadAt: null,
      );
      expect(conversation.unreadFor('me'), isFalse);
    });

    test('shows a placeholder for a deleted message', () {
      final conversation = ConversationSummary.fromJson(<String, dynamic>{
        'conversationId': 'c1',
        'updatedAt': '2026-08-13T10:00:00.000Z',
        'lastMessage': <String, dynamic>{'content': 'gone', 'isDeleted': true},
      });
      expect(conversation.lastMessagePreview, 'Message deleted');
    });
  });

  group('ContactRequest', () {
    test('reads the counterparty from whichever side the API sent', () {
      final received = ContactRequest.fromJson(<String, dynamic>{
        'id': 'r1',
        'status': 'PENDING',
        'createdAt': '2026-08-13T10:00:00.000Z',
        'message': 'Hi there',
        'requester': <String, dynamic>{
          'displayName': 'Ade',
          'username': 'ade',
          'media': <Map<String, dynamic>>[
            <String, dynamic>{'storageUrl': 'https://cdn/avatar'},
          ],
        },
      });

      expect(received.counterpartName, 'Ade');
      expect(received.counterpartAvatarUrl, 'https://cdn/avatar');
      expect(received.isPending, isTrue);

      final sent = ContactRequest.fromJson(<String, dynamic>{
        'id': 'r2',
        'status': 'ACCEPTED',
        'createdAt': '2026-08-13T10:00:00.000Z',
        'owner': <String, dynamic>{
          'displayName': 'Zainab',
          'username': 'zainab',
        },
      });

      expect(sent.counterpartName, 'Zainab');
      expect(sent.status, ContactRequestStatus.accepted);
    });
  });

  group('MemberSettings', () {
    test('clamps the age range to the 18+ floor', () {
      final settings = MemberSettings.fromJson(<String, dynamic>{
        'settings': <String, dynamic>{'ageRangeMin': 13, 'ageRangeMax': 200},
      });
      expect(settings.ageRangeMin, 18);
      expect(settings.ageRangeMax, 100);
    });

    test('round-trips through toPatch', () {
      const settings = MemberSettings(
        notifyOnLike: true,
        showInDiscovery: false,
      );
      final patch = settings.toPatch();
      expect(patch['notifyOnLike'], isTrue);
      expect(patch['showInDiscovery'], isFalse);
    });
  });

  group('Wallet', () {
    test('reads the nested boost, featured and referral blocks', () {
      final wallet = Wallet.fromJson(<String, dynamic>{
        'balance': 120,
        'whatsappNumber': '+2348000000000',
        'referral': <String, dynamic>{'code': 'PNP123', 'count': 3},
        'boost': <String, dynamic>{
          'active': true,
          'tier': 2,
          'expiresAt': '2026-08-14T10:00:00.000Z',
        },
        'featured': <String, dynamic>{'active': false},
      });

      expect(wallet.balance, 120);
      expect(wallet.referralCode, 'PNP123');
      expect(wallet.boostActive, isTrue);
      expect(wallet.boostTier, 2);
      expect(wallet.featuredActive, isFalse);
    });
  });
}
