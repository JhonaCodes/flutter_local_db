# Changelog

## 1.5.0

### Added
- **Web Platform Support**: Full IndexedDB backend via `package:web` and `dart:js_interop`
  - New `DatabaseCore` web implementation with complete CRUD operations
  - New `Initializer` web implementation (no-op, no native bindings needed)
  - New `PathHelper` web implementation (database names instead of file paths)
  - Platform-agnostic factory files using `if (dart.library.js_interop)` conditional imports
- **Web platform declaration** in `pubspec.yaml` (`pluginClass: none`)

### Fixed
- **Web `contentHash` persistence**: `_serializeModel` now includes `contentHash` so data integrity hashes survive read/write cycles
- **Web input validation**: Added `_validateKey` and `_validateKeyAndData` to web `DatabaseCore`, matching native validation (max key length, max value size)
- **Web `getAll` null safety**: Added null/undefined checks on `request.result` before casting to `JSArray`, with per-record try/catch for resilience
- **Web `_deserializeModel` robustness**: Timestamps are now parsed optionally (matching `LocalDbModel.fromMap` behavior)

## 1.4.0

### Fixed
- **Rust-Dart Response Parsing**: Fixed response format mismatch between Rust backend and Dart frontend
  - Rust `AppResponse` enum (`{"Ok": "..."}`) now correctly parsed in Dart
  - Added `_parseRustResponse()` helper using Dart 3 pattern matching
- **Model Serialization**: Fixed `LocalDbModel` serialization for Rust compatibility
  - Changed `contentHash` to `hash` in JSON serialization to match Rust model
  - `fromMap()` now supports both formats for backwards compatibility
- **GetAll Operation**: Fixed JSON parsing for list responses from Rust backend
- **Get Operation**: Fixed data parsing when Rust returns JSON string in `Ok` response

### Added
- **Integration Tests**: Added comprehensive integration tests that run with `flutter test`
  - Tests load native library directly from project directory
  - Test output stored in `.test_output/` (gitignored)
  - Full CRUD test coverage: POST, GET, PUT, DELETE, GET ALL, CLEAR
- **Unit Tests**: Added 16 unit tests for `LocalDbModel`, `LocalDbResult`, and `ErrorLocalDb`

### Changed
- Improved test structure: separate unit tests and integration tests
- Updated `flutter_test` and `integration_test` as dev dependencies

## 1.3.0

### Fixed
- **Android 15 Compatibility**: Fixed 16 KB page size alignment issue for Android 15+ devices
  - Native libraries now compiled with `-Wl,-z,max-page-size=16384` flag
  - Resolves "ELF alignment check failed" and "LOAD segment not aligned" errors
  - All architectures (arm64-v8a, armeabi-v7a, x86, x86_64) now properly aligned

### Changed
- Updated native library compilation to use NDK 28
- Code cleanup: removed unnecessary imports in service layer

## 1.2.0
- **Fix Method**: Update post and put method.

## 1.1.0

### Added
- **New FFI Architecture**: Introduced centralized FFI function management through `FfiFunction` enum
- **REST-like API**: Added HTTP-inspired methods (POST, PUT, UPDATE) for more intuitive database operations
- **Enhanced Error Handling**: Improved response parsing with JSON-based communication between Dart and Rust
- **Logger Integration**: Added `logger_rs` for better debugging and monitoring capabilities
- **Path Provider Support**: Integrated `path_provider` for cross-platform file system access

### Changed
- **Refactored FFI Bindings**: Migrated from direct FFI calls to a more maintainable architecture using `FfiFunction` enum
- **Improved Database Core**: Enhanced `DatabaseCore` with better error handling and response parsing
- **Updated Dependencies**: Added Flutter SDK dependency and latest platform-specific packages
- **Rust Communication**: Standardized all Rust function responses to JSON format for consistency

### Improved
- **Type Safety**: Enhanced type safety in FFI layer with centralized function names
- **Error Messages**: More descriptive error messages with contextual information
- **Code Organization**: Better separation of concerns with dedicated FFI functions module
- **Platform Support**: Enhanced cross-platform compatibility with path_provider integration

