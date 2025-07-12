# Changelog

## [0.6.0] - 2025-07-12

### 🎉 Major Features

#### Hot Reload Recovery System
- **Intelligent Hot Reload Detection**: Multi-strategy detection system that identifies when Flutter hot reload has invalidated FFI connections
- **Automatic Recovery**: Graceful recovery with fallback strategies when connections become stale
- **Enhanced Error Reporting**: Detailed, actionable error messages for development scenarios
- **LocalDbLifecycleManager Widget**: Enhanced widget for comprehensive lifecycle management during development

#### Generation-Based Validation System
- **Instance Generation Tracking**: Rust-based generation system to validate connection integrity
- **Stale Connection Detection**: Automatic detection and cleanup of invalid connections
- **Connection Pool Management**: Smart connection pooling with generation-based validation
- **Heartbeat/Ping Operations**: Health check operations to verify connection responsiveness

#### Enterprise-Grade Logging
- **Standardized Logging Class**: Corporate-standard logging implementation with consistent formatting
- **Security-First Approach**: Sanitized logging that prevents information leakage
- **Multiple Log Levels**: Debug, Info, Warning, Error, and Fatal levels with appropriate usage guidelines
- **Performance Optimized**: Minimal overhead logging system suitable for production use

### 🔧 Technical Improvements

#### Enhanced FFI Stability
- **Connection Validation**: Multiple validation strategies (generation, ping, legacy fallback)
- **Error Recovery**: Robust error handling with automatic reconnection attempts
- **Memory Management**: Improved cleanup and resource management for FFI operations
- **Function Pointer Safety**: Reset and rebinding of function pointers for hot restart compatibility

#### Database Operations
- **Improved Error Handling**: More descriptive error messages with proper categorization
- **Better Validation**: Enhanced ID format validation and data integrity checks
- **Performance Optimizations**: Reduced overhead in database operations
- **Cross-Platform Consistency**: Unified behavior across native and web platforms

### 🧪 Testing Enhancements

#### Comprehensive Test Suite
- **Connection Pool Tests**: Validation of connection management and generation system
- **Hot Reload Recovery Tests**: Edge case testing for development scenarios  
- **Security and Logging Tests**: Verification of secure logging practices and data privacy
- **Performance Benchmarks**: Realistic performance expectations for CI environments
- **Database Cleanup**: Proper test isolation with automatic cleanup

#### Test Infrastructure
- **Improved Test Performance**: Reduced test data sizes and more realistic timeouts
- **Better Test Isolation**: Each test properly cleans up its database state
- **Enhanced Coverage**: Tests for new features including logging, security, and hot reload recovery

### 🔒 Security Enhancements

#### Data Privacy
- **Secure Logging**: No sensitive data (passwords, tokens, personal info) logged
- **Path Sanitization**: File paths sanitized to prevent directory structure exposure
- **Error Message Sanitization**: Generic error messages prevent information leakage
- **Input Validation**: Protection against injection-style attacks

#### Production Readiness
- **Corporate Logging Standards**: Following enterprise logging best practices
- **Security Documentation**: Comprehensive security notes in logging implementation
- **Privacy Compliance**: Design with privacy regulations in mind

### 🐛 Bug Fixes

- **FFI Null Pointer Exceptions**: Resolved crashes during Flutter hot reload
- **Connection State Management**: Fixed stale connection issues in development
- **Memory Leaks**: Improved cleanup of database connections and FFI resources
- **Performance Issues**: Optimized operations to reduce overhead
- **Test Flakiness**: Stabilized test suite with proper cleanup and realistic expectations

### 💥 Breaking Changes

- **Logging Integration**: All internal debug prints replaced with standardized logging
- **Error Handling**: Some error message formats changed for better security
- **Development Dependencies**: Added `logger: ^2.4.0` dependency

### 📦 Dependencies

#### Added
- `logger: ^2.4.0` - Corporate-standard logging implementation

### 🔄 Migration Guide

#### From 0.5.x to 0.6.0

**For most users, this is a drop-in replacement with significant stability improvements.**

1. **Update pubspec.yaml**:
   ```yaml
   dependencies:
     flutter_local_db: ^0.6.0
   ```

2. **Optional: Add Lifecycle Management** (Recommended for development):
   ```dart
   import 'package:flutter_local_db/flutter_local_db.dart';
   
   // Wrap your app with lifecycle management
   MaterialApp(
     home: MyHomePage(),
   ).withLocalDbLifecycle(
     onHotRestart: () => print('Database recovered from hot restart'),
   )
   ```

3. **Optional: Custom Logging** (If you want to integrate with your logging system):
   ```dart
   import 'package:flutter_local_db/src/core/log.dart';
   
   // Use the standardized logging in your app
   Log.i('Application started');
   Log.e('Error occurred', error: exception, stackTrace: stackTrace);
   ```

