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

  Future process(Future Function() function)async{
    _queue.add(function);
    return await _processQueue();
  }


  Future _processQueue() async {

    if(_isProcessing || _queue.isEmpty) return;

    _isProcessing = true;

    try{

      while(_queue.isNotEmpty){

        /// Because remove from list and return element
        final function = _queue.removeFirst();

        return await function();

      }

    }catch(error, stackTrace){

      log(error.toString());
      log(stackTrace.toString());

    } finally {

      _isProcessing = false;

    }

  }

}