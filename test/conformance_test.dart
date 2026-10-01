import 'dart:io';

import 'package:db_dsl/conformance.dart';
import 'package:flutter_local_db/src/native/offline_first_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// The conformance suite of db_dsl against the bundled offline_first_core:
/// the native engine must behave exactly like the protocol (and like
/// `MemoryEngine`, which runs the same suite in db_dsl).
void main() {
  late Directory root;
  var next = 0;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp(
      'flutter_local_db_conformance',
    );
  });
  tearDownAll(() => root.delete(recursive: true));

  final host = ConformanceHost(
    OfflineFirstCore.engine,
    () async => '${root.path}/db-${next++}',
  );

  for (final ConformanceCase(:group, :name, :run) in Conformance.cases) {
    test('$group: $name', () => run(host));
  }
}
