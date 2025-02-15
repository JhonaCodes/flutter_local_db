# Changelog

# Changelog

## [0.3.0-alpha.1] - February 16, 2025

⚠️ **BREAKING CHANGES WARNING**
This version introduces significant architectural changes by replacing the JSON-based storage with RedB (Rust Embedded Database). There is no automatic migration system available. Please ensure you have backed up your data before upgrading, as you will need to manually migrate your existing data to the new format.

### Breaking Changes
- Removed JSON-based storage in favor of RedB (Rust Embedded Database)
- Removed `ConfigDBModel` and its related configurations
- Changed minimum ID length requirement from 9 to 3 characters
- Removed `MobileDirectoryManager` and directory management abstractions
- Removed reactive state management through `local_database_notifier`
- Changed initialization process to require database name
- Removed `Get` method with pagination (use `GetAll` instead)
- Removed `Clean` and `DeepClean` methods
- Changed error handling to use Result types

### Added
- New Rust-based core using RedB embedded database
- FFI bridge for native platform integration
- Result type system for better error handling
- Cross-platform native libraries:
    - Android: `.so` shared library
    - iOS: `.a` static library
    - macOS: `.dylib` dynamic library
- Type-safe database operations with error handling
- New initialization system with database name parameter
- Rust-inspired `Result` types for all operations

### Changed
- Simplified API to focus on core CRUD operations
- Updated ID validation to require minimum 3 characters
- Moved to async/await for all database operations
- Improved error handling with detailed error messages
- Enhanced cross-platform support
- Streamlined initialization process

### Removed
- Complex configuration options
- Directory management system
- Automatic backup system
- Pagination support
- Deep cleaning functionality
- State management integration
- Automatic encryption
- Block-based storage system

### Migration Guide
1. Backup your existing data
2. Update your initialization code:
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
3. Update your CRUD operations to handle Results:
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
4. Remove any usage of removed features:
    - Pagination
    - Clean/DeepClean
    - ConfigDBModel
    - Directory management
    - State management

## [0.2.1] - December 15, 2024
- Update example.

## [0.2.0] - December 15, 2024

### Added
- New `local_database_notifier` for reactive state management
- Initial implementation of `MobileDirectoryManager` to handle directory operations
- Enhanced singleton pattern enforcement after initialization

### Improved
- Comprehensive code documentation across the library
- Significantly simplified initialization process
- Better separation of concerns in core components
- Directory management abstraction with dedicated handlers

## [0.1.0] - 2024-12-15
### Added
- Advanced block-based storage system
- Queue system for managing concurrent operations
- Platform-specific implementations (web/device)
- Secure storage option with AES encryption
- Backup configuration system
- Directory structure with dedicated paths
- ID validation with regex pattern
- JSON validation and size calculation
- Automatic block management

### Changed
- Enhanced performance with reactive notifiers
- Improved error handling and logging
- Upgraded configuration management

### Fixed
- Race conditions in concurrent operations
- Memory leaks in large dataset handling

## [0.0.2] - 2024-12-01
### Added
- Basic documentation structure
- Initial performance metrics

### Changed
- Code organization improvements
- Documentation updates
- Minor optimizations

### Fixed
- Basic implementation issues
- Documentation typos

## [0.0.1] - 2024-11-15
### Added
- Initial project structure
- Basic CRUD operations
- Simple file-based storage
- Fundamental database interface
- Core implementation scaffold
- Basic error handling
- Initial documentation

### Note
- Initial release under construction
- Core functionality implementation
- Foundation for future features

