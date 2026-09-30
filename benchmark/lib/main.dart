import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'src/benchmark.dart';

/// Runs the benchmark of flutter_local_db against SQLite, Hive CE and Sembast
/// on the device and shows the results. Use a release or profile build:
/// debug builds run unoptimized Dart code.
void main() => runApp(const BenchmarkApp());

/// The benchmark app.
class BenchmarkApp extends StatelessWidget {
  /// Creates the app.
  const BenchmarkApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'flutter_local_db benchmark',
    theme: ThemeData(colorSchemeSeed: Colors.teal),
    home: const BenchmarkPage(),
  );
}

/// State of a benchmark run.
final class BenchmarkController extends ChangeNotifier {
  /// Results so far, one per finished engine.
  final List<EngineResult> results = [];

  /// Whether a run is in progress.
  bool running = false;

  /// The error of the last run, if it failed.
  Object? error;

  /// The results as a Markdown table.
  String get table => Benchmark.markdown(results);

  /// Runs every engine once more.
  Future<void> run() async {
    if (running) {
      return;
    }
    running = true;
    error = null;
    results.clear();
    notifyListeners();
    try {
      final root = await getTemporaryDirectory();
      await Benchmark.run(
        root,
        progress: (result) {
          results.add(result);
          notifyListeners();
        },
      );
    } on Object catch (e) {
      error = e;
    }
    running = false;
    notifyListeners();
  }
}

/// Starts runs and shows their results.
class BenchmarkPage extends StatefulWidget {
  /// Creates the page.
  const BenchmarkPage({super.key});

  @override
  State<BenchmarkPage> createState() => _BenchmarkPageState();
}

class _BenchmarkPageState extends State<BenchmarkPage> {
  final BenchmarkController _controller = BenchmarkController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('flutter_local_db benchmark'),
        bottom: _controller.running
            ? const PreferredSize(
                preferredSize: Size.fromHeight(1.5),
                child: LinearProgressIndicator(minHeight: 1.5),
              )
            : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _controller.running ? null : _controller.run,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Run'),
      ),
      body: ResultsView(controller: _controller),
    ),
  );
}

/// The results table, selectable so it can be copied.
class ResultsView extends StatelessWidget {
  /// Shows the results of [controller].
  const ResultsView({required this.controller, super.key});

  /// The run shown.
  final BenchmarkController controller;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: SelectableText(
      controller.error?.toString() ?? controller.table,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
    ),
  );
}
