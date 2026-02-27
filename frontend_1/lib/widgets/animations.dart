// lib/widgets/animations.dart
// Reusable animation widgets for Tracely platform

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Fade + slide-up entrance animation
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double offsetY;
  final Curve curve;

  const FadeSlideIn({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.delay = Duration.zero,
    this.offsetY = 30,
    this.curve = Curves.easeOutCubic,
  }) : super(key: key);

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _controller, curve: widget.curve);
    _offset = Tween<Offset>(
      begin: Offset(0, widget.offsetY),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: _offset.value,
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// Staggered list — children appear one after another
class StaggeredList extends StatelessWidget {
  final List<Widget> children;
  final Duration itemDelay;
  final Duration itemDuration;
  final double offsetY;
  final Axis direction;

  const StaggeredList({
    Key? key,
    required this.children,
    this.itemDelay = const Duration(milliseconds: 60),
    this.itemDuration = const Duration(milliseconds: 450),
    this.offsetY = 20,
    this.direction = Axis.vertical,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(children.length, (index) {
        return FadeSlideIn(
          delay: Duration(milliseconds: itemDelay.inMilliseconds * index),
          duration: itemDuration,
          offsetY: offsetY,
          child: children[index],
        );
      }),
    );
  }
}

/// Animated counter — smooth number counting effect
class AnimatedCounter extends StatefulWidget {
  final int value;
  final Duration duration;
  final TextStyle? style;
  final String prefix;
  final String suffix;

  const AnimatedCounter({
    Key? key,
    required this.value,
    this.duration = const Duration(milliseconds: 1200),
    this.style,
    this.prefix = '',
    this.suffix = '',
  }) : super(key: key);

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(
      begin: 0,
      end: widget.value.toDouble(),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = oldWidget.value;
      _animation = Tween<double>(
        begin: _previousValue.toDouble(),
        end: widget.value.toDouble(),
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          '${widget.prefix}${_animation.value.round()}${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}

/// Shimmer loading skeleton placeholder
class ShimmerBlock extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBlock({
    Key? key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 8,
  }) : super(key: key);

  @override
  State<ShimmerBlock> createState() => _ShimmerBlockState();
}

class _ShimmerBlockState extends State<ShimmerBlock>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + 3 * _controller.value, 0),
              end: Alignment(-0.5 + 3 * _controller.value, 0),
              colors: [
                Colors.grey.shade200,
                Colors.grey.shade100,
                Colors.grey.shade200,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Shimmer card — full card-sized shimmer skeleton
class ShimmerCard extends StatelessWidget {
  final double? height;

  const ShimmerCard({Key? key, this.height}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBlock(height: 14, width: 100, borderRadius: 4),
          const SizedBox(height: 12),
          ShimmerBlock(height: 28, width: 60, borderRadius: 4),
          const SizedBox(height: 8),
          ShimmerBlock(height: 10, width: 80, borderRadius: 4),
        ],
      ),
    );
  }
}

/// Hover scale card — lifts and glows on mouse hover
class HoverScaleCard extends StatefulWidget {
  final Widget child;
  final double hoverScale;
  final double hoverElevation;
  final Duration duration;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const HoverScaleCard({
    Key? key,
    required this.child,
    this.hoverScale = 1.02,
    this.hoverElevation = 8,
    this.duration = const Duration(milliseconds: 200),
    this.onTap,
    this.borderRadius,
  }) : super(key: key);

  @override
  State<HoverScaleCard> createState() => _HoverScaleCardState();
}

class _HoverScaleCardState extends State<HoverScaleCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: widget.duration,
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()
            ..scale(_isHovered ? widget.hoverScale : 1.0),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_isHovered ? 0.12 : 0.04),
                blurRadius: _isHovered ? widget.hoverElevation : 2,
                offset: Offset(0, _isHovered ? 4 : 1),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Animated gradient background
class GradientBackground extends StatefulWidget {
  final Widget child;
  final List<Color>? colors;
  final Duration duration;

  const GradientBackground({
    Key? key,
    required this.child,
    this.colors,
    this.duration = const Duration(seconds: 6),
  }) : super(key: key);

  @override
  State<GradientBackground> createState() => _GradientBackgroundState();
}

class _GradientBackgroundState extends State<GradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors ??
        [
          const Color(0xFFFF6B2C).withOpacity(0.05),
          const Color(0xFF7C3AED).withOpacity(0.05),
          const Color(0xFF10B981).withOpacity(0.03),
        ];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(
                math.sin(t * math.pi * 2) * 0.5,
                math.cos(t * math.pi * 2) * 0.3,
              ),
              radius: 1.2 + t * 0.3,
              colors: colors,
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// Pulse animation widget — breathe/pulse effect
class PulseWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double minScale;
  final double maxScale;

  const PulseWidget({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
    this.minScale = 0.95,
    this.maxScale = 1.05,
  }) : super(key: key);

  @override
  State<PulseWidget> createState() => _PulseWidgetState();
}

class _PulseWidgetState extends State<PulseWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: widget.minScale, end: widget.maxScale)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: widget.child,
    );
  }
}

/// Typing text animation — types out text character by character
class TypingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration charDuration;
  final VoidCallback? onComplete;

  const TypingText({
    Key? key,
    required this.text,
    this.style,
    this.charDuration = const Duration(milliseconds: 40),
    this.onComplete,
  }) : super(key: key);

  @override
  State<TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<TypingText> {
  String _displayed = '';
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _typeNext();
  }

  void _typeNext() {
    if (_index < widget.text.length) {
      Future.delayed(widget.charDuration, () {
        if (mounted) {
          setState(() {
            _index++;
            _displayed = widget.text.substring(0, _index);
          });
          _typeNext();
        }
      });
    } else {
      widget.onComplete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(_displayed, style: widget.style);
  }
}

/// Scroll-triggered animation — animates when widget scrolls into view
class ScrollReveal extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double offsetY;

  const ScrollReveal({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.delay = Duration.zero,
    this.offsetY = 40,
  }) : super(key: key);

  @override
  State<ScrollReveal> createState() => _ScrollRevealState();
}

class _ScrollRevealState extends State<ScrollReveal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _offset = Tween<Offset>(
      begin: Offset(0, widget.offsetY),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onVisibilityChanged(bool visible) {
    if (visible && !_hasAnimated) {
      _hasAnimated = true;
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use a LayoutBuilder to detect when visible
    return LayoutBuilder(
      builder: (context, constraints) {
        // Trigger animation when built (visible in layout)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _onVisibilityChanged(true);
        });

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacity.value,
              child: Transform.translate(
                offset: _offset.value,
                child: widget.child,
              ),
            );
          },
        );
      },
    );
  }
}
