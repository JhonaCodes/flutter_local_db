import 'expression.dart';

/// A typed field of a table, used to build filters and sort keys.
///
/// The operators follow Diesel: [eq], [ne], [gt], [ge], [lt], [le],
/// [eqAny], [neAll], [isNull], [isNotNull], [between], [notBetween].
/// Comparisons follow SQL: a missing or `null` field matches no comparison;
/// use [isNull] to find it.
base class Column<V extends Object> {
  /// A column stored at the field path [name] (`"address.city"` reaches a
  /// nested field).
  const Column(this.name);

  /// Field path in the row.
  final String name;

  /// How a Dart value of this column is stored.
  Object? encode(V value) => value;

  Expression _compare(String op, V value) =>
      Expression.fromJson({'op': op, 'field': name, 'value': encode(value)});

  /// `this = value`.
  Expression eq(V value) => _compare('eq', value);

  /// `this <> value`.
  Expression ne(V value) => _compare('ne', value);

  /// `this > value`.
  Expression gt(V value) => _compare('gt', value);

  /// `this >= value`.
  Expression ge(V value) => _compare('ge', value);

  /// `this < value`.
  Expression lt(V value) => _compare('lt', value);

  /// `this <= value`.
  Expression le(V value) => _compare('le', value);

  /// `this IN (values)`; matches nothing for an empty list.
  Expression eqAny(Iterable<V> values) => Expression.fromJson({
    'op': 'eq_any',
    'field': name,
    'values': [for (final value in values) encode(value)],
  });

  /// `this NOT IN (values)`.
  Expression neAll(Iterable<V> values) => Expression.fromJson({
    'op': 'ne_all',
    'field': name,
    'values': [for (final value in values) encode(value)],
  });

  /// The field is missing or `null`.
  Expression isNull() => Expression.fromJson({'op': 'is_null', 'field': name});

  /// The field is present and not `null`.
  Expression isNotNull() =>
      Expression.fromJson({'op': 'is_not_null', 'field': name});

  /// `this BETWEEN low AND high` (inclusive).
  Expression between(V low, V high) => Expression.fromJson({
    'op': 'between',
    'field': name,
    'low': encode(low),
    'high': encode(high),
  });

  /// `this NOT BETWEEN low AND high`.
  Expression notBetween(V low, V high) => Expression.fromJson({
    'op': 'not_between',
    'field': name,
    'low': encode(low),
    'high': encode(high),
  });

  /// Ascending sort key.
  OrderingTerm asc() => OrderingTerm(name);

  /// Descending sort key.
  OrderingTerm desc() => OrderingTerm(name, descending: true);

  @override
  String toString() => 'Column($name)';
}

/// A text column, with pattern matching.
final class TextColumn extends Column<String> {
  /// A text column stored at [name].
  const TextColumn(super.name);

  /// `this LIKE pattern`: `%` matches any sequence, `_` one character.
  Expression like(String pattern) =>
      Expression.fromJson({'op': 'like', 'field': name, 'pattern': pattern});

  /// `this ILIKE pattern` (ASCII case-insensitive).
  Expression ilike(String pattern) =>
      Expression.fromJson({'op': 'ilike', 'field': name, 'pattern': pattern});
}

/// An integer column.
final class IntColumn extends Column<int> {
  /// An integer column stored at [name].
  const IntColumn(super.name);
}

/// A floating point column.
final class RealColumn extends Column<double> {
  /// A floating point column stored at [name].
  const RealColumn(super.name);
}

/// A boolean column.
final class BoolColumn extends Column<bool> {
  /// A boolean column stored at [name].
  const BoolColumn(super.name);
}

/// A date and time column, stored as microseconds since the Unix epoch (UTC),
/// so that order and range filters follow time.
///
/// Store and read the value with [toStorage] and [fromStorage] in the
/// `toJson` / `fromJson` of the table.
final class DateTimeColumn extends Column<DateTime> {
  /// A date and time column stored at [name].
  const DateTimeColumn(super.name);

  @override
  Object? encode(DateTime value) => toStorage(value);

  /// The stored form of [value].
  static int toStorage(DateTime value) => value.toUtc().microsecondsSinceEpoch;

  /// The [DateTime] (UTC) of a stored value.
  static DateTime fromStorage(Object? stored) =>
      DateTime.fromMicrosecondsSinceEpoch(stored! as int, isUtc: true);
}
