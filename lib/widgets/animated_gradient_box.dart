import 'package:flutter/material.dart';

class AnimatedGradientBox extends StatefulWidget {
  final Widget child;
  
  const AnimatedGradientBox({
    super.key,
    required this.child,
  });

  @override
  State<AnimatedGradientBox> createState() => _AnimatedGradientBoxState();
}

class _AnimatedGradientBoxState extends State<AnimatedGradientBox> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Alignment> _topAlignment;
  late Animation<Alignment> _bottomAlignment;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(reverse: true);

    _topAlignment = TweenSequence<Alignment>([
      TweenSequenceItem(
        weight: 1.0,
        tween: AlignmentTween(
          begin: const Alignment(-1.0, -1.0),
          end: const Alignment(1.0, -1.0),
        ),
      ),
    ]).animate(_controller);

    _bottomAlignment = TweenSequence<Alignment>([
      TweenSequenceItem(
        weight: 1.0,
        tween: AlignmentTween(
          begin: const Alignment(1.0, 1.0),
          end: const Alignment(-1.0, 1.0),
        ),
      ),
    ]).animate(_controller);
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
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: _topAlignment.value,
              end: _bottomAlignment.value,
              colors: [
                Theme.of(context).colorScheme.primary.withOpacity(0.1),
                Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                Theme.of(context).colorScheme.tertiary.withOpacity(0.1),
              ],
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}
