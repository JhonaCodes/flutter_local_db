import 'package:flutter_local_db/flutter_local_db.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/skills.dart';

void main() {
  final skills = SkillsTable();

  test('a table definition lists its key and indexes', () {
    expect(skills.toDefinition(), {
      'name': 'skills',
      'primary_key': 'id',
      'auto_increment': false,
      'indexes': [
        {
          'name': 'by_language_priority',
          'fields': ['language', 'priority'],
          'unique': false,
        },
        {
          'name': 'by_slug',
          'fields': ['slug'],
          'unique': true,
        },
      ],
    });
  });

  test('queries serialize to the wire protocol', () {
    final query = skills
        .filter(skills.language.eq('rust'))
        .filter(skills.priority.between(1, 3))
        .orFilter(~skills.enabled.eq(true))
        .order(skills.priority.desc())
        .thenOrderBy(skills.id.asc())
        .limit(10)
        .offset(5);

    expect(query.toJson(), {
      'op': 'select',
      'table': 'skills',
      'filter': {
        'op': 'or',
        'args': [
          {
            'op': 'and',
            'args': [
              {'op': 'eq', 'field': 'language', 'value': 'rust'},
              {'op': 'between', 'field': 'priority', 'low': 1, 'high': 3},
            ],
          },
          {
            'op': 'not',
            'arg': {'op': 'eq', 'field': 'enabled', 'value': true},
          },
        ],
      },
      'order': [
        {'field': 'priority', 'desc': true},
        {'field': 'id', 'desc': false},
      ],
      'limit': 10,
      'offset': 5,
    });
  });

  test('writes serialize with their conditions and assignments', () {
    expect(
      skills
          .update()
          .filter(skills.id.eq('x'))
          .set(skills.priority, 5)
          .expectAffectedRows(1)
          .toJson(),
      {
        'op': 'update',
        'table': 'skills',
        'filter': {'op': 'eq', 'field': 'id', 'value': 'x'},
        'set': {'priority': 5},
        'expect': 1,
      },
    );
    expect(skills.delete().toJson(), {'op': 'delete', 'table': 'skills'});
    expect(
      skills
          .insert([Skills.make(1, 'go', 2)])
          .onConflictReplace()
          .toJson()['on_conflict'],
      'replace',
    );
  });

  test('date columns are stored as UTC microseconds, which sort by time', () {
    const column = DateTimeColumn('at');
    final early = DateTime.utc(2026, 1, 1, 0, 0, 0, 0, 500);
    final late = DateTime.utc(2026, 1, 1, 0, 0, 0, 1);
    expect(column.eq(early).json['value'], early.microsecondsSinceEpoch);
    expect(
      DateTimeColumn.toStorage(early) < DateTimeColumn.toStorage(late),
      isTrue,
    );
    expect(DateTimeColumn.fromStorage(DateTimeColumn.toStorage(late)), late);
  });

  test('expressions compare by value', () {
    expect(
      skills.id.eq('a') & skills.id.eq('b'),
      skills.id.eq('a') & skills.id.eq('b'),
    );
    expect(skills.id.eq('a'), isNot(skills.id.eq('b')));
  });
}
