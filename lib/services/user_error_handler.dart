import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'api_service.dart';

/// Converts internal exceptions into short messages suitable for app users.
class UserErrorMessages {
  static String from(Object error, {String fallback = 'Something went wrong. Please try again.'}) {
    if (error is ApiException) {
      final message = error.message.trim();
      // Do not expose backend traces, SQL details, or local development hints.
      if (message.isEmpty ||
          message.contains('artisan serve') ||
          message.toLowerCase().contains('sqlstate') ||
          message.toLowerCase().contains('exception') ||
          message.contains('\n')) {
        return error.statusCode == 0
            ? 'Could not connect. Check your internet connection and try again.'
            : fallback;
      }
      return message;
    }
    if (error is TimeoutException) return 'The request took too long. Please try again.';
    return fallback;
  }
}

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Gives uncaught app errors a calm, user-facing surface while retaining
/// Flutter's normal diagnostics for developers.
void installUserErrorHandlers() {
  ErrorWidget.builder = (details) => const Material(
        color: Color(0xFFF4F5EF),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'This part of the page could not be displayed. Please go back and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF20372D)),
            ),
          ),
        ),
      );
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _showUnexpectedError();
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught application error: $error\n$stack');
    _showUnexpectedError();
    return true;
  };
}

void _showUnexpectedError() {
  final context = appNavigatorKey.currentContext;
  if (context == null) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(const SnackBar(
    content: Text('Something went wrong. Please try again.'),
    behavior: SnackBarBehavior.floating,
  ));
}

