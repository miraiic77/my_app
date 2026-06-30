import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/csv_service.dart';

class ViewReportsScreen extends StatefulWidget {
  const ViewReportsScreen({super.key});

  @override
  State<ViewReportsScreen> createState() => _ViewReportsScreenState();
}

class _ViewReportsScreenState extends State<ViewReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String? _selectedBatchId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(context: context, initialDate: _endDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
    if (picked != null) setState(() => _endDate = picked);
  }

  String _formatDate(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Color _getStatusColor(String status) {
    switch (status) {
      case 'present': return Colors.green;
      case 'absent': return Colors.red;
      case 'late': return Colors.orange;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Reports'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [Tab(text: 'Student Reports'), Tab(text: 'Faculty Reports')],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.teal.shade50,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: InkWell(onTap: _pickStartDate, child: InputDecorator(decoration: const InputDecoration(labelText: 'Start Date', border: OutlineInputBorder(), filled: true, fillColor: Colors.white, suffixIcon: Icon(Icons.calendar_today, size: 20)), child: Text(_formatDate(_startDate))))),
                    const SizedBox(width: 12),
                    Expanded(child: InkWell(onTap: _pickEndDate, child: InputDecorator(decoration: const InputDecoration(labelText: 'End Date', border: OutlineInputBorder(), filled: true, fillColor: Colors.white, suffixIcon: Icon(Icons.calendar_today, size: 20)), child: Text(_formatDate(_endDate))))),
                  ],
                ),
                if (_tabController.index == 0) ...[
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('batches').orderBy('name').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();
                      final batches = snapshot.data!.docs;
                      return DropdownButtonFormField<String>(
                        value: _selectedBatchId,
                        decoration: const InputDecoration(labelText: 'Filter by Batch (Optional)', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                        items: [const DropdownMenuItem(value: null, child: Text('All Batches')), ...batches.map((batch) { final data = batch.data() as Map<String, dynamic>; return DropdownMenuItem(value: batch.id, child: Text(data['name'] ?? 'Unnamed')); })],
                        onChanged: (value) => setState(() => _selectedBatchId = value),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(hintText: 'Search by name...', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white, suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _searchQuery = '')) : null),
                  onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                ),
              ],
            ),
          ),
          Expanded(child: TabBarView(controller: _tabController, children: [_buildStudentReports(), _buildFacultyReports()])),
        ],
      ),
    );
  }

  Widget _buildStudentReports() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('student_attendance').orderBy('date').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final allRecords = snapshot.data!.docs;
        final startDateStr = _formatDate(_startDate);
        final endDateStr = _formatDate(_endDate);
        
        var filteredRecords = allRecords.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final date = data['date'] ?? '';
          return date.compareTo(startDateStr) >= 0 && date.compareTo(endDateStr) <= 0;
        }).toList();

        if (_selectedBatchId != null) filteredRecords = filteredRecords.where((doc) => (doc.data() as Map<String, dynamic>)['batchId'] == _selectedBatchId).toList();
        if (_searchQuery.isNotEmpty) filteredRecords = filteredRecords.where((doc) => (doc.data() as Map<String, dynamic>)['studentName'].toString().toLowerCase().contains(_searchQuery)).toList();

        if (filteredRecords.isEmpty) return const Center(child: Text('No attendance records found'));

        Map<String, List<Map<String, dynamic>>> groupedByStudent = {};
        for (var doc in filteredRecords) {
          final data = doc.data() as Map<String, dynamic>;
          final studentId = data['studentId'] ?? 'unknown';
          if (!groupedByStudent.containsKey(studentId)) groupedByStudent[studentId] = [];
          groupedByStudent[studentId]!.add({'date': data['date'], 'status': data['status'], 'studentName': data['studentName'], 'rollNumber': data['rollNumber'], 'batchName': data['batchName'], 'docId': doc.id});
        }

        int totalRecords = filteredRecords.length;
        int present = filteredRecords.where((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'present').length;
        int absent = filteredRecords.where((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'absent').length;
        int late = filteredRecords.where((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'late').length;
        double attendancePercentage = totalRecords > 0 ? ((present + late) / totalRecords * 100) : 0;

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16), color: Colors.white,
              child: Column(children: [
                Row(children: [_buildStatCard('Total', '$totalRecords', Colors.blue), const SizedBox(width: 8), _buildStatCard('Present', '$present', Colors.green), const SizedBox(width: 8), _buildStatCard('Absent', '$absent', Colors.red), const SizedBox(width: 8), _buildStatCard('Late', '$late', Colors.orange)]),
                const SizedBox(height: 12),
                Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.teal.shade200)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.analytics, color: Colors.teal, size: 32), const SizedBox(width: 12), Text('Overall Attendance Rate: ${attendancePercentage.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal))])),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: ElevatedButton.icon(onPressed: () => _exportStudentCsv(groupedByStudent), icon: const Icon(Icons.file_download), label: const Text('Export CSV'), style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white))),
                ]),
              ]),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: groupedByStudent.length,
                itemBuilder: (context, index) {
                  final studentId = groupedByStudent.keys.elementAt(index);
                  final records = groupedByStudent[studentId]!;
                  if (records.isEmpty) return const SizedBox();
                  
                  final firstRecord = records.first;
                  final studentName = firstRecord['studentName'] ?? 'Unknown';
                  final rollNumber = firstRecord['rollNumber'] ?? 'N/A';
                  final batchName = firstRecord['batchName'] ?? 'N/A';
                  
                  int studentPresent = records.where((r) => r['status'] == 'present').length;
                  int studentAbsent = records.where((r) => r['status'] == 'absent').length;
                  int studentLate = records.where((r) => r['status'] == 'late').length;
                  int studentTotal = records.length;
                  double studentPercentage = studentTotal > 0 ? ((studentPresent + studentLate) / studentTotal * 100) : 0;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: ExpansionTile(
                      leading: CircleAvatar(backgroundColor: studentPercentage >= 75 ? Colors.green : studentPercentage >= 50 ? Colors.orange : Colors.red, child: Text(studentName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      title: Row(children: [SizedBox(width: 120, child: Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)), const SizedBox(width: 8), SizedBox(width: 120, child: Text('Roll: $rollNumber', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)), SizedBox(width: 100, child: Text('Batch: $batchName', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))]),
                      subtitle: Text('Attendance: ${studentPercentage.toStringAsFixed(0)}% (${studentPresent}P/${studentAbsent}A/${studentLate}L)', style: TextStyle(color: studentPercentage >= 75 ? Colors.green : studentPercentage >= 50 ? Colors.orange : Colors.red, fontWeight: FontWeight.bold)),
                      trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: studentPercentage >= 75 ? Colors.green.shade100 : studentPercentage >= 50 ? Colors.orange.shade100 : Colors.red.shade100, borderRadius: BorderRadius.circular(20), border: Border.all(color: studentPercentage >= 75 ? Colors.green : studentPercentage >= 50 ? Colors.orange : Colors.red)), child: Text('${studentTotal} Records', style: TextStyle(color: studentPercentage >= 75 ? Colors.green.shade700 : studentPercentage >= 50 ? Colors.orange.shade700 : Colors.red.shade700, fontWeight: FontWeight.bold))),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Attendance History:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, runSpacing: 8, children: records.map((record) {
                              final date = record['date'] ?? '';
                              final status = record['status'] ?? '';
                              final color = _getStatusColor(status);
                              return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color)), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(date, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)), child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12)))]));
                            }).toList()),
                            const SizedBox(height: 16),
                            Row(children: [
                              Expanded(child: ElevatedButton.icon(onPressed: () => _editAttendanceRecord(studentId, records), icon: const Icon(Icons.edit), label: const Text('Edit'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue))),
                              const SizedBox(width: 8),
                              Expanded(child: ElevatedButton.icon(onPressed: () => _deleteAttendanceRecords(studentId, records), icon: const Icon(Icons.delete), label: const Text('Delete'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red))),
                            ]),
                          ]),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFacultyReports() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('faculty_attendance').orderBy('date').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final allRecords = snapshot.data!.docs;
        final startDateStr = _formatDate(_startDate);
        final endDateStr = _formatDate(_endDate);
        
        var filteredRecords = allRecords.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final date = data['date'] ?? '';
          return date.compareTo(startDateStr) >= 0 && date.compareTo(endDateStr) <= 0;
        }).toList();

        if (_searchQuery.isNotEmpty) filteredRecords = filteredRecords.where((doc) => (doc.data() as Map<String, dynamic>)['facultyName'].toString().toLowerCase().contains(_searchQuery)).toList();

        if (filteredRecords.isEmpty) return const Center(child: Text('No attendance records found'));

        Map<String, List<Map<String, dynamic>>> groupedByFaculty = {};
        for (var doc in filteredRecords) {
          final data = doc.data() as Map<String, dynamic>;
          final facultyId = data['facultyId'] ?? 'unknown';
          if (!groupedByFaculty.containsKey(facultyId)) groupedByFaculty[facultyId] = [];
          groupedByFaculty[facultyId]!.add({'date': data['date'], 'status': data['status'], 'facultyName': data['facultyName'], 'subject': data['subject'], 'docId': doc.id});
        }

        int totalRecords = filteredRecords.length;
        int present = filteredRecords.where((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'present').length;
        int absent = filteredRecords.where((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'absent').length;
        int late = filteredRecords.where((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'late').length;
        double attendancePercentage = totalRecords > 0 ? ((present + late) / totalRecords * 100) : 0;

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16), color: Colors.white,
              child: Column(children: [
                Row(children: [_buildStatCard('Total', '$totalRecords', Colors.blue), const SizedBox(width: 8), _buildStatCard('Present', '$present', Colors.green), const SizedBox(width: 8), _buildStatCard('Absent', '$absent', Colors.red), const SizedBox(width: 8), _buildStatCard('Late', '$late', Colors.orange)]),
                const SizedBox(height: 12),
                Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.teal.shade200)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.analytics, color: Colors.teal, size: 32), const SizedBox(width: 12), Text('Overall Attendance Rate: ${attendancePercentage.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal))])),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: ElevatedButton.icon(onPressed: () => _exportFacultyCsv(groupedByFaculty), icon: const Icon(Icons.file_download), label: const Text('Export CSV'), style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white))),
                ]),
              ]),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: groupedByFaculty.length,
                itemBuilder: (context, index) {
                  final facultyId = groupedByFaculty.keys.elementAt(index);
                  final records = groupedByFaculty[facultyId]!;
                  if (records.isEmpty) return const SizedBox();
                  
                  final firstRecord = records.first;
                  final facultyName = firstRecord['facultyName'] ?? 'Unknown';
                  final subject = firstRecord['subject'] ?? 'N/A';
                  
                  int facultyPresent = records.where((r) => r['status'] == 'present').length;
                  int facultyAbsent = records.where((r) => r['status'] == 'absent').length;
                  int facultyLate = records.where((r) => r['status'] == 'late').length;
                  int facultyTotal = records.length;
                  double facultyPercentage = facultyTotal > 0 ? ((facultyPresent + facultyLate) / facultyTotal * 100) : 0;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: ExpansionTile(
                      leading: CircleAvatar(backgroundColor: facultyPercentage >= 75 ? Colors.green : facultyPercentage >= 50 ? Colors.orange : Colors.red, child: Text(facultyName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      title: Row(children: [SizedBox(width: 120, child: Text(facultyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)), const SizedBox(width: 8), SizedBox(width: 150, child: Text('Subject: $subject', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))]),
                      subtitle: Text('Attendance: ${facultyPercentage.toStringAsFixed(0)}% (${facultyPresent}P/${facultyAbsent}A/${facultyLate}L)', style: TextStyle(color: facultyPercentage >= 75 ? Colors.green : facultyPercentage >= 50 ? Colors.orange : Colors.red, fontWeight: FontWeight.bold)),
                      trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: facultyPercentage >= 75 ? Colors.green.shade100 : facultyPercentage >= 50 ? Colors.orange.shade100 : Colors.red.shade100, borderRadius: BorderRadius.circular(20), border: Border.all(color: facultyPercentage >= 75 ? Colors.green : facultyPercentage >= 50 ? Colors.orange : Colors.red)), child: Text('${facultyTotal} Records', style: TextStyle(color: facultyPercentage >= 75 ? Colors.green.shade700 : facultyPercentage >= 50 ? Colors.orange.shade700 : Colors.red.shade700, fontWeight: FontWeight.bold))),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Attendance History:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, runSpacing: 8, children: records.map((record) {
                              final date = record['date'] ?? '';
                              final status = record['status'] ?? '';
                              final color = _getStatusColor(status);
                              return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color)), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(date, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)), child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12)))]));
                            }).toList()),
                            const SizedBox(height: 16),
                            Row(children: [
                              Expanded(child: ElevatedButton.icon(onPressed: () => _editAttendanceRecord(facultyId, records, isFaculty: true), icon: const Icon(Icons.edit), label: const Text('Edit'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue))),
                              const SizedBox(width: 8),
                              Expanded(child: ElevatedButton.icon(onPressed: () => _deleteAttendanceRecords(facultyId, records, isFaculty: true), icon: const Icon(Icons.delete), label: const Text('Delete'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red))),
                            ]),
                          ]),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))), child: Column(children: [Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)), Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700), textAlign: TextAlign.center)])));
  }

  Future<void> _editAttendanceRecord(String personId, List<Map<String, dynamic>> records, {bool isFaculty = false}) async {
    final selectedDate = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(title: const Text('Select Date to Edit'), content: SizedBox(width: 400, height: 300, child: ListView.builder(itemCount: records.length, itemBuilder: (context, index) {
        final record = records[index];
        return ListTile(title: Text(record['date'] ?? ''), trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _getStatusColor(record['status']).withOpacity(0.2), borderRadius: BorderRadius.circular(4)), child: Text(record['status'].toUpperCase())), onTap: () => Navigator.pop(ctx, record['date']));
      })), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))]),
    );
    if (selectedDate == null) return;

    final newStatus = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(title: const Text('Select New Status'), content: Column(mainAxisSize: MainAxisSize.min, children: [ListTile(leading: const Icon(Icons.check_circle, color: Colors.green), title: const Text('Present'), onTap: () => Navigator.pop(ctx, 'present')), ListTile(leading: const Icon(Icons.cancel, color: Colors.red), title: const Text('Absent'), onTap: () => Navigator.pop(ctx, 'absent')), ListTile(leading: const Icon(Icons.access_time, color: Colors.orange), title: const Text('Late'), onTap: () => Navigator.pop(ctx, 'late'))])),
    );
    if (newStatus == null) return;

    try {
      final collectionName = isFaculty ? 'faculty_attendance' : 'student_attendance';
      final idField = isFaculty ? 'facultyId' : 'studentId';
      final query = await FirebaseFirestore.instance.collection(collectionName).where(idField, isEqualTo: personId).where('date', isEqualTo: selectedDate).get();
      for (var doc in query.docs) await doc.reference.update({'status': newStatus});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Attendance updated successfully!')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
  }

  Future<void> _deleteAttendanceRecords(String personId, List<Map<String, dynamic>> records, {bool isFaculty = false}) async {
    bool? confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Delete Attendance Records'), content: Text('Are you sure you want to delete ${records.length} attendance records?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete'))]));
    if (confirm != true) return;

    try {
      final collectionName = isFaculty ? 'faculty_attendance' : 'student_attendance';
      final idField = isFaculty ? 'facultyId' : 'studentId';
      for (var record in records) {
        final query = await FirebaseFirestore.instance.collection(collectionName).where(idField, isEqualTo: personId).where('date', isEqualTo: record['date']).get();
        for (var doc in query.docs) await doc.reference.delete();
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Records deleted successfully!')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
  }

  Future<void> _exportStudentCsv(Map<String, List<Map<String, dynamic>>> groupedData) async {
    List<Map<String, dynamic>> exportData = [];
    groupedData.forEach((studentId, records) { for (var record in records) exportData.add({'Date': record['date'], 'Student Name': record['studentName'], 'Roll Number': record['rollNumber'], 'Batch': record['batchName'], 'Status': record['status']}); });
    String csv = CsvService.convertToCsv(exportData);
    CsvService.downloadCsv(csv, 'student_attendance_report_${_formatDate(_startDate)}_to_${_formatDate(_endDate)}.csv');
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV exported successfully!')));
  }

  Future<void> _exportFacultyCsv(Map<String, List<Map<String, dynamic>>> groupedData) async {
    List<Map<String, dynamic>> exportData = [];
    groupedData.forEach((facultyId, records) { for (var record in records) exportData.add({'Date': record['date'], 'Faculty Name': record['facultyName'], 'Subject': record['subject'], 'Status': record['status']}); });
    String csv = CsvService.convertToCsv(exportData);
    CsvService.downloadCsv(csv, 'faculty_attendance_report_${_formatDate(_startDate)}_to_${_formatDate(_endDate)}.csv');
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV exported successfully!')));
  }
}