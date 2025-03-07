import 'package:cloud_functions/cloud_functions.dart';

class FeedbackService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<void> sendFeedback({
    required String name,
    required String email,
    required String message,
  }) async {
    try {
      final callable = _functions.httpsCallable('sendFeedback');
      await callable.call({
        'name': name,
        'email': email,
        'message': message,
      });
    } catch (e) {
      throw Exception('Failed to send feedback: ${e.toString()}');
    }
  }
}
