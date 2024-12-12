# flutter_local_db "Under construction"

A efficient local storage system for Flutter applications that implements Copy-on-Write (CoW) for data integrity and provides optimized containers for different data states.

## Features

- 📦 Multiple storage containers for different data states (active, sealed, secure, backup)
- 🔒 Built-in security for sensitive data
- 🔄 Copy-on-Write (CoW) for safe data updates
- 📈 O(1) access time for data retrieval
- 🗄️ Automatic data lifecycle management
- 💾 Configurable backup and retention policies

## Getting Started

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_local_db: ^0.0.1
```

## Usage

Basic usage example:

```dart
import 'package:flutter_local_db/local_db.dart';

void main()async{
  await LocalDB.init();
  .......
}


// save data
await LocalDB.Post('key', Map);

// Store sensitive data
await LocalDB.Post('sensitive_key', sensitiveData, isSecure: true);

ALERT!! UNDER CONSTRUCTION

```

## Storage Types

- **Active**: For frequently accessed and modified data
- **Sealed**: For completed, immutable data
- **Secure**: For encrypted, sensitive information
- **Backup**: For automated data backups
- **Historical**: For version control and obsolete data
- **Sync**: For offline first applications

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## This is a initial empty commit I will upload the first version soon. Give it a like to know how much you are interested and to motivate me.

