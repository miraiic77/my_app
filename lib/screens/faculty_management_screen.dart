import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/csv_service.dart';

class FacultyManagementScreen extends StatefulWidget {
  const FacultyManagementScreen({super.key});

  @override
  State<FacultyManagementScreen> createState() => _FacultyManagementScreenState();
}

class _FacultyManagementScreenState extends State<FacultyManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _subjectController = TextEditingController();
  bool _isLoading = false;
  bool _isEditing = false;
  String? _editingFacultyId;
  String _searchQuery = '';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _nameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _subjectController.clear();
    _isEditing = false;
    _editingFacultyId = null;
  }

  Future<void> _saveFaculty() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final facultyData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'subject': _subjectController.text.trim(),
        'createdAt': Timestamp.now(),
      };

      if (_isEditing && _editingFacultyId != null) {
        await FirebaseFirestore.instance.collection('faculties').doc(_editingFacultyId).update(facultyData);
      } else {
        await FirebaseFirestore.instance.collection('faculties').add(facultyData);
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEditing ? 'Faculty updated!' : 'Faculty added!')));
      _clearForm();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => _isLoading = false);
  }

  Future<void> _editFaculty(String docId, Map<String, dynamic> data) async {
    _nameController.text = data['name'] ?? '';
    _emailController.text = data['email'] ?? '';
    _phoneController.text = data['phone'] ?? '';
    _subjectController.text = data['subject'] ?? '';
    _isEditing = true;
    _editingFacultyId = docId;
    _showFacultyDialog();
  }

  Future<void> _deleteFaculty(String docId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Faculty'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('faculties').doc(docId).delete();
    }
  }

  Future<void> _exportFaculties() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('faculties').get();
      List<Map<String, dynamic>> faculties = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'Faculty ID': doc.id,
          'Name': data['name'] ?? '',
          'Email': data['email'] ?? '',
          'Phone': data['phone'] ?? '',
          'Subject': data['subject'] ?? '',
        };
      }).toList();

      String csv = CsvService.convertToCsv(faculties);
      CsvService.downloadCsv(csv, 'faculties_export.csv');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exported!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _importFaculties() async {
    try {
      String? csvData = await CsvService.pickCsvFile();
      if (csvData == null) return;

      List<Map<String, dynamic>> faculties = CsvService.parseCsv(csvData);
      int count = 0;
      for (var faculty in faculties) {
        String name = faculty['Name'] ?? faculty['Faculty Name'] ?? '';
        if (name.isNotEmpty) {
          await FirebaseFirestore.instance.collection('faculties').add({
            'name': name,
            'email': faculty['Email'] ?? '',
            'phone': faculty['Phone'] ?? '',
            'subject': faculty['Subject'] ?? '',
            'createdAt': Timestamp.now(),
          });
          count++;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported $count faculties!')));
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showFacultyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isEditing ? 'Edit Faculty' : 'Add New Faculty'),
        content: SizedBox(
          width: 400,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name *', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 12),
                  TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  TextFormField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  TextFormField(controller: _subjectController, decoration: const InputDecoration(labelText: 'Subject *', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'Required' : null),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () { _clearForm(); Navigator.pop(context); }, child: const Text('Cancel')),
          ElevatedButton(onPressed: _isLoading ? null : _saveFaculty, child: Text(_isEditing ? 'Update' : 'Add')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculty Management'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.file_download), onPressed: _exportFaculties),
          IconButton(icon: const Icon(Icons.file_upload), onPressed: _importFaculties),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.orange.shade50,
            child: Row(
              children: [
                const Icon(Icons.school, color: Colors.orange, size: 32),
                const SizedBox(width: 12),
                const Text('Manage Faculty', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () { _clearForm(); _showFacultyDialog(); },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Faculty'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name, email, subject...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _searchQuery = '')) : null,
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('faculties').orderBy('name').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final faculties = snapshot.data!.docs;
                
                final filtered = faculties.where((f) {
                  final data = f.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final subject = (data['subject'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) || subject.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) return Center(child: Text(_searchQuery.isEmpty ? 'No faculty found.' : 'No match found.'));

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final faculty = filtered[index];
                    final data = faculty.data() as Map<String, dynamic>;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.orange.shade100,
                              child: Text((data['name'] ?? '?')[0].toUpperCase(), style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(width: 120, child: Text(data['name'] ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            SizedBox(width: 180, child: Text('Email: ${data['email'] ?? 'N/A'}', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                            SizedBox(width: 130, child: Text('Phone: ${data['phone'] ?? 'N/A'}', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                            Expanded(child: Text('Subject: ${data['subject'] ?? 'N/A'}', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                            PopupMenuButton<String>(
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('Edit')])),
                                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                              ],
                              onSelected: (value) {
                                if (value == 'edit') _editFaculty(faculty.id, data);
                                else if (value == 'delete') _deleteFaculty(faculty.id);
                              },
                            ),
                          ],
                        ),
                      ),
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