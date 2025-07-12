import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_db/src/local_db.dart';

// Para acceder a métodos privados, vamos a crear versiones públicas equivalentes para testing
class ValidationHelper {
  /// Validates that a map can be properly serialized to JSON.
  static bool isValidMap(dynamic map) {
    try {
      String jsonString = jsonEncode(map);
      jsonDecode(jsonString);
      return true;
    } catch (error) {
      return false;
    }
  }

  /// Validates the format of a database record identifier.
  static bool isValidId(String text) {
    RegExp regex = RegExp(r'^[a-zA-Z0-9_-]{3,}$');
    return regex.hasMatch(text);
  }

  /// Additional validation for JSON serialization limits
  static bool canSerializeToJson(dynamic data) {
    try {
      final jsonString = jsonEncode(data);
      // Check if the JSON string is reasonable size (not too large)
      if (jsonString.length > 10 * 1024 * 1024) { // 10MB limit
        return false;
      }
      // Verify it can be decoded back
      jsonDecode(jsonString);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Validates that data doesn't contain circular references
  static bool hasNoCircularReferences(Map<String, dynamic> data) {
    try {
      _checkCircularReferences(data, <Object>{});
      return true;
    } catch (e) {
      return false;
    }
  }

  static void _checkCircularReferences(dynamic obj, Set<Object> visited) {
    if (obj == null) return;
    
    if (obj is Map || obj is List) {
      if (visited.contains(obj)) {
        throw Exception('Circular reference detected');
      }
      visited.add(obj);
      
      if (obj is Map) {
        for (var value in obj.values) {
          _checkCircularReferences(value, visited);
        }
      } else if (obj is List) {
        for (var item in obj) {
          _checkCircularReferences(item, visited);
        }
      }
      
      visited.remove(obj);
    }
  }

  /// Sanitizes input data for safe storage
  static Map<String, dynamic> sanitizeData(Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};
    
    for (final entry in data.entries) {
      final key = _sanitizeKey(entry.key);
      final value = _sanitizeValue(entry.value);
      if (key.isNotEmpty && value != null) {
        sanitized[key] = value;
      }
    }
    
    return sanitized;
  }

  static String _sanitizeKey(String key) {
    // Remove null characters and control characters
    return key.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
  }

  static dynamic _sanitizeValue(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      // Remove control characters (0x00-0x1F and 0x7F) except tabs, newlines, and carriage returns
      return value.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
    }
    if (value is Map) {
      return sanitizeData(value.cast<String, dynamic>());
    }
    if (value is List) {
      return value.map(_sanitizeValue).toList();
    }
    return value;
  }
}

