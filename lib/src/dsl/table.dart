import 'column.dart';
import 'expression.dart';
import 'statements.dart';

/// A table: its name, primary key, indexes, and how its rows map to [T].
///
/// ```dart
/// final class SkillsTable extends Table<Skill> {
///   SkillsTable() : super('skills');
///
///   late final id = text('id');
///   late final language = text('language');
///   late final priority = integer('priority');
///
///   @override
///   Column<Object> get primaryKey => id;
///
///   @override
///   List<Index> get indexes => [Index('by_language', [language, priority])];
///
///   @override
///   Skill fromJson(Map<String, dynamic> json) => Skill.fromJson(json);
///
///   @override
///   Map<String, dynamic> toJson(Skill row) => row.toJson();
/// }
/// ```
///
/// Rows are stored as the JSON objects returned by [toJson]. Every query built
/// from a table runs in the native engine.
abstract class Table<T> {
  /// A table named [tableName] (non-empty, without `:`, not starting with
  /// `__`).
  Table(this.tableName);

  /// Name of the table.
  final String tableName;

  /// The column that identifies a row.
  Column<Object> get primaryKey;

  /// Rows inserted without a primary key get an increasing integer one.
  bool get autoIncrement => false;

  /// Secondary indexes, maintained in the same transaction as the rows.
  List<Index> get indexes => const [];

  /// Builds a row from its stored JSON.
  T fromJson(Map<String, dynamic> json);

  /// The JSON stored for [row].
  Map<String, dynamic> toJson(T row);

  /// A text column.
  TextColumn text(String name) => TextColumn(name);

  /// An integer column.
  IntColumn integer(String name) => IntColumn(name);

  /// A floating point column.
  RealColumn real(String name) => RealColumn(name);

  /// A boolean column.
  BoolColumn boolean(String name) => BoolColumn(name);

  /// A date and time column.
  DateTimeColumn dateTime(String name) => DateTimeColumn(name);

  /// The definition sent to the engine.
  Map<String, Object?> toDefinition() => {
    'name': tableName,
    'primary_key': primaryKey.name,
    'auto_increment': autoIncrement,
    'indexes': [for (final index in indexes) index.toJson()],
  };

  /// Every row (`SELECT * FROM table`).
  SelectQuery<T> all() => SelectQuery<T>(this);

  /// Rows matching [condition].
  SelectQuery<T> filter(Expression condition) => all().filter(condition);

  /// Every row, sorted.
  SelectQuery<T> order(OrderingTerm term) => all().order(term);

  /// The row whose primary key is [key].
  FindQuery<T> find(Object key) => FindQuery<T>(this, key);

  /// Inserts [rows] (`insert_into(table).values(rows)`).
  InsertStatement<T> insert(Iterable<T> rows) => InsertStatement<T>(this, rows);

  /// Updates rows (`update(table).filter(...).set(...)`).
  UpdateStatement<T> update() => UpdateStatement<T>(this);

  /// Deletes rows (`delete(table).filter(...)`).
  DeleteStatement<T> delete() => DeleteStatement<T>(this);

  @override
  String toString() => 'Table($tableName)';
}

/// A secondary index over one or more columns.
final class Index {
  /// A non-unique index.
  const Index(this.name, this.columns) : unique = false;

  /// A unique index: two rows cannot hold equal values in [columns] (rows
  /// with a `null` among them are exempt, as in SQL).
  const Index.unique(this.name, this.columns) : unique = true;

  /// Index name, unique within its table.
  final String name;

  /// Indexed columns, in order.
  final List<Column<Object>> columns;

  /// Whether the index rejects duplicates.
  final bool unique;

  /// The wire representation.
  Map<String, Object?> toJson() => {
    'name': name,
    'fields': [for (final column in columns) column.name],
    'unique': unique,
  };
}
