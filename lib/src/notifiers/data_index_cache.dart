import 'package:flutter/foundation.dart';
import 'package:flutter_local_db/src/model/data_model.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

@protected
final ReactiveNotifier<Map<String, List<DataLocalDBModel>>> dataIndexCache = ReactiveNotifier<Map<String, List<DataLocalDBModel>>>(()=> {});