import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/group_provider.dart';
import '../../models/group_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final userModel = context.read<AppAuthProvider>().userModel;
    if (userModel != null) {
      _usernameController.text = userModel.username;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      await authProvider.updateProfile(
        username: _usernameController.text.trim(),
      );

      if (authProvider.error != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authProvider.error!)),
        );
      } else {
        setState(() {
          _isEditing = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AppAuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userModel = authProvider.userModel;

    if (userModel == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(
              themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () {
              themeProvider.toggleTheme();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      userModel.username[0].toUpperCase(),
                      style: theme.textTheme.headlineLarge?.copyWith(
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!_isEditing)
                    Text(
                      userModel.username,
                      style: theme.textTheme.headlineMedium,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            if (_isEditing)
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a username';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isEditing = false;
                              _usernameController.text = userModel.username;
                            });
                          },
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: authProvider.isLoading ? null : _updateProfile,
                          child: authProvider.isLoading
                              ? const CircularProgressIndicator()
                              : const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: const Icon(Icons.email),
                    title: const Text('Email'),
                    subtitle: Text(userModel.email),
                  ),
                  Divider(),
                  ListTile(
                    leading: const Icon(Icons.group),
                    title: const Text('My Groups'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // Navigate to a screen showing group details if needed
                    },
                  ),
                  StreamBuilder<List<GroupModel>>(
                    stream: Provider.of<GroupProvider>(context, listen: false).getUserGroupsStream(userModel.uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text('Error loading groups: ${snapshot.error}', style: TextStyle(color: Colors.red)),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text('No groups joined yet.'),
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          final group = snapshot.data![index];
                          return ListTile(
                            title: Text(group.name),
                            subtitle: Text('Members: ${group.members.length}'),
                            onTap: () {
                              // Navigate to group details screen
                              Navigator.pushNamed(context, '/group-details', arguments: {'groupId': group.id, 'groupName': group.name});
                            },
                          );
                        },
                      );
                    },
                  ),
                  Divider(),
                  ListTile(
                    leading: const Icon(Icons.mail),
                    title: const Text('Pending Invitations'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pushNamed(context, '/invitations');
                    },
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('group_invitations')
                        .where('invitedUserId', isEqualTo: userModel.uid)
                        .where('status', isEqualTo: 'pending')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text('Error loading invitations: ${snapshot.error}', style: TextStyle(color: Colors.red)),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text('No pending invitations.'),
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final invitation = snapshot.data!.docs[index];
                          final invitationData = invitation.data() as Map<String, dynamic>;
                          final groupName = invitationData['groupName'] ?? 'Unnamed Group';
                          final invitedByUsername = invitationData['invitedByUsername'] ?? 'Unknown';

                          return ListTile(
                            title: Text('Join: $groupName'),
                            subtitle: Text('Invited by: $invitedByUsername'),
                            onTap: () {
                              Navigator.pushNamed(context, '/invitations');
                            },
                          );
                        },
                      );
                    },
                  ),
                  Divider(),
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Member Since'),
                    subtitle: Text(
                      '${userModel.createdAt.day}/${userModel.createdAt.month}/${userModel.createdAt.year}',
                    ),
                  ),
                  if (userModel.lastLogin != null)
                    ListTile(
                      leading: const Icon(Icons.access_time),
                      title: const Text('Last Login'),
                      subtitle: Text(
                        '${userModel.lastLogin!.day}/${userModel.lastLogin!.month}/${userModel.lastLogin!.year}',
                      ),
                    ),
                  const SizedBox(height: 16),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isEditing = true;
                        });
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit Profile'),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 32),
            Center(
              child: ElevatedButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Logout'),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
        await authProvider.signOut();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error logging out: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 