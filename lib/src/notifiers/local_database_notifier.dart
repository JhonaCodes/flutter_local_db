
import 'package:flutter/foundation.dart';
import 'package:flutter_local_db/src/db/database.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

@protected
final ReactiveNotifier<DataBase> localDatabaseNotifier = ReactiveNotifier<DataBase>(() => DataBase());