import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/difficulty.dart';
import '../models/level_progress.dart';
import '../models/settings.dart';
import '../theme.dart';
import 'audio.dart';
import 'peepo.dart';

/// Everything a grown-up can change, behind the parental gate that opens it.
///
/// Short on purpose. The only decision that matters here is the age, and it is
/// the first thing on the screen: everything else is a switch or a warning.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.progress,
    this.audio,
  });

  final AppSettings settings;
  final LevelProgress progress;

  /// Only so that switching the effects back on can demonstrate one. The
  /// switches themselves change [settings], and the audio follows from there.
  final GameAudio? audio;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PeepoColors.ground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: PeepoColors.cream,
        title: const Text('Grown-ups'),
      ),
      body: AnimatedBuilder(
        animation: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const _SectionTitle('How old is the player?'),
            const SizedBox(height: 4),
            const Text(
              'This changes how many things a level hides, how big they are, '
              'and how quickly the game steps in to help.',
              style: TextStyle(
                color: PeepoColors.dimSky,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            AgeBandPicker(
              selected: settings.band,
              onSelect: (band) => settings.band = band,
            ),
            const SizedBox(height: 28),
            const _SectionTitle('Help'),
            const SizedBox(height: 4),
            _Toggle(
              value: settings.assistWhenStuck,
              onChanged: (on) => settings.assistWhenStuck = on,
              title: 'Extra help when stuck',
              subtitle:
                  'After two hints go by without a find, hints come sooner '
                  'and stay longer, and taps count from further away. The '
                  'level never gets harder on its own.',
            ),
            const SizedBox(height: 20),
            const _SectionTitle('Sound'),
            const SizedBox(height: 4),
            _Toggle(
              value: settings.music,
              onChanged: (on) => settings.music = on,
              title: 'Music',
              subtitle:
                  'A tune of its own under each level. It fades out when the '
                  'game is put down and never plays over a call.',
            ),
            _Toggle(
              value: settings.soundEffects,
              onChanged: (on) {
                settings.soundEffects = on;
                // Turning them back on says so out loud, so a grown-up is not
                // left tapping the switch to find out which one it was.
                if (on) audio?.play(Sfx.found);
              },
              title: 'Sound effects',
              subtitle:
                  'The chime for a find, the sparkle for a hint and the '
                  'fanfare at the end of a level.',
            ),
            const SizedBox(height: 20),
            const _SectionTitle('Progress'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _confirmReset(context),
              icon: const Icon(Icons.restart_alt_rounded, size: 20),
              label: const Text('Start the levels over'),
              style: OutlinedButton.styleFrom(
                foregroundColor: PeepoColors.cream,
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
                side: const BorderSide(
                  color: PeepoColors.rim,
                  width: PeepoColors.strokeWidth,
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Peepo keeps everything on this device. No accounts, no ads, '
              'nothing sent anywhere.',
              style: TextStyle(
                color: PeepoColors.dimSky,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PeepoColors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: PeepoColors.rim),
        ),
        title: const Text(
          'Start over?',
          style: TextStyle(color: PeepoColors.cream, fontSize: 18),
        ),
        content: const Text(
          'Every level goes back to unfinished. This cannot be undone.',
          style: TextStyle(
            color: PeepoColors.dimSky,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: PeepoColors.dimSky),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: PeepoColors.berry,
              foregroundColor: PeepoColors.onAccent,
            ),
            child: const Text('Start over'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) progress.reset();
  }
}

/// The four age bands as cards, with what each one actually changes.
///
/// Used on the settings screen and on the first-run card, which is the same
/// question asked before anybody has played anything.
class AgeBandPicker extends StatelessWidget {
  const AgeBandPicker({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final AgeBand selected;
  final ValueChanged<AgeBand> onSelect;

  /// One line per band, in the terms a parent judges it by rather than the
  /// numbers the placer uses.
  static String summaryOf(AgeBand band) => switch (band) {
    AgeBand.peek =>
      'A few big things, pictures instead of words, '
          'generous taps, help within seconds.',
    AgeBand.look =>
      'A full room at picture-and-word chips, help if a '
          'find takes a while.',
    AgeBand.seek =>
      'More to find, smaller and closer together, five '
          'hints, stars at the end.',
    AgeBand.hunt =>
      'The whole room, no help unless asked, three hints '
          'and a rating.',
  };

  /// Below this the cards are stacked; above it they pair up.
  static const _twoColumnWidth = 560.0;

  @override
  Widget build(BuildContext context) {
    // The game is landscape-locked, so on a phone the four cards would run off
    // the bottom of a first-run dialog stacked. Two columns keeps all four on
    // screen at once, which is the point of showing them together.
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= _twoColumnWidth ? 2 : 1;
        final cardWidth = (constraints.maxWidth - 10 * (columns - 1)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final band in AgeBand.values)
              SizedBox(
                width: cardWidth,
                child: _BandCard(
                  band: band,
                  chosen: band == selected,
                  onTap: () => onSelect(band),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BandCard extends StatelessWidget {
  const _BandCard({
    required this.band,
    required this.chosen,
    required this.onTap,
  });

  final AgeBand band;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: chosen,
      label: '${band.label}, ages ${band.ageLabel}',
      child: Material(
        color: chosen ? PeepoColors.panelRaised : PeepoColors.panel,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            // Cards sit side by side, and summaries run to different lengths:
            // a floor keeps a pair the same height instead of ragged.
            constraints: const BoxConstraints(minHeight: 86),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              // The chosen band is ringed in the colour that means "yours"
              // everywhere else in the game; the rest carry a seam of the
              // same width, so picking one does not shove its neighbours.
              border: Border.all(
                color: chosen ? PeepoColors.teal : PeepoColors.rim,
                width: PeepoColors.strokeWidth,
              ),
            ),
            child: Row(
              children: [
                _AgeBadge(band: band, chosen: chosen),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        band.label,
                        style: TextStyle(
                          color: chosen ? PeepoColors.sunny : PeepoColors.cream,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AgeBandPicker.summaryOf(band),
                        style: const TextStyle(
                          color: PeepoColors.dimSky,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (chosen)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: PeepoColors.sunny,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AgeBadge extends StatelessWidget {
  const _AgeBadge({required this.band, required this.chosen});

  final AgeBand band;
  final bool chosen;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: chosen
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: PeepoColors.sealGradient,
              )
            : null,
        color: chosen ? null : PeepoColors.ground,
        border: Border.fromBorderSide(
          BorderSide(
            color: chosen ? PeepoColors.outline : PeepoColors.rim,
            width: PeepoColors.strokeWidth,
          ),
        ),
      ),
      // The age and the unit are stacked by hand: "11-12 yrs" on one line is
      // wider than the circle, and letting it wrap puts "yrs" half outside.
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                band.ageLabel,
                maxLines: 1,
                style: TextStyle(
                  color: chosen ? PeepoColors.onAccent : PeepoColors.dimSky,
                  fontSize: 13,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'yrs',
                maxLines: 1,
                style: TextStyle(
                  color: chosen ? PeepoColors.onAccent : PeepoColors.dimSky,
                  fontSize: 10,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One switch, its name and the sentence explaining what it does.
class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.value,
    required this.onChanged,
    required this.title,
    required this.subtitle,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      activeThumbColor: PeepoColors.teal,
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(color: PeepoColors.cream, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: PeepoColors.dimSky,
          fontSize: 12,
          height: 1.4,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: PeepoColors.sunny,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );
  }
}

/// The question asked once, on the very first launch, before a level has been
/// opened: the game cannot pick a sensible band on its own, and getting it
/// wrong is the difference between a level a four year old can finish and one
/// they cannot.
///
/// No gate in front of this one - there is nothing yet to protect, and a
/// grown-up is by definition the one setting the app up.
class FirstRunAgeCard extends StatelessWidget {
  const FirstRunAgeCard({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // A landscape phone gives this dialog barely 350 logical pixels of height,
    // and an AlertDialog spends that on a fixed header before the cards get a
    // say - which cropped the first and last band clean off. Header and cards
    // now share one scroll view, and the greeting shrinks when the screen is
    // short so all four bands fit without scrolling at all.
    final short = media.size.height < 460;
    // Height is what a landscape phone is short of, so there the card takes
    // all the width it is given: wider cards wrap their summary in fewer
    // lines, which is the cheapest height there is to buy.
    final maxWidth = short
        ? media.size.width - 40
        : math.min(720.0, media.size.width - 40);

    return Dialog(
      backgroundColor: PeepoColors.ground,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: const BorderSide(color: PeepoColors.rim),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, short ? 14 : 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Peepo(
                pose: PeepoPose.wave,
                size: short ? 48 : 76,
                semantic: true,
              ),
              SizedBox(height: short ? 6 : 10),
              Text(
                'Who is playing?',
                style: TextStyle(
                  color: PeepoColors.cream,
                  fontSize: short ? 18 : 20,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pick an age and Peepo hides things to suit it. '
                'A grown-up can change it any time.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: PeepoColors.dimSky,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              SizedBox(height: short ? 12 : 18),
              AgeBandPicker(
                selected: settings.band,
                onSelect: (band) {
                  settings.band = band;
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
