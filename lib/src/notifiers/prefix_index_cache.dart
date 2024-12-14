import 'package:flutter/cupertino.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

/// Cache for prefix-based indices using a nested map structure
/// Maintains a reactive mapping of prefixes to their corresponding data
/// Structure: { prefix: { key: value } }
@protected
final ReactiveNotifier<Map<String, Map<String, dynamic>>> prefixIndexCache =
ReactiveNotifier<Map<String, Map<String, dynamic>>>(() => {});
