import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tokens.dart';

class NeonBackdrop extends StatefulWidget {
  const NeonBackdrop({required this.child, super.key});
  final Widget child;

  @override
  State<NeonBackdrop> createState() => _NeonBackdropState();
}

class _NeonBackdropState extends State<NeonBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..forward();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, child) {
      final drift = math.sin(controller.value * math.pi) * 44;
      return Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: SvnlyColors.background),
          Positioned(
            top: -110 + drift,
            right: -90,
            child: _GlowOrb(
              color: SvnlyColors.electricBlue.withValues(alpha: .22),
              size: 280,
            ),
          ),
          Positioned(
            top: MediaQuery.sizeOf(context).height * .35,
            left: -130 - drift / 2,
            child: _GlowOrb(
              color: SvnlyColors.lime.withValues(alpha: .10),
              size: 230,
            ),
          ),
          Positioned(
            bottom: -130 - drift,
            left: -100,
            child: _GlowOrb(
              color: SvnlyColors.hotPink.withValues(alpha: .16),
              size: 310,
            ),
          ),
          child!,
        ],
      );
    },
    child: widget.child,
  );
}

class StickerTag extends StatelessWidget {
  const StickerTag({
    required this.label,
    this.color = SvnlyColors.lime,
    this.rotation = -.035,
    super.key,
  });
  final String label;
  final Color color;
  final double rotation;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: rotation,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w900,
          letterSpacing: .8,
        ),
      ),
    ),
  );
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 100, spreadRadius: 30)],
      ),
    ),
  );
}

class NeonBadge extends StatelessWidget {
  const NeonBadge({
    required this.label,
    this.color = SvnlyColors.lime,
    this.icon,
    super.key,
  });
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .14),
      border: Border.all(color: color.withValues(alpha: .75)),
      borderRadius: BorderRadius.circular(SvnlyRadius.pill),
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: .18), blurRadius: 16),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: .7,
          ),
        ),
      ],
    ),
  );
}

class Pulse extends StatefulWidget {
  const Pulse({required this.child, this.enabled = true, super.key});
  final Widget child;
  final bool enabled;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    lowerBound: 0,
    upperBound: 1,
  )..repeat(reverse: true);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    child: widget.child,
    builder: (context, child) => Transform.scale(
      scale: widget.enabled ? .98 + controller.value * .04 : 1,
      child: child,
    ),
  );
}

class GradientBorderCard extends StatelessWidget {
  const GradientBorderCard({
    required this.child,
    this.gradient = SvnlyGradients.social,
    this.padding = const EdgeInsets.all(1.4),
    super.key,
  });
  final Widget child;
  final Gradient gradient;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: gradient,
      borderRadius: BorderRadius.circular(SvnlyRadius.large),
      boxShadow: [
        BoxShadow(
          color: gradient.colors.first.withValues(alpha: .18),
          blurRadius: 28,
        ),
      ],
    ),
    child: Padding(
      padding: padding,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: SvnlyColors.deepNavy,
          borderRadius: BorderRadius.circular(SvnlyRadius.large - 1),
        ),
        child: child,
      ),
    ),
  );
}
