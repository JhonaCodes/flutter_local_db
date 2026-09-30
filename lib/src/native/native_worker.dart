import 'dart:async';
import 'dart:isolate';

import 'native_library.dart';

/// A long-lived isolate that owns every call into the native library.
///
/// Native calls block their thread until LMDB answers; running them here keeps
/// the UI isolate free. Requests are served in order and matched to their
/// replies by id.
final class NativeWorker {
  NativeWorker._(this._commands);

  final SendPort _commands;
  final Map<int, Completer<Object?>> _pending = {};
  int _nextId = 0;

  static Future<NativeWorker>? _shared;

  /// The worker of this isolate, started on first use.
  static Future<NativeWorker> shared() =>
      _shared ??= _spawn().catchError((Object error) {
        _shared = null;
        throw error;
      });

  static Future<NativeWorker> _spawn() async {
    final port = ReceivePort();
    await Isolate.spawn(_serve, port.sendPort, debugName: 'flutter_local_db');
    // The first message is the command port; the next ones are replies. No
    // reply arrives before the first command is sent.
    final replies = port.asBroadcastStream();
    final worker = NativeWorker._(await replies.first as SendPort);
    replies.listen(worker._onReply);
    return worker;
  }

  void _onReply(Object? message) {
    final [id as int, ok as bool, result] = message as List<Object?>;
    final completer = _pending.remove(id);
    if (completer == null) {
      return;
    }
    if (ok) {
      completer.complete(result);
    } else {
      completer.completeError(StateError(result.toString()));
    }
  }

  Future<Object?> _call(String operation, List<Object?> arguments) {
    final id = _nextId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    _commands.send([id, operation, arguments]);
    return completer.future;
  }

  /// Opens `<path>.lmdb`; returns the handle address (0 on failure) and the
  /// wire response.
  Future<(int, String)> open(String path, String? optionsJson) async {
    final [handle as int, response as String] =
        await _call('open', [path, optionsJson]) as List<Object?>;
    return (handle, response);
  }

  /// Runs one wire-protocol request on [handle].
  Future<String> execute(int handle, String request) async =>
      await _call('execute', [handle, request]) as String;

  /// Runs one call of the 0.5 key-value API on [handle].
  Future<String> legacy(int handle, String function, String? argument) async =>
      await _call('legacy', [handle, function, argument]) as String;

  /// Releases [handle].
  Future<String> close(int handle) async =>
      await _call('close', [handle]) as String;

  /// Entry point of the worker isolate: serves commands until the app exits.
  static void _serve(SendPort replies) {
    const library = NativeLibrary();
    final commands = ReceivePort();
    replies.send(commands.sendPort);
    commands.listen((message) {
      final [id as int, operation as String, arguments as List<Object?>] =
          message as List<Object?>;
      try {
        final Object result = switch (operation) {
          'open' => () {
            final (handle, response) = library.open(
              arguments[0] as String,
              arguments[1] as String?,
            );
            return [handle, response];
          }(),
          'execute' => library.execute(
            arguments[0] as int,
            arguments[1] as String,
          ),
          'legacy' => library.legacy(
            arguments[0] as int,
            arguments[1] as String,
            arguments[2] as String?,
          ),
          'close' => library.close(arguments[0] as int),
          _ => throw ArgumentError.value(operation, 'operation', 'unknown'),
        };
        replies.send([id, true, result]);
      } on Object catch (error) {
        replies.send([id, false, error.toString()]);
      }
    });
  }
}
