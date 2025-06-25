import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/group_model.dart';

class GroupSummaryScreen extends StatefulWidget {
  final String groupId;
  final List<GroupMember> members;
  final String groupName;

  const GroupSummaryScreen({
    Key? key,
    required this.groupId,
    required this.members,
    required this.groupName,
  }) : super(key: key);

  @override
  State<GroupSummaryScreen> createState() => _GroupSummaryScreenState();
}

class _GroupSummaryScreenState extends State<GroupSummaryScreen> {
  int? touchedGroupIndex;
  int? touchedRodIndex;

  @override
  Widget build(BuildContext context) {
    final sortedMembers = [...widget.members]
      ..sort((a, b) => a.username.compareTo(b.username));
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 500 ? 8.0 : 24.0;
    final maxContentWidth = 600.0;
    return Scaffold(
      appBar: AppBar(title: Text('Group Summary: ${widget.groupName}')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupId)
            .collection('expenses')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No expenses yet.'));
          }
          final expenses = snapshot.data!.docs;
          final Map<String, double> paidMap = {
            for (var m in sortedMembers) m.userId: 0.0
          };
          final Map<String, double> owedMap = {
            for (var m in sortedMembers) m.userId: 0.0
          };

          for (var doc in expenses) {
            final data = doc.data() as Map<String, dynamic>;
            final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
            final paidBy = data['paidBy'] as String?;
            final splitType = data['splitType'] ?? 'equal';

            // Add to Paid
            if (paidBy != null && paidMap.containsKey(paidBy)) {
              paidMap[paidBy] = paidMap[paidBy]! + amount;
            }

            // Calculate Owes
            if (splitType == 'custom' && data['splitData'] is Map) {
              final splitData = data['splitData'] as Map<String, dynamic>;
              splitData.forEach((uid, share) {
                if (owedMap.containsKey(uid)) {
                  owedMap[uid] =
                      owedMap[uid]! + (share is num ? share.toDouble() : 0.0);
                }
              });
            } else if (splitType == 'equal' && data['splitAmong'] is List) {
              final splitAmong = List<String>.from(data['splitAmong'] ?? []);
              final perUser =
                  splitAmong.isNotEmpty ? amount / splitAmong.length : 0.0;
              for (var uid in splitAmong) {
                if (owedMap.containsKey(uid)) {
                  owedMap[uid] = owedMap[uid]! + perUser;
                }
              }
            } else {
              // Fallback: split among all members
              final perUser = sortedMembers.isNotEmpty
                  ? amount / sortedMembers.length
                  : 0.0;
              for (var m in sortedMembers) {
                owedMap[m.userId] = owedMap[m.userId]! + perUser;
              }
            }
          }
          final Map<String, double> netMap = {
            for (var m in sortedMembers)
              m.userId: (paidMap[m.userId] ?? 0) - (owedMap[m.userId] ?? 0)
          };

          final allValues = [
            ...paidMap.values,
            ...owedMap.values,
            ...netMap.values.map((v) => v.abs())
          ];
          final maxValue =
              allValues.fold<double>(0, (prev, e) => e > prev ? e : prev);
          final safeMax = maxValue > 0 ? maxValue : 1;

          final barGroups = <BarChartGroupData>[];
          for (int i = 0; i < sortedMembers.length; i++) {
            final m = sortedMembers[i];
            barGroups.add(
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: (paidMap[m.userId]! / safeMax) * 100,
                    color: Colors.green,
                    width: 12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  BarChartRodData(
                    toY: (owedMap[m.userId]! / safeMax) * 100,
                    color: Colors.red,
                    width: 12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  BarChartRodData(
                    toY: (netMap[m.userId]!.abs() / safeMax) * 100,
                    color: Colors.blue,
                    width: 12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
                showingTooltipIndicators:
                    touchedGroupIndex == i && touchedRodIndex != null
                        ? [touchedRodIndex!]
                        : [],
              ),
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Paid, Owes, and Net by Member',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: screenWidth < 400 ? 180 : 260,
                      child: BarChart(
                        BarChartData(
                          barGroups: barGroups,
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 32,
                                getTitlesWidget: (value, meta) {
                                  if (value % 20 == 0 &&
                                      value >= 0 &&
                                      value <= 100) {
                                    return Text('${value.toInt()}%',
                                        style: const TextStyle(fontSize: 10));
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget:
                                    (double value, TitleMeta meta) {
                                  final idx = value.toInt();
                                  if (idx < 0 || idx >= sortedMembers.length)
                                    return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(sortedMembers[idx].username,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis),
                                  );
                                },
                              ),
                            ),
                            rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: 20),
                          borderData: FlBorderData(show: false),
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              tooltipBgColor: Colors.black87,
                              getTooltipItem:
                                  (group, groupIndex, rod, rodIndex) {
                                String label;
                                if (rodIndex == 0)
                                  label = 'Paid';
                                else if (rodIndex == 1)
                                  label = 'Owes';
                                else
                                  label = 'Net';
                                return BarTooltipItem(
                                  '$label: ${rod.toY.toStringAsFixed(2)}%',
                                  TextStyle(color: Colors.white),
                                );
                              },
                            ),
                            touchCallback: (event, response) {
                              setState(() {
                                if (event.isInterestedForInteractions &&
                                    response != null &&
                                    response.spot != null) {
                                  touchedGroupIndex =
                                      response.spot!.touchedBarGroupIndex;
                                  touchedRodIndex =
                                      response.spot!.touchedRodDataIndex;
                                } else {
                                  touchedGroupIndex = null;
                                  touchedRodIndex = null;
                                }
                              });
                            },
                            handleBuiltInTouches: true,
                          ),
                          groupsSpace: 24,
                          maxY: 100,
                          minY: 0,
                        ),
                        swapAnimationDuration:
                            const Duration(milliseconds: 800),
                        swapAnimationCurve: Curves.easeOutCubic,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(width: 16, height: 16, color: Colors.green),
                        const SizedBox(width: 4),
                        const Text('Paid', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 16),
                        Container(width: 16, height: 16, color: Colors.red),
                        const SizedBox(width: 4),
                        const Text('Owes', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 16),
                        Container(width: 16, height: 16, color: Colors.blue),
                        const SizedBox(width: 4),
                        const Text('Net', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('Group Summary Table',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Member')),
                          DataColumn(label: Text('Paid')),
                          DataColumn(label: Text('Owes')),
                          DataColumn(label: Text('Net')),
                        ],
                        rows: [
                          for (var m in sortedMembers)
                            DataRow(cells: [
                              DataCell(Text(m.username)),
                              DataCell(
                                  Text(paidMap[m.userId]!.toStringAsFixed(2))),
                              DataCell(
                                  Text(owedMap[m.userId]!.toStringAsFixed(2))),
                              DataCell(
                                  Text(netMap[m.userId]!.toStringAsFixed(2),
                                      style: TextStyle(
                                          color: (netMap[m.userId]! > 0)
                                              ? Colors.green
                                              : (netMap[m.userId]! < 0)
                                                  ? Colors.red
                                                  : Colors.grey))),
                            ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
