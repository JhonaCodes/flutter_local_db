import 'package:flutter/material.dart';
import 'package:flutter_local_db/flutter_local_db.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();


  /// Local db initialization.
  await LocalDB.init(config: const ConfigDBModel(maxRecordsPerFile: 5));

  runApp(const ExampleLocalDb());
}

class ExampleLocalDb extends StatelessWidget {
  const ExampleLocalDb({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter local db',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("Local database"),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              FutureBuilder(
                future: LocalDB.Get(),
                builder: (context, snapShot) {
                  if (snapShot.hasData) {
                    return SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (snapShot.data != null)
                            ...snapShot.data!.map((data) {
                              return Text(data.id);
                            })
                        ],
                      ),
                    );
                  }

                  if (snapShot.hasError) {
                    return Text(
                      "Error ${snapShot.error.toString()}",
                      style: const TextStyle(color: Colors.red),
                    );
                  }

                  return Center(
                    child: Transform.scale(
                        scale: 0.5,
                        child: const LinearProgressIndicator(
                          color: Colors.red,
                        )),
                  );
                },
              )
            ],
          ),
        ),
      ),

      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 10, right: 10.0, left: 30),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FloatingActionButton(
              onPressed: () async {},
              child: const Text('Encrypt'),
            ),
            FloatingActionButton(
              onPressed: () async {
                await LocalDB.Clean();
                setState(() {});
              },
              child: const Icon(Icons.delete),
            ),
            FloatingActionButton(
              onPressed: () async {

                await LocalDB.Post("29h8f2789f82gf2g72983f", {
                  "id": "29h8f2789f82gf2g72983f",
                  "name": "Jhonacode"
                });

              },
              tooltip: 'Increment',
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}