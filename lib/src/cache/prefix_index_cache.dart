import 'package:flutter/cupertino.dart';
import 'package:reactive_notifier/reactive_notifier.dart';


@protected
final ReactiveNotifier<Map<String, Map<String, dynamic>>> prefixIndexCache = ReactiveNotifier<Map<String, Map<String, dynamic>>>(()=> {});