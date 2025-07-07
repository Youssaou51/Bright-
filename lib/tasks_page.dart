import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

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
  bool isAdmin = false;

  List<Task> get _filteredTasks {
    return _tasks.where((task) =>
    task.title.toLowerCase().contains(_searchQuery.toLowerCase()) &&
        task.dueDate.month == _selectedMonth.month &&
        task.dueDate.year == _selectedMonth.year).toList();
  }

  int get _completedTasksCount => _filteredTasks.where((task) => task.isCompleted).length;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _checkIfAdmin();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      _showErrorSnackBar('No authenticated user found.');
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await supabase
          .from('tasks')
          .select()
          .eq('user_id', userId); // Filter by user_id

      if (response != null && response.isNotEmpty) {
        setState(() {
          _tasks = List<Map<String, dynamic>>.from(response)
              .map((map) => Task.fromMap(map))
              .toList();
        });
      } else {
        setState(() {
          _tasks = []; // Explicitly set to empty if no tasks
        });
        _showErrorSnackBar('No tasks found for this user.');
      }
    } catch (e) {
      print('Error loading tasks: $e');
      _showErrorSnackBar('Failed to load tasks: $e');
      setState(() {
        _tasks = []; // Reset tasks on error
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkIfAdmin() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final response = await supabase
        .from('users')
        .select('role')
        .eq('id', userId)
        .maybeSingle();

    if (response != null && response['role'] == 'admin') {
      setState(() {
        isAdmin = true;
      });
    }
  }

  Future<void> _toggleTaskCompletion(Task task) async {
    final wasCompleted = task.isCompleted;

    setState(() {
      task.isCompleted = !wasCompleted;
    });

    try {
      await supabase
          .from('tasks')
          .update({'is_completed': task.isCompleted})
          .eq('id', task.id);
    } catch (e) {
      setState(() {
        task.isCompleted = wasCompleted;
      });
      print('Erreur : $e');
      _showErrorSnackBar('Échec de la mise à jour.');
    }
  }

  void _showErrorSnackBar(String message) {
    final snackBar = SnackBar(
      content: Text(message, style: GoogleFonts.poppins()),
      backgroundColor: Colors.red,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Future<void> _deleteTask(Task task) async {
    try {
      await supabase.from('tasks').delete().eq('id', task.id);
      setState(() {
        _tasks.remove(task);
      });
    } catch (e) {
      print('Erreur suppression : $e');
    }
  }

  Future<void> _addTaskDialog() async {
    String title = '';
    Priority priority = Priority.medium;

    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 6,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Add Task', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 20),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onChanged: (value) => title = value,
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<Priority>(
                  value: priority,
                  decoration: InputDecoration(
                    labelText: 'Priority',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onChanged: (Priority? newValue) {
                    if (newValue != null) priority = newValue;
                  },
                  items: Priority.values.map((Priority value) {
                    return DropdownMenuItem<Priority>(
                      value: value,
                      child: Text(value.name.capitalize(), style: GoogleFonts.poppins()),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
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
                      child: Text('Add', style: GoogleFonts.poppins(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF1976D2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Cancel', style: GoogleFonts.poppins(color: Color(0xFF1976D2))),
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
    setState(() => _selectedMonth = month);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: Text('Tasks', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_left, color: Color(0xFF1976D2)),
                  onPressed: () => _selectMonth(DateTime(_selectedMonth.year, _selectedMonth.month - 1)),
                ),
                Text(
                  DateFormat.yMMMM().format(_selectedMonth),
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: Icon(Icons.arrow_right, color: Color(0xFF1976D2)),
                  onPressed: () => _selectMonth(DateTime(_selectedMonth.year, _selectedMonth.month + 1)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search tasks',
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  CircularProgressIndicator(
                    value: _filteredTasks.isEmpty ? 0 : _completedTasksCount / _filteredTasks.length,
                    backgroundColor: Colors.grey.shade300,
                    color: Color(0xFF1976D2),
                    strokeWidth: 6,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$_completedTasksCount/${_filteredTasks.length} tasks completed',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: Color(0xFF1976D2)))
                  : _filteredTasks.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.assignment, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text('No tasks for this month.', style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade600)),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: _filteredTasks.length,
                itemBuilder: (context, index) {
                  final task = _filteredTasks[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: Checkbox(
                        value: task.isCompleted,
                        onChanged: isAdmin ? (_) => _toggleTaskCompletion(task) : null,
                        activeColor: Color(0xFF1976D2),
                      ),
                      title: Text(
                        task.title,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Due: ${DateFormat.yMd().format(task.dueDate)}', style: GoogleFonts.poppins(color: Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          Chip(
                            label: Text(
                              task.priority.name.capitalize(),
                              style: GoogleFonts.poppins(color: Colors.white),
                            ),
                            backgroundColor: task.priority == Priority.low
                                ? Colors.green
                                : task.priority == Priority.medium
                                ? Colors.orange
                                : Colors.red,
                          ),
                        ],
                      ),
                      trailing: isAdmin
                          ? IconButton(
                        icon: Icon(Icons.delete, color: Colors.red.shade400),
                        onPressed: () => _deleteTask(task),
                      )
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
        onPressed: _addTaskDialog,
        child: Icon(Icons.add, color: Colors.white),
        backgroundColor: Color(0xFF1976D2),
      )
          : null,
    );
  }
}

extension CapitalizeString on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}