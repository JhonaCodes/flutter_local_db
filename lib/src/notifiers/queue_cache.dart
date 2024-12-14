import 'dart:collection';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

@protected
final queueCache = ReactiveNotifier<AsyncQueueVM>(AsyncQueueVM.new);

@protected
class AsyncQueueVM {

  final Queue<Future Function()> _queue = Queue();
  bool _isProcessing = false;

  Future<void> process(Future Function() function)async{
    _queue.add(function);
    await _processQueue();
  }

  int _counter = 0;
  Future<void> _processQueue() async {

    if(_isProcessing || _queue.isEmpty) return;

    _isProcessing = true;

    try{

      while(_queue.isNotEmpty){

        log("Queue counter ${_counter++}");

        /// Because remove from list and return element
        final function = _queue.removeFirst();

        await function();

      }

    }catch(error, stackTrace){

      log(error.toString());
      log(stackTrace.toString());

    } finally {

      _isProcessing = false;

    }

  }

}