import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

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
  bool isAdmin = false;

  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchReports();
    _checkIfAdmin();
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
      print('Error fetching reports: $e'); // Pour dev
      _showError('⚠️ Impossible de charger les rapports. Vérifie ta connexion Internet.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _checkIfAdmin() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('users')
          .select('role')
          .eq('id', userId)
          .maybeSingle();

      if (response != null && response['role'] == 'admin') {
        setState(() {
          isAdmin = true;
        });
      }
    } catch (e) {
      print('Error checking admin role: $e');
      // Pas de snack, ce n’est pas critique
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
          _showError('⚠️ Tu dois être connecté pour uploader un rapport.');
          return;
        }

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filePath = 'report_${timestamp}_${file.name.replaceAll(' ', '_')}';

        await _supabase.storage.from('reports').upload(filePath, File(file.path!));
        final fileUrl = _supabase.storage.from('reports').getPublicUrl(filePath);

        final inserted = await _supabase.from('reports').insert({
          'name': file.name,
          'file_url': fileUrl,
          'file_path': filePath,
          'user_id': userId,
          'created_at': DateTime.now().toIso8601String(),
        }).select().single();

        // 🔔 Notification via Edge Function
        await _supabase.functions.invoke(
          'sendNotification',
          body: {
            'table': 'reports',
            'record': {
              'id': inserted['id'],
              'name': file.name,
              'user_id': userId,
            },
          },
        );

        await _fetchReports();
        _showSuccess('🚀 ${file.name} uploaded successfully!');
      }
    } catch (e) {
      print('Error uploading report: $e');
      _showError('⚠️ Impossible d’uploader le rapport. Vérifie ta connexion.');
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
      _showSuccess('🗑️ Rapport supprimé avec succès');
    } catch (e) {
      print('Error deleting report: $e');
      _showError('⚠️ Impossible de supprimer le rapport.');
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
          content: Text(message, style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.poppins()),
          backgroundColor: Colors.green,
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Reports', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
        onPressed: _uploadReport,
        label: Text('Upload', style: GoogleFonts.poppins(color: Colors.white)),
        icon: const Icon(Icons.upload_file),
        backgroundColor: Color(0xFF1976D2),
      )
          : null,
      body: Column(
        children: [
          GestureDetector(
            onTap: _selectDate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade100,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, color: Color(0xFF1976D2)),
                  const SizedBox(width: 12),
                  Text(
                    '${_monthName(selectedDate.month)} ${selectedDate.year}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1976D2),
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
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1976D2)))
                : RefreshIndicator(
              onRefresh: _fetchReports,
              color: Color(0xFF1976D2),
              child: reports.isEmpty
                  ? Center(
                child: Text(
                  'Aucun rapport pour ce mois.',
                  style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade600),
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final report = reports[index];
                  return _ReportCard(
                    report: report,
                    isDeleting: isDeleting && deletingIndex == index,
                    isAdmin: isAdmin,
                    onDelete: () => _deleteReport(report['id'], report['file_path'], index),
                    onOpen: () async {
                      final url = report['file_url'];
                      if (url != null && await canLaunchUrl(Uri.parse(url))) {
                        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                      } else {
                        _showError('⚠️ Impossible d’ouvrir le rapport.');
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
      '',
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
  final bool isAdmin;
  final VoidCallback onDelete;
  final VoidCallback onOpen;

  const _ReportCard({
    Key? key,
    required this.report,
    required this.isDeleting,
    required this.isAdmin,
    required this.onDelete,
    required this.onOpen,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        onTap: onOpen,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          decoration: BoxDecoration(
            color: Color(0xFF1976D2).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(10),
          child: Icon(Icons.insert_drive_file, color: Color(0xFF1976D2), size: 28),
        ),
        title: Text(
          report['name'],
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        trailing: isAdmin
            ? (isDeleting
            ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF1976D2)),
        )
            : IconButton(
          icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
          onPressed: onDelete,
        ))
            : null,
      ),
    );
  }
}
