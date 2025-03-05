import 'package:flutter/material.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';

class SnackBarUtils {
  /// Shows an awesome snackbar with customizable content
  static void showAwesomeSnackBar({
    required BuildContext context, 
    required String title, 
    required String message, 
    ContentType contentType = ContentType.success,
    Duration duration = const Duration(seconds: 3),
  }) {
    final snackBar = SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      duration: duration,
      content: AwesomeSnackbarContent(
        title: title,
        message: message,
        contentType: contentType,
      ),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }
}
