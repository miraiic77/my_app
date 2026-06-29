import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/csv_service.dart';

class BatchManagementScreen extends StatefulWidget {
  const BatchManagementScreen({super.key});

  @override
  State<BatchManagementScreen> createState() => _BatchManagementScreenState();
}

class _BatchManagementScreenState extends State<BatchManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _facultyController = TextEditingController();
  bool _isLoading = false;
  bool _isEditing = false;
  String? _editingBatchId;

  @override
  void dispose() {
    _nameController.dispose();
    _facultyController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _nameController.clear();
    _facultyController.clear();
    _isEditing = false;
    _editingBatchId = null;
  }

  Future<void> _addBatch() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final batchData = {
        'name': _nameController.text.trim(),
        'facultyId': _facultyController.text.trim(),
        'studentCount': 0,
        'createdAt': Timestamp.now(),
      };

      if (_isEditing && _editingBatchId != null) {
        await FirebaseFirestore.instance
            .collection('batches')
            .doc(_editingBatchId)
            .update(batchData);
      } else {
        await FirebaseFirestore.instance.collection('batches').add(batchData);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? 'Batch updated!' : 'Batch added!')),
      );
      _clearForm();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => _isLoading = false);
  }

  Future<void> _editBatch(String docId, Map<String, dynamic> data) async {
    _nameController.text = data['name'] ?? '';
    _facultyController.text = data['facultyId'] ?? '';
    _isEditing = true;
    _editingBatchId = docId;
    _showAddBatchDialog();
  }

  Future<void> _deleteBatch(String docId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Batch'),
        content: const Text('Are you sure? This will not delete students.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('batches').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Batch deleted')));
      }
    }
  }

  Future<void> _exportBatches() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('batches').get();
      List<Map<String, dynamic>> batches = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'Batch ID': doc.id,
          'Name': data['name'] ?? '',
          'Faculty ID': data['facultyId'] ?? '',
          'Student Count': data['studentCount'] ?? 0,
        };
      }).toList();
      String csv = CsvService.convertToCsv(batches);
      CsvService.downloadCsv(csv, 'batches_export.csv');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exported!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _importBatches() async {
    try {
      String? csvData = await CsvService.pickCsvFile();
      if (csvData == null) return;

      List<Map<String, dynamic>> batches = CsvService.parseCsv(csvData);
      int count = 0;
      for (var batch in batches) {
        if (batch['Name'] != null && batch['Name'].toString().isNotEmpty) {
          await FirebaseFirestore.instance.collection('batches').add({
            'name': batch['Name'],
            'facultyId': batch['Faculty ID'] ?? '',
            'studentCount': int.tryParse(batch['Student Count']?.toString() ?? '0') ?? 0,
            'createdAt': Timestamp.now(),
          });
          count++;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported $count batches!')));
      }
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showAddBatchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isEditing ? 'Edit Batch' : 'Add New Batch'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Batch Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _facultyController,
                decoration: const InputDecoration(
                  labelText: 'Faculty ID',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
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
            onPressed: _isLoading ? null : _addBatch,
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_isEditing ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Management'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.file_download), onPressed: _exportBatches),
          IconButton(icon: const Icon(Icons.file_upload), onPressed: _importBatches),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                const Icon(Icons.class_, color: Colors.blue, size: 32),
                const SizedBox(width: 12),
                const Text('Manage Batches', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () {
                    _clearForm();
                    _showAddBatchDialog();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Batch'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance.collection('batches').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final batches = snapshot.data!.docs;
                if (batches.isEmpty) return const Center(child: Text('No batches found.'));
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: batches.length,
                  itemBuilder: (context, index) {
                    final batch = batches[index];
                    final data = batch.data();
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.class_, color: Colors.blue),
                        ),
                        title: Text(data['name'] ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Faculty: ${data['facultyId'] ?? 'N/A'} | Students: ${data['studentCount'] ?? 0}'),
                        trailing: PopupMenuButton<String>(
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('Edit')]),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))]),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'edit') {
                              _editBatch(batch.id, data);
                            } else if (value == 'delete') {
                              _deleteBatch(batch.id);
                            }
                          },
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