// The bindings are internal: this test checks how they compile.
// ignore_for_file: implementation_imports

import 'package:flutter_local_db/src/native/offline_first_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Built ahead of time (`flutter drive --profile`), every binding resolves
/// even in a program that only takes their addresses, as db_dsl's worker
/// does: an ahead-of-time build can drop how such a function resolves.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every binding resolves when only its address is taken', (
    tester,
  ) async {
    final symbols = OfflineFirstCore.symbols;
    final keyValue = symbols.keyValue!;

    expect(
      [
        symbols.open,
        symbols.execute,
        symbols.freeString,
        symbols.close,
        keyValue.push,
        keyValue.update,
        keyValue.getById,
        keyValue.deleteById,
        keyValue.getAll,
        keyValue.clear,
      ].map((pointer) => pointer.address),
      everyElement(isNot(0)),
    );
  });
}
