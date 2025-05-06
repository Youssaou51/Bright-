import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'].toString(),
      title: map['title'],
      dueDate: DateTime.parse(map['due_date']),
      isCompleted: map['is_completed'] ?? false,
      priority: Priority.values.firstWhere(
            (e) => e.name == (map['priority'] ?? 'medium'),
        orElse: () => Priority.medium,
      ),
    );
  }

  Map<String, dynamic> toMap(String userId) {
    return {
      'user_id': userId,
      'title': title,
      'due_date': dueDate.toIso8601String(),
      'is_completed': isCompleted,
      'priority': priority.name,
    };
  }
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
  final supabase = Supabase.instance.client;
  bool _isLoading = true;

  List<Task> get _filteredTasks {
    return _tasks.where((task) =>
    task.title.toLowerCase().contains(_searchQuery.toLowerCase()) &&
        task.dueDate.month == _selectedMonth.month &&
        task.dueDate.year == _selectedMonth.year).toList();
  }

  int get _completedTasksCount {
    return _filteredTasks.where((task) => task.isCompleted).length;
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await supabase
          .from('tasks')
          .select()
          .eq('user_id', userId);

      if (response != null) {
        setState(() {
          _tasks = List<Map<String, dynamic>>.from(response)
              .map((map) => Task.fromMap(map))
              .toList();
        });
      }
    } catch (e) {
      print('Error loading tasks: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addTaskDialog() async {
    String title = '';
    Priority priority = Priority.medium;

    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 10,
          child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Add Task',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (value) {
                    title = value;
                  },
                ),
                SizedBox(height: 20),
                DropdownButtonFormField<Priority>(
                  value: priority,
                  decoration: InputDecoration(
                    labelText: 'Priority',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (Priority? newValue) {
                    priority = newValue!;
                  },
                  items: Priority.values.map((Priority value) {
                    return DropdownMenuItem<Priority>(
                      value: value,
                      child: Text(value.name.capitalize()),
                    );
                  }).toList(),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        if (title.isNotEmpty) {
                          final userId = supabase.auth.currentUser?.id;
                          if (userId == null) return;

                          try {
                            final response = await supabase
                                .from('tasks')
                                .insert({
                              'user_id': userId,
                              'title': title,
                              'due_date': DateTime.now().toIso8601String(),
                              'is_completed': false,
                              'priority': priority.name,
                            })
                                .select();

                            if (response != null) {
                              await _loadTasks();
                            }
                          } catch (e) {
                            print('Error adding task: $e');
                          }

                          if (mounted) Navigator.of(context).pop();
                        }
                      },
                      child: Text('Add', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade900),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Cancel',
                          style: TextStyle(color: Colors.blue.shade900)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _selectMonth(DateTime month) {
    setState(() {
      _selectedMonth = month;
    });
  }

  Future<void> _toggleTaskCompletion(Task task) async {
    try {
      // First update the local state immediately for responsive UI
      setState(() {
        task.isCompleted = !task.isCompleted;
      });

      // Then update the database
      final response = await supabase
          .from('tasks')
          .update({'is_completed': task.isCompleted})
          .eq('id', task.id)
          .select();

      if (response == null) {
        // If update failed, revert the local state
        setState(() {
          task.isCompleted = !task.isCompleted;
        });
        print('Failed to update task status');
      }
    } catch (e) {
      // If error occurred, revert the local state
      setState(() {
        task.isCompleted = !task.isCompleted;
      });
      print('Error updating task: $e');
    }
  }

  Future<void> _deleteTask(Task task) async {
    try {
      await supabase.from('tasks').delete().eq('id', task.id);
      setState(() {
        _tasks.remove(task);
      });
    } catch (e) {
      print('Error deleting task: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tasks', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_left),
                  onPressed: () => _selectMonth(DateTime(_selectedMonth.year, _selectedMonth.month - 1)),
                ),
                Text(
                  DateFormat.yMMMM().format(_selectedMonth),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(Icons.arrow_right),
                  onPressed: () => _selectMonth(DateTime(_selectedMonth.year, _selectedMonth.month + 1)),
                ),
              ],
            ),
            SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search tasks',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
            SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  CircularProgressIndicator(
                    value: _filteredTasks.isEmpty ? 0 : _completedTasksCount / _filteredTasks.length,
                    backgroundColor: Colors.grey[300],
                    color: Colors.blue,
                    strokeWidth: 8,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '$_completedTasksCount/${_filteredTasks.length} tasks completed',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _filteredTasks.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.assignment, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No tasks for this month.',
                        style: TextStyle(fontSize: 18, color: Colors.grey)),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: _filteredTasks.length,
                itemBuilder: (context, index) {
                  final task = _filteredTasks[index];
                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 2,
                    child: ListTile(
                      leading: Checkbox(
                        value: task.isCompleted,
                        onChanged: (_) => _toggleTaskCompletion(task),
                      ),
                      title: Text(
                        task.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Due: ${DateFormat.yMd().format(task.dueDate)}'),
                          SizedBox(height: 4),
                          Chip(
                            label: Text(
                              task.priority.name.capitalize(),
                              style: TextStyle(color: Colors.white),
                            ),
                            backgroundColor: task.priority == Priority.low
                                ? Colors.green
                                : task.priority == Priority.medium
                                ? Colors.orange
                                : Colors.red,
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteTask(task),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTaskDialog,
        child: Icon(Icons.add, color: Colors.white),
        backgroundColor: Colors.blue.shade900,
      ),
    );
  }
}

extension CapitalizeString on String {
  String capitalize() {
    return isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
  }
}
