# Changelog

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