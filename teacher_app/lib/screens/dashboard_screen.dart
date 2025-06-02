import 'package:flutter/material.dart';
import 'student_management_screen.dart';
import 'task_management_screen.dart';
import 'profile_screen.dart';
import 'messages_screen.dart';
import 'reports_screen.dart';
import 'subject_management_screen.dart';
import 'subject_registrations_screen.dart';

class DashboardScreen extends StatelessWidget {
  final String teacherId;
  final String teacherName;

  const DashboardScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Welcome, $teacherName',
          style: TextStyle(color: Colors.grey[800]),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: Colors.deepPurple),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(
                  teacherId: teacherId,
                  teacherName: teacherName,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () => Navigator.pushReplacementNamed(context, '/'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dashboard',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildDashboardCard(
                    context,
                    'Students',
                    Icons.people,
                    Colors.blue,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StudentManagementScreen(),
                      ),
                    ),
                  ),
                  _buildDashboardCard(
                    context,
                    'Tasks',
                    Icons.assignment,
                    Colors.orange,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TaskManagementScreen(),
                      ),
                    ),
                  ),
                  _buildDashboardCard(
                    context,
                    'Messages',
                    Icons.message,
                    Colors.green,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MessagesScreen(
                          userId: teacherId,
                          userName: teacherName,
                          userType: 'teacher',
                        ),
                      ),
                    ),
                  ),
                  _buildDashboardCard(
                    context,
                    'Reports',
                    Icons.bar_chart,
                    Colors.purple,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReportsScreen(
                          teacherId: teacherId,
                        ),
                      ),
                    ),
                  ),
                  _buildDashboardCard(
                    context,
                    'Subjects',
                    Icons.subject,
                    Colors.brown,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SubjectManagementScreen(),
                      ),
                    ),
                  ),
                  _buildDashboardCard(
                    context,
                    'Registrations',
                    Icons.how_to_reg,
                    Colors.teal,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SubjectRegistrationsScreen(
                          teacherId: teacherId,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: color,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
