import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MarkAttendanceScreen extends StatefulWidget {
  const MarkAttendanceScreen({super.key});

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  String? _selectedBatchId;
  String? _selectedBatchName;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isSaving = false;
  
  Map<String, String> _attendanceStatus = {};
  List<Map<String, dynamic>> _students = [];

  Future<void> _loadStudents() async {
    if (_selectedBatchId == null) return;
    setState(() => _isLoading = true);
    _attendanceStatus.clear();
    _students.clear();

    try {
      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('batchId', isEqualTo: _selectedBatchId)
          .orderBy('name')
          .get();

      for (var doc in studentsSnapshot.docs) {
        final data = doc.data();
        _students.add({
          'id': doc.id,
          'name': data['name'] ?? '',
          'rollNumber': data['rollNumber'] ?? '',
          'email': data['email'] ?? '',
        });
        _attendanceStatus[doc.id] = 'present';
      }

      final dateStr = _formatDate(_selectedDate);
      final existingAttendance = await FirebaseFirestore.instance
          .collection('student_attendance')
          .where('date', isEqualTo: dateStr)
          .where('batchId', isEqualTo: _selectedBatchId)
          .get();

      if (existingAttendance.docs.isNotEmpty) {
        for (var doc in existingAttendance.docs) {
          final data = doc.data();
          final studentId = data['studentId'];
          if (studentId != null) {
            _attendanceStatus[studentId] = data['status'] ?? 'present';
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚠️ Attendance already marked for this date. You can update it.'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading students: $e')));
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveAttendance() async {
    if (_students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No students to mark attendance for')));
      return;
    }

    bool? confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Save Attendance'),
      content: Text('Save attendance for ${_students.length} students on ${_formatDate(_selectedDate)}?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
      ],
    ));

    if (confirm != true) return;
    setState(() => _isSaving = true);

    try {
      final dateStr = _formatDate(_selectedDate);
      final currentUser = FirebaseAuth.instance.currentUser;

      final existing = await FirebaseFirestore.instance
          .collection('student_attendance')
          .where('date', isEqualTo: dateStr)
          .where('batchId', isEqualTo: _selectedBatchId)
          .get();

      for (var doc in existing.docs) await doc.reference.delete();

      final batch = FirebaseFirestore.instance.batch();
      for (var student in _students) {
        final status = _attendanceStatus[student['id']] ?? 'present';
        final docRef = FirebaseFirestore.instance.collection('student_attendance').doc();
        batch.set(docRef, {
          'date': dateStr,
          'batchId': _selectedBatchId,
          'batchName': _selectedBatchName ?? '',
          'studentId': student['id'],
          'studentName': student['name'],
          'rollNumber': student['rollNumber'],
          'status': status,
          'markedBy': currentUser?.email ?? 'Unknown',
          'markedAt': Timestamp.now(),
        });
      }
      await batch.commit();

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Attendance saved for ${_students.length} students!'), backgroundColor: Colors.green, duration: const Duration(seconds: 2)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
    }
    setState(() => _isSaving = false);
  }

  void _markAllPresent() { setState(() { for (var student in _students) _attendanceStatus[student['id']] = 'present'; }); }
  void _markAllAbsent() { setState(() { for (var student in _students) _attendanceStatus[student['id']] = 'absent'; }); }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      if (_selectedBatchId != null) _loadStudents();
    }
  }

  String _formatDate(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  int _countByStatus(String status) => _attendanceStatus.values.where((s) => s == status).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mark Attendance'), backgroundColor: Colors.purple, foregroundColor: Colors.white),
      body: Column(
        children: [
          Container(padding: const EdgeInsets.all(16), color: Colors.purple.shade50, child: const Row(children: [Icon(Icons.check_circle, color: Colors.purple, size: 32), SizedBox(width: 12), Text('Mark Student Attendance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))])),
          Container(
            padding: const EdgeInsets.all(16), color: Colors.grey.shade100,
            child: Column(children: [
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('batches').orderBy('name').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  final batches = snapshot.data!.docs;
                  return DropdownButtonFormField<String>(
                    value: _selectedBatchId,
                    decoration: const InputDecoration(labelText: 'Select Batch *', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                    items: batches.map((batch) {
                      final data = batch.data() as Map<String, dynamic>;
                      return DropdownMenuItem(value: batch.id, child: Text(data['name'] ?? 'Unnamed'));
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedBatchId = value;
                        final batch = batches.firstWhere((b) => b.id == value);
                        _selectedBatchName = (batch.data() as Map<String, dynamic>)['name'];
                      });
                      _loadStudents();
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              InkWell(onTap: _pickDate, child: InputDecorator(decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder(), filled: true, fillColor: Colors.white, suffixIcon: Icon(Icons.calendar_today)), child: Text(_formatDate(_selectedDate)))),
            ]),
          ),
          if (_students.isNotEmpty)
            Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), color: Colors.white, child: Row(children: [
              _buildStatusChip('Present', _countByStatus('present'), Colors.green), const SizedBox(width: 8),
              _buildStatusChip('Absent', _countByStatus('absent'), Colors.red), const SizedBox(width: 8),
              _buildStatusChip('Late', _countByStatus('late'), Colors.orange), const Spacer(),
              TextButton.icon(onPressed: _markAllPresent, icon: const Icon(Icons.check, size: 18), label: const Text('All Present')),
              TextButton.icon(onPressed: _markAllAbsent, icon: const Icon(Icons.close, size: 18), label: const Text('All Absent')),
            ])),
          Expanded(
            child: _isLoading ? const Center(child: CircularProgressIndicator())
            : _selectedBatchId == null ? const Center(child: Text('Select a batch to view students', style: TextStyle(color: Colors.grey, fontSize: 16)))
            : _students.isEmpty ? const Center(child: Text('No students in this batch', style: TextStyle(color: Colors.grey, fontSize: 16)))
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _students.length,
                itemBuilder: (context, index) {
                  final student = _students[index];
                  final status = _attendanceStatus[student['id']] ?? 'present';
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          CircleAvatar(backgroundColor: _getStatusColor(status).withOpacity(0.2), child: Text((student['name'] ?? '?')[0].toUpperCase(), style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold))),
                          const SizedBox(width: 12),
                          SizedBox(width: 120, child: Text(student['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          SizedBox(width: 120, child: Text('Roll: ${student['rollNumber'] ?? 'N/A'}', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                          const Spacer(),
                          _buildStatusToggle(student['id'], status),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ),
          if (_students.isNotEmpty)
            Container(padding: const EdgeInsets.all(16), color: Colors.white, child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveAttendance,
              icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
              label: Text(_isSaving ? 'Saving...' : 'Save Attendance (${_students.length} students)', style: const TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ))),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, int count, Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color)), child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6), Text('$count $label', style: TextStyle(color: color, fontWeight: FontWeight.bold))]));
  }

  Widget _buildStatusToggle(String studentId, String currentStatus) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _buildStatusButton(studentId, 'present', 'P', Colors.green, currentStatus), const SizedBox(width: 4),
      _buildStatusButton(studentId, 'absent', 'A', Colors.red, currentStatus), const SizedBox(width: 4),
      _buildStatusButton(studentId, 'late', 'L', Colors.orange, currentStatus),
    ]);
  }

  Widget _buildStatusButton(String studentId, String status, String label, Color color, String currentStatus) {
    final isSelected = currentStatus == status;
    return InkWell(onTap: () { setState(() { _attendanceStatus[studentId] = status; }); }, child: Container(width: 36, height: 36, decoration: BoxDecoration(color: isSelected ? color : Colors.grey.shade200, borderRadius: BorderRadius.circular(8), border: Border.all(color: isSelected ? color : Colors.grey.shade400)), child: Center(child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade700, fontWeight: FontWeight.bold)))));
  }

  Color _getStatusColor(String status) {
    switch (status) { case 'present': return Colors.green; case 'absent': return Colors.red; case 'late': return Colors.orange; default: return Colors.grey; }
  }
}