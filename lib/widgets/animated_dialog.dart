import 'package:flutter/material.dart';
import 'package:animations/animations.dart';

class AnimatedDialog extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;
  final Color? backgroundColor;
  
  const AnimatedDialog({
    super.key,
    required this.child,
    required this.animation,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return FadeScaleTransition(
      animation: animation,
      child: child,
    );
  }
}
