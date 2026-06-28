import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/csv_service.dart';

class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  State<StudentManagementScreen> createState() =>
      _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _rollController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedBatchId;
  bool _isLoading = false;
  bool _isEditing = false;
  String? _editingStudentId;
  String _searchQuery = '';

  @override
  void dispose() {
    _nameController.dispose();
    _rollController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _nameController.clear();
    _rollController.clear();
    _emailController.clear();
    _phoneController.clear();
    _selectedBatchId = null;
    _isEditing = false;
    _editingStudentId = null;
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBatchId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a batch')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final studentData = {
        'name': _nameController.text.trim(),
        'rollNumber': _rollController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'batchId': _selectedBatchId,
        'enrollmentDate': Timestamp.now(),
      };

      if (_isEditing && _editingStudentId != null) {
        await FirebaseFirestore.instance
            .collection('students')
            .doc(_editingStudentId)
            .update(studentData);
      } else {
        await FirebaseFirestore.instance
            .collection('students')
            .add(studentData);

        // Update student count in batch
        await FirebaseFirestore.instance
            .collection('batches')
            .doc(_selectedBatchId)
            .update({'studentCount': FieldValue.increment(1)});
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Student updated!' : 'Student added!'),
        ),
      );

      _clearForm();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }

    setState(() => _isLoading = false);
  }

  Future<void> _editStudent(String docId, Map<String, dynamic> data) async {
    _nameController.text = data['name'] ?? '';
    _rollController.text = data['rollNumber'] ?? '';
    _emailController.text = data['email'] ?? '';
    _phoneController.text = data['phone'] ?? '';
    _selectedBatchId = data['batchId'];
    _isEditing = true;
    _editingStudentId = docId;
    _showStudentDialog();
  }

  Future<void> _deleteStudent(String docId, String? batchId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Student'),
        content: const Text('Are you sure you want to delete this student?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('students')
            .doc(docId)
            .delete();

        // Update student count in batch
        if (batchId != null) {
          await FirebaseFirestore.instance
              .collection('batches')
              .doc(batchId)
              .update({'studentCount': FieldValue.increment(-1)});
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Student deleted')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _exportStudents() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('students')
          .get();
      final batchesSnapshot = await FirebaseFirestore.instance
          .collection('batches')
          .get();

      // Create batch ID to name map
      Map<String, String> batchMap = {};
      for (var batch in batchesSnapshot.docs) {
        batchMap[batch.id] = batch.data()['name'] ?? 'Unknown';
      }

      List<Map<String, dynamic>> students = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'Student ID': doc.id,
          'Name': data['name'] ?? '',
          'Roll Number': data['rollNumber'] ?? '',
          'Email': data['email'] ?? '',
          'Phone': data['phone'] ?? '',
          'Batch': batchMap[data['batchId']] ?? 'Unknown',
          'Enrollment Date':
              (data['enrollmentDate'] as Timestamp?)?.toDate().toString() ?? '',
        };
      }).toList();

      String csv = CsvService.convertToCsv(students);
      CsvService.downloadCsv(csv, 'students_export.csv');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Students exported successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export error: $e')));
    }
  }

  Future<void> _importStudents() async {
    try {
      String? csvData = await CsvService.pickCsvFile();
      if (csvData == null) return;

      // Get batches to match names to IDs
      final batchesSnapshot = await FirebaseFirestore.instance
          .collection('batches')
          .get();
      Map<String, String> batchNameToId = {};
      for (var batch in batchesSnapshot.docs) {
        batchNameToId[batch.data()['name']?.toLowerCase() ?? ''] = batch.id;
      }

      List<Map<String, dynamic>> students = CsvService.parseCsv(csvData);

      int successCount = 0;
      for (var student in students) {
        if (student['Name'] != null && student['Name'].toString().isNotEmpty) {
          // Try to find batch ID from batch name
          String? batchId;
          String batchName = student['Batch']?.toString().toLowerCase() ?? '';
          if (batchName.isNotEmpty) {
            batchId = batchNameToId[batchName];
          }

          if (batchId != null) {
            await FirebaseFirestore.instance.collection('students').add({
              'name': student['Name'],
              'rollNumber': student['Roll Number'] ?? '',
              'email': student['Email'] ?? '',
              'phone': student['Phone'] ?? '',
              'batchId': batchId,
              'enrollmentDate': Timestamp.now(),
            });
            successCount++;
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported $successCount students successfully!'),
        ),
      );

      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import error: $e')));
    }
  }

  void _showStudentDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(_isEditing ? 'Edit Student' : 'Add New Student'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Student Name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _rollController,
                      decoration: const InputDecoration(
                        labelText: 'Roll Number *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('batches')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const CircularProgressIndicator();
                        }

                        final batches = snapshot.data!.docs;
                        return DropdownButtonFormField<String>(
                          value: _selectedBatchId,
                          decoration: const InputDecoration(
                            labelText: 'Batch *',
                            border: OutlineInputBorder(),
                          ),
                          items: batches.map((batch) {
                            return DropdownMenuItem(
                              value: batch.id,
                              child: Text(
                                (batch.data()
                                        as Map<String, dynamic>)['name'] ??
                                    'Unnamed',
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedBatchId = value;
                            });
                          },
                          validator: (v) => v == null ? 'Required' : null,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _clearForm();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveStudent,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Management'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export CSV',
            onPressed: _exportStudents,
          ),
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: 'Import CSV',
            onPressed: _importStudents,
          ),
        ],
      ),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green.shade50,
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.green, size: 32),
                const SizedBox(width: 12),
                const Text(
                  'Manage Students',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () {
                    _clearForm();
                    _showStudentDialog();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Student'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name, roll number, or email...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // Students List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('students')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final students = snapshot.data!.docs;

                // Filter students based on search
                final filteredStudents = students.where((student) {
                  final data = student.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final roll = (data['rollNumber'] ?? '')
                      .toString()
                      .toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) ||
                      roll.contains(_searchQuery) ||
                      email.contains(_searchQuery);
                }).toList();

                if (filteredStudents.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'No students found. Add one to get started!'
                          : 'No students match your search.',
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredStudents.length,
                  itemBuilder: (context, index) {
                    final student = filteredStudents[index];
                    final data = student.data() as Map<String, dynamic>;

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('batches')
                          .doc(data['batchId'])
                          .get(),
                      builder: (context, batchSnapshot) {
                        String batchName = 'Loading...';
                        if (batchSnapshot.hasData &&
                            batchSnapshot.data!.exists) {
                          batchName = batchSnapshot.data!['name'] ?? 'Unknown';
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green.shade100,
                              child: Text(
                                (data['name'] ?? '?')[0].toUpperCase(),
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              data['name'] ?? 'Unnamed',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text('Roll: ${data['rollNumber'] ?? 'N/A'}'),
                                Text('Batch: $batchName'),
                                if (data['email'] != null &&
                                    data['email'].toString().isNotEmpty)
                                  Text('Email: ${data['email']}'),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 20),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete,
                                        size: 20,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _editStudent(student.id, data);
                                } else if (value == 'delete') {
                                  _deleteStudent(student.id, data['batchId']);
                                }
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
