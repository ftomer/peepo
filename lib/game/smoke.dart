import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// The smoke is the first thing seen every time a level opens, so it is tinted
/// to the app's own ground rather than to candle smoke: it has to look like
/// the screen it clears off, not like a different game's atmosphere.
const _fogColor = PeepoColors.panel;
const _puffColor = PeepoColors.dimSky;
const _sparkColor = PeepoColors.sunny;

/// A single blurred smoke blob. Positions and radii are normalized to the
/// paint box (radius against its shortest side) so the cloud looks the same
/// on any screen.
class _Puff {
  const _Puff({
    required this.origin,
    required this.radius,
    required this.drift,
    required this.phase,
    required this.wobble,
    required this.alpha,
  });

  final Offset origin;
  final double radius;

  /// Where the puff travels as the cloud dissipates, in normalized units.
  final Offset drift;

  /// 0..1 stagger so puffs do not all clear on the same frame.
  final double phase;

  /// Amplitude of the idle churn drift.
  final Offset wobble;
  final double alpha;
}

class _Spark {
  const _Spark({
    required this.origin,
    required this.radius,
    required this.rise,
    required this.phase,
  });

  final Offset origin;
  final double radius;
  final double rise;
  final double phase;
}

/// Fixed layout, generated once - a stable cloud beats a per-frame random one.
final List<_Puff> _puffs = _buildPuffs();
final List<_Spark> _sparks = _buildSparks();

List<_Puff> _buildPuffs() {
  final random = math.Random(20260822);
  return [
    // Two rows of overlapping blobs, oversized past the edges so the box is
    // fully covered at rest.
    for (var row = 0; row < 4; row++)
      for (var col = 0; col < 6; col++)
        _Puff(
          origin: Offset(
            -0.1 + col * 0.24 + random.nextDouble() * 0.12,
            -0.05 + row * 0.34 + random.nextDouble() * 0.14,
          ),
          radius: 0.21 + random.nextDouble() * 0.15,
          drift: Offset(
            (random.nextDouble() - 0.5) * 0.5,
            -0.25 - random.nextDouble() * 0.5,
          ),
          phase: random.nextDouble(),
          wobble: Offset(
            0.012 + random.nextDouble() * 0.02,
            0.008 + random.nextDouble() * 0.014,
          ),
          alpha: 0.62 + random.nextDouble() * 0.3,
        ),
  ];
}

List<_Spark> _buildSparks() {
  final random = math.Random(1789);
  return [
    for (var i = 0; i < 26; i++)
      _Spark(
        origin: Offset(random.nextDouble(), 0.15 + random.nextDouble() * 0.8),
        radius: 0.002 + random.nextDouble() * 0.004,
        rise: 0.12 + random.nextDouble() * 0.3,
        phase: random.nextDouble() * 0.5,
      ),
  ];
}

/// A cloud of magical smoke covering its box.
///
/// [clear] drives the reveal: 0 is an opaque cloud, 1 is fully dissipated.
/// The cloud keeps churning on its own while it is on screen.
class SmokeCloud extends StatefulWidget {
  const SmokeCloud({super.key, required this.clear});

  final double clear;

  @override
  State<SmokeCloud> createState() => _SmokeCloudState();
}

class _SmokeCloudState extends State<SmokeCloud>
    with SingleTickerProviderStateMixin {
  late final AnimationController _churn = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat();

  @override
  void dispose() {
    _churn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _churn,
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: _SmokePainter(churn: _churn.value, clear: widget.clear),
          ),
        ),
      ),
    );
  }
}

class _SmokePainter extends CustomPainter {
  _SmokePainter({required this.churn, required this.clear});

  /// 0..1 looping turbulence phase.
  final double churn;

  /// 0 = opaque cloud, 1 = gone.
  final double clear;

  @override
  void paint(Canvas canvas, Size size) {
    if (clear >= 1) return;
    final shortest = size.shortestSide;
    final eased = Curves.easeInCubic.transform(clear);

    // Base fog: hides the scene outright, then thins out well before the
    // puffs finish drifting away.
    final fog = (1 - clear * 1.9).clamp(0.0, 1.0);
    if (fog > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = _fogColor.withValues(alpha: fog),
      );
    }

    for (final puff in _puffs) {
      // Each puff clears on its own schedule so the cloud tears apart
      // unevenly instead of fading as one sheet.
      final start = puff.phase * 0.35;
      final local = ((clear - start) / (1 - start)).clamp(0.0, 1.0);
      final alpha = puff.alpha * (1 - Curves.easeInQuad.transform(local));
      if (alpha <= 0.01) continue;

      final turn = churn * 2 * math.pi;
      final swirl = Offset(
        math.sin(turn + puff.phase * 6.3) * puff.wobble.dx,
        math.cos(turn * 0.7 + puff.phase * 6.3) * puff.wobble.dy,
      );
      final center = Offset(
        (puff.origin.dx + swirl.dx + puff.drift.dx * eased) * size.width,
        (puff.origin.dy + swirl.dy + puff.drift.dy * eased) * size.height,
      );
      final radius = puff.radius * shortest * (1 + 1.5 * eased);

      // A radial falloff, not a blurred circle: same soft edge at a fraction
      // of the GPU cost, which matters with two dozen of these per frame.
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              _puffColor.withValues(alpha: alpha),
              _puffColor.withValues(alpha: alpha * 0.75),
              _puffColor.withValues(alpha: 0),
            ],
            stops: const [0, 0.45, 1],
          ).createShader(rect),
      );
    }

    // Embers riding the smoke as it lifts.
    for (final spark in _sparks) {
      final local = ((clear - spark.phase) / (0.75 - spark.phase * 0.5)).clamp(
        0.0,
        1.0,
      );
      if (local <= 0 || local >= 1) continue;
      final alpha = math.sin(local * math.pi);
      final radius = spark.radius * shortest;
      final center = Offset(
        (spark.origin.dx +
                math.sin(churn * 2 * math.pi + spark.phase * 9) * 0.01) *
            size.width,
        (spark.origin.dy - spark.rise * local) * size.height,
      );
      canvas.drawCircle(
        center,
        radius * 3.5,
        Paint()
          ..shader = RadialGradient(
            colors: [
              _sparkColor.withValues(alpha: alpha * 0.45),
              _sparkColor.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius * 3.5)),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = _sparkColor.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_SmokePainter old) =>
      old.churn != churn || old.clear != clear;
}