### 📈 Performance Improvements

- **Reduced Hot Reload Impact**: Faster recovery from development interruptions
- **Optimized Connection Management**: Smart pooling reduces connection overhead
- **Improved Error Handling**: Faster failure detection and recovery
- **Test Performance**: 50-70% faster test execution with optimized test data sizes

### 🏗️ Architecture Changes

#### New Components
- **ConnectionPool**: Manages database connections with generation validation
- **DatabaseConnection**: Encapsulates connection state and metadata  
- **Log**: Standardized logging with security considerations
- **Enhanced LocalDbLifecycleManager**: Widget for automatic hot reload recovery

#### Enhanced Components
- **DatabaseNative**: Improved error handling and connection validation
- **LocalDB**: Better state management and operation reliability
- **Error Handling**: More descriptive and secure error reporting

### 0.5.1
#### Added
- **Web Platform Support**: Full IndexedDB implementation for web platforms
- **Cross-Platform API**: Unified API that works seamlessly across all platforms
- **Smart Backend Selection**: Automatic platform detection (Rust+RedB for native, IndexedDB for web)
- **Web-Optimized Performance**: Native IndexedDB integration without WASM overhead
- **Platform Information**: Built-in platform detection and information display
- **Enhanced Examples**: Updated example app demonstrating cross-platform capabilities

#### Changed
- **Architecture**: Multi-backend architecture with platform-optimized storage solutions
- **Documentation**: Comprehensive documentation explaining technical decisions and platform differences
- **API Exports**: Added missing exports for `LocalDbModel`, `ErrorLocalDb`, and `LocalDbResult` types
- **Example App**: Enhanced UI showing current platform and storage backend information

#### Fixed
- **Web Compatibility**: Resolved all web platform compatibility issues
- **Type Exports**: Fixed missing type exports in main library file
- **Analysis Warnings**: Cleaned up all Dart analyzer warnings and lints
- **IndexedDB Integration**: Proper JavaScript interop and data conversion
- **Cross-Platform Initialization**: Seamless initialization across all supported platforms

#### Technical Details
- **Native Platforms**: Continue using Rust + RedB for optimal performance
- **Web Platform**: Uses IndexedDB for browser-native performance and compatibility
- **WASM Alternative**: Chose IndexedDB over WASM for better bundle size and performance
- **API Consistency**: Same Dart API works identically on all platforms
- **Error Handling**: Unified error handling across different backend implementations

### 0.5.0
#### Added
- **Hot Restart Support**: Complete solution for preventing crashes during Flutter hot restart
- **Memory Management**: Proper FFI memory cleanup with `free_c_string()` function
- **Connection Validation**: Enhanced connection state validation and automatic recovery
- **Lifecycle Manager Widget**: `LocalDbLifecycleManager` for automatic hot restart handling
- **Database Close Function**: Manual database closure capability with `LocalDB.CloseDatabase()`
- **Connection State Check**: `LocalDB.IsConnectionValid()` for debugging connection issues
- **Transaction Timeouts**: Built-in timeout handling for long-running database operations
- **Reference Counting**: AppDbState instance tracking to prevent use-after-free errors

#### Changed
- **Enhanced Error Handling**: Better error recovery and automatic reconnection
- **Improved FFI Safety**: All C string responses are now properly freed
- **Transaction Safety**: Added timeout checks to prevent hanging transactions
- **Connection Resilience**: Automatic cleanup and reconnection on connection failure

#### Fixed
- **Hot Restart Crashes**: Fixed critical crashes when performing hot restart in Android/iOS
- **Memory Leaks**: Resolved FFI memory leaks in C string handling
- **File Lock Issues**: Proper cleanup of ReDB file locks and resources
- **Dangling Pointers**: Eliminated use of invalid database pointers after restart

#### Performance
- **Optimized Reconnection**: Faster automatic database reconnection
- **Transaction Monitoring**: Performance logging for slow operations
- **Resource Cleanup**: Efficient cleanup of native resources

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
This version introduces significant architectural changes by replacing the JSON-based storage with RedB (Rust Embedded Database). There is no automatic migration system available. Please ensure you have backed up your data before upgrading, as you will need to manually migrate your existing data to the new format.

#### Breaking Changes
- Removed JSON-based storage in favor of RedB (Rust Embedded Database)
- Removed `ConfigDBModel` and related configurations
- Reduced minimum ID length requirement from 9 to 3 characters
- Removed `MobileDirectoryManager` and directory management abstractions
- Eliminated reactive state management through `local_database_notifier`
- Modified initialization process to require database name
- Removed `Get` method with pagination (use `GetAll` instead)
- Removed `Clean` and `DeepClean` methods
- Transitioned to Result-based error handling

#### Added
- Rust-based core using RedB embedded database
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
   await LocalDB.init(localDbName: "my_app_db");
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