import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'foundation_amount_widget.dart';

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

  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    try {
      setState(() => isLoading = true);

      final startDate = DateTime(selectedDate.year, selectedDate.month, 1);
      final endDate = DateTime(selectedDate.year, selectedDate.month + 1, 1);

      final response = await _supabase
          .from('reports')
          .select('*')
          .gte('created_at', startDate.toIso8601String())
          .lt('created_at', endDate.toIso8601String())
          .order('created_at', ascending: false);

      setState(() => reports = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      _showError('Oops! Failed to load reports: $e');
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

        if (userId == null) throw Exception('User not authenticated');

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filePath = 'report_${timestamp}_${file.name.replaceAll(' ', '_')}';

        await _supabase.storage.from('reports').upload(filePath, File(file.path!));
        final fileUrl = _supabase.storage.from('reports').getPublicUrl(filePath);

        await _supabase.from('reports').insert({
          'name': file.name,
          'file_url': fileUrl,
          'file_path': filePath,
          'user_id': userId,
          'created_at': DateTime.now().toIso8601String(),
        });

        await _fetchReports();
        _showSuccess('🚀 ${file.name} uploaded successfully!');
      }
    } catch (e) {
      _showError('Upload failed: $e');
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
      _showSuccess('🗑️ Report deleted successfully');
    } catch (e) {
      _showError('Delete failed: $e');
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
          backgroundColor: Colors.red.shade600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
          backgroundColor: Colors.green.shade600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        ),
      );
    }
  }

  Future<void> _selectDate() async {
    final pickedDate = await showMonthPicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null && pickedDate != selectedDate) {
      setState(() => selectedDate = pickedDate);
      await _fetchReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = Colors.blue.shade700;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          'Reports',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploadReport,
        label: const Text('Upload'),
        icon: const Icon(Icons.upload_file),
        backgroundColor: primaryColor,
        elevation: 6,
        hoverElevation: 12,
      ),
      body: Column(
        children: [
          GestureDetector(
            onTap: _selectDate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(

                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, color: primaryColor),
                  // FoundationAmountWidget(),
                  const SizedBox(width: 12),
                  Text(
                    '${_monthName(selectedDate.month)} ${selectedDate.year}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                ],
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              onRefresh: _fetchReports,
              color: primaryColor,
              child: reports.isEmpty
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No reports found for this month.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final report = reports[index];
                  return _ReportCard(
                    report: report,
                    isDeleting: isDeleting && deletingIndex == index,
                    onDelete: () => _deleteReport(report['id'], report['file_path'], index),
                    onOpen: () async {
                      final url = report['file_url'];
                      if (url != null && await canLaunchUrl(Uri.parse(url))) {
                        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                      } else {
                        _showError('Could not open the report.');
                      }
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      '', // padding to make months 1-based
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month];
  }
}

class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final bool isDeleting;
  final VoidCallback onDelete;
  final VoidCallback onOpen;

  const _ReportCard({
    Key? key,
    required this.report,
    required this.isDeleting,
    required this.onDelete,
    required this.onOpen,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.blue.shade700;
    return Card(
      elevation: 6,
      shadowColor: primaryColor.withOpacity(0.25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        onTap: onOpen,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        leading: Container(
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(12),
          child: Icon(
            Icons.insert_drive_file,
            color: primaryColor,
            size: 32,
          ),
        ),
        title: Text(
          report['name'],
          style: const TextStyle(fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isDeleting
            ? const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 3),
        )
            : IconButton(
          icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
          onPressed: onDelete,
          splashRadius: 24,
          tooltip: 'Delete report',
        ),
      ),
    );
  }
}
