// Runs the game's own placer over a level and prints the layout it produces.
//
// Placement happens when a level is played, so there is no file to look at to
// see where things ended up. This gives you one: pick a seed, get the scene the
// player would get, in the shape the old baked scene files had.
//
//     dart run tools/layout.dart pirate_cabin --seed 7
//     dart run tools/layout.dart pirate_cabin --band peek
//     tools/scene.sh preview pirate_cabin --seed 7 --outlines
//
// A level is hidden differently for every age band, so a preview is only ever
// a preview of one of them: --band picks which, and Look - the band the art is
// drawn for - is what you get without it.
//
// It imports the placer the app uses rather than reimplementing it, so a
// preview cannot drift from the game. That is why lib/game/placement.dart and
// the models it reads stay free of Flutter.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:peepo/game/placement.dart';
import 'package:peepo/models/difficulty.dart';
import 'package:peepo/models/prop_catalog.dart';
import 'package:peepo/models/scene_meta.dart';

void main(List<String> args) {
  final positional = <String>[];
  int? seed;
  String? variant;
  var band = AgeBand.look;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--seed') {
      seed = int.parse(args[++i]);
    } else if (args[i] == '--variant') {
      variant = args[++i];
    } else if (args[i] == '--band') {
      final name = args[++i];
      final chosen = AgeBand.byId(name);
      if (chosen == null) {
        stderr.writeln(
          'unknown band "$name"; one of '
          '${AgeBand.values.map((b) => b.id).join(', ')}',
        );
        exit(2);
      }
      band = chosen;
    } else {
      positional.add(args[i]);
    }
  }
  if (positional.length != 1) {
    stderr.writeln(
      'usage: dart run tools/layout.dart <level id> [--seed N] '
      '[--band ${AgeBand.values.map((b) => b.id).join('|')}] '
      '[--variant <name>]',
    );
    exit(2);
  }

  final dir = Directory('assets/levels/${positional.first}');
  // A variant is a second backdrop for the same level, with its own room
  // description over the same sprites. Without one, the band decides: the
  // older two play the dense scene where a level ships it.
  final chosen = variant ?? band.profile.sceneVariant;
  final variantFile = chosen == null
      ? null
      : File('${dir.path}/scene.$chosen.json');
  final playing = variantFile != null && variantFile.existsSync();
  // A variant asked for by name and not on disk is an error, not a base
  // layout: printing the level's own scene under the name of a variant that
  // was never built is how an author reviews the wrong room. A variant the
  // band merely prefers is different - a level that ships none is played by
  // every band as it was authored.
  if (variant != null && !playing) {
    stderr.writeln('${variantFile!.path} not found; run build first');
    exit(1);
  }
  final catalogFile = playing ? variantFile : File('${dir.path}/scene.json');
  if (!catalogFile.existsSync()) {
    stderr.writeln('${catalogFile.path} not found; run build first');
    exit(1);
  }
  final json =
      jsonDecode(catalogFile.readAsStringSync()) as Map<String, dynamic>;
  if (!PropCatalog.isCatalog(json)) {
    // A hand-placed level has one layout and it is already on disk.
    stdout.write(catalogFile.readAsStringSync());
    return;
  }

  final catalog = PropCatalog.fromJson(json);
  final meta = SceneMeta.fromJsonString(
    File('${dir.path}/${catalog.metaFile}').readAsStringSync(),
  );
  final layout = layoutScene(
    catalog: catalog,
    meta: meta,
    profile: band.profile,
    seed: seed ?? Random().nextInt(1 << 32),
  );
  if (!layout.isComplete) {
    stderr.writeln(
      'warning: placed ${layout.finds.length} of ${layout.requested} '
      'objects - the room ran out of legal spots',
    );
  }

  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'sceneId': catalog.sceneId,
      'name': catalog.name,
      'background': catalog.background,
      'seed': layout.seed,
      'band': band.id,
      if (playing) 'variant': chosen,
      'size': {'w': catalog.sceneWidth, 'h': catalog.sceneHeight},
      'objects': [
        for (final placement in layout.placements)
          {
            'id': placement.id,
            'label': placement.prop.label,
            'sprite': placement.prop.sprite,
            'region': placement.regionId,
            'place': placement.place,
            'pos': [_r(placement.x), _r(placement.y)],
            'size': [_r(placement.width), _r(placement.height)],
            'rotation': _r(placement.rotation),
            'polygon': [
              for (final point in placement.polygon)
                [_r(point[0]), _r(point[1])],
            ],
            if (placement.clip != null)
              'clip': [
                _r(placement.clip!.x0),
                _r(placement.clip!.y0),
                _r(placement.clip!.x1),
                _r(placement.clip!.y1),
              ],
            if (!placement.findable) 'findable': false,
          },
      ],
    }),
  );
}

double _r(double value) => double.parse(value.toStringAsFixed(5));
