import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/group_model.dart';
import 'admin_settle_between_screen.dart';

class SettleUpScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final List<GroupMember> members;

  const SettleUpScreen({
    Key? key,
    required this.groupId,
    required this.groupName,
    required this.members,
  }) : super(key: key);

  @override
  State<SettleUpScreen> createState() => _SettleUpScreenState();
}

class _SettleUpScreenState extends State<SettleUpScreen> {
  String? payerId;
  String? payeeId;
  final _amountController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ModalRoute.of(context)?.settings.arguments is Map
        ? (ModalRoute.of(context)!.settings.arguments as Map)['currentUserId']
            as String?
        : null;
    // Fallback: try to get from members (admin is first)
    final isAdmin =
        widget.members.any((m) => m.userId == currentUserId && m.isAdmin);

    return Scaffold(
      appBar: AppBar(
        title: Text('Settle Up: ${widget.groupName}'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: Icon(Icons.group),
              tooltip: 'Settle Between Members',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AdminSettleBetweenScreen(
                      groupId: widget.groupId,
                      groupName: widget.groupName,
                      members: widget.members,
                      currentUserId: currentUserId ?? '',
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupId)
            .collection('expenses')
            .snapshots(),
        builder: (context, expenseSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('groups')
                .doc(widget.groupId)
                .collection('settlements')
                .orderBy('timestamp', descending: false)
                .snapshots(),
            builder: (context, settlementSnapshot) {
              if (!expenseSnapshot.hasData || !settlementSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final expenses = expenseSnapshot.data!.docs;
              final settlements = settlementSnapshot.data!.docs;
              final sortedMembers = [...widget.members]
                ..sort((a, b) => a.username.compareTo(b.username));
              final Map<String, double> paidMap = {
                for (var m in sortedMembers) m.userId: 0.0
              };
              final Map<String, double> owedMap = {
                for (var m in sortedMembers) m.userId: 0.0
              };

              // --- Add initial amount as a virtual expense if present ---
              // We'll fetch the group doc for initialAmount
              // For now, skip (should be passed in or fetched, can be improved)

              // --- Expenses ---
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
                      owedMap[uid] = owedMap[uid]! +
                          (share is num ? share.toDouble() : 0.0);
                    }
                  });
                } else if (splitType == 'equal' && data['splitAmong'] is List) {
                  final splitAmong =
                      List<String>.from(data['splitAmong'] ?? []);
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

              // --- Net before settlements ---
              final Map<String, double> netMap = {
                for (var m in sortedMembers)
                  m.userId: (paidMap[m.userId] ?? 0) - (owedMap[m.userId] ?? 0)
              };

              // --- Apply settlements ---
              for (var doc in settlements) {
                final data = doc.data() as Map<String, dynamic>;
                final fromUserId = data['fromUserId'] as String?;
                final toUserId = data['toUserId'] as String?;
                final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                if (fromUserId != null && toUserId != null && amount > 0) {
                  netMap[fromUserId] = (netMap[fromUserId] ?? 0) + amount;
                  netMap[toUserId] = (netMap[toUserId] ?? 0) - amount;
                }
              }

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Net Balances',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: sortedMembers.length,
                        itemBuilder: (context, index) {
                          final member = sortedMembers[index];
                          final net = netMap[member.userId] ?? 0.0;
                          return ListTile(
                            leading: CircleAvatar(
                                child: Text(member.username
                                    .substring(0, 1)
                                    .toUpperCase())),
                            title: Text(member.username),
                            subtitle: Text(
                              net > 0
                                  ? 'Should receive: ${net.toStringAsFixed(2)}'
                                  : net < 0
                                      ? 'Should pay: ${(-net).toStringAsFixed(2)}'
                                      : 'Settled',
                              style: TextStyle(
                                color: net > 0
                                    ? Colors.green
                                    : net < 0
                                        ? Colors.red
                                        : Colors.grey,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                      ),
                    // Always show the regular settle up form for everyone
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Record a Settlement',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: payerId,
                                    hint: const Text('Payer'),
                                    items: sortedMembers
                                        .map((m) => DropdownMenuItem(
                                              value: m.userId,
                                              child: Text(m.username),
                                            ))
                                        .toList(),
                                    onChanged: (val) =>
                                        setState(() => payerId = val),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: payeeId,
                                    hint: const Text('Payee'),
                                    items: sortedMembers
                                        .map((m) => DropdownMenuItem(
                                              value: m.userId,
                                              child: Text(m.username),
                                            ))
                                        .toList(),
                                    onChanged: (val) =>
                                        setState(() => payeeId = val),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _amountController,
                              keyboardType: TextInputType.numberWithOptions(
                                  decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Amount',
                                prefixIcon: Icon(Icons.attach_money),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              icon: _isSubmitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.check),
                              label: Text(_isSubmitting
                                  ? 'Recording...'
                                  : 'Record Settlement'),
                              onPressed: _isSubmitting
                                  ? null
                                  : () async {
                                      setState(() {
                                        _error = null;
                                      });
                                      if (payerId == null ||
                                          payeeId == null ||
                                          payerId == payeeId) {
                                        setState(() {
                                          _error =
                                              'Select different payer and payee.';
                                        });
                                        return;
                                      }
                                      final amount = double.tryParse(
                                          _amountController.text.trim());
                                      if (amount == null || amount <= 0) {
                                        setState(() {
                                          _error = 'Enter a valid amount.';
                                        });
                                        return;
                                      }
                                      setState(() {
                                        _isSubmitting = true;
                                      });
                                      try {
                                        await FirebaseFirestore.instance
                                            .collection('groups')
                                            .doc(widget.groupId)
                                            .collection('settlements')
                                            .add({
                                          'fromUserId': payerId,
                                          'toUserId': payeeId,
                                          'amount': amount,
                                          'timestamp':
                                              FieldValue.serverTimestamp(),
                                        });
                                        // Notification logic
                                        final fromUser =
                                            sortedMembers.firstWhere(
                                                (m) => m.userId == payerId,
                                                orElse: () => GroupMember(
                                                    userId: payerId ?? '',
                                                    username: 'Unknown',
                                                    email: '',
                                                    isAdmin: false,
                                                    joinedAt: DateTime.now()));
                                        final toUser = sortedMembers.firstWhere(
                                            (m) => m.userId == payeeId,
                                            orElse: () => GroupMember(
                                                userId: payeeId ?? '',
                                                username: 'Unknown',
                                                email: '',
                                                isAdmin: false,
                                                joinedAt: DateTime.now()));
                                        await FirebaseFirestore.instance
                                            .collection(
                                                'group_settlement_notifications')
                                            .add({
                                          'groupId': widget.groupId,
                                          'groupName': widget.groupName,
                                          'fromUserId': payerId,
                                          'fromUsername': fromUser.username,
                                          'toUserId': payeeId,
                                          'toUsername': toUser.username,
                                          'amount': amount,
                                          'action': 'created',
                                          'timestamp':
                                              FieldValue.serverTimestamp(),
                                        });
                                        _amountController.clear();
                                        setState(() {
                                          payerId = null;
                                          payeeId = null;
                                          _isSubmitting = false;
                                        });
                                      } catch (e) {
                                        setState(() {
                                          _error =
                                              'Failed to record settlement: $e';
                                          _isSubmitting = false;
                                        });
                                      }
                                    },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Settlement History',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Expanded(
                      child: settlements.isEmpty
                          ? const Text('No settlements yet.')
                          : ListView.builder(
                              itemCount: settlements.length,
                              itemBuilder: (context, index) {
                                final doc = settlements[index];
                                final data = doc.data() as Map<String, dynamic>;
                                final fromUserId =
                                    data['fromUserId'] as String?;
                                final toUserId = data['toUserId'] as String?;
                                final amount =
                                    (data['amount'] as num?)?.toDouble() ?? 0.0;
                                final timestamp =
                                    (data['timestamp'] as Timestamp?)?.toDate();
                                final fromUser = sortedMembers.firstWhere(
                                    (m) => m.userId == fromUserId,
                                    orElse: () => GroupMember(
                                        userId: fromUserId ?? '',
                                        username: 'Unknown',
                                        email: '',
                                        isAdmin: false,
                                        joinedAt: DateTime.now()));
                                final toUser = sortedMembers.firstWhere(
                                    (m) => m.userId == toUserId,
                                    orElse: () => GroupMember(
                                        userId: toUserId ?? '',
                                        username: 'Unknown',
                                        email: '',
                                        isAdmin: false,
                                        joinedAt: DateTime.now()));
                                return Card(
                                  child: ListTile(
                                    leading: const Icon(Icons.swap_horiz),
                                    title: Text(
                                        '${fromUser.username} paid ${toUser.username}'),
                                    subtitle: Text(
                                        'Amount: ${amount.toStringAsFixed(2)}${timestamp != null ? '\n${timestamp.toLocal()}' : ''}'),
                                    trailing: isAdmin
                                        ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit,
                                                    color: Colors.blue),
                                                tooltip: 'Edit',
                                                onPressed: () async {
                                                  final newAmountStr =
                                                      await showDialog<String>(
                                                    context: context,
                                                    builder: (context) {
                                                      final controller =
                                                          TextEditingController(
                                                              text: amount
                                                                  .toStringAsFixed(
                                                                      2));
                                                      return AlertDialog(
                                                        title: const Text(
                                                            'Edit Settlement Amount'),
                                                        content: TextField(
                                                          controller:
                                                              controller,
                                                          keyboardType:
                                                              TextInputType
                                                                  .numberWithOptions(
                                                                      decimal:
                                                                          true),
                                                          decoration:
                                                              const InputDecoration(
                                                                  labelText:
                                                                      'Amount'),
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    context),
                                                            child: const Text(
                                                                'Cancel'),
                                                          ),
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    context,
                                                                    controller
                                                                        .text
                                                                        .trim()),
                                                            child: const Text(
                                                                'Update'),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  );
                                                  if (newAmountStr != null) {
                                                    final newAmount =
                                                        double.tryParse(
                                                            newAmountStr);
                                                    if (newAmount != null &&
                                                        newAmount > 0 &&
                                                        newAmount != amount) {
                                                      await FirebaseFirestore
                                                          .instance
                                                          .collection('groups')
                                                          .doc(widget.groupId)
                                                          .collection(
                                                              'settlements')
                                                          .doc(doc.id)
                                                          .update({
                                                        'amount': newAmount
                                                      });
                                                      // Notification logic
                                                      final fromUser =
                                                          sortedMembers.firstWhere(
                                                              (m) =>
                                                                  m
                                                                      .userId ==
                                                                  fromUserId,
                                                              orElse: () => GroupMember(
                                                                  userId:
                                                                      fromUserId ??
                                                                          '',
                                                                  username:
                                                                      'Unknown',
                                                                  email: '',
                                                                  isAdmin:
                                                                      false,
                                                                  joinedAt:
                                                                      DateTime
                                                                          .now()));
                                                      final toUser = sortedMembers
                                                          .firstWhere(
                                                              (m) =>
                                                                  m.userId ==
                                                                  toUserId,
                                                              orElse: () => GroupMember(
                                                                  userId:
                                                                      toUserId ??
                                                                          '',
                                                                  username:
                                                                      'Unknown',
                                                                  email: '',
                                                                  isAdmin:
                                                                      false,
                                                                  joinedAt:
                                                                      DateTime
                                                                          .now()));
                                                      await FirebaseFirestore
                                                          .instance
                                                          .collection(
                                                              'group_settlement_notifications')
                                                          .add({
                                                        'groupId':
                                                            widget.groupId,
                                                        'groupName':
                                                            widget.groupName,
                                                        'fromUserId':
                                                            fromUserId,
                                                        'fromUsername':
                                                            fromUser.username,
                                                        'toUserId': toUserId,
                                                        'toUsername':
                                                            toUser.username,
                                                        'amount': newAmount,
                                                        'action': 'updated',
                                                        'timestamp': FieldValue
                                                            .serverTimestamp(),
                                                      });
                                                    }
                                                  }
                                                },
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete,
                                                    color: Colors.red),
                                                tooltip: 'Delete',
                                                onPressed: () async {
                                                  final confirm =
                                                      await showDialog<bool>(
                                                    context: context,
                                                    builder: (context) =>
                                                        AlertDialog(
                                                      title: const Text(
                                                          'Delete Settlement'),
                                                      content: const Text(
                                                          'Are you sure you want to delete this settlement?'),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  context,
                                                                  false),
                                                          child: const Text(
                                                              'Cancel'),
                                                        ),
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  context,
                                                                  true),
                                                          child: const Text(
                                                              'Delete',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .red)),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirm == true) {
                                                    await FirebaseFirestore
                                                        .instance
                                                        .collection('groups')
                                                        .doc(widget.groupId)
                                                        .collection(
                                                            'settlements')
                                                        .doc(doc.id)
                                                        .delete();
                                                    // Notification logic
                                                    final fromUser =
                                                        sortedMembers.firstWhere(
                                                            (m) =>
                                                                m.userId ==
                                                                fromUserId,
                                                            orElse: () => GroupMember(
                                                                userId:
                                                                    fromUserId ??
                                                                        '',
                                                                username:
                                                                    'Unknown',
                                                                email: '',
                                                                isAdmin: false,
                                                                joinedAt:
                                                                    DateTime
                                                                        .now()));
                                                    final toUser = sortedMembers
                                                        .firstWhere(
                                                            (m) =>
                                                                m.userId ==
                                                                toUserId,
                                                            orElse: () => GroupMember(
                                                                userId:
                                                                    toUserId ??
                                                                        '',
                                                                username:
                                                                    'Unknown',
                                                                email: '',
                                                                isAdmin: false,
                                                                joinedAt:
                                                                    DateTime
                                                                        .now()));
                                                    await FirebaseFirestore
                                                        .instance
                                                        .collection(
                                                            'group_settlement_notifications')
                                                        .add({
                                                      'groupId': widget.groupId,
                                                      'groupName':
                                                          widget.groupName,
                                                      'fromUserId': fromUserId,
                                                      'fromUsername':
                                                          fromUser.username,
                                                      'toUserId': toUserId,
                                                      'toUsername':
                                                          toUser.username,
                                                      'amount': amount,
                                                      'action': 'deleted',
                                                      'timestamp': FieldValue
                                                          .serverTimestamp(),
                                                    });
                                                  }
                                                },
                                              ),
                                            ],
                                          )
                                        : null,
                                  ),
                                );
                              },
                            ),
                    ),
                    if (!isAdmin)
                      Text('Only group admins can record settlements.',
                          style: TextStyle(color: Colors.blueGrey)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
