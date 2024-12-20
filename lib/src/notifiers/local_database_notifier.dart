import 'package:flutter_local_db/src/db/database.dart';
import 'package:flutter_local_db/src/model/config_db_model.dart';
import 'package:flutter_local_db/src/model/data_model.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

mixin LocalDataBaseNotifier {
  /// Main database instance notifier
  /// Provides reactive access to the database ViewModel implementation
  /// Protected to ensure proper initialization and access control
  static final instanceDatabase = ReactiveNotifier<DataBaseVM>(DataBaseVM.new);

  /// Configuration state notifier
  /// Maintains reactive access to database configuration settings
  static final instanceConfig =
      ReactiveNotifier<ConfigDBModel>(ConfigDBModel.new);


  /// Maintains a reactive list of all directory prefixes currently in use.
  ///
  /// This notifier tracks the first two characters of each record ID that are used
  /// to organize data into subdirectories. Updates automatically when directories
  /// are created or removed, enabling real-time monitoring of the database structure.
  ///
  /// Example prefixes: ['05', '1b', '3f', ...]
  static final ReactiveNotifier<List<String>> currentListPrefix = ReactiveNotifier<List<String>>(()=>[]);

  /// Singleton cache that maintains in-memory storage of the main index data
  /// for fast access. This reactive cache ensures quick data retrieval without
  /// constant disk reads.
  ///
  /// The cache structure is:
  /// - Key: Container/Directory identifier (String)
  /// - Value: List of data models within that container
  static final ReactiveNotifier<Map<String, List<DataLocalDBModel>>> dataIndexCache = ReactiveNotifier<Map<String, List<DataLocalDBModel>>>(() => {});

}
