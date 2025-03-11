import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A utility class to handle task completion effects
class CompletionEffects {
  /// Plays haptic feedback for task completion
  static void playTaskCompletionFeedback() {
    HapticFeedback.mediumImpact();
  }
  
  /// Simple widget wrapper for task completion without animations
  static Widget buildTaskCompletionAnimation({
    required Widget child,
    required bool isCompleted,
    required AnimationController controller,
  }) {
    return child;
  }
  
  /// Simple checkmark widget without animations
  static Widget buildCheckmarkAnimation({
    required AnimationController controller,
    required Color color,
    double size = 16,
  }) {
    return SizedBox();
  }
}
