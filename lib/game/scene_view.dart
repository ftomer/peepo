import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/scene.dart';
import '../theme.dart';

/// Renders the scene inside an InteractiveViewer and reports taps in
/// normalized scene coordinates.
///
/// The scene is laid out cover-style: it always fills the viewport on both
/// axes, whatever the window or device aspect ratio is, and whatever spills
/// over is reachable by dragging. Pinch scales up to [_maxZoom] on top of
/// that, and dragging pans within the scene at any zoom level.
///
/// No double-tap gesture here on purpose: a double-tap recognizer would make
/// every single tap wait out the double-tap timeout, and a hidden object game
/// lives on instant tap feedback.
///
/// The GestureDetector lives inside the InteractiveViewer's child, so
/// tap localPosition arrives already in scene space - no manual matrix
/// inversion needed.
class SceneView extends StatefulWidget {
  const SceneView({
    super.key,
    required this.scene,
    required this.foundIds,
    required this.onSceneTap,
    this.hintTarget,
    this.missMarker,
    this.spriteOpacity = 1.0,
  });

  static const double _maxZoom = 5;

  final GameScene scene;
  final Set<String> foundIds;
  final ValueChanged<Offset> onSceneTap;
  final SceneObject? hintTarget;
  final Offset? missMarker;

  /// How solid the finds are drawn - see [DifficultyProfile.blendOpacity].
  /// The older bands play a picture whose finds the room shows through.
  final double spriteOpacity;

  @override
  State<SceneView> createState() => _SceneViewState();
}

class _SceneViewState extends State<SceneView> {
  /// Held only to open the room in the middle of itself. Everything after that
  /// is the player's: the controller is never written again while a size
  /// lasts, so a pan or a pinch is not undone by a rebuild.
  final TransformationController _view = TransformationController();

  /// The layout the current view was centred for.
  Size? _centredFor;

  @override
  void dispose() {
    _view.dispose();
    super.dispose();
  }

