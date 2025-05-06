import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import 'package:url_launcher/url_launcher.dart';


class ReportsPage extends StatefulWidget {
  const ReportsPage({Key? key}) : super(key: key);

  @override
  _ReportsPageState createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> reports = [];
  bool isLoading = true;
  bool isDeleting = false;
  int? deletingIndex;

  DateTime selectedDate = DateTime.now(); // To hold selected month and year

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    try {
      setState(() => isLoading = true);

      // Fetch reports filtered by month and year
      final response = await _supabase
          .from('reports')
          .select('*')
          .gte('created_at', DateTime(selectedDate.year, selectedDate.month, 1).toIso8601String())
          .lt('created_at', DateTime(selectedDate.year, selectedDate.month + 1, 1).toIso8601String())
          .order('created_at', ascending: false); // Order by date created

      setState(() => reports = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      _showError('Error loading reports: ${e.toString()}');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _uploadReport() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'doc', 'docx'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() => isLoading = true);
        final file = result.files.single;
        final userId = _supabase.auth.currentUser?.id;

        if (userId == null) {
          throw Exception('User not authenticated');
        }

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filePath = 'report_${timestamp}_${file.name.replaceAll(' ', '_')}';

        await _supabase.storage
            .from('reports')
            .upload(filePath, File(file.path!));

        final fileUrl = _supabase.storage
            .from('reports')
            .getPublicUrl(filePath);

        await _supabase.from('reports').insert({
          'name': file.name,
          'file_url': fileUrl,
          'file_path': filePath,
          'user_id': userId,
          'created_at': DateTime.now().toIso8601String(),
        });

        await _fetchReports();
        _showSuccess('${file.name} uploaded successfully');
      }
    } catch (e) {
      _showError('Upload failed: ${e.toString()}');
      debugPrint('Upload error details: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _deleteReport(String id, String filePath, int index) async {
    try {
      setState(() {
        isDeleting = true;
        deletingIndex = index;
      });

      await _supabase.storage.from('reports').remove([filePath]);
      await _supabase.from('reports').delete().eq('id', id);

      await _fetchReports();
      _showSuccess('Report deleted successfully');
    } catch (e) {
      _showError('Delete failed: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          isDeleting = false;
          deletingIndex = null;
        });
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red[400],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green[400],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  // Open month/year picker dialog
  Future<void> _selectDate() async {
    final DateTime? pickedDate = await showMonthPicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null && pickedDate != selectedDate) {
      setState(() {
        selectedDate = pickedDate;
      });
      await _fetchReports(); // Refresh reports after date selection
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Reports',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadReport,
        backgroundColor: Colors.blue[600],
        child: const Icon(Icons.add, size: 28),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: _selectDate,
              child: Row(
                children: [
                  Text(
                    'Selected: ${selectedDate.month}/${selectedDate.year}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.date_range, color: Colors.blue[600]),
                ],
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              onRefresh: _fetchReports,
              color: Colors.blue[600],
              child: reports.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.folder_open,
                      size: 60,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No reports for this date',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 16),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final report = reports[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.insert_drive_file,
                            size: 28,
                            color: Colors.blue[600],
                          ),
                        ),
                        title: Text(
                          report['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: isDeleting && deletingIndex == index
                            ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                            : IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: Colors.red[400],
                          ),
                          onPressed: () => _deleteReport(
                            report['id'],
                            report['file_path'],
                            index,
                          ),
                        ),
                        onTap: () async {
                          final url = report['file_url'];
                          if (url != null && await canLaunchUrl(Uri.parse(url))) {
                            await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                          } else {
                            _showError('Could not open the report.');
                          }
                        },

                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
//end
