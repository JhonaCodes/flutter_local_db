import 'package:flutter/material.dart';

import 'tasks.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await TaskStore.open();
  runApp(TasksApp(store: store));
}

/// The example app: a task list stored with flutter_local_db.
class TasksApp extends StatelessWidget {
  const TasksApp({super.key, required this.store});

  final TaskStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_local_db',
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      home: TasksPage(store: store),
    );
  }
}

/// The list of tasks, with a field to add one.
class TasksPage extends StatelessWidget {
  const TasksPage({super.key, required this.store});

  final TaskStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [ClearDoneButton(store: store)],
      ),
      body: Column(
        children: [
          NewTaskField(store: store),
          Expanded(child: TaskList(store: store)),
        ],
      ),
    );
  }
}

/// Deletes finished tasks.
class ClearDoneButton extends StatelessWidget {
  const ClearDoneButton({super.key, required this.store});

  final TaskStore store;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Delete finished tasks',
      icon: const Icon(Icons.cleaning_services_outlined),
      onPressed: store.clearDone,
    );
  }
}

/// A text field that adds a task on submit.
class NewTaskField extends StatefulWidget {
  const NewTaskField({super.key, required this.store});

  final TaskStore store;

  @override
  State<NewTaskField> createState() => _NewTaskFieldState();
}

class _NewTaskFieldState extends State<NewTaskField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(String title) async {
    if (title.trim().isEmpty) {
      return;
    }
    await widget.store.add(title.trim());
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        key: const Key('new-task'),
        controller: _controller,
        decoration: const InputDecoration(labelText: 'New task'),
        onSubmitted: _submit,
      ),
    );
  }
}

/// The tasks, refreshed after every committed write.
class TaskList extends StatelessWidget {
  const TaskList({super.key, required this.store});

  final TaskStore store;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: store.watchAll(),
      builder: (context, snapshot) {
        final tasks = snapshot.data ?? const [];
        return ListView(
          children: [
            for (final task in tasks) TaskTile(store: store, task: task),
          ],
        );
      },
    );
  }
}

/// One task: tap to toggle, swipe to delete.
class TaskTile extends StatelessWidget {
  const TaskTile({super.key, required this.store, required this.task});

  final TaskStore store;
  final Task task;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(task.id),
      onDismissed: (_) => store.remove(task),
      child: CheckboxListTile(
        value: task.done,
        title: Text(task.title),
        onChanged: (_) => store.toggle(task),
      ),
    );
  }
}
