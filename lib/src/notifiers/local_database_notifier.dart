import 'package:flutter/foundation.dart';
import 'package:flutter_local_db/src/db/database.dart';
import 'package:flutter_local_db/src/model/config_db_model.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

@protected
final localDatabaseNotifier = ReactiveNotifier<DataBaseVM>(DataBaseVM.new);

final configNotifier = ReactiveNotifier<ConfigDBModel>(ConfigDBModel.new);