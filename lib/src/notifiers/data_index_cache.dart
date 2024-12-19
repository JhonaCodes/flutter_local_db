import 'package:flutter/foundation.dart';
import 'package:flutter_local_db/src/model/data_model.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

/// Singleton cache that maintains in-memory storage of the main index data
/// for fast access. This reactive cache ensures quick data retrieval without
/// constant disk reads.
///
/// The cache structure is:
/// - Key: Container/Directory identifier (String)
/// - Value: List of data models within that container
@protected
final ReactiveNotifier<Map<String, List<DataLocalDBModel>>> dataIndexCache =
ReactiveNotifier<Map<String, List<DataLocalDBModel>>>(() => {});
