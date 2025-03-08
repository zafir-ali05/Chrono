import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CompletionEffects {
  /// Plays a quick scale animation on a widget
  static Widget buildPulseAnimation({
    required Widget child,
    required AnimationController controller,
    required bool isCompleted,
    bool playOnComplete = true,
  }) {
    if ((playOnComplete && isCompleted) || (!playOnComplete && !isCompleted)) {
      controller.reset();
      controller.forward();
    }
    
    final Animation<double> pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    ));
    
    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: pulseAnimation.value,
          child: child,
        );
      },
      child: child,
    );
  }
  
  /// Adds a completion effect with ripple animation
  static Widget buildRippleEffect({
    required Widget child,
    required AnimationController controller,
    required Color color,
  }) {
    final Animation<double> rippleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeOut,
    ));
    
    return Stack(
      alignment: Alignment.center,
      children: [
        // Ripple effect
        AnimatedBuilder(
          animation: rippleAnimation,
          builder: (context, _) {
            return Opacity(
              opacity: 1.0 - rippleAnimation.value,
              child: Transform.scale(
                scale: 0.8 + (rippleAnimation.value * 0.7),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.3 * (1.0 - rippleAnimation.value)),
                  ),
                ),
              ),
            );
          },
        ),
        // Original widget
        child,
      ],
    );
  }
  
  /// Plays standard haptic feedback for completion
  static void playCompletionFeedback() {
    HapticFeedback.mediumImpact();
  }
  
  /// Creates a shimmer effect across a completed item
  static Widget buildShimmerEffect({
    required Widget child,
    required AnimationController controller,
    required bool isCompleted,
  }) {
    if (!isCompleted) {
      return child;
    }
    
    final Animation<double> shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    ));
    
    return Stack(
      children: [
        // Original widget
        child,
        // Shimmer overlay
        AnimatedBuilder(
          animation: shimmerAnimation,
          builder: (context, _) {
            return ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  begin: Alignment(shimmerAnimation.value - 1, 0.0),
                  end: Alignment(shimmerAnimation.value, 0.0),
                  colors: [
                    Colors.transparent,
                    Colors.white.withOpacity(0.5),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.srcATop,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.transparent,
              ),
            );
          },
        ),
      ],
    );
  }

  /// Creates a slide-and-fade animation specifically for task completion
  static Widget buildTaskCompletionAnimation({
    required Widget child,
    required AnimationController controller,
    required bool isCompleted,
    Axis direction = Axis.horizontal,
  }) {
    if (isCompleted) {
      controller.reset();
      controller.forward();
    }
    
    final slideDistance = direction == Axis.horizontal ? 0.2 : 0.1;
    
    final Animation<Offset> slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: direction == Axis.horizontal 
          ? const Offset(0.2, 0.0)  // Slide right
          : const Offset(0.0, 0.1),  // Slide down
    ).animate(CurvedAnimation(
      parent: controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));
    
    final Animation<double> fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.7,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));
    
    final Animation<double> scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.95), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    ));
    
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: fadeAnimation,
          child: SlideTransition(
            position: slideAnimation,
            child: Transform.scale(
              scale: scaleAnimation.value,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
  
  /// Creates a checkmark drawing animation
  static Widget buildCheckmarkAnimation({
    required AnimationController controller,
    required Color color,
    double size = 24.0,
  }) {
    final Animation<double> checkAnimation = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );
    
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: checkAnimation,
        builder: (context, _) {
          return CustomPaint(
            painter: _CheckmarkPainter(
              animation: checkAnimation,
              color: color,
              strokeWidth: 2.0,
            ),
          );
        },
      ),
    );
  }
  
  /// Plays a more subtle haptic feedback for task completion
  static void playTaskCompletionFeedback() {
    HapticFeedback.lightImpact();
  }

  /// Creates a sweep animation with glow effect for task completion
  static Widget buildSweepingCheckAnimation({
    required Widget child,
    required AnimationController controller,
    required bool isCompleted,
    Color? glowColor,
  }) {
    if (isCompleted) {
      controller.reset();
      controller.forward();
    }
    
    // Create a sweeping animation sequence
    final Animation<double> sweepAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 7),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 3),
    ]).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutQuart,
    ));
    
    // Create a scale animation for the bounce effect
    final Animation<double> scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.03), weight: 3),
      TweenSequenceItem(tween: Tween(begin: 1.03, end: 0.98), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.98, end: 1.0), weight: 2),
    ]).animate(CurvedAnimation(
      parent: controller,
      curve: const Interval(0.0, 0.8, curve: Curves.easeInOut),
    ));
    
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Stack(
          children: [
            // Glow effect when animation is playing
            if (controller.value > 0 && controller.value < 1.0)
              Positioned.fill(
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (glowColor ?? Colors.green).withOpacity(0.3 * controller.value),
                          blurRadius: 16 * controller.value,
                          spreadRadius: 4 * controller.value,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            
            // Scale effect
            Transform.scale(
              scale: scaleAnimation.value,
              child: child,
            ),
          ],
        );
      },
      child: child,
    );
  }
  
  /// Creates a custom circular progress animation for checkmarks
  static Widget buildCircularCheckmarkAnimation({
    required AnimationController controller,
    required Color color,
    double size = 24.0,
  }) {
    final Animation<double> progressAnimation = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );
    
    final Animation<double> checkAnimation = CurvedAnimation(
      parent: controller, 
      curve: const Interval(0.5, 1.0, curve: Curves.elasticOut),
    );
    
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _CircularCheckmarkPainter(
              progressAnimation: progressAnimation,
              checkAnimation: checkAnimation,
              color: color,
              strokeWidth: 2.0,
            ),
          );
        },
      ),
    );
  }
}

