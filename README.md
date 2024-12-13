# Flutter Local DB

A high-performance local database for Flutter that provides incredible simplicity with powerful underlying architecture. Store any JSON data with just an ID string and let the system handle all the complexity for you.

## Why Flutter Local DB?

- 🎯 **Ultimate Simplicity**: Store any JSON with just an ID
- ⚡ **Lightning Fast**: O(1) access times through smart indexing
- 🛡️ **Fault Tolerant**: Corrupted file? No problem, only affects that block
- 📦 **Infinitely Scalable**: No practical size limits thanks to block architecture
- 🔍 **Smart Storage**: Automatic block management and space optimization
- 🚀 **Zero Config**: Just initialize and start using

## Installation

```yaml
dependencies:
  flutter_local_db: ^0.0.2
```

## Quick Start

### 1. Initialize
```dart
void main() async {
  await LocalDB.init();
  runApp(MyApp());
}
```

### 2. Store Data
```dart
// Store any JSON data with just an ID
await LocalDB.Post('user_123', {
  'name': 'John Doe',
  'age': 30,
  'preferences': {
    'theme': 'dark',
    'notifications': true
  },
  'scores': [100, 95, 98]
});
```

### 3. Retrieve Data
```dart
// Get by ID - Lightning fast O(1) operation
final userData = await LocalDB.GetById('user_123');

// Get multiple records with pagination
final records = await LocalDB.Get(limit: 20, offset: 0);
```

### 4. Update Data
```dart
// Simply provide the ID and updated data
await LocalDB.Put('user_123', {
  'name': 'John Doe',
  'age': 31,  // Updated age
  'preferences': {
    'theme': 'light'  // Changed theme
  }
});
```

### 5. Delete Data
```dart
// Delete single record
await LocalDB.Delete('user_123');

// Clear database
await LocalDB.Clean();
```

## Why It's Amazing

### 🎯 Built for Simplicity
Store any JSON structure you want - the system handles all the complexity:
```dart
// Store simple data
await LocalDB.Post('settings', {'theme': 'dark'});

// Store complex nested structures
await LocalDB.Post('gameState', {
  'player': {
    'position': {'x': 100, 'y': 200},
    'inventory': ['sword', 'shield'],
    'stats': {
      'health': 100,
      'mana': 50,
      'skills': ['jump', 'run']
    }
  }
});
```

### ⚡ Smart Architecture
```
local_database/
├── active/          # Active data
    ├── ab/         # Smart hash prefixing
        ├── index   # Fast lookup index
        └── block   # Isolated data block
    └── cd/         # Another prefix
└── backup/         # Automatic backups
```

### 🛡️ Fault Tolerance
- Each record is stored in isolated blocks
- If one file corrupts, other data remains safe
- Automatic block management and optimization

### 🚀 High Performance
- O(1) access time for any record
- Smart caching system
- Efficient space management
- Distributed block structure

## Real World Example

```dart
class GameSaveSystem {
  // Save game state
  Future<void> saveGame(String saveId, Map<String, dynamic> gameState) async {
    await LocalDB.Post(saveId, gameState);
  }

  // Load game state
  Future<Map<String, dynamic>> loadGame(String saveId) async {
    return await LocalDB.GetById(saveId);
  }

  // Update specific game data
  Future<void> updateGameState(String saveId, Map<String, dynamic> newState) async {
    await LocalDB.Put(saveId, newState);
  }
}
```

## Benefits at Scale

- **Infinite Scalability**: No practical size limits thanks to block-based architecture
- **Fast Regardless of Size**: O(1) access time whether you have 10 or 10 million records
- **Space Efficient**: Smart block management and automatic optimization
- **Data Safety**: Corruption in one file never affects other data
- **Memory Efficient**: Loads only what you need, when you need it

Perfect for:
- Game save systems
- User preferences
- Cached API responses
- Offline data storage
- And much more!

## Contributing

Contributions are welcome! If you find a bug or want a feature, please file an issue. Feel free to make a pull request if you want to contribute code.

## Testing
```dart
flutter test
```

## Example
A complete example can be found in the `/example` directory.


## Contribution

Contributions are welcome! If you have ideas for new features or improvements, please open an [issue](https://github.com/JhonaCodes/flutter_local_db/issues) or submit a pull request.

1. Fork the repository.
2. Create a new branch (`git checkout -b feature/new-feature`).
3. Commit your changes (`git commit -am 'Add new feature'`).
4. Push to the branch (`git push origin feature/new-feature`).
5. Open a pull request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author
Made with ❤️ by [JhonaCodes](https://github.com/JhonaCodes)