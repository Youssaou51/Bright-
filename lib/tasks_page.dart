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
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 10,
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade100, Colors.blue.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Add Task',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                SizedBox(height: 20),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Title',
                    labelStyle: TextStyle(color: Colors.blue.shade900),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.blue.shade900),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.blue.shade900),
                    ),
                  ),
                  onChanged: (value) => title = value,
                ),
                SizedBox(height: 20),
                DropdownButtonFormField<Priority>(
                  value: priority,
                  decoration: InputDecoration(
                    labelText: 'Priority',
                    labelStyle: TextStyle(color: Colors.blue.shade900),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.blue.shade900),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.blue.shade900),
                    ),
                  ),
                  onChanged: (Priority? newValue) {
                    setState(() {
                      priority = newValue!;
                    });
                  },
                  items: Priority.values.map<DropdownMenuItem<Priority>>((Priority value) {
                    return DropdownMenuItem<Priority>(
                      value: value,
                      child: Text(
                        value.name.capitalize(),
                        style: TextStyle(color: Colors.blue.shade900),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton(
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
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        backgroundColor: Colors.blue.shade900, // Use this instead of 'primary'
                      ),
                      child: Text(
                        'Add',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),

                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.blue.shade900),
                      ),
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Custom title row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tasks',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16), // Add some spacing
            // Month selection at the top
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
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
            SizedBox(height: 16), // Add some spacing
            // Search field
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search tasks',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
            SizedBox(height: 16), // Add some spacing
            // Centered Progress Indicator and Text
            Center(
              child: Column(
                children: [
                  CircularProgressIndicator(
                    value: _filteredTasks.isEmpty ? 0 : _completedTasksCount / _filteredTasks.length,
                    backgroundColor: Colors.grey[300],
                    color: Colors.blue,
                    strokeWidth: 8,
                  ),
                  SizedBox(height: 16), // Add some spacing
                  Text(
                    '$_completedTasksCount/${_filteredTasks.length} tasks completed',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16), // Add some spacing
            // Task list
            Expanded(
              child: _filteredTasks.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.assignment, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No tasks for this month.',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
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
                          fontWeight: FontWeight.bold,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTask,
        child: Icon(Icons.add, color: Colors.white),
        backgroundColor: Colors.blue.shade900,
        elevation: 5,
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