# flutter_local_db benchmark

Runs the same workload on flutter_local_db 3.0 and on the databases Flutter
apps use most: SQLite (`package:sqlite3`, on the calling isolate), drift (on a
background isolate), Hive CE and Sembast.

The workload ([`lib/src/benchmark.dart`](lib/src/benchmark.dart)):

- 10 000 rows `id, name, email, age, city, active`, with an index on
  `(city, age)` where the engine has indexes;
- insert them in one transaction, then 100 inserts in a transaction each;
- 2 000 lookups by primary key;
- 500 queries `city = x AND age > y LIMIT 50` (each checked to return 50
  rows);
- 200 counts `city = x` (each checked);
- 100 updates by key, in a transaction each.

Every engine runs 3 rounds in fresh directories; each cell is the median.
Engines are labelled with what a commit guarantees and with the isolate their
work runs on ([`lib/src/engines.dart`](lib/src/engines.dart)).

## Run

Use a profile or release build: debug builds run unoptimized Dart code.

```sh
# Prints the table and saves it to build/benchmark.md.
flutter drive --profile -d macos \
  --driver test_driver/integration_test.dart \
  --target integration_test/benchmark_test.dart

# Or run the app and press Run (the table can be selected and copied).
flutter run --release -d <device>
```
