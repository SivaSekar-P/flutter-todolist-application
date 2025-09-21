import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const ProductivityApp());
}

// ------------------- Main App -------------------
class ProductivityApp extends StatefulWidget {
  const ProductivityApp({Key? key}) : super(key: key);
  @override
  State<ProductivityApp> createState() => _ProductivityAppState();
}

class _ProductivityAppState extends State<ProductivityApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('theme_mode');
    if (savedTheme != null) {
      setState(() {
        switch (savedTheme) {
          case 'light':
            _themeMode = ThemeMode.light;
            break;
          case 'dark':
            _themeMode = ThemeMode.dark;
            break;
          default:
            _themeMode = ThemeMode.system;
        }
      });
    }
  }

  Future<void> _saveTheme() async {
    final prefs = await SharedPreferences.getInstance();
    String themeString;
    switch (_themeMode) {
      case ThemeMode.light:
        themeString = 'light';
        break;
      case ThemeMode.dark:
        themeString = 'dark';
        break;
      default:
        themeString = 'system';
    }
    await prefs.setString('theme_mode', themeString);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'மறவாதிரு',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.deepPurple,
        cardTheme: const CardThemeData(margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.deepPurple,
        cardTheme: const CardThemeData(margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
      ),
      themeMode: _themeMode,
      home: HomePage(
        onThemeToggle: () {
          setState(() {
            _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
          });
          _saveTheme();
        },
      ),
    );
  }
}

// ------------------- HomePage -------------------
class HomePage extends StatefulWidget {
  final VoidCallback onThemeToggle;
  const HomePage({Key? key, required this.onThemeToggle}) : super(key: key);
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final GlobalKey<_TasksTabState> tasksKey = GlobalKey<_TasksTabState>();
  final GlobalKey<_NotesTabState> notesKey = GlobalKey<_NotesTabState>();
  final GlobalKey<_DeletedTasksTabState> deletedTasksKey = GlobalKey<_DeletedTasksTabState>();
  late final List<Widget> _pages;
  late final List<String> _tabTitles;

  @override
  void initState() {
    super.initState();
    _pages = [
      TasksTab(key: tasksKey, deletedTasksKey: deletedTasksKey),
      NotesTab(key: notesKey),
      DeletedTasksTab(key: deletedTasksKey),
    ];
    _tabTitles = ['Tasks', 'Notes', 'Deleted'];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tabTitles[_currentIndex]),
        actions: [
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: widget.onThemeToggle,
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.checklist), label: 'Tasks'),
          BottomNavigationBarItem(icon: Icon(Icons.note), label: 'Notes'),
          BottomNavigationBarItem(icon: Icon(Icons.delete), label: 'Deleted'),
        ],
        onTap: (index) => setState(() => _currentIndex = index),
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text("Add Task"),
        onPressed: () => tasksKey.currentState?.showAddTaskDialog(context),
      )
          : _currentIndex == 1
          ? FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text("Add Note"),
        onPressed: () => notesKey.currentState?.showAddNoteDialog(context),
      )
          : null,
    );
  }
}

// ------------------- TasksTab -------------------
enum TaskPriority { low, medium, high }

