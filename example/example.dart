// example/example.dart

import '../lib/flutter_local_db.dart';

Future<void> main() async {
  print('🚀 Flutter LocalDB Example - Starting...');
  
  // Inicializar base de datos
  try {
    await LocalDB.init('example_db');
    print('✅ Database initialized successfully');
  } catch (e) {
    print('❌ Initialization failed: $e');
    return;
  }
  
  // Limpiar datos previos
  await LocalDB.ClearData();
  
  print('\n📝 Testing CRUD operations...');
  
  // CREATE - Insertar nuevo usuario
  print('\n1️⃣ Creating new user...');
  final createResult = await LocalDB.Post('user-123', {
    'name': 'John Doe',
    'email': 'john@example.com',
    'age': 30,
    'preferences': {
      'theme': 'dark',
      'language': 'en'
    }.toString() // Convertir a string para simplificar serialización
  });
  
  createResult.when(
    ok: (entry) => print('✅ User created: ${entry.id} - ${entry.data}'),
    err: (error) => print('❌ Create failed: $error')
  );
  
  // READ - Obtener usuario por ID
  print('\n2️⃣ Reading user by ID...');
  final readResult = await LocalDB.GetById('user-123');
  
  readResult.when(
    ok: (entry) {
      if (entry != null) {
        print('✅ User found: ${entry.id}');
        print('   Name: ${entry.data['name']}');
        print('   Email: ${entry.data['email']}');
      } else {
        print('⚠️ User not found');
      }
    },
    err: (error) => print('❌ Read failed: $error')
  );
  
  // UPDATE - Actualizar usuario existente
  print('\n3️⃣ Updating user...');
  final updateResult = await LocalDB.Put('user-123', {
    'name': 'John Smith',  // Nombre actualizado
    'email': 'john.smith@example.com',
    'age': 31,
    'status': 'updated'
  });
  
  updateResult.when(
    ok: (entry) => print('✅ User updated: ${entry.data}'),
    err: (error) => print('❌ Update failed: $error')
  );
  
  // Crear múltiples usuarios
  print('\n4️⃣ Creating multiple users...');
  final users = [
    {'id': 'user-456', 'name': 'Jane Doe', 'role': 'admin'},
    {'id': 'user-789', 'name': 'Bob Wilson', 'role': 'user'},
    {'id': 'user-101', 'name': 'Alice Johnson', 'role': 'moderator'},
  ];
  
  for (final userData in users) {
    final result = await LocalDB.Post(userData['id']!, {
      'name': userData['name'],
      'role': userData['role'],
      'created_at': DateTime.now().millisecondsSinceEpoch.toString(),
    });
    
    result.when(
      ok: (entry) => print('✅ Created: ${entry.id}'),
      err: (error) => print('❌ Failed to create ${userData['id']}: $error')
    );
  }
  
  // LIST - Obtener todos los usuarios
  print('\n5️⃣ Getting all users...');
  final allResult = await LocalDB.GetAll();
  
  allResult.when(
    ok: (entries) {
      print('✅ Found ${entries.length} users:');
      for (final entry in entries) {
        print('   - ${entry.id}: ${entry.data['name']} (${entry.data['role'] ?? 'N/A'})');
      }
    },
    err: (error) => print('❌ GetAll failed: $error')
  );
  
  // DELETE - Eliminar usuario
  print('\n6️⃣ Deleting user...');
  final deleteResult = await LocalDB.Delete('user-456');
  
  deleteResult.when(
    ok: (success) => print('✅ User deleted successfully'),
    err: (error) => print('❌ Delete failed: $error')
  );
  
  // Verificar eliminación
  print('\n7️⃣ Verifying deletion...');
  final verifyResult = await LocalDB.GetById('user-456');
  
  verifyResult.when(
    ok: (entry) => print(entry != null ? '⚠️ User still exists!' : '✅ User successfully deleted'),
    err: (error) => print('❌ Verification failed: $error')
  );
  
  // Mostrar usuarios restantes
  print('\n8️⃣ Remaining users:');
  final finalResult = await LocalDB.GetAll();
  
  finalResult.when(
    ok: (entries) {
      print('✅ ${entries.length} users remaining:');
      for (final entry in entries) {
        print('   - ${entry.id}: ${entry.data}');
      }
    },
    err: (error) => print('❌ Final query failed: $error')
  );
  
  // CLEAR - Limpiar todos los datos
  print('\n9️⃣ Clearing all data...');
  final clearResult = await LocalDB.ClearData();
  
  clearResult.when(
    ok: (success) => print('✅ All data cleared'),
    err: (error) => print('❌ Clear failed: $error')
  );
  
  // Verificar limpieza
  final emptyResult = await LocalDB.GetAll();
  emptyResult.when(
    ok: (entries) => print('✅ Database empty: ${entries.length} entries'),
    err: (error) => print('❌ Verification failed: $error')
  );
  
  // Cerrar base de datos
  await LocalDB.close();
  print('\n🏁 Example completed successfully!');
}