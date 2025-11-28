import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../providers/group_provider.dart';
import '../../providers/auth_provider.dart';

class UserInviteSearchScreen extends StatefulWidget {
  final String groupId;
  final List<String> currentMemberIds;
  final String currentUserId;
  const UserInviteSearchScreen({
    Key? key,
    required this.groupId,
    required this.currentMemberIds,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<UserInviteSearchScreen> createState() => _UserInviteSearchScreenState();
}

class _UserInviteSearchScreenState extends State<UserInviteSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<DocumentSnapshot> _results = [];
  bool _isLoading = false;
  Timer? _debounceTimer;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && _searchController.text.isEmpty) {
        setState(() => _showSuggestions = false);
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _results = [];
        _showSuggestions = false;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _showSuggestions = true;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    try {
      final queryLower = query.toLowerCase();

      // Search by username prefix
      final usernameQuery = FirebaseFirestore.instance
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: queryLower)
          .where('username', isLessThanOrEqualTo: queryLower + '\uf8ff')
          .limit(10);

      // Search by email prefix
      final emailQuery = FirebaseFirestore.instance
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: queryLower)
          .where('email', isLessThanOrEqualTo: queryLower + '\uf8ff')
          .limit(10);

      final results = await Future.wait([
        usernameQuery.get(),
        emailQuery.get(),
      ]);

      final allDocs = <DocumentSnapshot>{};
      for (var snapshot in results) {
        for (var doc in snapshot.docs) {
          if (doc.id != widget.currentUserId &&
              !widget.currentMemberIds.contains(doc.id)) {
            allDocs.add(doc);
          }
        }
      }

      // Filter results to match prefix (case-insensitive)
      final filteredResults = allDocs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final username = (data['username'] ?? '').toString().toLowerCase();
        final email = (data['email'] ?? '').toString().toLowerCase();
        return username.startsWith(queryLower) || email.startsWith(queryLower);
      }).toList();

      if (mounted) {
        setState(() {
          _results = filteredResults;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _results = [];
          _isLoading = false;
        });
      }
    }
  }

  void _inviteUser(DocumentSnapshot userDoc) async {
    final userData = userDoc.data() as Map<String, dynamic>;
    final email = userData['email'];
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final inviterUsername = authProvider.currentUserModel?.username ?? '';
    final inviterEmail = authProvider.currentUserModel?.email ?? '';
    try {
      await groupProvider.inviteUserToGroup(
        groupId: widget.groupId,
        invitedBy: widget.currentUserId,
        invitedByUsername: inviterUsername,
        invitedByEmail: inviterEmail,
        invitedUserEmail: email,
      );
      if (groupProvider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(groupProvider.error!), backgroundColor: Colors.red),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Invitation sent successfully!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to send invitation: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invite Member')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search by username or email',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _results = [];
                                _showSuggestions = false;
                              });
                            },
                          )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onTap: () {
                if (_searchController.text.isNotEmpty) {
                  setState(() => _showSuggestions = true);
                }
              },
            ),
          ),
          if (_showSuggestions && _results.isNotEmpty)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final userDoc = _results[index];
                    final userData = userDoc.data() as Map<String, dynamic>;
                    final userName =
                        userData['username'] ?? userData['email'] ?? 'Unknown';
                    final email = userData['email'] ?? '';
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(userName.substring(0, 1).toUpperCase()),
                      ),
                      title: Text(userName),
                      subtitle: email.isNotEmpty ? Text(email) : null,
                      trailing: const Icon(Icons.person_add),
                      onTap: () {
                        _inviteUser(userDoc);
                        _searchController.clear();
                        setState(() {
                          _showSuggestions = false;
                          _results = [];
                        });
                      },
                    );
                  },
                ),
              ),
            )
          else if (_showSuggestions &&
              !_isLoading &&
              _searchController.text.isNotEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'No users found matching "${_searchController.text}"',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            )
          else if (!_showSuggestions)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Start typing to search for users to invite',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
