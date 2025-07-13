# Changelog

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