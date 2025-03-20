import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io'; // For File class


class ReportsPage extends StatefulWidget {
  @override
  _ReportsPageState createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> reports = []; // List to store report details
  String selectedMonth = 'All'; // Default month for filtering
  List<Map<String, dynamic>> filteredReports = [];
  bool isLoading = false; // To track if a report is being uploaded

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  // Fetch reports from Supabase
  Future<void> _fetchReports() async {
    final response = await _supabase.from('reports').select('*').order('date', ascending: false);
    setState(() {
      reports = List<Map<String, dynamic>>.from(response);
      _filterReports();
    });
  }

  // Upload report to Supabase
  Future<void> _uploadReport() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );

    if (result != null) {
      setState(() => isLoading = true);
      try {
        final file = result.files.single;

        // Convert Uint8List to File
        String tempPath = '${(await getTemporaryDirectory()).path}/${file.name}';
        File tempFile = File(tempPath);
        await tempFile.writeAsBytes(file.bytes!);

        // Upload the converted file
        final fileUrl = 'reports/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        await _supabase.storage.from('reports').upload(fileUrl, tempFile);

        // Insert report metadata into the `reports` table
        await _supabase.from('reports').insert({
          'name': file.name,
          'date': DateTime.now().toIso8601String(),
          'file_url': fileUrl,
        });

        // Refresh reports
        _fetchReports();
      } catch (e) {
        print('Error uploading report: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload report')),
        );
      } finally {
        setState(() => isLoading = false);
      }
    }
  }


  // Delete report from Supabase
  Future<void> _deleteReport(String id) async {
    try {
      await _supabase.from('reports').delete().eq('id', id);
      _fetchReports(); // Refresh the reports list
    } catch (e) {
      print('Error deleting report: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete report')),
      );
    }
  }

  // Filter reports by selected month
  void _filterReports() {
    if (selectedMonth == 'All') {
      filteredReports = List.from(reports);
    } else {
      filteredReports = reports.where((report) {
        DateTime reportDate = DateTime.parse(report["date"]);
        return DateFormat('MMMM').format(reportDate) == selectedMonth;
      }).toList();
    }
  }

  // Download report file
  Future<void> _downloadReport(String url, String fileName) async {
    try {
      var dio = Dio();
      String dir = (await getApplicationDocumentsDirectory()).path;
      await dio.download(url, "$dir/$fileName");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloaded $fileName')),
      );
    } catch (e) {
      print('Error downloading report: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download report')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> months = [
      'All',
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

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Monthly Reports',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.upload_file),
                  onPressed: _uploadReport,
                ),
              ],
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedMonth,
              items: months.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedMonth = newValue!;
                  _filterReports();
                });
              },
              decoration: InputDecoration(
                labelText: 'Select Month',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator())
                  : filteredReports.isEmpty
                  ? Center(child: Text('No reports found.'))
                  : ListView.builder(
                itemCount: filteredReports.length,
                itemBuilder: (context, index) {
                  Map<String, dynamic> report = filteredReports[index];
                  DateTime reportDate = DateTime.parse(report["date"]);
                  String formattedDate = DateFormat('MMMM yyyy').format(reportDate);
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      leading: Icon(Icons.description),
                      title: Text(report["name"]),
                      subtitle: Text(formattedDate),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.download),
                            onPressed: () {
                              _downloadReport(report["file_url"], report["name"]);
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () {
                              _deleteReport(report["id"]);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}