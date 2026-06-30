import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'batch_management_screen.dart';
import 'student_management_screen.dart';
import 'faculty_management_screen.dart';
import 'mark_attendance_screen.dart';
import 'faculty_attendance_screen.dart';
import 'view_reports_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Dashboard'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome Back!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  const SizedBox(height: 8),
                  Text(user?.email ?? 'User', style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Dashboard Stats - REAL DATA
            const Text('Quick Stats', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildRealTimeStat('Batches', Icons.class_, Colors.blue, 'batches')),
                const SizedBox(width: 12),
                Expanded(child: _buildRealTimeStat('Students', Icons.people, Colors.green, 'students')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildRealTimeStat('Faculty', Icons.school, Colors.orange, 'faculties')),
                const SizedBox(width: 12),
                Expanded(child: _buildTodayAttendanceStat()),
              ],
            ),
            const SizedBox(height: 24),

            // Main Actions
            const Text('Manage', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            _buildActionCard(context, 'Manage Batches', 'Create and manage student batches', Icons.class_, Colors.blue, () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => BatchManagementScreen()));
            }),
            const SizedBox(height: 12),

            _buildActionCard(context, 'Manage Students', 'Add and view student records', Icons.people, Colors.green, () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const StudentManagementScreen()));
            }),
            const SizedBox(height: 12),

            _buildActionCard(context, 'Manage Faculty', 'Add and manage faculty members', Icons.school, Colors.orange, () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => FacultyManagementScreen()));
            }),
            const SizedBox(height: 12),

            _buildActionCard(context, 'Mark Attendance', 'Record student attendance', Icons.check_circle, Colors.purple, () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const MarkAttendanceScreen()));
            }),
            const SizedBox(height: 12),

            _buildActionCard(context, 'Faculty Attendance', 'Track faculty attendance', Icons.person, Colors.red, () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const FacultyAttendanceScreen()));
            }),
            const SizedBox(height: 12),

            _buildActionCard(context, 'View Reports', 'Attendance reports and analytics', Icons.analytics, Colors.teal, () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ViewReportsScreen()));
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRealTimeStat(String title, IconData icon, Color color, String collection) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collection).snapshots(),
      builder: (context, snapshot) {
        int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text('$count', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              Text(title, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTodayAttendanceStat() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('student_attendance')
          .where('date', isEqualTo: _formatDate(DateTime.now())).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.purple.withOpacity(0.3))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.today, color: Colors.purple, size: 32),
              const SizedBox(height: 8),
              const Text('0%', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.purple)),
              const Text('Today', style: TextStyle(fontSize: 14, color: Colors.grey)),
            ]),
          );
        }
        
        final records = snapshot.data!.docs;
        int present = records.where((r) => (r.data() as Map<String, dynamic>)['status'] == 'present').length;
        int total = records.length;
        double percentage = total > 0 ? (present / total * 100) : 0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.today, color: Colors.purple, size: 32),
              const SizedBox(height: 8),
              Text('${percentage.toStringAsFixed(0)}%', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.purple)),
              const Text('Today', style: TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Widget _buildActionCard(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback? onTap) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        trailing: Icon(Icons.arrow_forward_ios, color: color, size: 20),
        onTap: onTap ?? () {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title - Coming Soon!')));
        },
      ),
    );
  }
}