# Flutter Local DB

A high-performance cross-platform local database for Flutter with **unified API** across all platforms. Uses Rust's RedB embedded database through FFI for native platforms and IndexedDB for web, providing optimal performance on each platform while maintaining the same developer experience.

![flutter_local_db](https://github.com/user-attachments/assets/09c97008-cfc6-4588-b54c-5737ad00e9e4)

## Features

🔄 **Unified API**: Same code works on all platforms - write once, run everywhere  
🦀 **Rust Powered Native**: Uses [RedB](https://docs.rs/redb/latest/redb) embedded database for maximum performance on mobile/desktop  
🌐 **Web Optimized**: Native IndexedDB integration for optimal web performance  
🎯 **Simple API**: Store and retrieve JSON data with minimal code, [FFI-DART](https://github.com/JhonaCodes/offline_first_core)  
🛡️ **Result Types**: Rust-inspired Result types for better error handling  
📱 **True Cross-Platform**: Android, iOS, macOS, and Web with platform-optimized backends  
⚡ **Async Operations**: All database operations are asynchronous  
🔍 **Smart Backend Selection**: Automatically chooses the best storage solution per platform

## Platform Architecture

### Why Different Backends?

Flutter Local DB uses different storage backends optimized for each platform:

#### Native Platforms (Android, iOS, macOS)
- **Backend**: Rust + RedB embedded database via FFI
- **Why**: Maximum performance, memory efficiency, and reliability
- **Benefits**: 
  - Zero-copy operations
  - ACID transactions
  - Minimal memory footprint
  - No external dependencies

#### Web Platform
- **Backend**: Native IndexedDB
- **Why**: RedB (Rust) doesn't compile to WebAssembly efficiently, and WASM has limitations
- **Benefits**:
  - Browser-native performance
  - No WASM overhead
  - Smaller bundle size
  - Better browser compatibility
  - Leverages browser optimizations

### Technical Reasons for IndexedDB on Web

1. **WASM Limitations**: 
   - RedB requires file system access not available in browsers
   - WASM compilation adds significant bundle size
   - Performance overhead of WASM bridge calls

2. **IndexedDB Advantages**:
   - Asynchronous by design (perfect for Flutter)
   - Handles large datasets efficiently
   - Built-in browser security and sandboxing
   - No additional dependencies or compile steps

3. **Unified API**: Despite different backends, the same Dart API works everywhere

## Installation

Add to your pubspec.yaml:

```yaml
dependencies:
  flutter_local_db: ^0.5.0
```

## Basic Usage

### Cross-Platform Initialization

The same initialization code works on all platforms:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Same API, different optimized backends:
  // - Native: Rust + RedB 
  // - Web: IndexedDB
  await LocalDB.init(localDbName: "my_app.db");
  
  runApp(MyApp());
}
```

### Platform-Aware Initialization (Optional)

```dart
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (kIsWeb) {
    await LocalDB.init(localDbName: 'my_web_app'); // IndexedDB
    print('Using IndexedDB for web storage');
  } else {
    await LocalDB.init(localDbName: 'my_app.db'); // Rust + RedB
    print('Using Rust + RedB for native storage');
  }
  
  runApp(MyApp());
}
```

### CRUD Operations (Same API Everywhere)

```dart
// Create - Works identically on all platforms
final result = await LocalDB.Post('user-123', {
  'name': 'John Doe',
  'email': 'john@example.com',
  'metadata': {
    'lastLogin': DateTime.now().toIso8601String(),
    'platform': kIsWeb ? 'web' : 'native'
  }
});

// Handle result (same Result type on all platforms)
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

// Clear all data
final clearResult = await LocalDB.ClearData();
```

## Platform-Specific Examples

### Web-Specific Features

```dart
// Web: Leverages IndexedDB transactions
await LocalDB.Post('web-optimized', {
  'browserInfo': kIsWeb ? 'Modern browser' : 'Not applicable',
  'storageType': 'IndexedDB',
  'features': ['transactions', 'indexed_queries', 'blob_support']
});
```

### Native-Specific Features

```dart
// Native: Leverages Rust performance
await LocalDB.Post('native-optimized', {
  'platformInfo': !kIsWeb ? Platform.operatingSystem : 'Not applicable',
  'storageType': 'RedB',
  'features': ['zero_copy', 'memory_mapped', 'acid_transactions']
});
```

## Error Handling

The library uses a Result type system inspired by Rust for better error handling across all platforms:

```dart
final result = await LocalDB.Post('user-123', userData);
if (result.isOk) {
  final data = result.data;
  // Handle success - same on web and native
} else {
  final error = result.errorOrNull;
  // Handle error - same error types across platforms
}

// Or using pattern matching
result.when(
  ok: (data) => // Handle success,
  err: (error) => // Handle error
);
```

## Hot Restart Support

Works on native platforms (web doesn't need this as it doesn't use FFI):

```dart
import 'package:flutter_local_db/flutter_local_db.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDB.init(localDbName: "my_app.db");
  
  runApp(MyApp().withLocalDbLifecycle());
}