## 1.0.0

### Added
- Support `Android, IOS, MacOs, Linux`


## 0.9.0

### Added
- Official web platform support using IndexedDB with a unified API across platforms.

## 0.8.0 (Breaking Changes)

⚠️ **BREAKING CHANGES WARNING**  
This version introduces significant simplifications and standardizations. There is no automatic migration or data recovery system available.

### Breaking Changes
- **Standardized Database Naming**: No custom database names allowed. The system now uses a standardized name `flutter_local_db` internally
- **No Data Recovery**: Lost data cannot be recovered if you upgrade from previous versions
- **Simplified Initialization**: The API has been further simplified to reduce user configuration errors
- **Removed Custom Configuration**: All database configuration options have been removed in favor of sensible defaults

### Added
- Standardized database naming for consistency across applications
- Improved error handling with more specific error types
- Enhanced FFI error parsing for better debugging
- Cleaner test suite with improved isolation
- **Rust Backend Migration**: Migrated from redb to LMDB for better performance and stability

### Changed
- Database initialization now uses a fixed, standard database name
- Error messages are more descriptive and developer-friendly
- Rust error format parsing has been updated for better compatibility
- Test suite cleanup and optimization
- **Database Backend**: Replaced redb with LMDB for improved native performance and memory efficiency

### Removed
- Custom database naming capability
- Data migration tools
- Complex configuration options
- Legacy error handling patterns

### Migration Guide
**Warning: No automatic migration is available. Data will be lost.**

1. **Backup your data** before upgrading (if needed)
2. Update initialization code:
   ```dart
   // Old (all previous versions)
   await LocalDB.init(/* any custom config */);
   
   // New (0.8.0+)
   await LocalDB.init(); // No configuration needed
   ```
3. **Accept data loss**: Previous database files will not be accessible
4. Re-populate your database with fresh data

### 0.7.0
#### Added
- Enhanced hot reload support for better development experience
- Comprehensive test suite improvements
- Security enhancements for FFI operations
- Improved error handling and logging

#### Changed
- Enhanced FFI stability and performance
- Better connection management
- Improved memory leak prevention

#### Fixed
- Hot reload issues with database connections
- Memory leaks in FFI layer
- Connection management improvements

### 0.6.0
#### Added
- Full web platform support using IndexedDB
- Hot restart support for development
- Cross-platform unified API

#### Changed
- Improved platform abstraction
- Enhanced web integration
- Better cross-platform compatibility

#### Fixed
- Platform-specific initialization issues
- Web compatibility problems

### 0.5.1
#### Fixed
- Minor bug fixes and improvements
- Enhanced stability

### 0.5.0
#### Added
- Web platform support (IndexedDB integration)
- Unified API across all platforms
- Enhanced cross-platform compatibility

#### Changed
- Improved platform detection and initialization
- Better error handling across platforms

### 0.4.1
- Update description.
- Improve database initialization.
- More test cases.

### 0.4.0

#### Added
- Full compatibility with iOS and macOS platforms
- Compiled Rust binary for multiple iOS architectures
- Dynamic binary support for iOS

#### Changed
- Database file extension defaults to .db when only name is provided
- Improved distribution scripts logic for binary deployment
- Enhanced Rust binary compilation for cross-platform support

#### Fixed
- Compatibility issues with Gradle configuration
- Binary distribution problems across different platforms


### 0.3.0

#### Added
- Full support for iOS arm64 architecture
- Expanded macOS support (arm64/x86_64)
- Additional test cases for data integrity and concurrent operations
- Comprehensive performance testing suite
- Memory leak detection and prevention
- New unit tests for error handling scenarios

#### Changed
- Improved Rust binary management and linking
- Enhanced error handling in FFI layer
- Optimized database operations for better performance
- Updated internal dependencies
- Refactored platform-specific code
- Strengthened type safety in FFI bridge

