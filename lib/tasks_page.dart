import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import the intl package

class Task {
  final String id;
  final String title;
  DateTime dueDate;
  bool isCompleted;
  final Priority priority;

  Task({
    required this.id,
    required this.title,
    required this.dueDate,
    this.isCompleted = false,
    required this.priority,
  });
}

enum Priority { low, medium, high }

class TasksPage extends StatefulWidget {
  @override
  _TasksPageState createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  DateTime _selectedMonth = DateTime.now();
  List<Task> _tasks = [];
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<Task> get _filteredTasks {
    return _tasks.where((task) =>
    task.title.toLowerCase().contains(_searchQuery.toLowerCase()) &&
        task.dueDate.month == _selectedMonth.month &&
        task.dueDate.year == _selectedMonth.year).toList();
  }

  int get _completedTasksCount {
    return _filteredTasks.where((task) => task.isCompleted).length;
  }

  void _selectMonth(DateTime month) {
    setState(() {
      _selectedMonth = month;
    });
  }

  void _toggleTaskCompletion(Task task) {
    setState(() {
      task.isCompleted = !task.isCompleted;
    });
  }

  void _deleteTask(Task task) {
    setState(() {
      _tasks.remove(task);
    });
  }

  void _addTask() {
    String title = '';
    Priority priority = Priority.medium; // Default priority

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(labelText: 'Title'),
                onChanged: (value) => title = value,
              ),
              DropdownButton<Priority>(
                value: priority,
                onChanged: (Priority? newValue) {
                  setState(() {
                    priority = newValue!;
                  });
                },
                items: Priority.values.map<DropdownMenuItem<Priority>>((Priority value) {
                  return DropdownMenuItem<Priority>(
                    value: value,
                    child: Text(value.name.capitalize()),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (title.isNotEmpty) {
                  setState(() {
                    _tasks.add(Task(
                      id: DateTime.now().toString(),
                      title: title,
                      dueDate: DateTime.now(), // Automatically set to current date
                      priority: priority,
                    ));
                  });
                  Navigator.of(context).pop();
                }
              },
              child: Text('Add'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tasks'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _addTask,
          ),
        ],
      ),
      body: Column(
        children: [
          // Month selection at the top
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_left),
                  onPressed: () {
                    _selectMonth(DateTime(_selectedMonth.year, _selectedMonth.month - 1));
                  },
                ),
                Text(
                  DateFormat.yMMMM().format(_selectedMonth),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(Icons.arrow_right),
                  onPressed: () {
                    _selectMonth(DateTime(_selectedMonth.year, _selectedMonth.month + 1));
                  },
                ),
              ],
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search tasks',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)
                ),
              ),
            ),
          ),
          // Progress indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: LinearProgressIndicator(
              value: _filteredTasks.isEmpty ? 0 : _completedTasksCount / _filteredTasks.length,
              backgroundColor: Colors.grey[300],
              color: Colors.blue,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              '$_completedTasksCount/${_filteredTasks.length} tasks completed',
              style: TextStyle(fontSize: 16),
            ),
          ),
          Expanded(
            child: _filteredTasks.isEmpty
                ? Center(child: Text('No tasks for this month.'))
                : ListView.builder(
              itemCount: _filteredTasks.length,
              itemBuilder: (context, index) {
                final task = _filteredTasks[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    leading: Checkbox(
                      value: task.isCompleted,
                      onChanged: (_) => _toggleTaskCompletion(task),
                    ),
                    title: Text(
                      task.title,
                      style: TextStyle(
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Due: ${DateFormat.yMd().format(task.dueDate)}'),
                        Text('Priority: ${task.priority.name}'),
                      ],
                    ),
                    trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () => _deleteTask(task)),
                    onTap: () {
                      // Navigate to task details
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Extension to capitalize string
extension CapitalizeString on String {
  String capitalize() {
    return this.isEmpty ? this : '${this[0].toUpperCase()}${this.substring(1)}';
  }
}