class TasksTab extends StatefulWidget {
  final GlobalKey<_DeletedTasksTabState> deletedTasksKey;
  const TasksTab({Key? key, required this.deletedTasksKey}) : super(key: key);
  @override
  State<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<TasksTab> {
  List<Todo> _tasks = [];
  List<Todo> _filteredTasks = [];
  String _sortBy = 'Default';
  bool _showCompleted = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _searchController.addListener(_filterTasks);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tasksJson = prefs.getString('tasks');
    if (tasksJson != null) {
      final List decoded = jsonDecode(tasksJson);
      setState(() {
        _tasks = decoded.map((e) => Todo.fromMap(e)).toList();
        _filteredTasks = _tasks;
      });
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tasks', jsonEncode(_tasks.map((e) => e.toMap()).toList()));
  }

  Future<void> _saveDeletedTask(Todo task) async {
    final prefs = await SharedPreferences.getInstance();
    final String? deletedTasksJson = prefs.getString('deleted_tasks');
    List<Todo> deletedTasks = [];
    if (deletedTasksJson != null) {
      final List decoded = jsonDecode(deletedTasksJson);
      deletedTasks = decoded.map((e) => Todo.fromMap(e)).toList();
    }
    deletedTasks.insert(0, task);
    if (deletedTasks.length > 20) {
      deletedTasks = deletedTasks.take(20).toList();
    }
    await prefs.setString('deleted_tasks', jsonEncode(deletedTasks.map((e) => e.toMap()).toList()));
    widget.deletedTasksKey.currentState?.refresh();
  }

  void _addTask(Todo task) {
    setState(() {
      _tasks.add(task);
      _filterTasks();
    });
    _saveTasks();
  }

  void _toggleTask(int index) {
    setState(() {
      _tasks[index].done = !_tasks[index].done;
      _filterTasks();
    });
    _saveTasks();
  }

  void _deleteTask(int index) {
    final task = _tasks[index];
    setState(() {
      _tasks.removeAt(index);
      _filterTasks();
    });
    _saveTasks();
    _saveDeletedTask(task);
  }

  void _sortTasks(String? value) {
    setState(() {
      _sortBy = value ?? 'Default';
      if (_sortBy == 'Completion') {
        _tasks.sort((a, b) => a.done == b.done ? 0 : a.done ? 1 : -1);
      } else if (_sortBy == 'Priority') {
        _tasks.sort((a, b) => b.priority.index.compareTo(a.priority.index));
      } else if (_sortBy == 'Due Date') {
        _tasks.sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
      } else if (_sortBy == 'Creation Date') {
        _tasks.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }
      _filterTasks();
    });
  }

  void _filterTasks() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTasks = _tasks.where((task) {
        final matchesQuery = task.title.toLowerCase().contains(query);
        final matchesCompleted = _showCompleted || !task.done;
        return matchesQuery && matchesCompleted;
      }).toList();
    });
  }

  void showAddTaskDialog(BuildContext context) {
    final titleController = TextEditingController();
    TaskPriority priority = TaskPriority.low;
    DateTime? dueDate;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Task"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(hintText: "Task title"),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<TaskPriority>(
                value: priority,
                decoration: const InputDecoration(labelText: "Priority"),
                items: TaskPriority.values
                    .map((p) => DropdownMenuItem(
                  value: p,
                  child: Text(p.toString().split('.').last.capitalize()),
                ))
                    .toList(),
                onChanged: (value) => priority = value ?? TaskPriority.low,
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () async {
                  final selectedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (selectedDate != null) {
                    dueDate = selectedDate;
                  }
                },
                child: const Text("Select Due Date"),
              ),
              if (dueDate != null)
                Text("Due: ${DateFormat.yMMMd().format(dueDate!)}"),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) return;
                _addTask(Todo(
                  title: titleController.text.trim(),
                  priority: priority,
                  dueDate: dueDate,
                  createdAt: DateTime.now(),
                ));
                Navigator.pop(context);
              },
              child: const Text("Add")),
        ],
      ),
    );
  }

  void showEditTaskDialog(BuildContext context, int index) {
    final titleController = TextEditingController(text: _tasks[index].title);
    TaskPriority priority = _tasks[index].priority;
    DateTime? dueDate = _tasks[index].dueDate;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Task"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(hintText: "Task title"),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<TaskPriority>(
                value: priority,
                decoration: const InputDecoration(labelText: "Priority"),
                items: TaskPriority.values
                    .map((p) => DropdownMenuItem(
                  value: p,
                  child: Text(p.toString().split('.').last.capitalize()),
                ))
                    .toList(),
                onChanged: (value) => priority = value ?? TaskPriority.low,
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () async {
                  final selectedDate = await showDatePicker(
                    context: context,
                    initialDate: dueDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (selectedDate != null) {
                    dueDate = selectedDate;
                  }
                },
                child: const Text("Select Due Date"),
              ),
              if (dueDate != null)
                Text("Due: ${DateFormat.yMMMd().format(dueDate!)}"),
              TextButton(
                onPressed: () => dueDate = null,
                child: const Text("Clear Due Date"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) return;
                setState(() {
                  _tasks[index].title = titleController.text.trim();
                  _tasks[index].priority = priority;
                  _tasks[index].dueDate = dueDate;
                });
                _saveTasks();
                _filterTasks();
                Navigator.pop(context);
              },
              child: const Text("Save")),
        ],
      ),
    );
  }

  void showDeleteTasksByDateDialog(BuildContext context) {
    DateTime? selectedDate;
    bool deleteNoDueDate = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocalState) => AlertDialog(
          title: const Text("Delete Tasks by Date"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () async {
                    final pickedDate = await showDatePicker(
                      context: dialogContext,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime(2030),
                    );
                    if (pickedDate != null) {
                      setLocalState(() => selectedDate = pickedDate);
                    }
                  },
                  child: const Text("Select Date"),
                ),
                if (selectedDate != null)
                  Text("Selected: ${DateFormat.yMMMd().format(selectedDate!)}"),
                CheckboxListTile(
                  title: const Text("Delete tasks with no due date"),
                  value: deleteNoDueDate,
                  onChanged: (value) {
                    setLocalState(() => deleteNoDueDate = value ?? false);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext), child: const Text("Cancel")),
            ElevatedButton(
                onPressed: () {
                  if (selectedDate == null && !deleteNoDueDate) return;
                  setState(() {
                    final tasksToDelete = _tasks.where((task) {
                      if (deleteNoDueDate && task.dueDate == null) return true;
                      if (selectedDate == null) return false;
                      return task.dueDate != null &&
                          task.dueDate!.year == selectedDate!.year &&
                          task.dueDate!.month == selectedDate!.month &&
                          task.dueDate!.day == selectedDate!.day;
                    }).toList();
                    for (var task in tasksToDelete) {
                      _tasks.remove(task);
                      _saveDeletedTask(task);
                    }
                    _filterTasks();
                  });
                  _saveTasks();
                  Navigator.pop(dialogContext);
                },
                child: const Text("Delete")),
          ],
        ),
      ),
    );
  }

  void _clearAllTasks() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Clear All Tasks"),
        content: const Text("Are you sure you want to delete all tasks?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () {
                setState(() {
                  for (var task in _tasks) {
                    _saveDeletedTask(task);
                  }
                  _tasks.clear();
                  _filteredTasks.clear();
                });
                _saveTasks();
                Navigator.pop(context);
              },
              child: const Text("Clear All")),
        ],
      ),
    );
  }

  Map<String, List<Todo>> _groupTasksByDate(List<Todo> tasksList) {
    final Map<String, List<Todo>> grouped = {'No Due Date': []};
    for (var task in tasksList) {
      if (task.dueDate == null) {
        grouped['No Due Date']!.add(task);
      } else {
        final dateKey = DateFormat.yMMMd().format(task.dueDate!);
        grouped.putIfAbsent(dateKey, () => []).add(task);
      }
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedTasks = _groupTasksByDate(_filteredTasks);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: "Search tasks...",
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Show Completed"),
              Switch(
                value: _showCompleted,
                onChanged: (value) {
                  setState(() {
                    _showCompleted = value;
                    _filterTasks();
                  });
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: _sortBy,
                  hint: const Text("Sort By"),
                  isExpanded: true,
                  items: ['Default', 'Completion', 'Priority', 'Due Date', 'Creation Date']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: _sortTasks,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep),
                tooltip: 'Delete Tasks by Date',
                onPressed: () => showDeleteTasksByDateDialog(context),
              ),
              IconButton(
                icon: const Icon(Icons.clear_all),
                tooltip: 'Clear All Tasks',
                onPressed: _clearAllTasks,
              ),
            ],
          ),
        ),
        Expanded(
          child: groupedTasks.isEmpty
              ? const Center(child: Text("No tasks yet. Add one!"))
              : ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: groupedTasks.keys.length,
            itemBuilder: (context, index) {
              final dateKey = groupedTasks.keys.elementAt(index);
              final tasks = groupedTasks[dateKey]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      '$dateKey (${tasks.length} task${tasks.length == 1 ? '' : 's'})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...tasks.asMap().entries.map((entry) {
                    final globalIndex = _tasks.indexOf(entry.value);
                    final task = entry.value;
                    final isOverdue = task.dueDate != null && task.dueDate!.isBefore(DateTime.now()) && !task.done;
                    return Card(
                      child: ListTile(
                        title: Text(
                          task.title,
                          style: TextStyle(
                            color: isOverdue ? Colors.red : null,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Priority: ${task.priority.toString().split('.').last.capitalize()}",
                              style: TextStyle(
                                color: task.priority == TaskPriority.high
                                    ? Colors.red
                                    : task.priority == TaskPriority.medium
                                    ? Colors.orange
                                    : Colors.green,
                              ),
                            ),
                            if (task.dueDate != null)
                              Text(
                                "Due: ${DateFormat.yMMMd().format(task.dueDate!)}",
                                style: TextStyle(
                                  color: isOverdue ? Colors.red : null,
                                ),
                              ),
                            Text(
                              "Created: ${DateFormat.yMMMd().format(task.createdAt)}",
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        leading: Checkbox(
                          value: task.done,
                          onChanged: (_) => _toggleTask(globalIndex),
                        ),
                        onTap: () => showEditTaskDialog(context, globalIndex),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteTask(globalIndex),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class Todo {
  String title;
  bool done;
  TaskPriority priority;
  DateTime? dueDate;
  DateTime createdAt;

  Todo({
    required this.title,
    this.done = false,
    this.priority = TaskPriority.low,
    this.dueDate,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'done': done,
    'priority': priority.index,
    'dueDate': dueDate?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory Todo.fromMap(Map<String, dynamic> map) => Todo(
    title: map['title'],
    done: map['done'],
    priority: TaskPriority.values[map['priority'] ?? 0],
    dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
    createdAt: DateTime.parse(map['createdAt']),
  );
}

// ------------------- NotesTab -------------------
class NotesTab extends StatefulWidget {
  const NotesTab({Key? key}) : super(key: key);
  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> {
  List<Note> _notes = [];
  List<Note> _filteredNotes = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _searchController.addListener(_filterNotes);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? notesJson = prefs.getString('notes');
    if (notesJson != null) {
      final List decoded = jsonDecode(notesJson);
      setState(() {
        _notes = decoded.map((e) => Note.fromMap(e)).toList();
        _filteredNotes = _notes;
      });
    }
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notes', jsonEncode(_notes.map((e) => e.toMap()).toList()));
  }

  void _addNote(Note note) {
    setState(() {
      _notes.add(note);
      _filteredNotes = _notes;
    });
    _saveNotes();
  }

  void _deleteNote(int index) {
    setState(() {
      _notes.removeAt(index);
      _filteredNotes = _notes;
    });
    _saveNotes();
  }

  void _filterNotes() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredNotes = _notes
          .where((note) =>
      note.title.toLowerCase().contains(query) ||
          note.content.toLowerCase().contains(query))
          .toList();
    });
  }

  void showAddNoteDialog(BuildContext context) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Note"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(hintText: "Title"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(hintText: "Note content"),
                maxLines: 5,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () {
                final title = titleController.text.trim();
                final content = contentController.text.trim();
                if (title.isEmpty && content.isEmpty) return;
                _addNote(Note(
                  title: title,
                  content: content,
                  createdAt: DateTime.now(),
                ));
                Navigator.pop(context);
              },
              child: const Text("Add")),
        ],
      ),
    );
  }

  void showEditNoteDialog(BuildContext context, int index) {
    final titleController = TextEditingController(text: _notes[index].title);
    final contentController = TextEditingController(text: _notes[index].content);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Note"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(hintText: "Title"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(hintText: "Note content"),
                maxLines: 5,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () {
                final title = titleController.text.trim();
                final content = contentController.text.trim();
                if (title.isEmpty && content.isEmpty) return;
                setState(() {
                  _notes[index].title = title;
                  _notes[index].content = content;
                });
                _saveNotes();
                Navigator.pop(context);
              },
              child: const Text("Save")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: "Search notes...",
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: _filteredNotes.isEmpty
              ? const Center(child: Text("No notes yet. Add one!"))
              : ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _filteredNotes.length,
            itemBuilder: (context, index) {
              final note = _filteredNotes[index];
              return Card(
                child: ListTile(
                  title: Text(note.title.isEmpty ? 'Untitled' : note.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(note.content),
                      const SizedBox(height: 4),
                      Text(
                        "Created: ${DateFormat.yMMMd().format(note.createdAt)}",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  onTap: () => showEditNoteDialog(context, _notes.indexOf(note)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteNote(_notes.indexOf(note)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ------------------- DeletedTasksTab -------------------
class DeletedTasksTab extends StatefulWidget {
  const DeletedTasksTab({Key? key}) : super(key: key);
  @override
  State<DeletedTasksTab> createState() => _DeletedTasksTabState();
}

class _DeletedTasksTabState extends State<DeletedTasksTab> {
  List<Todo> _deletedTasks = [];

  @override
  void initState() {
    super.initState();
    _loadDeletedTasks();
  }

  Future<void> _loadDeletedTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? deletedTasksJson = prefs.getString('deleted_tasks');
    if (deletedTasksJson != null) {
      final List decoded = jsonDecode(deletedTasksJson);
      setState(() {
        _deletedTasks = decoded.map((e) => Todo.fromMap(e)).toList();
      });
    }
  }

  Future<void> _saveDeletedTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('deleted_tasks', jsonEncode(_deletedTasks.map((e) => e.toMap()).toList()));
  }

  void _permanentlyDeleteTask(int index) {
    setState(() {
      _deletedTasks.removeAt(index);
    });
    _saveDeletedTasks();
  }

  void refresh() {
    _loadDeletedTasks();
  }

  @override
  Widget build(BuildContext context) {
    return _deletedTasks.isEmpty
        ? const Center(child: Text("No deleted tasks."))
        : ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _deletedTasks.length,
      itemBuilder: (context, index) {
        final task = _deletedTasks[index];
        final isOverdue = task.dueDate != null && task.dueDate!.isBefore(DateTime.now()) && !task.done;
        return Card(
          child: ListTile(
            title: Text(
              task.title,
              style: TextStyle(
                color: isOverdue ? Colors.red : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Priority: ${task.priority.toString().split('.').last.capitalize()}",
                  style: TextStyle(
                    color: task.priority == TaskPriority.high
                        ? Colors.red
                        : task.priority == TaskPriority.medium
                        ? Colors.orange
                        : Colors.green,
                  ),
                ),
                if (task.dueDate != null)
                  Text(
                    "Due: ${DateFormat.yMMMd().format(task.dueDate!)}",
                    style: TextStyle(
                      color: isOverdue ? Colors.red : null,
                    ),
                  ),
                Text(
                  "Created: ${DateFormat.yMMMd().format(task.createdAt)}",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_forever),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Permanently Delete Task"),
                    content: Text("Are you sure you want to permanently delete '${task.title}'?"),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                      ElevatedButton(
                          onPressed: () {
                            _permanentlyDeleteTask(index);
                            Navigator.pop(context);
                          },
                          child: const Text("Delete")),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class Note {
  String title;
  String content;
  DateTime createdAt;

  Note({required this.title, required this.content, required this.createdAt});

  Map<String, dynamic> toMap() => {
    'title': title,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Note.fromMap(Map<String, dynamic> map) => Note(
    title: map['title'],
    content: map['content'],
    createdAt: DateTime.parse(map['createdAt']),
  );
}

// Utility extension for string capitalization
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}