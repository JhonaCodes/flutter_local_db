import 'dart:io';

import 'package:flutter/foundation.dart';

mixin SystemUtils {
  static get isTest =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  static get isMobile =>
      !isTest &&
      !isWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  static get isDesktop =>
      !isTest &&
      !isWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static get isWeb => !isTest && kIsWeb;

  static get isAndroid => defaultTargetPlatform == TargetPlatform.android;
  static get isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  static String currentMillisecondsEpocFromDay() {
    // Obtener la fecha actual
    DateTime now = DateTime.now();

    // Crear una nueva fecha con hora 00:00:00 del día actual
    DateTime dateOnly = DateTime(now.year, now.month, now.day);

    // Obtener el valor en segundos desde la época (Epoch)
    int epochTime = dateOnly.millisecondsSinceEpoch ~/ 1000;

    return "$epochTime";
  }
}