// Or manually
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDB.init(localDbName: "my_app.db");
  
  runApp(
    LocalDbLifecycleManager(
      child: MyApp(),
      onHotRestart: () => print('Hot restart detected - native only'),
    ),
  );
}
```

### Manual Connection Management

```dart
// Check if connection is valid (works on all platforms)
final isValid = await LocalDB.IsConnectionValid();

// Manually close database (useful for native platforms)
await LocalDB.CloseDatabase();

// Connection will be automatically re-established on next operation
final result = await LocalDB.GetById('some-id');
```

## Performance Characteristics

### Native Platforms (Rust + RedB)
- **Throughput**: 10,000+ operations/second
- **Memory**: Minimal overhead, memory-mapped files
- **Latency**: Sub-millisecond for simple operations
- **Storage**: Efficient binary format

### Web Platform (IndexedDB)
- **Throughput**: 1,000+ operations/second (browser dependent)
- **Memory**: Browser-managed, optimized for web
- **Latency**: ~1-5ms per operation
- **Storage**: Browser-optimized, handles large objects well

## ID Format Requirements

- Must be at least 3 characters long
- Can only contain letters, numbers, hyphens (-) and underscores (_)
- Must be unique within the database

## Implementation Details

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter Layer (Dart)                    │
│                  Unified LocalDB API                       │
├─────────────────────────────────────────────────────────────┤
│                Platform Detection Layer                    │
├─────────────────────┬───────────────────────────────────────┤
│   Native Platforms  │            Web Platform              │
│                     │                                      │
│  ┌─────────────────┐│  ┌─────────────────────────────────┐ │
│  │   FFI Bridge    ││  │    IndexedDB Bridge             │ │
│  │                 ││  │                                 │ │
│  │ ┌─────────────┐ ││  │ ┌─────────────────────────────┐ │ │
│  │ │ Rust Core   │ ││  │ │      IndexedDB API          │ │ │
│  │ │   (RedB)    │ ││  │ │   (Browser Native)          │ │ │
│  │ └─────────────┘ ││  │ └─────────────────────────────┘ │ │
│  └─────────────────┘│  └─────────────────────────────────┘ │
└─────────────────────┴───────────────────────────────────────┘
```

### Platform Support Matrix

| Platform | Backend | Status | Library Type | Performance |
|----------|---------|--------|--------------|-------------|
| Android  | Rust+RedB | ✅ | `.so` shared library | Excellent |
| iOS      | Rust+RedB | ✅ | `.a` static library | Excellent |
| macOS    | Rust+RedB | ✅ | `.dylib` dynamic library | Excellent |
| Web      | IndexedDB | ✅ | Native browser API | Very Good |
| Windows  | Rust+RedB | 🚧 | Coming soon | - |
| Linux    | Rust+RedB | 🚧 | Coming soon | - |

### Why This Architecture?

1. **Best of Both Worlds**: Native performance where possible, web-optimized where needed
2. **Single API**: Developers don't need to learn different APIs for different platforms
3. **Optimal Performance**: Each platform uses its most efficient storage solution
4. **Future Proof**: Easy to add new platforms or optimize existing ones
5. **No Compromises**: Avoid the "lowest common denominator" approach

## Limitations

### General
- Data must be JSON-serializable
- IDs must follow the format requirements
- Currently no support for complex queries or indexing
- No automatic migration system

### Platform-Specific

#### Native (Rust + RedB)
- Requires FFI support
- Binary size impact (~1-2MB per platform)

#### Web (IndexedDB)
- Browser storage quotas apply
- No file system access
- Dependent on browser IndexedDB implementation

## Migration Guide

If you're migrating from a version without web support:

```dart
// Before (native only)
await LocalDB.init(localDbName: "my_app.db");

// After (cross-platform)
await LocalDB.init(localDbName: "my_app.db"); // Same API!

// Optional: Platform-specific naming
if (kIsWeb) {
  await LocalDB.init(localDbName: "my_web_app");
} else {
  await LocalDB.init(localDbName: "my_app.db");
}
```

## Contributing

Contributions are welcome! The project uses a multi-language architecture:

- **Flutter/Dart**: High-level API, platform detection, and bridges
- **Rust**: Core database operations for native platforms
- **Web APIs**: IndexedDB integration for web platform

Please ensure you have both Rust and Flutter development environments set up before contributing to native features.

## Roadmap

- [ ] Windows support (Rust + RedB)
- [ ] Linux support (Rust + RedB)
- [ ] Query optimization
- [ ] Data migration system
- [ ] Encryption support
- [ ] Batch operations
- [ ] Reactive streams/observables

## License

MIT License - see [LICENSE](https://github.com/JhonaCodes/flutter_local_db/LICENSE)

## Author

Made with ❤️ by [JhonaCode](https://github.com/JhonaCodes)

---

*Flutter Local DB: Write once, run everywhere - with optimal performance on every platform.*