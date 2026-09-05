import 'package:flutter/material.dart';

/// Every colour the game paints, in one place.
///
/// The values are sampled from the shipped art rather than invented: the app
/// icon in `rawimages/app_icon/master.png` and Peepo himself in
/// `assets/peepo/`. That is the whole point of this file. Peepo is the first
/// thing a parent sees on a store shelf and the only branding that happens
/// before install, so the chrome around the game has to be the same set of
/// colours as the owl on the icon - see [docs/branding.md].
///
/// Nothing in `lib/` should hold a `Color(0x...)` literal. A hue that lives in
/// one widget is a hue that drifts.
abstract final class PeepoColors {
  // --- Sampled straight off the art -----------------------------------------

  /// Peepo's body. Every interactive and selected thing in the game.
  static const teal = Color(0xFF44BCB9);

  /// The shaded side of him. Pressed states, and the "found" mark.
  static const tealDeep = Color(0xFF268587);

  /// The app icon's field, and the beak. Reward and attention: the hint
  /// pulse, the completion seal, the stars, the primary call to action.
  ///
  /// Never a whole screen. A full yellow ground behind a screenful of bright
  /// artwork leaves the art nothing to sit against.
  static const sunny = Color(0xFFFDD84C);

  /// The deep half of the beak, used as the low stop of the gold gradients.
  static const beak = Color(0xFFEDAF13);

  /// His belly.
  static const cream = Color(0xFFF7E8C7);

  /// The navy every asset in the game is outlined in.
  ///
  /// Nothing in the UI paints with it - it is the anchor the two dark
  /// surfaces below are derived from, [ground] by dropping it and [outline]
  /// by taking it further under that.
  static const outlineArt = Color(0xFF183C6C);

  /// The magnifying glass. Alarming things only - a miss, or wiping progress.
  static const berry = Color(0xFFF24C50);

  /// His hand in the icon. Only the confetti uses it.
  static const sky = Color(0xFF529BD0);

  // --- Derived surfaces -----------------------------------------------------

  /// The app's ground: [outlineArt] dropped far enough that a bright 4:3
  /// scene thumbnail still jumps off it.
  static const ground = Color(0xFF12294A);

  /// Cards, sheets, the object list bar, the settings panels.
  static const panel = Color(0xFF1B3A64);

  /// A panel that is chosen or raised above its neighbours.
  static const panelRaised = Color(0xFF26507F);

  /// Secondary text: object counts, captions, a chip not yet found.
  static const dimSky = Color(0xFFA6BEDC);

  /// Text and icons too quiet to be [dimSky] - a spent hint, a disabled star.
  static const faint = Color(0xFF5E7CA6);

  // --- Rules the palette imposes -------------------------------------------

  /// What goes on top of [teal] or [sunny].
  ///
  /// Cream on teal is 4.4:1 and fails AA; [outline] on teal is 4.8:1 and on
  /// sunny 7.9:1. So a coloured button always carries dark text, never light.
  static const onAccent = outline;

  /// [berry] is only 4.1:1 on [ground], so it may carry a shape or a ring but
  /// not a word. Where the alarm has to be text, it is this instead.
  static const berryText = Color(0xFFFF7A78);

  /// The thick dark line the art is drawn with, taken below the ground.
  ///
  /// [outlineArt] is the darkest value in a *bright* frame, which is the only
  /// kind of frame the art ever sits in. On this app's navy ground it is
  /// barely darker than a panel, and the line simply disappears. So the UI
  /// line is that same hue pushed under the ground, and the rule that falls
  /// out of it is: [outline] wherever the surround is bright - a card over a
  /// scene thumbnail, a seal on gold, a label on teal - and [rim] or [teal]
  /// wherever one dark surface meets another, where a dark line says nothing.
  static const outline = Color(0xFF0B1D38);

  /// The seam between two dark surfaces: a panel against the ground, a badge
  /// against a panel. Lighter than both of them, because a dark line drawn on
  /// something dark is not a line.
  static const rim = Color(0xFF2C5A8F);

  static const strokeWidth = 2.0;
  static Border get stroke => Border.all(color: outline, width: strokeWidth);

  /// A scrim over artwork, tinted to the ground rather than to black.
  ///
  /// The scenes are daylit and cool, so a warm or neutral black over them
  /// reads as dirt on the picture instead of shade.
  static const scrimClear = Color(0x0009162C);
  static const scrim = Color(0xEB09162C);
  static const scrimSoft = Color(0xB309162C);

  /// Cast shadow under a raised thing. Neutral black rather than a tinted
  /// one: it falls on artwork of every hue, and a navy shadow on a warm scene
  /// reads as a stain rather than as depth.
  static const shadow = Color(0xAA000000);
  static const shadowSoft = Color(0x73000000);

  /// The gold on the completion seal and the stars, low stop last.
  static const sealGradient = [sunny, beak];

  /// Confetti, one burst of the whole palette.
  static const confetti = [teal, sunny, berry, sky, cream, beak];
}

/// The Material baseline the widgets that are not hand-painted fall back to.
///
/// Spelled out rather than grown from a seed: `ColorScheme.fromSeed` invents
/// its own tints, and the ones it invented from the old brass seed were what
/// put antique gold on dialogs and buttons nobody had styled.
ThemeData peepoTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: PeepoColors.teal,
    onPrimary: PeepoColors.onAccent,
    primaryContainer: PeepoColors.tealDeep,
    onPrimaryContainer: PeepoColors.cream,
    secondary: PeepoColors.sunny,
    onSecondary: PeepoColors.onAccent,
    secondaryContainer: PeepoColors.beak,
    onSecondaryContainer: PeepoColors.outline,
    tertiary: PeepoColors.sky,
    onTertiary: PeepoColors.onAccent,
    error: PeepoColors.berry,
    onError: PeepoColors.onAccent,
    surface: PeepoColors.ground,
    onSurface: PeepoColors.cream,
    surfaceContainerHighest: PeepoColors.panelRaised,
    onSurfaceVariant: PeepoColors.dimSky,
    outline: PeepoColors.outline,
    outlineVariant: PeepoColors.faint,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: PeepoColors.ground,
    canvasColor: PeepoColors.ground,
    dialogTheme: const DialogThemeData(backgroundColor: PeepoColors.panel),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: PeepoColors.teal,
    ),
  );
}
