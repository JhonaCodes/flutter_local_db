import 'package:flutter/material.dart';
import 'package:flutter_local_db/flutter_local_db.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDB.init(localDbName: 'example_local_db');
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Local DB Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String userID = 'user-123';

  Future<void> _createUser() async {
    final result = await LocalDB.Post(userID, {
      'name': 'John Doe',
      'email': 'john@example.com',
      'createdAt': DateTime.now().toIso8601String(),
    });

    result.when(
      ok: (data) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User created: ${data.id}')),
      ),
      err: (error) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      ),
    );

    setState(() {});
  }

  Future<void> _deleteUser() async {
    final result = await LocalDB.Delete(userID);

    result.when(
      ok: (success) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? 'User deleted' : 'Delete failed')),
      ),
      err: (error) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      ),
    );

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local DB Example'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder(
          future: LocalDB.GetById(userID),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasData) {
              return snapshot.data!.when(
                ok: (userData) => userData == null
                    ? const Center(child: Text('No user found'))
                    : Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('ID: ${userData.id}'),
                              Text('Data: ${userData.data}'),
                            ],
                          ),
                        ),
                      ),
                err: (error) => Center(
                  child: Text('Error: $error',
                      style: const TextStyle(color: Colors.red)),
                ),
              );
            }

            return const Center(child: Text('No data'));
          },
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _deleteUser,
            child: const Icon(Icons.delete),
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            onPressed: _createUser,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
