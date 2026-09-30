import 'package:flutter_local_db/flutter_local_db.dart';

/// A task of the example app.
final class Task {
  const Task({
    required this.id,
    required this.title,
    required this.done,
    required this.createdAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'] as int,
    title: json['title'] as String,
    done: json['done'] as bool,
    createdAt: DateTimeColumn.fromStorage(json['created_at']),
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
    'created_at': DateTimeColumn.toStorage(createdAt),
  };
}

/// The `tasks` table: auto-increment key and an index for the list order.
final class TasksTable extends Table<Task> {
  TasksTable() : super('tasks');

  late final id = integer('id');
  late final title = text('title');
  late final done = boolean('done');
  late final createdAt = dateTime('created_at');

  @override
  Column<Object> get primaryKey => id;

  @override
  bool get autoIncrement => true;

  @override
  List<Index> get indexes => [
    Index('by_done_created', [done, createdAt]),
  ];

  @override
  Task fromJson(Map<String, dynamic> json) => Task.fromJson(json);

  @override
  Map<String, dynamic> toJson(Task row) => row.toJson();
}

/// Every operation of the example, on one [LocalDatabase].
final class TaskStore {
  TaskStore(this.db);

  /// Opens the example database in the application support directory.
  static Future<TaskStore> open() async =>
      TaskStore(await LocalDatabase.openNamed('tasks', tables: [tasks]));

  /// The table (one instance for the whole app).
  static final TasksTable tasks = TasksTable();

  final LocalDatabase db;

  /// Pending tasks first, newest first, updated after every write.
  Stream<List<Task>> watchAll() => tasks
      .all()
      .order(tasks.done.asc())
      .thenOrderBy(tasks.createdAt.desc())
      .watch(db);

  Future<void> add(String title) => tasks
      .insert([
        Task(id: null, title: title, done: false, createdAt: DateTime.now()),
      ])
      .execute(db);

  Future<void> toggle(Task task) => tasks
      .update()
      .filter(tasks.id.eq(task.id!))
      .set(tasks.done, !task.done)
      .execute(db);

  Future<void> remove(Task task) =>
      tasks.delete().filter(tasks.id.eq(task.id!)).execute(db);

  /// Deletes every finished task in one transaction and returns how many.
  Future<int> clearDone() => db.transaction(
    (tx) => tasks.delete().filter(tasks.done.eq(true)).execute(tx),
  );
}
