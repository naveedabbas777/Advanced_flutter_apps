import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/group_model.dart';

class GroupSummaryTableScreen extends StatelessWidget {
  final String groupId;
  final String groupName;
  final List<GroupMember> members;
  final double? initialAmount;
  final String createdBy;

  const GroupSummaryTableScreen({
    Key? key,
    required this.groupId,
    required this.groupName,
    required this.members,
    this.initialAmount,
    required this.createdBy,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 500 ? 8.0 : 24.0;
    final maxContentWidth = 600.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Summary - $groupName'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .snapshots(),
        builder: (context, groupSnapshot) {
          if (!groupSnapshot.hasData || !groupSnapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final group = GroupModel.fromFirestore(groupSnapshot.data!);

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('groups')
                .doc(groupId)
                .collection('expenses')
                .snapshots(),
            builder: (context, expenseSnapshot) {
              if (!expenseSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final expenses = expenseSnapshot.data!.docs;

              return FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('groups')
                    .doc(groupId)
                    .collection('settlements')
                    .orderBy('timestamp', descending: false)
                    .get(),
                builder: (context, settlementSnapshot) {
                  if (!settlementSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final settlements = settlementSnapshot.data!.docs;
                  final sortedMembers = [...members]
                    ..sort((a, b) => a.username.compareTo(b.username));

                  final Map<String, double> paidMap = {
                    for (var m in sortedMembers) m.userId: 0.0
                  };
                  final Map<String, double> owedMap = {
                    for (var m in sortedMembers) m.userId: 0.0
                  };

                  // Add initial amount as a virtual expense
                  if (group.initialAmount != null &&
                      group.initialAmount! > 0 &&
                      group.memberIds.isNotEmpty) {
                    final double perUser =
                        group.initialAmount! / group.memberIds.length;
                    if (paidMap.containsKey(group.createdBy)) {
                      paidMap[group.createdBy] =
                          paidMap[group.createdBy]! + group.initialAmount!;
                    }
                    for (var m in sortedMembers) {
                      owedMap[m.userId] = owedMap[m.userId]! + perUser;
                    }
                  }

                  // Process expenses
                  for (var doc in expenses) {
                    final data = doc.data() as Map<String, dynamic>;
                    final amount =
                        (data['amount'] as num?)?.toDouble() ?? 0.0;
                    final paidBy = data['paidBy'] as String?;
                    final splitType = data['splitType'] ?? 'equal';

                    // Add to Paid
                    if (paidBy != null && paidMap.containsKey(paidBy)) {
                      paidMap[paidBy] = paidMap[paidBy]! + amount;
                    }

                    // Calculate Owes
                    if (splitType == 'custom' && data['splitData'] is Map) {
                      final splitData =
                          data['splitData'] as Map<String, dynamic>;
                      splitData.forEach((uid, share) {
                        if (owedMap.containsKey(uid)) {
                          owedMap[uid] = owedMap[uid]! +
                              (share is num ? share.toDouble() : 0.0);
                        }
                      });
                    } else if (splitType == 'equal' &&
                        data['splitAmong'] is List) {
                      final splitAmong =
                          List<String>.from(data['splitAmong'] ?? []);
                      final perUser = splitAmong.isNotEmpty
                          ? amount / splitAmong.length
                          : 0.0;
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

                  // Calculate Net
                  final Map<String, double> netMap = {
                    for (var m in sortedMembers)
                      m.userId: (paidMap[m.userId] ?? 0) - (owedMap[m.userId] ?? 0)
                  };

                  // Apply settlements
                  for (var doc in settlements) {
                    final data = doc.data() as Map<String, dynamic>;
                    final fromUserId = data['fromUserId'] as String?;
                    final toUserId = data['toUserId'] as String?;
                    final amount =
                        (data['amount'] as num?)?.toDouble() ?? 0.0;
                    if (fromUserId != null &&
                        toUserId != null &&
                        amount > 0) {
                      netMap[fromUserId] = (netMap[fromUserId] ?? 0) + amount;
                      netMap[toUserId] = (netMap[toUserId] ?? 0) - amount;
                    }
                  }

                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContentWidth),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding, vertical: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              children: [
                                Icon(Icons.table_chart,
                                    color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Group Summary Table',
                                  style: Theme.of(context).textTheme.headlineSmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (group.initialAmount != null &&
                                group.initialAmount! > 0)
                              Card(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withOpacity(0.3),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline,
                                          size: 20,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Initial amount of \$${group.initialAmount!.toStringAsFixed(2)} is included as an equal split among all members.',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 24),
                            // Summary Cards
                            Row(
                              children: [
                                Expanded(
                                  child: Card(
                                    color: Colors.green.withOpacity(0.1),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        children: [
                                          Text(
                                            'Total Paid',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '\$${paidMap.values.fold<double>(0, (sum, val) => sum + val).toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Card(
                                    color: Colors.red.withOpacity(0.1),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        children: [
                                          Text(
                                            'Total Owed',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '\$${owedMap.values.fold<double>(0, (sum, val) => sum + val).toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // Data Table
                            Card(
                              elevation: 2,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columnSpacing: 24,
                                  columns: const [
                                    DataColumn(
                                      label: Text(
                                        'Member',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Paid',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      numeric: true,
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Owes',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      numeric: true,
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Net',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      numeric: true,
                                    ),
                                  ],
                                  rows: [
                                    for (var m in sortedMembers)
                                      DataRow(
                                        cells: [
                                          DataCell(
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 16,
                                                  child: Text(
                                                    m.username
                                                        .substring(0, 1)
                                                        .toUpperCase(),
                                                    style: const TextStyle(
                                                        fontSize: 12),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    m.username,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w500),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              '\$${paidMap[m.userId]!.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              '\$${owedMap[m.userId]!.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                color: Colors.red,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              '\$${netMap[m.userId]!.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                color: (netMap[m.userId]! > 0)
                                                    ? Colors.green
                                                    : (netMap[m.userId]! < 0)
                                                        ? Colors.red
                                                        : Colors.grey,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Legend
                            Card(
                              color: Theme.of(context).colorScheme.surfaceVariant,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Legend',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildLegendItem(
                                        context, 'Paid', Colors.green,
                                        'Total amount paid by this member'),
                                    _buildLegendItem(
                                        context, 'Owes', Colors.red,
                                        'Total amount this member owes'),
                                    _buildLegendItem(
                                        context, 'Net', Colors.blue,
                                        'Net balance (Paid - Owes). Green = owed money, Red = owes money'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLegendItem(
      BuildContext context, String label, Color color, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}