void main() {
  group('Pure Validation Tests - 100% Dart No FFI', () {
    group('ID Validation Tests', () {
      test('Should validate correct IDs', () {
        final validIds = [
          'abc',
          'test-id',
          'user_123',
          'valid-id-with-dashes',
          'user_profile_data',
          'ABC123',
          'mixed-Case_ID',
          'a' * 100, // Long but valid
          '123-456-789',
          'test_001',
        ];

        for (final id in validIds) {
          expect(ValidationHelper.isValidId(id), true, 
              reason: 'ID "$id" should be valid');
        }
      });

      test('Should reject invalid IDs', () {
        final invalidIds = [
          '', // Empty
          'ab', // Too short
          'a', // Too short
          'test@id', // Invalid character @
          'test id', // Space
          'test#id', // Invalid character #
          'test\$id', // Invalid character \$
          'test&id', // Invalid character &
          'test+id', // Invalid character +
          'test=id', // Invalid character =
          'test.id', // Invalid character .
          'test,id', // Invalid character ,
          'test;id', // Invalid character ;
          'test:id', // Invalid character :
          'test/id', // Invalid character /
          'test\\id', // Invalid character \\
          'test|id', // Invalid character |
          'test(id)', // Invalid characters ()
          'test[id]', // Invalid characters []
          'test{id}', // Invalid characters {}
          'test<id>', // Invalid characters <>
          'test"id"', // Invalid character "
          "test'id'", // Invalid character '
          'test\nid', // Newline
          'test\tid', // Tab
          'test\rid', // Carriage return
        ];

        for (final id in invalidIds) {
          expect(ValidationHelper.isValidId(id), false, 
              reason: 'ID "$id" should be invalid');
        }
      });

      test('Should handle Unicode characters in IDs', () {
        final unicodeIds = [
          'test-世界', // Chinese characters (should be invalid)
          'test-café', // Accented characters (should be invalid)
          'test-🚀', // Emoji (should be invalid)
          'test-αβγ', // Greek letters (should be invalid)
        ];

        for (final id in unicodeIds) {
          expect(ValidationHelper.isValidId(id), false, 
              reason: 'Unicode ID "$id" should be invalid (ASCII only)');
        }
      });

      test('Should handle edge cases for ID length', () {
        expect(ValidationHelper.isValidId('ab'), false); // Exactly 2 chars
        expect(ValidationHelper.isValidId('abc'), true); // Exactly 3 chars
        expect(ValidationHelper.isValidId('a' * 1000), true); // Very long
      });
    });

    group('JSON Map Validation Tests', () {
      test('Should validate simple valid maps', () {
        final validMaps = [
          <String, dynamic>{},
          {'key': 'value'},
          {'string': 'text', 'number': 42, 'boolean': true},
          {'null_value': null},
          {'empty_string': ''},
          {'zero': 0, 'negative': -1, 'float': 3.14},
        ];

        for (final map in validMaps) {
          expect(ValidationHelper.isValidMap(map), true, 
              reason: 'Map $map should be valid');
        }
      });

      test('Should validate complex nested structures', () {
        final complexMap = {
          'user': {
            'profile': {
              'name': 'John Doe',
              'age': 30,
              'settings': {
                'theme': 'dark',
                'notifications': true
              }
            },
            'contacts': [
              {'type': 'email', 'value': 'john@example.com'},
              {'type': 'phone', 'value': '+1234567890'}
            ]
          },
          'metadata': {
            'created': '2024-01-01T00:00:00Z',
            'version': 1.0,
            'tags': ['user', 'active', 'verified']
          }
        };

        expect(ValidationHelper.isValidMap(complexMap), true);
      });

      test('Should validate arrays and lists', () {
        final mapWithArrays = {
          'numbers': [1, 2, 3, 4, 5],
          'strings': ['a', 'b', 'c'],
          'mixed': [1, 'two', 3.0, true, null],
          'nested_arrays': [
            [1, 2, 3],
            ['a', 'b', 'c'],
            [true, false]
          ],
          'empty_array': <dynamic>[],
        };

        expect(ValidationHelper.isValidMap(mapWithArrays), true);
      });

      test('Should reject maps with non-serializable values', () {
        // DateTime objects are not directly JSON serializable without conversion
        final mapWithDateTime = {
          'date': DateTime.now(), // This should fail JSON serialization
        };

        expect(ValidationHelper.isValidMap(mapWithDateTime), false);
      });

      test('Should handle special numeric values', () {
        final specialNumbers = {
          'infinity': double.infinity,
          'negative_infinity': double.negativeInfinity,
          'nan': double.nan,
        };

        // These should fail JSON serialization
        expect(ValidationHelper.isValidMap(specialNumbers), false);
      });

      test('Should validate Unicode content in maps', () {
        final unicodeMap = {
          'chinese': '你好世界',
          'emoji': '🌍🚀💡',
          'arabic': 'مرحبا بك',
          'russian': 'Привет мир',
          'special_chars': '!@#\$%^&*()_+-=[]{}|;:,.<>?',
          'escaped_chars': 'Line 1\nLine 2\tTabbed\r\nWindows newline',
        };

        expect(ValidationHelper.isValidMap(unicodeMap), true);
      });
    });

    group('JSON Serialization Limits Tests', () {
      test('Should handle reasonable data sizes', () {
        // Create a reasonably sized data structure
        final reasonableData = <String, dynamic>{};
        for (int i = 0; i < 100; i++) {
          reasonableData['item_$i'] = {
            'name': 'Item $i',
            'value': i,
            'description': 'This is item number $i' * 10, // Some repeated text
          };
        }

        expect(ValidationHelper.canSerializeToJson(reasonableData), true);
      });

      test('Should reject extremely large data structures', () {
        // Create a very large data structure that would exceed reasonable limits
        final largeData = <String, dynamic>{};
        for (int i = 0; i < 10000; i++) {
          largeData['item_$i'] = {
            'data': 'x' * 10000, // 10KB per item * 10000 items = 100MB+
          };
        }

        // This should be rejected due to size
        expect(ValidationHelper.canSerializeToJson(largeData), false);
      });

      test('Should handle deeply nested structures', () {
        // Create deeply nested structure (should be valid but test depth limits)
        Map<String, dynamic> createNested(int depth) {
          if (depth <= 0) return {'value': 'leaf'};
          return {'nested': createNested(depth - 1), 'level': depth};
        }

        final deeplyNested = createNested(100); // 100 levels deep
        expect(ValidationHelper.canSerializeToJson(deeplyNested), true);

        // Even deeper (1000 levels) might hit recursion limits
        final veryDeep = createNested(1000);
        // This may or may not work depending on the system, but shouldn't crash
        ValidationHelper.canSerializeToJson(veryDeep);
      });
    });

    group('Circular Reference Detection Tests', () {
      test('Should detect circular references in maps', () {
        final mapA = <String, dynamic>{'name': 'A'};
        final mapB = <String, dynamic>{'name': 'B', 'ref': mapA};
        mapA['ref'] = mapB; // Create circular reference

        expect(ValidationHelper.hasNoCircularReferences(mapA), false);
      });

      test('Should detect circular references in arrays', () {
        final list = <dynamic>['item1'];
        final map = <String, dynamic>{'list': list};
        list.add(map); // Create circular reference

        expect(ValidationHelper.hasNoCircularReferences(map), false);
      });

      test('Should pass for valid non-circular structures', () {
        final validStructure = {
          'user': {
            'name': 'John',
            'friends': [
              {'name': 'Alice'},
              {'name': 'Bob'}
            ]
          },
          'posts': [
            {
              'title': 'First Post',
              'author': {'name': 'John'} // Same structure but different instance
            }
          ]
        };

        expect(ValidationHelper.hasNoCircularReferences(validStructure), true);
      });
    });

    group('Data Sanitization Tests', () {
      test('Should sanitize control characters from strings', () {
        final dirtyData = {
          'normal': 'clean text',
          'with_null': 'text\u0000with null',
          'with_control': 'text\x01\x02control chars',
          'with_tabs': 'text\twith\ttabs',
          'with_newlines': 'line1\nline2\rline3',
        };

        final sanitized = ValidationHelper.sanitizeData(dirtyData);

        expect(sanitized['normal'], 'clean text');
        expect(sanitized['with_null'], 'textwith null');
        expect(sanitized['with_control'], 'textcontrol chars');
        expect(sanitized['with_tabs'], 'text\twith\ttabs'); // Tabs preserved
        expect(sanitized['with_newlines'], 'line1\nline2\rline3'); // Newlines preserved
      });

      test('Should sanitize keys with control characters', () {
        final dirtyData = {
          'normal_key': 'value1',
          'key\x00with_null': 'value2',
          'key\x01control': 'value3',
          '  spaced_key  ': 'value4',
        };

        final sanitized = ValidationHelper.sanitizeData(dirtyData);

        expect(sanitized.containsKey('normal_key'), true);
        expect(sanitized.containsKey('keywith_null'), true);
        expect(sanitized.containsKey('keycontrol'), true);
        expect(sanitized.containsKey('spaced_key'), true);
        expect(sanitized['spaced_key'], 'value4');
      });

      test('Should handle nested data sanitization', () {
        final nestedDirtyData = {
          'user': {
            'name\x00': 'John\u0000Doe',
            'profile': {
              'bio': 'Hello\x01World',
              'settings': [
                {'key\x02': 'value\x03'},
                'clean_string'
              ]
            }
          }
        };

        final sanitized = ValidationHelper.sanitizeData(nestedDirtyData);

        expect(sanitized['user']['name'], 'JohnDoe');
        expect(sanitized['user']['profile']['bio'], 'HelloWorld');
        expect(sanitized['user']['profile']['settings'][0]['key'], 'value');
        expect(sanitized['user']['profile']['settings'][1], 'clean_string');
      });

      test('Should remove empty keys after sanitization', () {
        final dataWithEmptyKeys = {
          'valid_key': 'value',
          '\x00\x01\x02': 'should_be_removed',
          '   ': 'spaces_only',
          '': 'empty_key',
        };

        final sanitized = ValidationHelper.sanitizeData(dataWithEmptyKeys);

        expect(sanitized.length, 1);
        expect(sanitized['valid_key'], 'value');
      });
    });

    group('Input Validation Edge Cases', () {
      test('Should handle various string edge cases', () {
        final edgeCases = {
          'empty_string': '',
          'whitespace_only': '   ',
          'single_char': 'a',
          'very_long': 'x' * 10000,
          'all_numbers': '1234567890',
          'all_symbols': '!@#\$%^&*()',
          'mixed_case': 'MiXeD CaSe TeXt',
        };

        for (final entry in edgeCases.entries) {
          expect(ValidationHelper.isValidMap({entry.key: entry.value}), true,
              reason: 'Should handle string case: ${entry.key}');
        }
      });

      test('Should handle numeric edge cases', () {
        final numericCases = {
          'zero': 0,
          'negative': -1,
          'large_int': 9223372036854775807, // Max int64
          'small_double': 0.0000000001,
          'large_double': 1.7976931348623157e+308,
          'negative_zero': -0.0,
        };

        expect(ValidationHelper.isValidMap(numericCases), true);
      });

      test('Should handle boolean and null edge cases', () {
        final booleanCases = {
          'true_bool': true,
          'false_bool': false,
          'null_value': null,
        };

        expect(ValidationHelper.isValidMap(booleanCases), true);
      });

      test('Should handle empty collections', () {
        final emptyCollections = {
          'empty_map': <String, dynamic>{},
          'empty_list': <dynamic>[],
          'null_map': null,
          'null_list': null,
        };

        expect(ValidationHelper.isValidMap(emptyCollections), true);
      });
    });

    group('Performance and Stress Tests', () {
      test('Should validate large valid structures efficiently', () {
        final startTime = DateTime.now();
        
        // Create a large but valid structure
        final largeData = <String, dynamic>{};
        for (int i = 0; i < 1000; i++) {
          largeData['user_$i'] = {
            'name': 'User $i',
            'email': 'user$i@example.com',
            'profile': {
              'age': 20 + (i % 50),
              'interests': ['coding', 'reading', 'gaming'],
              'settings': {
                'theme': i % 2 == 0 ? 'dark' : 'light',
                'notifications': i % 3 == 0,
              }
            }
          };
        }
        
        final isValid = ValidationHelper.isValidMap(largeData);
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);
        
        expect(isValid, true);
        expect(duration.inMilliseconds, lessThan(5000), // Should complete in under 5 seconds
            reason: 'Validation took too long: ${duration.inMilliseconds}ms');
      });

      test('Should handle repeated validation calls efficiently', () {
        final testData = {
          'repeated_test': 'value',
          'nested': {
            'data': [1, 2, 3, 4, 5]
          }
        };
        
        final startTime = DateTime.now();
        
        // Validate the same data 1000 times
        for (int i = 0; i < 1000; i++) {
          expect(ValidationHelper.isValidMap(testData), true);
        }
        
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);
        
        expect(duration.inMilliseconds, lessThan(1000), // Should complete in under 1 second
            reason: 'Repeated validation too slow: ${duration.inMilliseconds}ms');
      });
    });
  });
}