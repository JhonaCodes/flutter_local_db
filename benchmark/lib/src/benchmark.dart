import 'dart:io';

import 'package:flutter_local_db/flutter_local_db.dart';

import 'engines.dart';

/// The time per operation of one engine, for each measured operation.
final class EngineResult {
  /// Result of [engine].
  const EngineResult(
    this.engine,
    this.durability,
    this.runsOn,
    this.microseconds,
  );

  /// Engine name.
  final String engine;

  /// When a committed write reaches the disk.
  final String durability;

  /// Where the database work runs.
  final String runsOn;

  /// Median microseconds per operation, by [Operation].
  final Map<Operation, double> microseconds;
}

/// A measured operation.
enum Operation {
  /// 10 000 rows inserted in one transaction (time per row).
  insertBatch('Insert 10k rows, 1 transaction (per row)'),

  /// One transaction per inserted row.
  insertOne('Insert, 1 transaction per row'),

  /// A lookup by primary key.
  find('Find by primary key'),

  /// `city = x AND age > y`, limit 50, on an index of `(city, age)`.
  query('Indexed query, limit 50'),

  /// `COUNT(*) WHERE city = x` (2 500 matching rows).
  count('Indexed count'),

  /// One row updated by key, in its own transaction.
  update('Update by key');

  const Operation(this.label);

  /// Column title.
  final String label;
}

/// The workload: the same rows and operations for every engine.
abstract final class Benchmark {
  /// Rows inserted before the reads.
  static const int rows = 10000;

  /// Rounds per engine; each cell is the median of the rounds.
  static const int rounds = 3;

  /// Values of the `city` column.
  static const List<String> cities = ['Bogotá', 'Auckland', 'Lima', 'Madrid'];

  /// Engines, in the order of the results.
  static List<BenchmarkEngine Function()> get engines => [
    () => LocalDbEngine(Durability.full),
    () => SqliteEngine(durable: true),
    DriftEngine.new,
    () => LocalDbEngine(Durability.noMetaSync),
    () => LocalDbEngine(Durability.noSync),
    () => SqliteEngine(durable: false),
    HiveEngine.new,
    SembastEngine.new,
  ];

  /// The row with primary key [id].
  static Map<String, Object?> row(int id) => {
    'id': id,
    'name': 'user-$id',
    'email': 'user$id@example.com',
    'age': 18 + id % 60,
    'city': cities[id % 4],
    'active': id % 3 != 0,
  };

  /// Runs every engine in a fresh directory under [root]; [progress] receives
  /// each finished engine.
  static Future<List<EngineResult>> run(
    Directory root, {
    void Function(EngineResult result)? progress,
  }) async {
    await root.create(recursive: true);
    final results = <EngineResult>[];
    for (final create in engines) {
      final samples = <Operation, List<double>>{};
      final probe = create();
      for (var round = 0; round < rounds; round++) {
        final engine = round == 0 ? probe : create();
        final directory = await root.createTemp('round');
        await engine.open(directory.path);
        final times = await _measure(engine);
        await engine.close();
        await directory.delete(recursive: true);
        times.forEach((op, time) => (samples[op] ??= []).add(time));
      }
      final result = EngineResult(probe.name, probe.durability, probe.runsOn, {
        for (final MapEntry(:key, :value) in samples.entries)
          key: _median(value),
      });
      results.add(result);
      progress?.call(result);
    }
    return results;
  }

  static Future<Map<Operation, double>> _measure(BenchmarkEngine engine) async {
    final data = [for (var id = 0; id < rows; id++) row(id)];
    final times = <Operation, double>{};
    Future<void> time(
      Operation op,
      int operations,
      Future<void> Function() body,
    ) async {
      final watch = Stopwatch()..start();
      await body();
      watch.stop();
      times[op] = watch.elapsedMicroseconds / operations;
    }

    await time(Operation.insertBatch, rows, () => engine.insertBatch(data));
    await time(Operation.insertOne, 100, () async {
      for (var id = rows; id < rows + 100; id++) {
        await engine.insertOne(row(id));
      }
    });
    await time(Operation.find, 2000, () async {
      for (var i = 0; i < 2000; i++) {
        if (await engine.find(i * 7 % rows) == null) {
          throw StateError('${engine.name}: row ${i * 7 % rows} not found');
        }
      }
    });
    await time(Operation.query, 500, () async {
      for (var i = 0; i < 500; i++) {
        final found = await engine.query(cities[i % 4], 30 + i % 20, 50);
        if (found != 50) {
          throw StateError('${engine.name}: query returned $found rows');
        }
      }
    });
    await time(Operation.count, 200, () async {
      for (var i = 0; i < 200; i++) {
        final city = cities[i % 4];
        final expected = (rows + 100) ~/ 4;
        final found = await engine.count(city);
        if (found != expected) {
          throw StateError('${engine.name}: count($city) = $found');
        }
      }
    });
    await time(Operation.update, 100, () async {
      for (var id = 0; id < 100; id++) {
        await engine.updateAge(id, 40);
      }
    });
    return times;
  }

  static double _median(List<double> values) {
    final sorted = [...values]..sort();
    return sorted[sorted.length ~/ 2];
  }

  /// Formats [microseconds] for the results table.
  static String format(double microseconds) => microseconds >= 1000
      ? '${(microseconds / 1000).toStringAsFixed(2)} ms'
      : '${microseconds.toStringAsFixed(1)} µs';

  /// The results as a Markdown table.
  static String markdown(List<EngineResult> results) {
    final header = [
      'Engine',
      'Durability',
      'Runs on',
      for (final op in Operation.values) op.label,
    ];
    return [
      '| ${header.join(' | ')} |',
      '|${List.filled(header.length, '---').join('|')}|',
      for (final result in results)
        '| ${[result.engine, result.durability, result.runsOn, for (final op in Operation.values) format(result.microseconds[op]!)].join(' | ')} |',
    ].join('\n');
  }
}
