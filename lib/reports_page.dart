import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class ReportsPage extends StatefulWidget {
  @override
  _ReportsPageState createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  List<Map<String, dynamic>> reports = []; // List to store report details
  String selectedMonth = 'All'; // Default month for filtering
  List<Map<String, dynamic>> filteredReports = [];
  bool isLoading = false; // To track if a report is being uploaded

  @override
  void initState() {
    super.initState();
    _loadDummyReports();
    _filterReports();
  }

  // Dummy reports data for testing
  void _loadDummyReports() {
    DateTime now = DateTime.now();
    reports.addAll([
      {
        "name": "Monthly Report - January",
        "date": DateTime(now.year, 1),
        "filePath": "https://example.com/report_january.pdf" // Example URL
      },
      {
        "name": "Monthly Report - February",
        "date": DateTime(now.year, 2),
        "filePath": "https://example.com/report_february.pdf" // Example URL
      },
      {
        "name": "Monthly Report - March",
        "date": DateTime(now.year, 3),
        "filePath": "https://example.com/report_march.pdf" // Example URL
      },
      {
        "name": "Monthly Report - April",
        "date": DateTime(now.year, 4),
        "filePath": "https://example.com/report_april.pdf" // Example URL
      },
    ]);
    _filterReports();
  }

  // Function to simulate report upload (replace with your actual logic)
  void _uploadReport() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );

    if (result != null) {
      setState(() {
        isLoading = true;
      });
      try {
        String fileName = result.files.single.name;
        DateTime now = DateTime.now();
        reports.add({
          "name": fileName,
          "date": now,
          "filePath": result.files.single.path,
        });
        _filterReports();
      } catch (e) {
        print('Error uploading report: $e');
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    } else {
      // User canceled the picker
    }
  }

  void _deleteReport(int index) {
    setState(() {
      // Find the report in the original list
      Map<String, dynamic> reportToDelete = filteredReports[index];
      reports.remove(reportToDelete);
      filteredReports.removeAt(index);
    });
  }

  // Function to filter reports by selected month
  void _filterReports() {
    if (selectedMonth == 'All') {
      filteredReports = List.from(reports);
    } else {
      filteredReports = reports.where((report) {
        DateTime reportDate = report["date"];
        return DateFormat('MMMM').format(reportDate) == selectedMonth;
      }).toList();
    }
  }

  Future<void> _downloadReport(String url, String fileName) async {
    try {
      var dio = Dio();
      // Specify the download path
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
              child: filteredReports.isEmpty
                  ? Center(child: Text('No reports found.'))
                  : ListView.builder(
                itemCount: filteredReports.length,
                itemBuilder: (context, index) {
                  Map<String, dynamic> report = filteredReports[index];
                  DateTime reportDate = report["date"];
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
                              _downloadReport(report["filePath"], report["name"]);
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () {
                              _deleteReport(index);
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