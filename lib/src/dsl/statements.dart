import '../database/local_database.dart';
import 'column.dart';
import 'expression.dart';
import 'table.dart';

/// Something statements run on: a [LocalDatabase] (each statement in its own
/// transaction) or a [Transaction].
abstract interface class QueryExecutor {
  /// Runs one statement of the wire protocol (`{"op": "select", ...}`) and
  /// returns its result.
  Future<Map<String, Object?>> executeStatement(Map<String, Object?> statement);
}

/// A statement that writes; see [LocalDatabase.atomicBatch].
abstract interface class WriteStatement {
  /// The table it writes.
  String get tableName;

  /// The wire representation.
  Map<String, Object?> toJson();
}

/// Combining filters of the builders.
abstract final class _Conditions {
  /// [next] AND the conditions so far, if any.
  static Expression and(Expression? current, Expression next) =>
      current == null ? next : current & next;
}

/// A query over one table, built like Diesel: `filter`, `orFilter`, `order`,
/// `thenOrderBy`, `limit`, `offset`, then a terminal (`load`, `first`,
/// `count`, aggregates, `watch`).
///
/// Builders never touch the database; the terminal sends the whole query to
/// the native engine. Without [order], the order of the rows is unspecified.
final class SelectQuery<T> {
  /// Every row of [table].
  SelectQuery(this.table)
    : condition = null,
      ordering = const [],
      maxRows = null,
      skipped = null;

  SelectQuery._(
    this.table,
    this.condition,
    this.ordering,
    this.maxRows,
    this.skipped,
  );

  /// The queried table.
  final Table<T> table;

  /// The filter, if any.
  final Expression? condition;

  /// The sort keys.
  final List<OrderingTerm> ordering;

  /// The maximum number of rows, if any.
  final int? maxRows;

  /// The number of rows skipped, if any.
  final int? skipped;

  /// Adds a condition (AND with the previous ones).
  SelectQuery<T> filter(Expression expression) => SelectQuery._(
    table,
    _Conditions.and(condition, expression),
    ordering,
    maxRows,
    skipped,
  );

  /// Adds an alternative (OR with the conditions so far).
  SelectQuery<T> orFilter(Expression expression) => SelectQuery._(
    table,
    condition == null ? expression : condition! | expression,
    ordering,
    maxRows,
    skipped,
  );

  /// Replaces the sort keys.
  SelectQuery<T> order(OrderingTerm term) =>
      SelectQuery._(table, condition, [term], maxRows, skipped);

  /// Adds a sort key.
  SelectQuery<T> thenOrderBy(OrderingTerm term) =>
      SelectQuery._(table, condition, [...ordering, term], maxRows, skipped);

  /// Returns at most [count] rows.
  SelectQuery<T> limit(int count) =>
      SelectQuery._(table, condition, ordering, count, skipped);

  /// Skips the first [count] rows.
  SelectQuery<T> offset(int count) =>
      SelectQuery._(table, condition, ordering, maxRows, count);

  /// The query of the wire protocol (a `Select`).
  Map<String, Object?> toQueryJson() => {
    'table': table.tableName,
    if (condition != null) 'filter': condition!.json,
    if (ordering.isNotEmpty)
      'order': [for (final term in ordering) term.toJson()],
    'limit': ?maxRows,
    'offset': ?skipped,
  };

  /// The statement of the wire protocol.
  Map<String, Object?> toJson() => {'op': 'select', ...toQueryJson()};

  /// Loads the matching rows.
  Future<List<T>> load(QueryExecutor executor) async {
    final result = await executor.executeStatement(toJson());
    return [
      for (final row in result['rows']! as List<Object?>)
        table.fromJson(row! as Map<String, dynamic>),
    ];
  }

  /// Loads the first matching row, or `null`.
  Future<T?> first(QueryExecutor executor) async {
    final rows = await limit(1).load(executor);
    return rows.isEmpty ? null : rows.first;
  }

  /// Counts the matching rows (limit and offset are ignored).
  Future<int> count(QueryExecutor executor) async {
    final result = await executor.executeStatement({
      'op': 'count',
      'table': table.tableName,
      if (condition != null) 'filter': condition!.json,
    });
    return result['count']! as int;
  }

  Future<Object?> _aggregate(
    String function,
    Column<Object> column,
    QueryExecutor executor,
  ) async {
    final result = await executor.executeStatement({
      'op': 'aggregate',
      'table': table.tableName,
      if (condition != null) 'filter': condition!.json,
      'function': function,
      'field': column.name,
    });
    return result['value'];
  }

  /// Sum of [column] over the matching rows, or `null` when none has a value.
  Future<num?> sum(Column<num> column, QueryExecutor executor) async =>
      await _aggregate('sum', column, executor) as num?;

  /// Average of [column], or `null` when no row has a value.
  Future<double?> avg(Column<num> column, QueryExecutor executor) async =>
      (await _aggregate('avg', column, executor) as num?)?.toDouble();

  /// Smallest stored value of [column], or `null`.
  Future<Object?> min(Column<Object> column, QueryExecutor executor) =>
      _aggregate('min', column, executor);

  /// Largest stored value of [column], or `null`.
  Future<Object?> max(Column<Object> column, QueryExecutor executor) =>
      _aggregate('max', column, executor);

  /// The plan the engine chooses (index, order), without running the query.
  Future<Map<String, Object?>> explain(LocalDatabase database) =>
      database.explain(this);

  /// The matching rows now and after every committed write to the table.
  Stream<List<T>> watch(LocalDatabase database) => database.watch(this);

  @override
  String toString() => 'SelectQuery(${toJson()})';
}

