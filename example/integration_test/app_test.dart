import 'package:flutter_local_db/flutter_local_db.dart';
import 'package:flutter_local_db_example/tasks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Runs on a device or desktop with the native library bundled in the app:
/// verifies the packaging of each platform, not only the Dart code.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(LocalDB.close);

  testWidgets('tables work with the bundled library', (tester) async {
    final directory = await getApplicationSupportDirectory();
    // No table listed: `tasks` defines itself on its first use.
    value(
      await LocalDB.init(
        path:
            '${directory.path}/integration_${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    const store = TaskStore();
    final tasks = Task.table;

    value(await store.add('write the docs'));
    value(await store.add('publish'));
    final all = value(await tasks.all().order(tasks.id.asc()));
    expect(all.map((task) => task.title), ['write the docs', 'publish']);

    expect(value(await store.toggle(all.first)), 1);
    expect(value(await tasks.filter(tasks.done.eq(true)).count()), 1);
    expect(value(await store.clearDone()), 1);
    expect(value(await tasks.all().count()), 1);
    expect(value(await LocalDB.info()).storage, '1.0.2');
  });

  testWidgets('records work with the bundled library', (tester) async {
    value(await LocalDB.init());
    value(await LocalDB.Post('integration', {'value': 42}));

    expect(value(await LocalDB.GetById('integration'))?.data['value'], 42);
    value(await LocalDB.Delete('integration'));
  });
}

/// The value of an `Ok`; fails the test on an `Err`.
T value<T, E>(Result<T, E> result) =>
    result.when(ok: (data) => data, err: (error) => fail('Err: $error'));
