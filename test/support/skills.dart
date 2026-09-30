import 'package:flutter_local_db/flutter_local_db.dart';

/// A row of the test table.
final class Skill {
  const Skill({
    required this.id,
    required this.slug,
    required this.language,
    required this.priority,
    this.enabled = true,
  });

  factory Skill.fromJson(Map<String, dynamic> json) => Skill(
    id: json['id'] as String,
    slug: json['slug'] as String?,
    language: json['language'] as String,
    priority: json['priority'] as int,
    enabled: json['enabled'] as bool,
  );

  final String id;
  final String? slug;
  final String language;
  final int priority;
  final bool enabled;

  Map<String, dynamic> toJson() => {
    'id': id,
    'slug': slug,
    'language': language,
    'priority': priority,
    'enabled': enabled,
  };

  @override
  bool operator ==(Object other) =>
      other is Skill &&
      other.id == id &&
      other.slug == slug &&
      other.language == language &&
      other.priority == priority &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(id, slug, language, priority, enabled);

  @override
  String toString() => 'Skill($id, $language, $priority, $enabled)';
}

/// The test table, with a composite index and a unique one.
final class SkillsTable extends Table<Skill> {
  SkillsTable() : super('skills');

  late final id = text('id');
  late final slug = text('slug');
  late final language = text('language');
  late final priority = integer('priority');
  late final enabled = boolean('enabled');

  @override
  Column<Object> get primaryKey => id;

  @override
  List<Index> get indexes => [
    Index('by_language_priority', [language, priority]),
    Index.unique('by_slug', [slug]),
  ];

  @override
  Skill fromJson(Map<String, dynamic> json) => Skill.fromJson(json);

  @override
  Map<String, dynamic> toJson(Skill row) => row.toJson();
}

/// Test rows.
abstract final class Skills {
  /// The row number [n].
  static Skill make(
    int n,
    String language,
    int priority, {
    bool enabled = true,
  }) => Skill(
    id: 's${n.toString().padLeft(3, '0')}',
    slug: 'slug-$n',
    language: language,
    priority: priority,
    enabled: enabled,
  );
}