/// A lookup by primary key (`table.find(key)`).
final class FindQuery<T> {
  /// The row of [table] whose primary key is [key].
  FindQuery(this.table, this.key);

  /// The table.
  final Table<T> table;

  /// The primary key.
  final Object key;

  /// The statement of the wire protocol.
  Map<String, Object?> toJson() => {
    'op': 'find',
    'table': table.tableName,
    'key': (table.primaryKey as dynamic).encode(key),
  };

  /// The row, or `null` when there is none.
  Future<T?> first(QueryExecutor executor) async {
    final row = (await executor.executeStatement(toJson()))['row'];
    return row == null ? null : table.fromJson(row as Map<String, dynamic>);
  }
}

/// An insert (`insert_into(table).values(rows)`).
final class InsertStatement<T> implements WriteStatement {
  /// Inserts [rows] into [table].
  InsertStatement(this.table, Iterable<T> rows, {this.onConflict = 'error'})
    : rows = List.unmodifiable(rows);

  /// The table.
  final Table<T> table;

  /// The rows.
  final List<T> rows;

  /// `error` (default: an existing primary key fails with `DuplicateKey`),
  /// `replace` or `ignore`.
  final String onConflict;

  @override
  String get tableName => table.tableName;

  /// Keeps the existing row when the primary key already exists.
  InsertStatement<T> onConflictDoNothing() =>
      InsertStatement(table, rows, onConflict: 'ignore');

  /// Replaces the existing row when the primary key already exists.
  InsertStatement<T> onConflictReplace() =>
      InsertStatement(table, rows, onConflict: 'replace');

  @override
  Map<String, Object?> toJson() => {
    'op': 'insert',
    'table': table.tableName,
    'on_conflict': onConflict,
    'rows': [
      for (final row in rows)
        {
          for (final MapEntry(:key, :value) in table.toJson(row).entries)
            // A null key lets an auto-increment table generate it.
            if (!(table.autoIncrement &&
                key == table.primaryKey.name &&
                value == null))
              key: value,
        },
    ],
  };

  /// Runs the insert; returns how many rows were inserted.
  Future<int> execute(QueryExecutor executor) async =>
      (await executor.executeStatement(toJson()))['affected']! as int;

  /// Runs the insert and returns the inserted rows, with generated keys.
  Future<List<T>> getResults(QueryExecutor executor) async {
    final result = await executor.executeStatement(toJson());
    return [
      for (final row in result['rows']! as List<Object?>)
        table.fromJson(row! as Map<String, dynamic>),
    ];
  }
}

/// An update (`update(table).filter(...).set(...)`).
final class UpdateStatement<T> implements WriteStatement {
  /// Updates rows of [table].
  UpdateStatement(this.table)
    : condition = null,
      assignments = const {},
      expected = null;

  UpdateStatement._(
    this.table,
    this.condition,
    this.assignments,
    this.expected,
  );

  /// The table.
  final Table<T> table;

  /// Rows to update; every row when null.
  final Expression? condition;

  /// New values by field path.
  final Map<String, Object?> assignments;

  /// The statement fails unless it updates exactly this many rows.
  final int? expected;

  @override
  String get tableName => table.tableName;

  /// Restricts the updated rows.
  UpdateStatement<T> filter(Expression expression) => UpdateStatement._(
    table,
    _Conditions.and(condition, expression),
    assignments,
    expected,
  );

  /// Sets [column] to [value].
  UpdateStatement<T> set<V extends Object>(Column<V> column, V value) =>
      UpdateStatement._(table, condition, {
        ...assignments,
        column.name: column.encode(value),
      }, expected);

  /// Sets [column] to `null`.
  UpdateStatement<T> setNull(Column<Object> column) => UpdateStatement._(
    table,
    condition,
    {...assignments, column.name: null},
    expected,
  );

  /// Fails, writing nothing, unless exactly [count] rows are updated.
  UpdateStatement<T> expectAffectedRows(int count) =>
      UpdateStatement._(table, condition, assignments, count);

  @override
  Map<String, Object?> toJson() => {
    'op': 'update',
    'table': table.tableName,
    if (condition != null) 'filter': condition!.json,
    'set': assignments,
    'expect': ?expected,
  };

  /// Runs the update; returns how many rows were updated.
  Future<int> execute(QueryExecutor executor) async =>
      (await executor.executeStatement(toJson()))['affected']! as int;
}

/// A delete (`delete(table).filter(...)`).
final class DeleteStatement<T> implements WriteStatement {
  /// Deletes rows of [table].
  DeleteStatement(this.table) : condition = null, expected = null;

  DeleteStatement._(this.table, this.condition, this.expected);

  /// The table.
  final Table<T> table;

  /// Rows to delete; every row when null.
  final Expression? condition;

  /// The statement fails unless it deletes exactly this many rows.
  final int? expected;

  @override
  String get tableName => table.tableName;

  /// Restricts the deleted rows.
  DeleteStatement<T> filter(Expression expression) => DeleteStatement._(
    table,
    _Conditions.and(condition, expression),
    expected,
  );

  /// Fails, deleting nothing, unless exactly [count] rows are deleted.
  DeleteStatement<T> expectAffectedRows(int count) =>
      DeleteStatement._(table, condition, count);

  @override
  Map<String, Object?> toJson() => {
    'op': 'delete',
    'table': table.tableName,
    if (condition != null) 'filter': condition!.json,
    'expect': ?expected,
  };

  /// Runs the delete; returns how many rows were deleted.
  Future<int> execute(QueryExecutor executor) async =>
      (await executor.executeStatement(toJson()))['affected']! as int;
}
