# Flutter Local DB v0.1.0

A high-performance local database for Flutter that provides simple JSON storage with a powerful underlying architecture. Designed for efficient data persistence with automatic block management and smart indexing.

## Features

- 🚀 **High Performance**: O(1) access times through smart indexing and caching
- 🎯 **Simple API**: Store and retrieve JSON data with minimal code
- 🛡️ **Fault Tolerant**: Block-based architecture prevents total data corruption
- 📦 **Smart Storage**: Automatic block management and space optimization
- 🔐 **Secure Storage**: Optional encryption for sensitive data
- 🔄 **Async Queue**: Built-in request queue management
- 📱 **Cross-Platform**: Works on mobile, desktop and web(soon)

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_local_db: ^0.1.0
```

## Basic Usage

### Initialize Database

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize with default configuration
  await LocalDB.init();
  
  // Or initialize with custom configuration
  await LocalDB.init(
    config: ConfigDBModel(
      maxRecordsPerFile: 2000,
      backupEveryDays: 7,
      hashEncrypt: 'your-16-char-key'
    )
  );
  
  runApp(MyApp());
}
```

### CRUD Operations

```dart
// Create
await LocalDB.Post('user-123456789', {
  'name': 'John Doe',
  'email': 'john@example.com',
  'metadata': {
    'lastLogin': DateTime.now().toIso8601String(),
    'preferences': {'theme': 'dark'}
  }
});

// Read single record
final user = await LocalDB.GetById('user-123456789');

// Read multiple records with pagination
final users = await LocalDB.Get(limit: 20);

// Update
await LocalDB.Put('user-123456789', {
  'name': 'John Doe',
  'email': 'john.doe@example.com',
  'metadata': {
    'lastLogin': DateTime.now().toIso8601String(),
    'preferences': {'theme': 'light'}
  }
});

// Delete
await LocalDB.Delete('user-123456789');

// Clear all records
await LocalDB.Clean();

// Deep clean (resets database)
await LocalDB.DeepClean();
```

## Advanced Configuration

### ConfigDBModel

```dart
final config = ConfigDBModel(
  // Maximum records per storage block
  maxRecordsPerFile: 2000,
  
  // Days between automatic backups (0 = disabled)
  backupEveryDays: 7,
  
  // Encryption key (must be 16 characters)
  hashEncrypt: 'your-16-char-key'
);
```

## Directory Structure

```
local_database/
├── active/          # Current data blocks
│   ├── index.json  # Global index
│   └── blocks/     # Data blocks by prefix
├── sealed/         # Immutable data
├── secure/         # Encrypted data
├── backup/         # Automatic backups
├── historical/     # Archived data
└── sync/          # Sync metadata
```

## Implementation Examples

### Basic Data Storage
```dart
class UserPreferences {
  static Future<void> savePreferences(Map<String, dynamic> prefs) async {
    await LocalDB.Post('prefs-${DateTime.now().millisecondsSinceEpoch}', prefs);
  }

  static Future<List<DataLocalDBModel>> getPreferences() async {
    return await LocalDB.Get(limit: 1);
  }
}
```

### Caching API Responses
```dart
class ApiCache {
  static Future<void> cacheResponse(String endpoint, Map<String, dynamic> data) async {
    final cacheId = 'cache-${endpoint.hashCode}';
    await LocalDB.Post(cacheId, {
      'endpoint': endpoint,
      'timestamp': DateTime.now().toIso8601String(),
      'data': data
    });
  }

  static Future<DataLocalDBModel?> getCachedResponse(String endpoint) async {
    try {
      return await LocalDB.GetById('cache-${endpoint.hashCode}');
    } catch (e) {
      return null;
    }
  }
}
```

## Performance Considerations

- **ID Format**: IDs must be alphanumeric and at least 9 characters long
- **Block Size**: Default 2000 records per block for optimal performance
- **Pagination**: Use appropriate limit values to avoid loading unnecessary data
- **Encryption**: Adds slight overhead when enabled
- **Queuing**: Operations are automatically queued to prevent conflicts

## Error Handling

```dart
try {
  await LocalDB.Post('invalid-id', data);
} catch (e) {
  print('Error: Invalid ID format');
}

try {
  final data = await LocalDB.GetById('non-existent');
} catch (e) {
  print('Error: Record not found');
}
```

## Limitations

- IDs must be at least 9 characters long
- JSON serialization required for stored data
- Encryption key must be exactly 16 characters
- Web storage limited by browser constraints


## Contribution

Contributions are welcome! If you have ideas for new features or improvements, please open an [issue](https://github.com/JhonaCodes/flutter_local_db/issues) or submit a pull request.

1. Fork the repository.
2. Create a new branch (`git checkout -b feature/new-feature`).
3. Commit your changes (`git commit -am 'Add new feature'`).
4. Push to the branch (`git push origin feature/new-feature`).
5. Open a pull request.

## License

MIT License - see [LICENSE](https://github.com/JhonaCodes/flutter_local_db/LICENSE)

## Author

Made with ❤️ by [JhonaCode](https://github.com/JhonaCodes)