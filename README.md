# flutter_local_db

A high-performance cross-platform local database for Dart and Flutter applications using Rust + LMDB via FFI.

[![pub package](https://img.shields.io/pub/v/flutter_local_db.svg)](https://pub.dev/packages/flutter_local_db)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

![flutter_local_db](https://github.com/user-attachments/assets/09c97008-cfc6-4588-b54c-5737ad00e9e4)

## Features

- **High-performance**: LMDB backend with Rust implementation
- **Rust-powered**: Memory-safe native performance
- **Cross-platform**: Android, iOS, macOS, Linux, Windows
- **Android 15+ Compatible**: Full support for 16 KB page size requirements
- **Simple API**: Key-value interface with CRUD operations
- **Type-safe**: Result-based error handling
- **Easy to use**: Single file, zero configuration

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_local_db: ^1.5.1
```

## Usage

```dart
import 'package:flutter_local_db/flutter_local_db.dart';

void main() async {
  // Initialize the database
  await LocalDB.init('my_database');

  // Create a record
  final result = await LocalDB.Post('user_1', {
    'name': 'John Doe',
    'email': 'john@example.com',
    'age': 30
  });

  result.when(
    ok: (model) => print('Created: ${model.id}'),
    err: (error) => print('Error: $error'),
  );

  // Get a record
  final getResult = await LocalDB.GetById('user_1');
  final user = getResult.unwrapOr(null);
  print('User: $user');

  // Update a record
  await LocalDB.Put('user_1', {
    'name': 'Jane Doe',
    'email': 'jane@example.com',
    'age': 25
  });

  // Get all records
  final allResult = await LocalDB.GetAll();
  allResult.when(
    ok: (models) => print('Total records: ${models.length}'),
    err: (error) => print('Error: $error'),
  );

  // Delete a record
  await LocalDB.Delete('user_1');

  // Clear all data
  await LocalDB.ClearData();

  // Close database (optional)
  await LocalDB.close();
}
```

## Platform Support

| Platform | Status | Architecture |
|----------|--------|--------------|
| Android  | Supported | arm64-v8a, armeabi-v7a, x86, x86_64 |
| iOS      | Supported | arm64 |
| macOS    | Supported | arm64, x86_64 |
| Linux    | Supported | x86_64 |
| Windows  | Supported | x86_64 |

### Android 15+ Compatibility

This package fully supports Android 15's 16 KB page size requirement. Native libraries are compiled with proper ELF alignment to ensure compatibility with all Android versions.

### Platform Setup

This package uses FFI to load native Rust libraries. The required binaries are included.

**Android**: The Flutter plugin automatically includes the native libraries for all architectures. No additional setup required.

**iOS**: The iOS plugin includes the static library via Cocoapods. No additional setup required.

**Desktop**: Desktop platforms (macOS, Linux, Windows) automatically include the native libraries via their respective build systems. No additional setup required.

## API Reference

### Result Type

All database operations return `LocalDbResult<T, E>` for type-safe error handling:

```dart
result.when(
  ok: (value) => handleSuccess(value),
  err: (error) => handleError(error),
);

// Or use convenience methods
final value = result.unwrapOr(defaultValue);
final maybeValue = result.okOrNull;
```

### Error Handling

Errors are typed for better handling:

```dart
result.when(
  ok: (model) => print('Success: $model'),
  err: (error) {
    switch (error.type) {
      case LocalDbErrorType.notFound:
        print('Record not found');
        break;
      case LocalDbErrorType.validation:
        print('Invalid key: ${error.message}');
        break;
      case LocalDbErrorType.database:
        print('Database error: ${error.message}');
        break;
    }
  },
);
```

## Performance

- **Fast**: Direct FFI calls to optimized Rust code
- **Memory efficient**: LMDB memory-mapped storage
- **Minimal overhead**: Single file, no complex abstractions
- **Production ready**: Used in multiple production applications

## Limitations

- Data must be JSON-serializable
- IDs must follow the format requirements
- Platform-specific limitations may apply
- Currently no support for complex queries or indexing
- No automatic migration system

## Native Library

This package uses [offline_first_core](https://github.com/JhonaCodes/offline_first_core), a Rust library built on LMDB (Lightning Memory-Mapped Database) - the same database engine used by Bitcoin Core and OpenLDAP.

## Contributing

Contributions are welcome! The project uses a dual-language architecture:

- Flutter/Dart for the high-level API and FFI bridge
- Rust for the core database operations

Please ensure you have both Rust and Flutter development environments set up before contributing.

## License

MIT License - see [LICENSE](https://github.com/JhonaCodes/flutter_local_db/blob/main/LICENSE)

## Author

Made with Rust + Flutter by [JhonaCode](https://github.com/JhonaCodes)
