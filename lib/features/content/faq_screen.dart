import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/credits.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'content_widgets.dart';

/// The website's `/faq`, as a screen.
///
/// ## Two answers are corrected, and the website's own rule demands it
///
/// `src/app/faq/page.tsx` opens with this instruction to whoever edits it:
///
/// > Every answer below describes behaviour that is actually implemented. If a
/// > feature changes, change the answer in the same commit: a FAQ that
/// > describes how the product used to work is worse than no FAQ, because
/// > members make safety decisions from it.
///
/// Two answers no longer follow it, both left behind by the 2026-08-23 release
/// that deleted the contact-request flow:
///
///  1. **"Who can see my phone number?"** said "When someone asks to contact
///     you, you accept or decline; only after you accept does a WhatsApp chat
///     open." There is no asking, no accepting and no declining. A chat is
///     opened by paying for it, and the member being contacted is charged too.
///     Left as written, this tells a member a consent gate protects her when
///     none exists — the single most consequential thing the FAQ could be
///     wrong about.
///  2. **"What are credits for?"** described boosts only. Credits are now what
///     makes a member reachable at all: 100 from each side to open a chat, and
///     a balance under that makes her uncontactable.
///
/// Both are rewritten here to what the platform does. Everything else is the
/// website's wording, transcribed. The website needs the same two fixes; that
/// is the other repository's change to make.
class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ContentScaffold(
      title: 'FAQ',
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                Icons.help_outline_rounded,
                color: AppColors.rose,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Frequently asked questions',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text:
                        'How Pinorpinor actually works. If something here does '
                        'not match what you see in the product, treat it as a '
                        'bug and ',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                  ),
                  TextSpan(
                    text: 'tell us',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.6,
                      color: AppColors.rose,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.rose,
                    ),
                    recognizer: null,
                  ),
                  TextSpan(
                    text: '.',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => context.push(AppRoutes.support),
                child: const Text('Contact & Support'),
              ),
            ),
          ],
        ),

        for (final entry in _faqs)
          _FaqTile(question: entry.$1, answer: entry.$2),
      ],
    );
  }
}

/// `(question, answer)`, in the website's order.
final List<(String, String)> _faqs = <(String, String)>[
  (
    'Do I need an account to browse?',
    'No. Public member profiles, photos and videos are visible without '
        'signing in. You need an account, and credits, to open a WhatsApp '
        'chat with a member.',
  ),
  // Corrected. The website still describes the deleted consent gate.
  (
    'Who can see my phone number?',
    'Nobody. Your number is never sent to the app or the browser on any '
        'page, and it is not in the data a profile card is built from. A '
        'member who wants to reach you on WhatsApp pays '
        '$kWhatsAppUnlockCredits credits to open the chat, and you are charged '
        '$kWhatsAppUnlockCredits as well — so a balance below that makes you '
        'uncontactable rather than exposed. When a chat does open it opens '
        'through a server-side redirect that still never prints your number.',
  ),
  (
    'What does the Services list on a profile mean?',
    'It shows only what that member ticked for themselves, and nothing else. '
        'An item missing from the list means they did not choose it. Nothing '
        'on a profile is an offer or an obligation, and a member can change '
        'or remove any of it at any time from Edit Profile. See the safety '
        'guidance before arranging to meet anyone.',
  ),
  (
    'What happens to a photo after I upload it?',
    'It goes live straight away, so your profile is visible as soon as you '
        'upload. You control separately whether each photo is public, and '
        'turning that off hides it immediately. Our moderators review media '
        'after it is published and remove anything that breaks the rules; a '
        'removed photo is deleted from storage, not just hidden.',
  ),
  (
    'How is 18+ enforced?',
    'Members confirm they are 18 or over when they register, and the platform '
        'is restricted to adults. Be clear about what that is worth: it is a '
        'declaration they make, not something we have verified, and the age '
        'notice on the front of the site proves nothing either. We rely on '
        'moderation and on reports. If you believe a profile belongs to '
        'someone under 18, report it and we will act on it immediately.',
  ),
  (
    'What does the verified badge actually mean?',
    'It means the member confirmed control of a phone number or email we sent '
        'a code to, and nothing more. It is not identity verification and it '
        'is not proof of age. Registration does not currently issue it, so '
        'most profiles will not have one, and its absence says nothing bad '
        'about a member.',
  ),
  (
    'Can I hide my profile without deleting it?',
    'Yes. Turning off discoverability removes you from browsing, search and '
        'the homepage while keeping your account and media intact. Your '
        'existing conversations are unaffected.',
  ),
  (
    'How do I block or report someone?',
    'Every profile has a report control, and blocking is available from your '
        'settings. A block works both ways: you disappear from their browsing '
        'and they disappear from yours, including anywhere you had already '
        'saved each other.',
  ),
  // Corrected. The website's answer predates paid contact and names only
  // boosts, which is now the secondary use.
  (
    'What are credits for?',
    'Two things. Opening a WhatsApp chat costs $kWhatsAppUnlockCredits credits '
        'from the member starting it and $kWhatsAppUnlockCredits from the member '
        'being contacted, in one transaction — if either wallet is short, '
        'neither is charged and the chat does not open. Credits also pay for '
        'profile boosts, which raise your placement for a fixed period; a '
        'boost buys position and nothing else, it does not change your badge '
        'and it is not an endorsement. Card payments are currently suspended; '
        'credits are arranged over WhatsApp and applied by an admin.',
  ),
  (
    'How do I delete my account?',
    'Ask from your settings page and we remove your profile, media and '
        'messages. Deleted media is removed from storage, not just hidden, '
        'because a file that is hidden but still present is reachable by '
        'anything that later signs its key.',
  ),
];

/// One expandable question.
///
/// `ExpansionTile` is the platform equivalent of the website's `<details>`:
/// keyboard and screen-reader operable without hand-rolling either.
class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // The default divider on an ExpansionTile draws a hairline across a
        // card that already has a border.
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 2,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          iconColor: AppColors.rose,
          collapsedIconColor: AppColors.rose,
          title: Text(
            question,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textMain,
            ),
          ),
          children: <Widget>[
            Align(alignment: Alignment.centerLeft, child: ContentBody(answer)),
          ],
        ),
      ),
    );
  }
}
