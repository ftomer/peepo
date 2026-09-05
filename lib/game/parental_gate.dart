import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';
import 'peepo.dart';

/// Asks a question a child of twelve can do and a child of four cannot, and
/// answers true only if it is answered right.
///
/// Everything that is a grown-up's decision sits behind this: the age band,
/// wiping progress, and later any purchase or any link that leaves the app.
/// Apple's Kids Category and Google's Designed for Families both require the
/// gate; it is not a security measure and does not pretend to be one.
///
/// The question is thrown fresh each time, so a child cannot learn the answer
/// by watching once.
Future<bool> showParentalGate(BuildContext context) async {
  final passed = await showDialog<bool>(
    context: context,
    // Tapping outside backs out, same as Cancel: a grown-up who opened the
    // gate by accident should not have to hunt for the way out.
    //
    // This used to be false, because a finger that missed an answer and landed
    // on the barrier shut the gate, which reads as the answer being rejected.
    // The answers are now full-width 48pt pills inside the dialog's own 24pt
    // content padding, so a near miss lands on the dialog surface and does
    // nothing; reaching the barrier means tapping clear of the card.
    barrierDismissible: true,
    builder: (context) => const _GateDialog(),
  );
  return passed ?? false;
}

/// One sum and the four answers offered for it.
///
/// Thrown fresh for every question, and a question is only ever asked once:
/// a wrong tap draws a new [_Sum] rather than leaving the same four buttons
/// up. Guessing is what a child does at a gate, and four buttons that stay
/// put are four guesses.
class _Sum {
  const _Sum({
    required this.question,
    required this.answer,
    required this.options,
  });

  /// [instead] is the question just asked, which this one may not repeat: a
  /// wrong tap has to change the sum, or the four buttons that were up are
  /// four guesses at the same answer. One in seven hundred draws lands on the
  /// same pair, so it is drawn again rather than left to chance.
  factory _Sum.random(Random random, {String? instead}) {
    // Two-digit addition: past a four-year-old, easy for a grown-up at a
    // glance.
    var a = 12 + random.nextInt(28);
    var b = 13 + random.nextInt(27);
    while ('$a + $b' == instead) {
      a = 12 + random.nextInt(28);
      b = 13 + random.nextInt(27);
    }
    final answer = a + b;

    // Wrong answers that are close enough to need the sum done, not eyeballed.
    final options = <int>{answer};
    while (options.length < 4) {
      final wrong =
          answer + (random.nextInt(2) == 0 ? -1 : 1) * (2 + random.nextInt(9));
      if (wrong > 0) options.add(wrong);
    }

    return _Sum(
      question: '$a + $b',
      answer: answer,
      options: options.toList()..shuffle(random),
    );
  }

  final String question;
  final int answer;
  final List<int> options;
}

class _GateDialog extends StatefulWidget {
  const _GateDialog();

  @override
  State<_GateDialog> createState() => _GateDialogState();
}

class _GateDialogState extends State<_GateDialog> {
  final Random _random = Random();

  late _Sum _sum = _Sum.random(_random);

  /// Set after a wrong tap, which says so and asks a different sum rather than
  /// closing - a parent who mis-taps is not thrown out, they just do another
  /// one.
  bool _wrong = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: PeepoColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: PeepoColors.rim),
      ),
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Peepo(pose: PeepoPose.search, size: 30),
          SizedBox(width: 10),
          Text(
            'Grown-ups only',
            style: TextStyle(color: PeepoColors.cream, fontSize: 18),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _sum.question,
            style: const TextStyle(
              color: PeepoColors.sunny,
              fontSize: 34,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          // One row, always: the answers share the width evenly rather than
          // wrapping a lone fourth button onto a second line.
          Row(
            children: [
              for (final option in _sum.options) ...[
                if (option != _sum.options.first) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      if (option == _sum.answer) {
                        Navigator.of(context).pop(true);
                        return;
                      }
                      // A question is answered once. Guessing at four buttons
                      // gets a fresh sum, not a second look at this one.
                      setState(() {
                        _wrong = true;
                        _sum = _Sum.random(_random, instead: _sum.question);
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PeepoColors.cream,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      side: const BorderSide(
                        color: PeepoColors.teal,
                        width: PeepoColors.strokeWidth,
                      ),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Text('$option'),
                  ),
                ),
              ],
            ],
          ),
          if (_wrong) ...[
            const SizedBox(height: 14),
            const Text(
              'Not quite - here is another one.',
              style: TextStyle(color: PeepoColors.berryText, fontSize: 13),
            ),
          ],
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      actions: [
        // A filled pill, not bare text: at this age a word on its own does not
        // read as something you can press.
        FilledButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: FilledButton.styleFrom(
            backgroundColor: PeepoColors.panelRaised,
            foregroundColor: PeepoColors.cream,
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 28),
            shape: const StadiumBorder(
              side: BorderSide(
                color: PeepoColors.rim,
                width: PeepoColors.strokeWidth,
              ),
            ),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
