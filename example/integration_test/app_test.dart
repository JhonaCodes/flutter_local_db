import 'package:flutter_local_db/flutter_local_db.dart';
import 'package:flutter_local_db_example/tasks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Runs on a device or desktop with the native library bundled in the app:
/// verifies the packaging of each platform, not only the Dart code.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the query API works with the bundled library', (tester) async {
    final directory = await getApplicationSupportDirectory();
    final db = await LocalDatabase.open(
      path:
          '${directory.path}/integration_${DateTime.now().microsecondsSinceEpoch}',
      tables: [TaskStore.tasks],
    );
    final store = TaskStore(db);
    final tasks = TaskStore.tasks;

    await store.add('write the docs');
    await store.add('publish');
    final all = await tasks.all().order(tasks.id.asc()).load(db);
    expect(all.map((t) => t.title), ['write the docs', 'publish']);

    await store.toggle(all.first);
    expect(await tasks.filter(tasks.done.eq(true)).count(db), 1);
    expect(await store.clearDone(), 1);
    expect(await tasks.all().count(db), 1);

    final info = await db.info();
    expect(info['lmdb'], '1.0.2');
    await db.close();
  });

  testWidgets('the key-value API works with the bundled library', (
    tester,
  ) async {
    await LocalDB.init();
    await LocalDB.Post('integration', {'value': 42});
    final stored = await LocalDB.GetById('integration');
    expect(stored.okOrNull?.data['value'], 42);
    await LocalDB.Delete('integration');
  });
}
