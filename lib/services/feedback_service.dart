import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';

class FeedbackService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Replace these with your actual Google Form IDs
  final String _formId = '1FAIpQLSexample_form_id';
  final String _messageEntryId = '392264126';
  final String _nameEntryId = '340899659';
  final String _emailEntryId = '1836189635';

  Future<void> sendFeedback({
    required String message,
    String? name,
    String? email,
  }) async {
    try {
      // Check if user is logged in
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to send feedback.');
      }
      
      // Get user info if not provided
      final userEmail = email ?? user.email ?? '';
      final userName = name ?? user.displayName ?? '';
      
      // Encode parameters for URL
      final encodedMessage = Uri.encodeComponent(message);
      final encodedName = Uri.encodeComponent(userName);
      final encodedEmail = Uri.encodeComponent(userEmail);
      
      // Create Google Form URL with pre-filled data
      final url = 'https://docs.google.com/forms/d/e/1FAIpQLSe_zvqsoNTEUraWYzYcVEVt9kqHo219so6sAuHCoJT1SCQ-OA/viewform?usp=pp_url&entry.392264126=test&entry.1836189635=test&entry.340899659=test'
          'entry.$_messageEntryId=$encodedMessage&'
          'entry.$_nameEntryId=$encodedName&'
          'entry.$_emailEntryId=$encodedEmail&'
          'submit=Submit';
      
      if (kIsWeb) {
        // For web platform, open in a new tab
        await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
      } else {
        // For mobile platforms, we need to submit silently using HTTP
        // This is a workaround since direct form submission doesn't work well on mobile
        // Launch URL in hidden WebView
        final success = await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.inAppWebView,
          webViewConfiguration: const WebViewConfiguration(
            enableJavaScript: true,
            enableDomStorage: true,
          ),
        );
        
        if (!success) {
          throw Exception('Could not submit feedback form');
        }
        
        // Wait briefly to ensure form submission and then close the WebView
        await Future.delayed(const Duration(seconds: 2));
        if (!kIsWeb) {
          closeInAppWebView();
        }
      }
      
      return;
    } catch (e) {
      throw Exception('Failed to send feedback: ${e.toString()}');
    }
  }
}
