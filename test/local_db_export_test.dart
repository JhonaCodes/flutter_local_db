import 'dart:convert';

import 'package:flutter_local_db/flutter_local_db.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalDbExport', () {
    test('round-trips records with their ids, hashes and data', () {
      final records = [
        LocalDbModel(id: 'user-1', data: {'name': 'Ada', 'age': 36}),
        LocalDbModel(
          id: 'ñandú',
          data: {
            'nested': {
              'list': [1, 2, 3],
            },
          },
        ),
      ];

      final decoded = LocalDbExport.decode(LocalDbExport.encode(records));

      final models = decoded.unwrapOr(const []);
      expect(models, hasLength(2));
      for (var i = 0; i < records.length; i++) {
        expect(models[i].id, records[i].id);
        expect(models[i].data, records[i].data);
        expect(models[i].contentHash, records[i].contentHash);
      }
    });

    test('rejects documents of another format or version', () {
      final wrongFormat = jsonEncode({
        'format': 'x',
        'version': 1,
        'records': [],
      });
      final wrongVersion = jsonEncode({
        'format': LocalDbExport.format,
        'version': 99,
        'records': [],
      });

      expect(LocalDbExport.decode(wrongFormat).isErr, isTrue);
      expect(LocalDbExport.decode(wrongVersion).isErr, isTrue);
      expect(LocalDbExport.decode('not json').isErr, isTrue);
    });

    test('rejects records without an id or data object', () {
      final broken = jsonEncode({
        'format': LocalDbExport.format,
        'version': LocalDbExport.version,
        'records': [
          {'id': 1, 'data': {}},
        ],
      });

      expect(LocalDbExport.decode(broken).isErr, isTrue);
    });
  });
}
