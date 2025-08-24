# flutter_local_db

A high-performance cross-platform local database for Dart. Native platforms use Rust+LMDB via FFI, optimized for both Dart APIs and Flutter apps.

## Platform Setup

### Android
Copy the `.so` files to your Flutter project:
```bash
# Create directories
mkdir -p android/app/src/main/jniLibs/{arm64-v8a,armeabi-v7a,x86,x86_64}

# Copy binaries from package location
cp plugins/binaries/android/arm64-v8a/liboffline_first_core.so android/app/src/main/jniLibs/arm64-v8a/
cp plugins/binaries/android/armeabi-v7a/liboffline_first_core.so android/app/src/main/jniLibs/armeabi-v7a/
cp plugins/binaries/android/x86/liboffline_first_core.so android/app/src/main/jniLibs/x86/
cp plugins/binaries/android/x86_64/liboffline_first_core.so android/app/src/main/jniLibs/x86_64/
```

### iOS
No additional setup required. The library uses static linking.

### macOS, Linux, Windows
No additional setup required. Binaries are loaded automatically from the package.

## Usage

```dart
import 'package:flutter_local_db/flutter_local_db.dart';

// Initialize database
await LocalDB.init();

// Create a record
final result = await LocalDB.Post('user_1', {'name': 'John', 'age': 30});
result.when(
  ok: (model) => print('Created: ${model.id}'),
  err: (error) => print('Error: $error'),
);

// Get a record
final getResult = await LocalDB.GetById('user_1');
getResult.when(
  ok: (model) => print('Found: ${model?.data}'),
  err: (error) => print('Error: $error'),
);
```