#### Fixed
- Critical crash on macOS app launch
- Memory leaks in Rust FFI implementation
- Race conditions in concurrent database operations
- Incorrect error propagation in async operations
- Path handling issues on macOS
- Binary loading issues on arm64 architectures

### 0.3.0-alpha.4

#### Changed
- Update changelog.

### 0.3.0-alpha.3

#### Changed
- Update example file.

### 0.3.0-alpha.2

#### Changed
- Completely redesigned changelog format for improved readability and professionalism
- Updated changelog formatting to meet pub.dev best practices
- Enhanced version numbering and date representation
- Improved section organization and language clarity


### 0.3.0-alpha.1

⚠️ **BREAKING CHANGES WARNING**
This version introduces significant architectural changes by replacing the JSON-based storage with LMDB (Lightning Memory-Mapped Database). There is no automatic migration system available. Please ensure you have backed up your data before upgrading, as you will need to manually migrate your existing data to the new format.

#### Breaking Changes
- Removed JSON-based storage in favor of LMDB (Lightning Memory-Mapped Database)
- Removed `ConfigDBModel` and related configurations
- Reduced minimum ID length requirement from 9 to 3 characters
- Removed `MobileDirectoryManager` and directory management abstractions
- Eliminated reactive state management through `local_database_notifier`
- Modified initialization process to require database name
- Removed `Get` method with pagination (use `GetAll` instead)
- Removed `Clean` and `DeepClean` methods
- Transitioned to Result-based error handling

#### Added
- Rust-based core using LMDB embedded database
- FFI bridge for native platform integration
- Result type system for robust error handling
- Cross-platform native libraries:
    - Android: `.so` shared library
    - iOS: `.a` static library
    - macOS: `.dylib` dynamic library
- Type-safe database operations
- Simplified initialization system
- Rust-inspired `Result` types for all operations

#### Changed
- Simplified API focusing on core CRUD operations
- Updated ID validation requirements
- Migrated to async/await for all database operations
- Enhanced error handling with detailed messages
- Improved cross-platform support
- Streamlined initialization process

#### Removed
- Complex configuration options
- Directory management system
- Automatic backup functionality
- Pagination support
- Deep cleaning methods
- State management integration
- Automatic encryption
- Block-based storage system

#### Migration Guide
1. Backup existing data
2. Update initialization code:
   ```dart
   // Old
   await LocalDB.init(
     config: ConfigDBModel(
       maxRecordsPerFile: 2000,
       backupEveryDays: 7,
       hashEncrypt: 'your-16-char-key'
     )
   );

   // New
   await LocalDB.init();
   ```
3. Update CRUD operations to handle Results:
   ```dart
   // Old
   final user = await LocalDB.GetById('user-123');
   
   // New
   final result = await LocalDB.GetById('user-123');
   result.when(
     ok: (user) => print('Found user: ${user?.data}'),
     err: (error) => print('Error: $error')
   );
   ```
4. Remove usage of deprecated features

### 0.2.1
- Updated example documentation

### 0.2.0
#### Added
- Reactive state management with `local_database_notifier`
- `MobileDirectoryManager` for directory operations
- Enhanced singleton pattern initialization

#### Improved
- Comprehensive library documentation
- Simplified initialization process
- Better component separation
- Directory management abstraction

### 0.1.0
#### Added
- Block-based storage system
- Concurrent operation queue
- Platform-specific implementations
- Secure AES encryption
- Backup configuration
- Dedicated directory structure
- ID validation
- JSON validation and size calculation

#### Changed
- Performance improvements with reactive notifiers
- Enhanced error handling and logging
- Upgraded configuration management

#### Fixed
- Concurrent operation race conditions
- Memory leaks in large datasets

### 0.0.2
#### Added
- Initial documentation
- Performance metrics

#### Changed
- Code organization
- Documentation updates

#### Fixed
- Implementation issues
- Documentation typos

### 0.0.1
#### Added
- Initial project structure
- Basic CRUD operations
- File-based storage
- Database interface
- Core implementation
- Error handling
- Initial documentation