  /// Puts the middle of the room in the middle of the screen.
  ///
  /// The scene is drawn cover-style, so on a phone a 4:3 room overflows a
  /// 2.16:1 screen by about a third of its height. Left alone an
  /// InteractiveViewer opens at the top left of its child, which on the cabin
  /// is the ceiling and on the meadow is the sky - the room's own floor, where
  /// half the finds are, starts off screen and has to be dragged into view
  /// before the game can begin.
  ///
  /// Set after the frame rather than during it: the value is read by the
  /// InteractiveViewer being built right now, and writing it here would be a
  /// notify in the middle of a build. The player never sees the uncentred
  /// frame - a level is behind the smoke until it is loaded, and a resize
  /// settles inside one frame.
  void _centre(Size viewport, Size renderSize) {
    if (_centredFor == viewport) return;
    _centredFor = viewport;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _view.value = Matrix4.identity()
        ..translateByDouble(
          -(renderSize.width - viewport.width) / 2,
          -(renderSize.height - viewport.height) / 2,
          0,
          1,
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scene = widget.scene;
    final foundIds = widget.foundIds;
    final hintTarget = widget.hintTarget;
    final missMarker = widget.missMarker;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Cover fit: the scene fills the viewport on both axes, so there are
        // never letterbox bars; the overflow is reachable by panning.
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        final aspect = scene.size.aspectRatio;
        var renderSize = Size(viewport.width, viewport.width / aspect);
        if (renderSize.height < viewport.height) {
          renderSize = Size(viewport.height * aspect, viewport.height);
        }
        _centre(viewport, renderSize);

        return InteractiveViewer(
          constrained: false,
          minScale: 1,
          maxScale: SceneView._maxZoom,
          clipBehavior: Clip.hardEdge,
          transformationController: _view,
          child: SizedBox(
            width: renderSize.width,
            height: renderSize.height,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final normalized = Offset(
                  details.localPosition.dx / renderSize.width,
                  details.localPosition.dy / renderSize.height,
                );
                widget.onSceneTap(normalized);
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      scene.background,
                      fit: BoxFit.fill,
                      // High quality keeps the artwork clean when a pinch
                      // scales it past 1:1.
                      filterQuality: FilterQuality.high,
                      isAntiAlias: true,
                    ),
                  ),
                  for (final object in scene.objects)
                    _SpritePosition(
                      object: object,
                      renderSize: renderSize,
                      unclipped: foundIds.contains(object.id),
                      child: _FindableSprite(
                        object: object,
                        found: foundIds.contains(object.id),
                        opacity: widget.spriteOpacity,
                      ),
                    ),
                  if (hintTarget != null)
                    _HintPulse(target: hintTarget, renderSize: renderSize),
                  if (missMarker != null)
                    _MissRipple(center: missMarker, renderSize: renderSize),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Positions a sprite box by its normalized centre and rotates it in place.
class _SpritePosition extends StatelessWidget {
  const _SpritePosition({
    required this.object,
    required this.renderSize,
    required this.child,
    this.unclipped = false,
  });

  final SceneObject object;
  final Size renderSize;
  final Widget child;

  /// Once found, the prop steps out from behind the scenery: the celebration
  /// grows past the sprite box, and half a burst reads as a glitch.
  final bool unclipped;

  @override
  Widget build(BuildContext context) {
    final width = object.size.width * renderSize.width;
    final height = object.size.height * renderSize.height;
    final left = object.pos.dx * renderSize.width - width / 2;
    final top = object.pos.dy * renderSize.height - height / 2;
    final rotated = object.rotation == 0
        ? child
        : Transform.rotate(
            angle: object.rotation * math.pi / 180,
            child: child,
          );
    // A resting prop is grounded by a soft contact shadow, which is most of
    // what stops it reading as pasted onto the backdrop. The shadow sits in
    // scene space, outside the rotation - the ground does not tilt with the
    // prop - and inside the occlusion clip, so a tucked-away prop's shadow is
    // tucked away with it. Sprites bake no shadow of their own by design (see
    // art-direction.md), because this one would double it.
    //
    // It is centred on the prop's foot rather than on the bottom of the sprite
    // box, because that is where the placer put the prop down: a xylophone
    // turned thirty degrees has an empty triangle under one end, and a shadow
    // drawn across the box floats in it.
    final shadowHeight = height * 0.20;
    final shadowTop =
        height / 2 + object.foot * renderSize.height - shadowHeight / 2;
    final placed = !object.grounded
        ? rotated
        : Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: width * 0.06,
                right: width * 0.06,
                top: shadowTop,
                height: shadowHeight,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: unclipped ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 350),
                    child: const CustomPaint(painter: _ContactShadowPainter()),
                  ),
                ),
              ),
              Positioned.fill(child: rotated),
            ],
          );
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      // A prop tucked behind the scenery is drawn short of it. The backdrop
      // already holds what is doing the covering, so not drawing the covered
      // part is the whole of the effect - no foreground layer, no second
      // cut-out of the artwork.
      //
      // The clip is in scene space and so goes outside the rotation, which is
      // also what keeps it honest against the tap polygon.
      //
      // Once found, the prop steps out from behind the scenery, and that is
      // done by turning the clip off rather than by dropping the [ClipRect]:
      // taking the widget away changes the shape of the tree at that slot, so
      // the sprite's own animations are rebuilt from scratch and the find
      // plays with no fade and no scale at all.
      child: object.clip == null
          ? placed
          : ClipRect(
              clipper: _SceneClip(
                rect: object.clip!,
                renderSize: renderSize,
                origin: Offset(left, top),
              ),
              clipBehavior: unclipped ? Clip.none : Clip.hardEdge,
              child: placed,
            ),
    );
  }
}

/// The soft ellipse a grounded prop stands on: a single blurred shadow tone,
/// matching the flat one shadow tone the backdrops themselves are drawn with.
class _ContactShadowPainter extends CustomPainter {
  const _ContactShadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()
      ..color = const Color(0x55222222)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.height * 0.28);
    canvas.drawOval(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_ContactShadowPainter old) => false;
}

/// Clips a sprite to the part of it the scenery in front leaves showing,
/// converting the scene-space rectangle into the sprite box's own coordinates.
class _SceneClip extends CustomClipper<Rect> {
  const _SceneClip({
    required this.rect,
    required this.renderSize,
    required this.origin,
  });

  /// Visible part, in normalized scene coordinates.
  final Rect rect;

  final Size renderSize;

