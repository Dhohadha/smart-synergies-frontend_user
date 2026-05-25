import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/app_colors.dart';

class AeratorIcon extends StatelessWidget {
  final bool isOn;
  final Color color;
  final double size;
  final double padding;

  final bool useSolidGradient;

  const AeratorIcon({
    super.key,
    required this.isOn,
    required this.color,
    this.size = 28,
    this.padding = 10,
    this.useSolidGradient = false,
  });

  @override
  Widget build(BuildContext context) {
    return _GlowWrapper(
      isOn: isOn,
      color: color,
      child: Container(
        width: size + (padding * 2),
        height: size + (padding * 2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: useSolidGradient
              ? const LinearGradient(colors: [AppColors.cyan, AppColors.blue])
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.25),
                    color.withValues(alpha: 0.05),
                  ],
                ),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
          boxShadow: useSolidGradient
              ? [
                  BoxShadow(
                      color: AppColors.cyan.withValues(alpha:  0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]
              : [],
        ),
        child: Center(
          child: Icon(
            Icons.hub_rounded,
            size: size,
            color: useSolidGradient ? Colors.white : color,
          )
              .animate(
                  onPlay: (controller) => controller.repeat(),
                  target: isOn ? 1 : 0)
              .rotate(duration: 4000.ms, curve: Curves.linear),
        ),
      ),
    );
  }
}

class _GlowWrapper extends StatefulWidget {
  final bool isOn;
  final Color color;
  final Widget child;
  const _GlowWrapper(
      {required this.isOn, required this.color, required this.child});

  @override
  State<_GlowWrapper> createState() => _GlowWrapperState();
}

class _GlowWrapperState extends State<_GlowWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    if (widget.isOn) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_GlowWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOn != oldWidget.isOn) {
      if (widget.isOn) {
        _ctrl.repeat(reverse: true);
      } else {
        _ctrl.stop();
        _ctrl.reset();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: widget.isOn
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.1 * _ctrl.value),
                      blurRadius: 15 * _ctrl.value,
                      spreadRadius: 5 * _ctrl.value,
                    )
                  ]
                : [],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
