import 'dart:io';

import 'package:flutter/foundation.dart';

/// A utility mixin providing platform and environment detection methods.
///
/// This mixin offers static methods and getters to identify:
/// - Current platform type (mobile, desktop, web)
/// - Test environment
/// - Specific mobile platform (Android, iOS)
/// - Utility methods for time-related operations
mixin SystemUtils {
  /// Determines if the current environment is a Flutter test.
  ///
  /// Returns `true` if:
  /// - Not running on web
  /// - FLUTTER_TEST environment variable is set
  static get isTest =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  /// Checks if the current platform is a mobile device.
  ///
  /// Returns `true` if:
  /// - Not in a test environment
  /// - Not running on web
  /// - Platform is iOS or Android
  static get isMobile =>
      !isTest &&
      !isWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// Checks if the current platform is a desktop computer.
  ///
  /// Returns `true` if:
  /// - Not in a test environment
  /// - Not running on web
  /// - Platform is Linux, Windows, or macOS
  static get isDesktop =>
      !isTest &&
      !isWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Checks if the current platform is a web browser.
  ///
  /// Returns `true` if:
  /// - Not in a test environment
  /// - Running on web platform
  static get isWeb => !isTest && kIsWeb;

  /// Checks if the current platform is Android.
  ///
  /// Returns `true` if the platform is Android
  static get isAndroid => defaultTargetPlatform == TargetPlatform.android;

  /// Checks if the current platform is iOS.
  ///
  /// Returns `true` if the platform is iOS
  static get isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  /// Calculates the number of milliseconds since epoch for the current day at midnight.
  ///
  /// This method:
  /// 1. Gets the current date
  /// 2. Creates a new DateTime object with time set to 00:00:00
  /// 3. Converts the date to milliseconds since epoch
  ///
  /// Returns a [String] representing milliseconds since epoch for the current day
  static String currentMillisecondsEpocFromDay() {
    // Get the current date
    DateTime now = DateTime.now();

    // Create a new date with time set to 00:00:00 of the current day
    DateTime dateOnly = DateTime(now.year, now.month, now.day);

    // Get the value in seconds since Epoch
    int epochTime = dateOnly.millisecondsSinceEpoch ~/ 1000;

    return "$epochTime";
  }
}
