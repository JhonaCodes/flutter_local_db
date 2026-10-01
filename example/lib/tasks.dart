import 'package:flutter_local_db/flutter_local_db.dart';

/// A task of the example app, modeled as any app models its data: a
/// `fromJson` factory and a `toJson` method, plus the one line of its table.
final class Task {
  const Task({
    required this.id,
    required this.title,
    required this.done,
    required this.createdAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'] as int?,
    title: json['title'] as String,
    done: json['done'] as bool,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  /// The `tasks` table: generated keys and an index for the list order. It
  /// defines itself the first time it is used; nothing lists it.
  static final table = DbTable<Task>(
    'tasks',
    key: 'id',
    fromJson: Task.fromJson,
    autoIncrement: true,
    indexes: [
      Index(['done', 'id']),
    ],
  );

  /// Primary key; `null` until the database assigns it.
  final int? id;
  final String title;
  final bool done;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'done': done,
    'created_at': createdAt.toIso8601String(),
  };
}

// Written by the quick fix "Write the query fields from the model" of the
// db_dsl_lints plugin (enabled in analysis_options.yaml), not by hand.

/// The fields of `Task` for queries, read from its `toJson`.
extension TaskFields on DbTable<Task> {
  /// The stored `id`.
  Field<int> get id => field('id');

  /// The stored `title`.
  Field<String> get title => field('title');

  /// The stored `done`.
  Field<bool> get done => field('done');

  /// The stored `created_at`.
  Field<DateTime> get createdAt => field('created_at');
}

/// Every operation of the example. Each answers the `Result` of the
/// database: the UI shows an `Err` instead of crashing.
final class TaskStore {
  const TaskStore();

  static final DbTable<Task> _tasks = Task.table;

  /// Opens the database of the app.
  static Future<Result<TaskStore, DbError>> open() async =>
      (await LocalDB.init()).map((_) => const TaskStore());

  /// Pending tasks first, newest first, updated after every write.
  Stream<Result<List<Task>, DbError>> watchAll() => _tasks
      .all()
      .order(_tasks.done.asc())
      .thenOrderBy(_tasks.id.desc())
      .watch();

  Future<Result<int, DbError>> add(String title) => _tasks.insert([
    Task(
      id: null,
      title: title,
      done: false,
      createdAt: DateTime.now().toUtc(),
    ),
  ]);

  Future<Result<int, DbError>> toggle(Task task) => _tasks
      .update()
      .filter(_tasks.id.eq(task.id!))
      .set(_tasks.done, !task.done);

  Future<Result<int, DbError>> remove(Task task) =>
      _tasks.delete().filter(_tasks.id.eq(task.id!));

  /// Deletes every finished task in one transaction; answers how many.
  ///
  /// The screen watches the list first, which defines the table: a table
  /// used for the first time inside a transaction answers
  /// `DbErrorCode.tableNotReady`.
  Future<Result<int, DbError>> clearDone() =>
      LocalDB.transaction((tx) => _tasks.delete().filter(_tasks.done.eq(true)));
}
