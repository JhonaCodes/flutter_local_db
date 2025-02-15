# Flutter Local DB

A high-performance local database for Flutter that leverages Rust's RedB embedded database through FFI (Foreign Function Interface). This library provides a robust, efficient, and safe way to store local data in your Flutter applications across multiple platforms.

![flutter_local_db](https://github.com/user-attachments/assets/09c97008-cfc6-4588-b54c-5737ad00e9e4)

## Features

🦀 **Rust Powered**: Uses RedB embedded database for maximum performance and reliability  
🔄 **FFI Integration**: Seamless integration between Flutter and Rust  
🎯 **Simple API**: Store and retrieve JSON data with minimal code  
🛡️ **Result Types**: Rust-inspired Result types for better error handling  
📱 **Cross-Platform**: Supports Android, iOS, and macOS  
⚡ **Async Operations**: All database operations are asynchronous  
🔍 **Smart Querying**: Efficient data retrieval through RedB's B-tree implementation

## Installation

Add to your pubspec.yaml:

```yaml
dependencies:
  flutter_local_db: ^0.3.0
```

## Basic Usage

### Initialize Database

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize with database name
  await LocalDB.init(localDbName: "my_app_db");
  
  runApp(MyApp());
}
```

### CRUD Operations

```dart
// Create
final result = await LocalDB.Post('user-123', {
  'name': 'John Doe',
  'email': 'john@example.com',
  'metadata': {
    'lastLogin': DateTime.now().toIso8601String()
  }
});

// Handle result
result.when(
  ok: (data) => print('User created: ${data.id}'),
  err: (error) => print('Error: $error')
);

// Read single record
final userResult = await LocalDB.GetById('user-123');
userResult.when(
  ok: (user) => print('Found user: ${user?.data}'),
  err: (error) => print('Error: $error')
);

// Read all records
final allUsersResult = await LocalDB.GetAll();
allUsersResult.when(
  ok: (users) => users.forEach((user) => print(user.data)),
  err: (error) => print('Error: $error')
);

// Update
final updateResult = await LocalDB.Put('user-123', {
  'name': 'John Doe',
  'email': 'john.updated@example.com'
});

// Delete
final deleteResult = await LocalDB.Delete('user-123');
```

## Error Handling

The library uses a Result type system inspired by Rust for better error handling:

```dart
final result = await LocalDB.Post('user-123', userData);
if (result.isOk) {
  final data = result.data;
  // Handle success
} else {
  final error = result.errorOrNull;
  // Handle error
}

// Or using pattern matching
result.when(
  ok: (data) => // Handle success,
  err: (error) => // Handle error
);
```

## ID Format Requirements

- Must be at least 3 characters long
- Can only contain letters, numbers, hyphens (-) and underscores (_)
- Must be unique within the database

## Implementation Details

### Architecture

- **Flutter Layer**: Provides high-level API and type safety
- **FFI Bridge**: Handles communication between Flutter and Rust
- **Rust Core**: Manages the RedB database operations
- **Result Types**: Provides type-safe error handling

### Platform Support

- ✅ Android: `.so` shared library
- ✅ iOS: `.a` static library
- ✅ macOS: `.dylib` dynamic library
- 🚧 Windows: Coming soon
- 🚧 Linux: Coming soon
- 🚧 Web: Coming soon

## Limitations

- Data must be JSON-serializable
- IDs must follow the format requirements
- Platform-specific limitations may apply
- Currently no support for complex queries or indexing
- No automatic migration system

## Contributing

Contributions are welcome! The project uses a dual-language architecture:

- Flutter/Dart for the high-level API and FFI bridge
- Rust for the core database operations

Please ensure you have both Rust and Flutter development environments set up before contributing.

## License

MIT License - see [LICENSE](https://github.com/JhonaCodes/flutter_local_db/LICENSE)

## Author

Made with ❤️ by [JhonaCode](https://github.com/JhonaCodes)