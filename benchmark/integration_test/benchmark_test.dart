import 'package:flutter_local_db_benchmark/src/benchmark.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Runs the benchmark in the app process and hands the Markdown table to the
/// driver (`test_driver/integration_test.dart`), which saves it.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('benchmark', (tester) async {
    final results = await tester.runAsync(() async {
      final root = await getTemporaryDirectory();
      return Benchmark.run(root);
    });
    final table = Benchmark.markdown(results!);
    binding.reportData = {'table': table};
  }, timeout: const Timeout(Duration(minutes: 30)));
}
