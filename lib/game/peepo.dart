import 'package:flutter/material.dart';

/// The poses Peepo, the game's owl guide, is drawn in.
///
/// Each one is a cutout with transparency in `assets/peepo/`, generated
/// from `docs/imgenprompts/peepo-mascot.md` by `tools/scene.sh mascot`. Adding
/// a pose means adding a prompt block there and a value here - nothing in this
/// file needs to know what the art looks like.
enum PeepoPose {
  /// Hello. The level list and anywhere the game has nothing else to say.
  wave('wave', 'Peepo the owl waving'),

  /// On the hunt, magnifying glass up. Loading, hints, anything mid-search.
  search('search', 'Peepo the owl searching'),

  /// Wings up. Only for finishing something.
  cheer('cheer', 'Peepo the owl cheering');

  const PeepoPose(this.asset, this.label);

  /// File stem under `assets/peepo/`.
  final String asset;

  /// What a screen reader says when the pose is worth announcing.
  final String label;

  String get path => 'assets/peepo/$asset.png';
}

/// Peepo, at a given size.
///
/// The art is square and the owl is centred in it, so [size] is the box, not
/// the bird: two poses at the same size line up.
class Peepo extends StatelessWidget {
  /// Decodes every pose ahead of time.
  ///
  /// Peepo appears at moments that are already animating - the smoke closing
  /// over a level, the seal the confetti bursts from - and an image that has
  /// not decoded yet pops in a frame or two late, right through the animation
  /// it is supposed to be part of.
  static Future<void> precacheAll(BuildContext context) => Future.wait([
    for (final pose in PeepoPose.values)
      precacheImage(AssetImage(pose.path), context),
  ]);

  const Peepo({
    super.key,
    required this.pose,
    required this.size,
    this.semantic = false,
  });

  final PeepoPose pose;
  final double size;

  /// Whether Peepo is worth announcing. He is decoration next to a title and
  /// worth naming when he is the only thing on an empty screen.
  final bool semantic;

  @override
  Widget build(BuildContext context) {
    // Decoded at its own 512px size, not at the size it is drawn: three small
    // bitmaps cost nothing, and a per-size decode would miss the cache
    // [precacheAll] fills, which is the whole point of filling it.
    return Image.asset(
      pose.path,
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: !semantic,
      semanticLabel: semantic ? pose.label : null,
      errorBuilder: (context, error, stack) => SizedBox.square(dimension: size),
    );
  }
}
