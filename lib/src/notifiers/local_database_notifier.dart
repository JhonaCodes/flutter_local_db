import 'package:flutter/foundation.dart';
import 'package:flutter_local_db/src/db/database.dart';
import 'package:flutter_local_db/src/model/config_db_model.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

/// Main database instance notifier
/// Provides reactive access to the database ViewModel implementation
/// Protected to ensure proper initialization and access control
@protected
final localDatabaseNotifier = ReactiveNotifier<DataBaseVM>(DataBaseVM.new);

/// Configuration state notifier
/// Maintains reactive access to database configuration settings
@protected
final configNotifier = ReactiveNotifier<ConfigDBModel>(ConfigDBModel.new);
