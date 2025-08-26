# flutter_local_db

A high-performance cross-platform local database for Dart and Flutter applications using Rust + LMDB via FFI.

## Features

- 🚀 **High-performance**: LMDB backend with Rust implementation
- 🦀 **Rust-powered**: Memory-safe native performance  
- 📱 **Cross-platform**: Android, iOS, macOS, Linux, Windows
- 💾 **Simple API**: Key-value interface with CRUD operations
- 🛡️ **Type-safe**: Result-based error handling
- ✨ **Easy to use**: Single file, zero configuration

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_local_db: ^1.0.0
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

## Platform Setup

This package uses FFI to load native Rust libraries. The required binaries are included.

### Android
The Flutter plugin automatically includes the native libraries for all architectures. No additional setup required.

### iOS
The iOS plugin includes the static library via Cocoapods. No additional setup required.

### Desktop
Desktop platforms (macOS, Linux, Windows) automatically include the native libraries via their respective build systems. No additional setup required.

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

## License

MIT