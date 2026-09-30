/// A boolean condition over the fields of a row, built from columns:
/// `skills.language.eq('rust') & skills.priority.ge(3)`.
///
/// Expressions are data: they are sent to the native engine, which evaluates
/// them (never Dart). Combine them with `&` (and), `|` (or) and `~` (not), or
/// with [and], [or] and [not].
final class Expression {
  /// An expression from its wire representation.
  const Expression.fromJson(this.json);

  /// The wire representation (the `Expr` of offline_first_core).
  final Map<String, Object?> json;

  /// `this AND other`.
  Expression and(Expression other) => this & other;

  /// `this OR other`.
  Expression or(Expression other) => this | other;

  /// `NOT this`.
  Expression not() => ~this;

  /// `this AND other`.
  Expression operator &(Expression other) => Expression.fromJson({
    'op': 'and',
    'args': [..._flatten('and'), ...other._flatten('and')],
  });

  /// `this OR other`.
  Expression operator |(Expression other) => Expression.fromJson({
    'op': 'or',
    'args': [..._flatten('or'), ...other._flatten('or')],
  });

  /// `NOT this`.
  Expression operator ~() => Expression.fromJson({'op': 'not', 'arg': json});

  List<Object?> _flatten(String op) =>
      json['op'] == op ? json['args'] as List<Object?> : [json];

  @override
  bool operator ==(Object other) =>
      other is Expression && _Json.equals(json, other.json);

  @override
  int get hashCode => json.toString().hashCode;

  @override
  String toString() => 'Expression($json)';
}

/// One sort key: [Column.asc] or [Column.desc].
final class OrderingTerm {
  /// A sort key on [field].
  const OrderingTerm(this.field, {this.descending = false});

  /// Field path.
  final String field;

  /// Descending order.
  final bool descending;

  /// The wire representation.
  Map<String, Object?> toJson() => {'field': field, 'desc': descending};

  @override
  bool operator ==(Object other) =>
      other is OrderingTerm &&
      other.field == field &&
      other.descending == descending;

  @override
  int get hashCode => Object.hash(field, descending);

  @override
  String toString() => '$field ${descending ? 'DESC' : 'ASC'}';
}

/// Structural equality of decoded JSON values.
abstract final class _Json {
  static bool equals(Object? a, Object? b) {
    if (a is Map && b is Map) {
      return a.length == b.length &&
          a.keys.every((key) => b.containsKey(key) && equals(a[key], b[key]));
    }
    if (a is List && b is List) {
      if (a.length != b.length) {
        return false;
      }
      for (var i = 0; i < a.length; i++) {
        if (!equals(a[i], b[i])) {
          return false;
        }
      }
      return true;
    }
    return a == b;
  }
}
