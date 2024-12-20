import 'dart:io';

import 'package:flutter/foundation.dart';

mixin SystemUtils {

  static get isTest => !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  static get isMobile => !isTest &&
      !isWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

  static get isDesktop => !isTest &&
      !isWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static get isWeb => !isTest && kIsWeb;

  static get isAndroid => defaultTargetPlatform == TargetPlatform.android;
  static get isIOS => defaultTargetPlatform == TargetPlatform.iOS;
}


