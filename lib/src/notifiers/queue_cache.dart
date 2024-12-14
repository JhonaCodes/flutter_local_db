import 'dart:collection';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

/// Singleton notifier for maintaining global queue state across the library
@protected
final queueCache = ReactiveNotifier<AsyncQueueVM>(AsyncQueueVM.new);

/// Manages asynchronous operations queue to ensure ordered execution
/// Prevents concurrent processing and maintains FIFO order
@protected
class AsyncQueueVM {
  /// Queue storing pending async functions to be executed
  final Queue<Future Function()> _queue = Queue();

  /// Flag indicating if queue is currently processing a function
  bool _isProcessing = false;

  /// Adds a function to the queue and starts processing if idle
  /// @param function The async function to be queued
  /// @return Future Result of the processed function
  Future process(Future Function() function) async {
    _queue.add(function);
    return await _processQueue();
  }

  /// Processes queued functions in FIFO order
  /// Only processes one function at a time
  /// @return Future Result of the current processed function
  Future _processQueue() async {
    // Skip if already processing or queue is empty
    if (_isProcessing || _queue.isEmpty) return;

    _isProcessing = true;

    try {
      while (_queue.isNotEmpty) {
        // Remove and execute the first function in queue
        final function = _queue.removeFirst();
        return await function();
      }
    } catch (error, stackTrace) {
      // Log any errors that occur during processing
      log(error.toString());
      log(stackTrace.toString());
    } finally {
      // Reset processing flag regardless of success/failure
      _isProcessing = false;
    }
  }
}