  /// Top-left of the sprite box on screen, which the clip is measured from.
  final Offset origin;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
    rect.left * renderSize.width - origin.dx,
    rect.top * renderSize.height - origin.dy,
    rect.right * renderSize.width - origin.dx,
    rect.bottom * renderSize.height - origin.dy,
  );

  @override
  bool shouldReclip(_SceneClip old) =>
      old.rect != rect || old.renderSize != renderSize || old.origin != origin;
}

/// A findable object: fades and scales away when found, with a sparkle.
class _FindableSprite extends StatelessWidget {
  const _FindableSprite({
    required this.object,
    required this.found,
    this.opacity = 1.0,
  });

  final SceneObject object;
  final bool found;

  /// How solid the find is drawn before it is found. A find always leaves at
  /// full transparency, whatever it was drawn at.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: AnimatedScale(
            scale: found ? 1.6 : 1.0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: found ? 0.0 : opacity,
              duration: const Duration(milliseconds: 350),
              child: Image.asset(
                object.sprite,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                isAntiAlias: true,
              ),
            ),
          ),
        ),
        if (found)
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              builder: (context, t, _) {
                return Opacity(
                  opacity: 1.0 - t,
                  child: Transform.scale(
                    scale: 0.5 + t * 1.5,
                    child: const FittedBox(child: Text('✨')),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Pulsing ring drawn at the hint target's hintCenter, sized to the object.
class _HintPulse extends StatefulWidget {
  const _HintPulse({required this.target, required this.renderSize});

  final SceneObject target;
  final Size renderSize;

  @override
  State<_HintPulse> createState() => _HintPulseState();
}

class _HintPulseState extends State<_HintPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = Offset(
      widget.target.hintCenter.dx * widget.renderSize.width,
      widget.target.hintCenter.dy * widget.renderSize.height,
    );
    final maxRadius = math.max(
      widget.renderSize.shortestSide * 0.06,
      math.max(
            widget.target.size.width * widget.renderSize.width,
            widget.target.size.height * widget.renderSize.height,
          ) *
          0.85,
    );
    return Positioned(
      left: center.dx - maxRadius,
      top: center.dy - maxRadius,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            return SizedBox(
              width: maxRadius * 2,
              height: maxRadius * 2,
              child: CustomPaint(
                painter: _HintRingPainter(
                  radius: maxRadius * (0.4 + 0.6 * t),
                  alpha: 1.0 - t,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The ring itself: a dark line either side of a bright one.
///
/// A single hue cannot be trusted here. The ring is drawn over whatever the
/// level's art happens to be, and [PeepoColors.sunny] on the pirate cabin's
/// tan planks is very nearly the same colour - a child is shown a hint they
/// cannot see. So the ring borrows the rule the art itself uses: a thick dark
/// outline around a bright fill, which leaves an edge on any backdrop, light
/// or dark, warm or cool.
class _HintRingPainter extends CustomPainter {
  const _HintRingPainter({required this.radius, required this.alpha});

  final double radius;

  /// Fades as the pulse opens out.
  final double alpha;

  static const _bright = 4.0;
  static const _dark = 9.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (radius <= 0 || alpha <= 0) return;
    final center = size.center(Offset.zero);
    void ring(Color color, double width) => canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color.withValues(alpha: alpha),
    );
    ring(PeepoColors.outline, _dark);
    ring(PeepoColors.sunny, _bright);
  }

  @override
  bool shouldRepaint(_HintRingPainter old) =>
      old.radius != radius || old.alpha != alpha;
}

/// Brief red ripple where a miss tap landed.
class _MissRipple extends StatelessWidget {
  const _MissRipple({required this.center, required this.renderSize});

  final Offset center;
  final Size renderSize;

  @override
  Widget build(BuildContext context) {
    final position = Offset(
      center.dx * renderSize.width,
      center.dy * renderSize.height,
    );
    final radius = renderSize.shortestSide * 0.04;
    return Positioned(
      left: position.dx - radius,
      top: position.dy - radius,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          key: ValueKey(center),
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 450),
          builder: (context, t, _) {
            return Opacity(
              opacity: 1.0 - t,
              child: Container(
                width: radius * 2 * (0.5 + t),
                height: radius * 2 * (0.5 + t),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: PeepoColors.berry, width: 3),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
