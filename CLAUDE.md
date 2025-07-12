# Flutter Local DB - Project Context

## Project Overview
Flutter Local DB is a high-performance cross-platform local database solution for Flutter applications. It provides a unified API that works across all platforms while using optimized backends for each:

- **Native platforms** (Android, iOS, macOS): Rust + RedB embedded database via FFI
- **Web platform**: Native IndexedDB for optimal browser performance

## Architecture
```
Flutter Layer (Dart) - Unified LocalDB API
├── Native Platforms: FFI Bridge → Rust Core (RedB)
└── Web Platform: IndexedDB Bridge → Browser IndexedDB API
```

## Key Features
- ✅ Unified API across all platforms
- ✅ Rust-powered native performance  
- ✅ Web-optimized IndexedDB integration
- ✅ Result types for error handling
- ✅ Async operations
- ✅ Hot restart support (native)

## Project Structure
- `/lib/` - Main Dart implementation
  - `/src/bridge/` - Platform bridges (native FFI & web)
  - `/src/database/` - Database implementations per platform
  - `/src/model/` - Data models and error types
- `/android/` - Android native library integration
- `/ios/` - iOS native library integration  
- `/macos/` - macOS native library integration
- `/example/` - Example Flutter app demonstrating usage
- `/test/` - Test suite including mock, validation, and platform tests

## Current Version
- **Version**: 0.6.0
- **Flutter**: >=3.24.0
- **Dart SDK**: >=3.8.1 <4.0.0

## Development Commands
```bash
# Run tests
flutter test

# Run example app
cd example/app && flutter run

# Build for specific platforms
flutter build android
flutter build ios  
flutter build web
flutter build macos
```

## Platform Support Status
| Platform | Status | Backend |
|----------|--------|---------|
| Android  | ✅ | Rust+RedB (.so) |
| iOS      | ✅ | Rust+RedB (.a) |
| macOS    | ✅ | Rust+RedB (.dylib) |
| Web      | ✅ | IndexedDB |
| Windows  | 🚧 | Coming soon |
| Linux    | 🚧 | Coming soon |

## API Usage Pattern
```dart
// Initialize (same on all platforms)
await LocalDB.init(localDbName: "my_app.db");

// CRUD operations with Result types
final result = await LocalDB.Post('user-123', userData);
result.when(
  ok: (data) => print('Success: ${data.id}'),
  err: (error) => print('Error: $error')
);
```

## Dependencies
- `ffi: ^2.1.3` - For native FFI bridge
- `web: ^1.1.0` - For web platform integration  
- `path_provider: ^2.1.5` - For native file system access
- `logger: ^2.4.0` - For debugging and logging

## Testing Strategy
- Mock database testing
- Platform-specific validation
- Result system testing
- Web-specific IndexedDB testing
- Pure validation without FFI dependencies

## Known Limitations
- Data must be JSON-serializable
- IDs must be 3+ characters, alphanumeric with hyphens/underscores only
- No complex queries or indexing currently
- No automatic migration system
- Binary size impact (~1-2MB per native platform)

## Performance Characteristics
- **Native**: 10,000+ ops/sec, sub-ms latency
- **Web**: 1,000+ ops/sec, ~1-5ms latency