import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatefulWidget {
  final String teacherId;

  const ReportsScreen({
    super.key,
    required this.teacherId,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Reports & Analytics',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.deepPurple,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.deepPurple,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Student Reports'),
            Tab(text: 'Charts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildStudentReportsTab(),
          _buildChartsTab(),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: _exportReports,
              icon: const Icon(Icons.download),
              label: const Text('Export Reports'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.deepPurple,
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.deepPurple,
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('tasks')
          .where('teacherId', isEqualTo: widget.teacherId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final tasks = snapshot.data!.docs;
        final totalTasks = tasks.length;
        final completedTasks = tasks.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'completed';
        }).length;
        final pendingTasks = totalTasks - completedTasks;
        final completionRate = totalTasks > 0 
            ? (completedTasks / totalTasks * 100).toStringAsFixed(1)
            : '0.0';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOverviewCard(
                'Overall Progress',
                [
                  _buildStatRow('Total Tasks', totalTasks.toString()),
                  _buildStatRow('Completed Tasks', completedTasks.toString()),
                  _buildStatRow('Pending Tasks', pendingTasks.toString()),
                  _buildStatRow('Completion Rate', '$completionRate%'),
                ],
              ),
              const SizedBox(height: 16),
              _buildOverviewCard(
                'Recent Activity',
                tasks.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final String activityText;
                  final String timeAgo;

                  // Determine activity text based on task status or assignment
                  if (data['status'] == 'completed') {
                    activityText = '${data['assignedToName'] ?? 'A student'} completed ''${data['title']}''';
                  } else if (data['status'] == 'pending' && data['assignedToName'] != null) {
                    activityText = 'Task ''${data['title']}'' assigned to ${data['assignedToName']}';
                  } else {
                    activityText = 'Task update: ${data['title']}';
                  }

                  // Calculate time ago
                  final timestamp = data['timestamp'] as Timestamp?;
                  if (timestamp != null) {
                    final duration = DateTime.now().difference(timestamp.toDate());
                    if (duration.inMinutes < 60) {
                      timeAgo = '${duration.inMinutes} minutes ago';
                    } else if (duration.inHours < 24) {
                      timeAgo = '${duration.inHours} hours ago';
                    } else {
                      timeAgo = DateFormat('MMM d').format(timestamp.toDate());
                    }
                  } else {
                    timeAgo = 'N/A';
                  }

                  return _buildActivityItem(activityText, timeAgo);
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStudentReportsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('students').snapshots(),
      builder: (context, studentsSnapshot) {
        if (studentsSnapshot.hasError) {
          return Center(child: Text('Error: ${studentsSnapshot.error}'));
        }

        if (!studentsSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final students = studentsSnapshot.data!.docs;

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('tasks')
              .where('teacherId', isEqualTo: widget.teacherId)
              .snapshots(),
          builder: (context, tasksSnapshot) {
            if (!tasksSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final tasks = tasksSnapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: students.length,
              itemBuilder: (context, index) {
                final student = students[index].data() as Map<String, dynamic>;
                final studentId = students[index].id;
                
                // Calculate student-specific statistics
                final studentTasks = tasks.where((task) {
                  final taskData = task.data() as Map<String, dynamic>;
                  return taskData['assignedTo'] == studentId;
                }).toList();
                
                final totalTasks = studentTasks.length;
                final completedTasks = studentTasks.where((task) {
                  final taskData = task.data() as Map<String, dynamic>;
                  return taskData['status'] == 'completed';
                }).length;
                final pendingTasks = totalTasks - completedTasks;
                final completionRate = totalTasks > 0 
                    ? (completedTasks / totalTasks * 100).toStringAsFixed(1)
                    : '0.0';
                final score = completedTasks * 10.0; // Example scoring system

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ExpansionTile(
                    title: Text(
                      student['name'] ?? 'Unknown Student',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Text(
                      'Completion Rate: $completionRate%',
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildStatRow('Total Tasks', totalTasks.toString()),
                            const SizedBox(height: 8),
                            _buildStatRow('Completed Tasks', completedTasks.toString()),
                            const SizedBox(height: 8),
                            _buildStatRow('Pending Tasks', pendingTasks.toString()),
                            const SizedBox(height: 8),
                            _buildStatRow('Score', score.toString()),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildChartsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('tasks')
          .where('teacherId', isEqualTo: widget.teacherId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final tasks = snapshot.data!.docs;
        
        if (tasks.isEmpty) {
          return const Center(child: Text('No task data available for charts.'));
        }
        
        // Prepare data for charts
        Map<String, int> completedTasksByStudent = {};
        Map<String, int> totalTasksByStudent = {};
        
        // For line chart: task completion over time
        Map<DateTime, int> completedTasksOverTime = {};
        
        // For pie chart: task status distribution
        Map<String, int> taskStatusDistribution = {
          'completed': 0,
          'pending': 0,
          'overdue': 0,
          'assigned': 0, // Assuming 'assigned' is a status for non-completed tasks
        };

        for (var task in tasks) {
          final data = task.data() as Map<String, dynamic>;
          final assignedTo = data['assignedTo'] as String?;
          final status = data['status'] as String? ?? 'pending';
          final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
          
          if (assignedTo != null) {
            totalTasksByStudent[assignedTo] = (totalTasksByStudent[assignedTo] ?? 0) + 1;
            if (status == 'completed') {
              completedTasksByStudent[assignedTo] = (completedTasksByStudent[assignedTo] ?? 0) + 1;
            }
          }

          // Update task status distribution
          taskStatusDistribution[status] = (taskStatusDistribution[status] ?? 0) + 1;

          // Update completed tasks over time for line chart
          if (status == 'completed' && timestamp != null) {
            final date = DateTime(timestamp.year, timestamp.month, timestamp.day);
            completedTasksOverTime[date] = (completedTasksOverTime[date] ?? 0) + 1;
          }
        }

        // Sort completedTasksOverTime by date
        final sortedDates = completedTasksOverTime.keys.toList()..sort();
        final List<FlSpot> spots = sortedDates.map((date) {
          return FlSpot(date.millisecondsSinceEpoch.toDouble(), completedTasksOverTime[date]!.toDouble());
        }).toList();

        return FutureBuilder<QuerySnapshot>(
          future: _firestore.collection('students').get(),
          builder: (context, studentSnapshot) {
            if (!studentSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final students = studentSnapshot.data!.docs;
            Map<String, String> studentNames = {
              for (var student in students)
                student.id: (student.data() as Map<String, dynamic>)['name'] ?? 'Unknown',
            };

            List<BarChartGroupData> barGroups = completedTasksByStudent.entries.map((entry) {
              final studentId = entry.key;
              final totalTasks = totalTasksByStudent[studentId] ?? 0;
              final completedTasks = entry.value;
              final completionRate = totalTasks > 0 ? (completedTasks / totalTasks * 100) : 0.0;

              return BarChartGroupData(
                x: completedTasksByStudent.keys.toList().indexOf(studentId),
                barRods: [
                  BarChartRodData(
                    toY: completionRate,
                    color: Colors.deepPurple,
                    width: 20,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              );
            }).toList();

            if (barGroups.isEmpty) {
              return const Center(child: Text('No student completion data to display.'));
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Completion Rates by Student',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: 100,
                        barTouchData: BarTouchData(enabled: false),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                if (completedTasksByStudent.keys.isEmpty) return const Text('');
                                final studentId = completedTasksByStudent.keys.toList()[value.toInt()];
                                return Text(studentNames[studentId] ?? 'N/A', style: const TextStyle(fontSize: 10));
                              },
                              reservedSize: 30,
                              interval: 1,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                return Text('${value.toInt()}%');
                              },
                              reservedSize: 40,
                            ),
                          ),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: barGroups,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Task Completion Trends',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(show: false),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                if (sortedDates.isEmpty) return const Text('');
                                final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                                return Text(DateFormat('MMM d').format(date), style: const TextStyle(fontSize: 10));
                              },
                              reservedSize: 30,
                              interval: sortedDates.isNotEmpty ? (sortedDates.last.millisecondsSinceEpoch - sortedDates.first.millisecondsSinceEpoch) / 3 : 1,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                return Text(value.toInt().toString());
                              },
                              reservedSize: 40,
                            ),
                          ),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots.isEmpty ? [const FlSpot(0, 0)] : spots, // Handle empty spots
                            isCurved: true,
                            color: Colors.blueAccent,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(show: true),
                            belowBarData: BarAreaData(show: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Task Status Distribution',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: tasks.isEmpty ? [] : taskStatusDistribution.entries.map((entry) {
                          final isTouched = entry.key == 'completed'; // Example: highlight completed
                          final double fontSize = isTouched ? 16 : 12;
                          final double radius = isTouched ? 60 : 50;
                          final Color color;
                          switch (entry.key) {
                            case 'completed':
                              color = Colors.green;
                              break;
                            case 'pending':
                              color = Colors.orange;
                              break;
                            case 'overdue':
                              color = Colors.red;
                              break;
                            default:
                              color = Colors.blueGrey;
                          }

                          return PieChartSectionData(
                            color: color,
                            value: entry.value.toDouble(),
                            title: tasks.isEmpty ? '' : '${entry.value} (${(entry.value / tasks.length * 100).toStringAsFixed(1)}%)',
                            radius: radius,
                            titleStyle: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            badgeWidget: isTouched
                                ? _buildBadge(entry.key)
                                : null,
                            badgePositionPercentageOffset: 0.98,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: taskStatusDistribution.entries.map((entry) {
                      Color color;
                      switch (entry.key) {
                        case 'completed':
                          color = Colors.green;
                          break;
                        case 'pending':
                          color = Colors.orange;
                          break;
                        case 'overdue':
                          color = Colors.red;
                          break;
                        default:
                          color = Colors.blueGrey;
                      }
                      return _buildLegendItem(entry.key.toUpperCase(), color);
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOverviewCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: Colors.deepPurple),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                Text(
                  time,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _exportReports() {
    // TODO: Implement report export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Exporting reports...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha((255 * 0.5).round()),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }

  Widget _buildLegendItem(String title, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        Text(title),
      ],
    );
  }
} 