/// Custom painter for drawing the checkmark animation
class _CheckmarkPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;
  final double strokeWidth;
  
  _CheckmarkPainter({
    required this.animation,
    required this.color,
    this.strokeWidth = 2.0,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
      
    final path = Path();
    
    // Calculate checkmark points
    final startPoint = Offset(size.width * 0.2, size.height * 0.5);
    final midPoint = Offset(size.width * 0.4, size.height * 0.7);
    final endPoint = Offset(size.width * 0.8, size.height * 0.3);
    
    // First part of the checkmark (shorter line)
    if (animation.value <= 0.5) {
      final progress = animation.value / 0.5;
      final start = startPoint;
      final end = Offset.lerp(startPoint, midPoint, progress)!;
      
      path.moveTo(start.dx, start.dy);
      path.lineTo(end.dx, end.dy);
    } else {
      // Draw completed first segment
      path.moveTo(startPoint.dx, startPoint.dy);
      path.lineTo(midPoint.dx, midPoint.dy);
      
      // Second part of checkmark (longer line)
      final progress = (animation.value - 0.5) / 0.5;
      final start = midPoint;
      final end = Offset.lerp(midPoint, endPoint, progress)!;
      
      path.moveTo(start.dx, start.dy);
      path.lineTo(end.dx, end.dy);
    }
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(_CheckmarkPainter oldDelegate) => 
    animation.value != oldDelegate.animation.value ||
    color != oldDelegate.color ||
    strokeWidth != oldDelegate.strokeWidth;
}

/// Custom painter for drawing a circular progress animation with a checkmark
class _CircularCheckmarkPainter extends CustomPainter {
  final Animation<double> progressAnimation;
  final Animation<double> checkAnimation;
  final Color color;
  final double strokeWidth;
  
  _CircularCheckmarkPainter({
    required this.progressAnimation,
    required this.checkAnimation,
    required this.color,
    this.strokeWidth = 2.0,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
      
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth;
    
    // Draw the progress circle
    if (progressAnimation.value > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final startAngle = -90.0 * (3.14159 / 180);  // Start from the top (12 o'clock position)
      final sweepAngle = progressAnimation.value * 2 * 3.14159;  // Full circle is 2π
      
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
    }
    
    // Draw the checkmark when progress is at least 50% complete
    if (checkAnimation.value > 0) {
      final path = Path();
      
      // Calculate checkmark points
      final startPoint = Offset(size.width * 0.3, size.height * 0.5);
      final midPoint = Offset(size.width * 0.45, size.height * 0.65);
      final endPoint = Offset(size.width * 0.7, size.height * 0.35);
      
      // First part of the checkmark (shorter line)
      final midProgress = checkAnimation.value < 0.5 
          ? checkAnimation.value * 2 
          : 1.0;
          
      if (midProgress > 0) {
        final firstEnd = Offset.lerp(startPoint, midPoint, midProgress)!;
        path.moveTo(startPoint.dx, startPoint.dy);
        path.lineTo(firstEnd.dx, firstEnd.dy);
      }
      
      // Second part of checkmark (longer line)
      final secondProgress = checkAnimation.value > 0.5 
          ? (checkAnimation.value - 0.5) * 2 
          : 0.0;
          
      if (secondProgress > 0) {
        final secondEnd = Offset.lerp(midPoint, endPoint, secondProgress)!;
        path.moveTo(midPoint.dx, midPoint.dy);
        path.lineTo(secondEnd.dx, secondEnd.dy);
      }
      
      canvas.drawPath(path, paint);
    }
  }
  
  @override
  bool shouldRepaint(_CircularCheckmarkPainter oldDelegate) => 
    progressAnimation.value != oldDelegate.progressAnimation.value ||
    checkAnimation.value != oldDelegate.checkAnimation.value ||
    color != oldDelegate.color ||
    strokeWidth != oldDelegate.strokeWidth;
}
