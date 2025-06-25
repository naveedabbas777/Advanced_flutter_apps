import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/scheduler.dart';
import '../../models/group_model.dart';

class AdminSettleBetweenScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final List<GroupMember> members;
  final String currentUserId;

  const AdminSettleBetweenScreen({
    Key? key,
    required this.groupId,
    required this.groupName,
    required this.members,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<AdminSettleBetweenScreen> createState() =>
      _AdminSettleBetweenScreenState();
}

class _AdminSettleBetweenScreenState extends State<AdminSettleBetweenScreen> {
  String? payerId;
  String? payeeId;
  final _amountController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  bool get isAdmin =>
      widget.members.any((m) => m.userId == widget.currentUserId && m.isAdmin);

  @override
  void initState() {
    super.initState();
    // Verify admin status on init
    if (!isAdmin) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only admins can access this screen'),
            backgroundColor: Colors.red,
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If not admin, show loading until navigation completes
    if (!isAdmin) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final sortedMembers = [...widget.members]
      ..sort((a, b) => a.username.compareTo(b.username));

    // Filter out the current admin from the member lists to prevent self-settlement
    final filteredMembers =
        sortedMembers.where((m) => m.userId != widget.currentUserId).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Settle Between Members'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupId)
            .collection('settlements')
            .orderBy('timestamp', descending: false)
            .snapshots(),
        builder: (context, settlementSnapshot) {
          if (!settlementSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final settlements = settlementSnapshot.data!.docs;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Record a payment for ${widget.groupName}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        DropdownButtonFormField<String>(
                          value: payerId,
                          decoration: InputDecoration(
                            labelText: 'Paid By (Owes)',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                          ),
                          items: filteredMembers
                              .map((m) => DropdownMenuItem(
                                    value: m.userId,
                                    child: Text(m.username,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                  ))
                              .toList(),
                          onChanged: (val) => setState(() => payerId = val),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: payeeId,
                          decoration: InputDecoration(
                            labelText: 'Paid To (Is Owed)',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                          ),
                          items: filteredMembers
                              .map((m) => DropdownMenuItem(
                                    value: m.userId,
                                    child: Text(m.username,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                  ))
                              .toList(),
                          onChanged: (val) => setState(() => payeeId = val),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _amountController,
                          keyboardType:
                              TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Amount',
                            hintText: 'Amount',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            prefixIcon: const Icon(Icons.attach_money),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onPrimary,
                            ),
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
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(_error!,
                                style: const TextStyle(color: Colors.red)),
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
                            final fromUserId = data['fromUserId'] as String?;
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
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
