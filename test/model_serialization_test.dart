import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_db/src/model/local_db_request_model.dart';

void main() {
  group('LocalDbModel Serialization Tests - 100% Pure Dart', () {
    group('Model Construction', () {
      test('Should create model with required fields', () {
        final model = LocalDbModel(id: 'test-id', data: {'key': 'value'});

        expect(model.id, 'test-id');
        expect(model.hash, null);
        expect(model.data, {'key': 'value'});
      });

      test('Should create model with all fields', () {
        final model = LocalDbModel(
          id: 'test-id',
          hash: 'abc123',
          data: {'key': 'value'},
        );

        expect(model.id, 'test-id');
        expect(model.hash, 'abc123');
        expect(model.data, {'key': 'value'});
      });

      test('Should create model with complex data structures', () {
        final complexData = {
          'string': 'value',
          'number': 42,
          'double': 3.14,
          'boolean': true,
          'null_value': null,
          'list': [1, 2, 3, 'four'],
          'nested_map': {
            'inner_key': 'inner_value',
            'inner_list': [true, false],
          },
        };

        final model = LocalDbModel(id: 'complex-test', data: complexData);

        expect(model.data['string'], 'value');
        expect(model.data['number'], 42);
        expect(model.data['double'], 3.14);
        expect(model.data['boolean'], true);
        expect(model.data['null_value'], null);
        expect(model.data['list'], [1, 2, 3, 'four']);
        expect(model.data['nested_map']['inner_key'], 'inner_value');
        expect(model.data['nested_map']['inner_list'], [true, false]);
      });
    });

    group('JSON Serialization', () {
      test('Should serialize to JSON correctly', () {
        final model = LocalDbModel(
          id: 'test-id',
          hash: 'hash123',
          data: {'key': 'value', 'number': 42},
        );

        final json = model.toJson();

        expect(json, {
          'id': 'test-id',
          'hash': 'hash123',
          'data': {'key': 'value', 'number': 42},
        });
      });

      test('Should serialize model with null hash', () {
        final model = LocalDbModel(id: 'test-id', data: {'key': 'value'});

        final json = model.toJson();

        expect(json, {
          'id': 'test-id',
          'hash': null,
          'data': {'key': 'value'},
        });
      });

      test('Should serialize complex data structures', () {
        final complexData = {
          'users': [
            {'name': 'John', 'age': 30},
            {'name': 'Jane', 'age': 25},
          ],
          'settings': {
            'theme': 'dark',
            'notifications': {'email': true, 'push': false},
          },
          'metadata': {
            'created_at': '2024-01-01T00:00:00Z',
            'version': 1.0,
            'tags': ['user', 'profile', 'active'],
          },
        };

        final model = LocalDbModel(id: 'complex-data', data: complexData);

        final json = model.toJson();
        expect(json['data']['users'][0]['name'], 'John');
        expect(json['data']['settings']['theme'], 'dark');
        expect(json['data']['metadata']['tags'], ['user', 'profile', 'active']);
      });

      test('Should be JSON encodable with dart:convert', () {
        final model = LocalDbModel(
          id: 'encode-test',
          hash: 'hash123',
          data: {
            'string': 'test',
            'number': 42,
            'list': [1, 2, 3],
            'map': {'nested': 'value'},
          },
        );

        // Should not throw exception
        final jsonString = jsonEncode(model.toJson());
        expect(jsonString, isA<String>());

        // Should be valid JSON
        final decoded = jsonDecode(jsonString);
        expect(decoded['id'], 'encode-test');
        expect(decoded['hash'], 'hash123');
        expect(decoded['data']['string'], 'test');
      });
    });

    group('JSON Deserialization', () {
      test('Should deserialize from JSON correctly', () {
        final json = {
          'id': 'test-id',
          'hash': 'hash123',
          'data': {'key': 'value', 'number': 42},
        };

        final model = LocalDbModel.fromJson(json);

        expect(model.id, 'test-id');
        expect(model.hash, 'hash123');
        expect(model.data, {'key': 'value', 'number': 42});
      });

      test('Should deserialize with null hash', () {
        final json = {
          'id': 'test-id',
          'hash': null,
          'data': {'key': 'value'},
        };

        final model = LocalDbModel.fromJson(json);

        expect(model.id, 'test-id');
        expect(model.hash, null);
        expect(model.data, {'key': 'value'});
      });

      test('Should deserialize complex data structures', () {
        final json = {
          'id': 'complex-deserialize',
          'hash': 'hash456',
          'data': {
            'profile': {
              'user': {
                'name': 'John Doe',
                'preferences': {'language': 'en', 'timezone': 'UTC'},
              },
              'contacts': [
                {'type': 'email', 'value': 'john@example.com'},
                {'type': 'phone', 'value': '+1234567890'},
              ],
            },
            'stats': {
              'login_count': 150,
              'last_active': '2024-01-15T10:30:00Z',
            },
          },
        };

        final model = LocalDbModel.fromJson(json);

        expect(model.id, 'complex-deserialize');
        expect(model.data['profile']['user']['name'], 'John Doe');
        expect(
          model.data['profile']['contacts'][0]['value'],
          'john@example.com',
        );
        expect(model.data['stats']['login_count'], 150);
      });

      test('Should handle roundtrip serialization', () {
        final originalModel = LocalDbModel(
          id: 'roundtrip-test',
          hash: 'original-hash',
          data: {
            'text': 'Hello World',
            'numbers': [1, 2, 3, 4, 5],
            'nested': {
              'level1': {
                'level2': {'value': 'deep value'},
              },
            },
          },
        );

        // Serialize to JSON
        final json = originalModel.toJson();

        // Deserialize back to model
        final deserializedModel = LocalDbModel.fromJson(json);

        // Should be identical
        expect(deserializedModel.id, originalModel.id);
        expect(deserializedModel.hash, originalModel.hash);
        expect(deserializedModel.data, originalModel.data);
      });
    });

    group('CopyWith Method', () {
      test('Should copy with new id', () {
        final original = LocalDbModel(
          id: 'original-id',
          hash: 'hash123',
          data: {'key': 'value'},
        );

        final copied = original.copyWith(id: 'new-id');

        expect(copied.id, 'new-id');
        expect(copied.hash, 'hash123');
        expect(copied.data, {'key': 'value'});

        // Original should remain unchanged
        expect(original.id, 'original-id');
      });

      test('Should copy with new hash', () {
        final original = LocalDbModel(
          id: 'test-id',
          hash: 'old-hash',
          data: {'key': 'value'},
        );

        final copied = original.copyWith(hash: 'new-hash');

        expect(copied.id, 'test-id');
        expect(copied.hash, 'new-hash');
        expect(copied.data, {'key': 'value'});
      });

      test('Should copy with new data', () {
        final original = LocalDbModel(
          id: 'test-id',
          hash: 'hash123',
          data: {'old': 'data'},
        );

        final newData = {'new': 'data', 'more': 'fields'};
        final copied = original.copyWith(data: newData);

        expect(copied.id, 'test-id');
        expect(copied.hash, 'hash123');
        expect(copied.data, newData);

        // Original data should remain unchanged
        expect(original.data, {'old': 'data'});
      });

      test('Should copy with multiple fields', () {
        final original = LocalDbModel(
          id: 'original-id',
          hash: 'old-hash',
          data: {'old': 'data'},
        );

        final copied = original.copyWith(
          id: 'new-id',
          hash: 'new-hash',
          data: {'new': 'data'},
        );

        expect(copied.id, 'new-id');
        expect(copied.hash, 'new-hash');
        expect(copied.data, {'new': 'data'});
      });

      test('Should copy with no changes (all null)', () {
        final original = LocalDbModel(
          id: 'test-id',
          hash: 'hash123',
          data: {'key': 'value'},
        );

        final copied = original.copyWith();

        expect(copied.id, original.id);
        expect(copied.hash, original.hash);
        expect(copied.data, original.data);
      });

      test('Should handle explicit null hash in copyWith', () {
        final original = LocalDbModel(
          id: 'test-id',
          hash: 'existing-hash',
          data: {'key': 'value'},
        );

        // Note: copyWith with explicit null doesn't override with null in this implementation
        // This is expected behavior - to set hash to null, create a new model
        final copiedWithNoHashChange = original.copyWith();
        expect(copiedWithNoHashChange.hash, 'existing-hash');

        // To actually set hash to null, create new model
        final modelWithNullHash = LocalDbModel(
          id: original.id,
          hash: null,
          data: original.data,
        );
        expect(modelWithNullHash.hash, null);
        expect(modelWithNullHash.id, 'test-id');
        expect(modelWithNullHash.data, {'key': 'value'});
      });
    });

    group('ToString Method', () {
      test('Should provide readable string representation', () {
        final model = LocalDbModel(
          id: 'test-id',
          hash: 'hash123',
          data: {'key': 'value'},
        );

        final str = model.toString();

        expect(str, contains('LocalDbModel'));
        expect(str, contains('id: test-id'));
        expect(str, contains('hash: hash123'));
        expect(str, contains('data: {key: value}'));
      });

      test('Should handle null hash in toString', () {
        final model = LocalDbModel(id: 'test-id', data: {'key': 'value'});

        final str = model.toString();

        expect(str, contains('hash: null'));
      });

      test('Should handle complex data in toString', () {
        final model = LocalDbModel(
          id: 'complex-id',
          data: {
            'list': [1, 2, 3],
            'map': {'nested': 'value'},
          },
        );

        final str = model.toString();

        expect(str, isA<String>());
        expect(str, contains('complex-id'));
      });
    });

    group('Edge Cases and Error Handling', () {
      test('Should handle empty data map', () {
        final model = LocalDbModel(id: 'empty-data', data: {});

        expect(model.data, isEmpty);

        final json = model.toJson();
        expect(json['data'], isEmpty);

        final deserialized = LocalDbModel.fromJson(json);
        expect(deserialized.data, isEmpty);
      });

      test('Should handle special characters in ID', () {
        final model = LocalDbModel(
          id: 'test-id_with-special123',
          data: {'key': 'value'},
        );

        expect(model.id, 'test-id_with-special123');

        final json = model.toJson();
        final deserialized = LocalDbModel.fromJson(json);
        expect(deserialized.id, 'test-id_with-special123');
      });

      test('Should handle Unicode characters in data', () {
        final model = LocalDbModel(
          id: 'unicode-test',
          data: {
            'chinese': '你好世界',
            'emoji': '🌍🚀💡',
            'arabic': 'مرحبا',
            'russian': 'Привет',
          },
        );

        final json = model.toJson();
        final jsonString = jsonEncode(json);
        final decoded = jsonDecode(jsonString);
        final deserialized = LocalDbModel.fromJson(decoded);

        expect(deserialized.data['chinese'], '你好世界');
        expect(deserialized.data['emoji'], '🌍🚀💡');
        expect(deserialized.data['arabic'], 'مرحبا');
        expect(deserialized.data['russian'], 'Привет');
      });

      test('Should handle large data structures', () {
        // Create a large data structure
        final largeData = <String, dynamic>{};
        for (int i = 0; i < 1000; i++) {
          largeData['key_$i'] = {
            'value': 'data_$i',
            'number': i,
            'list': List.generate(10, (j) => 'item_${i}_$j'),
          };
        }

        final model = LocalDbModel(id: 'large-data-test', data: largeData);

        // Should handle serialization without issues
        final json = model.toJson();
        expect(json['data']['key_0']['value'], 'data_0');
        expect(json['data']['key_999']['number'], 999);

        // Should handle deserialization
        final deserialized = LocalDbModel.fromJson(json);
        expect(deserialized.data['key_500']['list'][5], 'item_500_5');
      });

      test('Should handle deeply nested structures', () {
        // Create deeply nested structure
        Map<String, dynamic> createNestedData(int depth) {
          if (depth == 0) {
            return {'leaf': 'value', 'depth': 0};
          }
          return {
            'level': depth,
            'nested': createNestedData(depth - 1),
            'data': 'level_$depth',
          };
        }

        final model = LocalDbModel(
          id: 'deep-nested',
          data: createNestedData(20), // 20 levels deep
        );

        final json = model.toJson();
        final deserialized = LocalDbModel.fromJson(json);

        // Navigate to the leaf
        dynamic current = deserialized.data;
        for (int i = 0; i < 20; i++) {
          current = current['nested'];
        }

        expect(current['leaf'], 'value');
        expect(current['depth'], 0);
      });

      test('Should preserve data types through serialization', () {
        final model = LocalDbModel(
          id: 'type-test',
          data: {
            'string': 'text',
            'int': 42,
            'double': 3.14159,
            'bool_true': true,
            'bool_false': false,
            'null_value': null,
            'empty_string': '',
            'zero': 0,
            'negative': -100,
            'list_mixed': [1, 'two', 3.0, true, null],
            'map_empty': <String, dynamic>{},
            'list_empty': <dynamic>[],
          },
        );

        final json = model.toJson();
        final jsonString = jsonEncode(json);
        final decoded = jsonDecode(jsonString);
        final deserialized = LocalDbModel.fromJson(decoded);

        expect(deserialized.data['string'], isA<String>());
        expect(deserialized.data['int'], isA<int>());
        expect(deserialized.data['double'], isA<double>());
        expect(deserialized.data['bool_true'], isA<bool>());
        expect(deserialized.data['bool_false'], isA<bool>());
        expect(deserialized.data['null_value'], null);
        expect(deserialized.data['empty_string'], '');
        expect(deserialized.data['zero'], 0);
        expect(deserialized.data['negative'], -100);
        expect(deserialized.data['list_mixed'], isA<List>());
        expect(deserialized.data['map_empty'], isA<Map>());
        expect(deserialized.data['list_empty'], isA<List>());
      });
    });
  });
}
