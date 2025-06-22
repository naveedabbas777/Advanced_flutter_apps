import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_app/models/group_model.dart';
import 'package:split_app/providers/auth_provider.dart';
import 'package:split_app/screens/groups/create_group_screen.dart';
import 'package:split_app/screens/groups/group_details_screen.dart';
import 'package:intl/intl.dart';

class GroupsTab extends StatefulWidget {
  @override
  _GroupsTabState createState() => _GroupsTabState();
}

class _GroupsTabState extends State<GroupsTab> {
  String _groupSearch = '';
  List<GroupModel> _groups = [];
  bool _isLoadingGroups = false;
  String? _groupsError;

  @override
  void initState() {
    super.initState();
    _fetchGroups();
  }

  Future<void> _fetchGroups() async {
    if (!mounted) return;
    setState(() {
      _isLoadingGroups = true;
      _groupsError = null;
    });

    final user = Provider.of<AppAuthProvider>(context, listen: false).currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isLoadingGroups = false;
        _groupsError = "User not logged in.";
      });
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('groups')
          .where('memberIds', arrayContains: user.uid)
          .get();
      if (!mounted) return;
      setState(() {
        _groups = snapshot.docs.map((doc) => GroupModel.fromFirestore(doc)).toList();
        _isLoadingGroups = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _groupsError = e.toString();
        _isLoadingGroups = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search groups...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (val) => setState(() => _groupSearch = val.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: _isLoadingGroups
              ? const Center(child: CircularProgressIndicator())
              : _groupsError != null
                  ? Center(
                      child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('Error loading groups: $_groupsError', textAlign: TextAlign.center),
                    ))
                  : _groups.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.group_outlined, size: 48, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('No groups yet.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                              SizedBox(height: 12),
                              ElevatedButton.icon(
                                icon: Icon(Icons.refresh),
                                label: Text('Reload'),
                                onPressed: _fetchGroups,
                              ),
                              SizedBox(height: 12),
                              ElevatedButton.icon(
                                icon: Icon(Icons.add),
                                label: Text('Create Group'),
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => CreateGroupScreen()));
                                },
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchGroups,
                          child: ListView.builder(
                            itemCount: _groups.where((g) => g.name.toLowerCase().contains(_groupSearch)).length,
                            itemBuilder: (context, index) {
                              final filteredGroups = _groups.where((g) => g.name.toLowerCase().contains(_groupSearch)).toList();
                              final group = filteredGroups[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  child: Text(group.name.isNotEmpty ? group.name.substring(0, 1).toUpperCase() : '?'),
                                ),
                                title: Text(group.name),
                                subtitle: Text(
                                  group.lastMessage ?? 'No messages yet.',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: group.lastMessageTime != null
                                    ? Text(
                                        DateFormat.jm().format(group.lastMessageTime!),
                                        style: TextStyle(fontSize: 12, color: Colors.grey),
                                      )
                                    : null,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => GroupDetailsScreen(groupId: group.id),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}
