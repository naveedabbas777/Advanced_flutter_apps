import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../utils/theme_manager.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with TickerProviderStateMixin {
  late AnimationController _contentController;
  late Animation<double> _contentAnimation;

  List<UserModel> _users = [];
  bool _isLoading = true;
  bool _hasAdminAccess = false;
  String _searchQuery = '';
  UserRole? _selectedRole;
  bool _showActiveOnly = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _verifyAdminAndLoadUsers();
  }

  Future<void> _verifyAdminAndLoadUsers() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        setState(() {
          _hasAdminAccess = false;
          _isLoading = false;
        });
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (!userDoc.exists) {
        setState(() {
          _hasAdminAccess = false;
          _isLoading = false;
        });
        return;
      }

      final currentUser = UserModel.fromFirestore(userDoc.data()!, firebaseUser.uid);
      final isAdmin = currentUser.isAdmin();

      setState(() {
        _hasAdminAccess = isAdmin;
      });

      if (isAdmin) {
        await _loadUsers();
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error verifying admin access: $e');
      setState(() {
        _hasAdminAccess = false;
        _isLoading = false;
      });
    }
  }

  void _initializeAnimations() {
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _contentAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );

    // Start animation
    Future.delayed(const Duration(milliseconds: 200), () {
      _contentController.forward();
    });
  }

  Future<void> _loadUsers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _users = snapshot.docs
            .map((doc) => UserModel.fromFirestore(doc.data(), doc.id))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading users: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<UserModel> get _filteredUsers {
    return _users.where((user) {
      final matchesSearch =
          user.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (user.studentId?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
              false);
      final matchesRole = _selectedRole == null || user.role == _selectedRole;
      final matchesStatus = !_showActiveOnly || user.isActive;
      return matchesSearch && matchesRole && matchesStatus;
    }).toList();
  }

  Future<void> _updateUserRole(UserModel user, UserRole newRole) async {
    try {
      final updatedUser = user.copyWith(role: newRole);
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'role': newRole.name},
      );

      setState(() {
        final index = _users.indexWhere((u) => u.uid == user.uid);
        if (index != -1) {
          _users[index] = updatedUser;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${user.displayName} role updated to ${newRole.displayName}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating user role: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update user role'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _promoteToAdmin(UserModel user) async {
    try {
      final updatedUser = user.copyWith(role: UserRole.admin);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'role': UserRole.admin.name},
      );

      setState(() {
        final index = _users.indexWhere((u) => u.uid == user.uid);
        if (index != -1) {
          _users[index] = updatedUser;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${user.displayName} has been promoted to Administrator',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error promoting user to admin: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to promote user to admin'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _toggleUserStatus(UserModel user) async {
    try {
      final newStatus = !user.isActive;
      final updatedUser = user.copyWith(isActive: newStatus);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'isActive': newStatus},
      );

      setState(() {
        final index = _users.indexWhere((u) => u.uid == user.uid);
        if (index != -1) {
          _users[index] = updatedUser;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${user.displayName} ${newStatus ? 'activated' : 'deactivated'}',
            ),
            backgroundColor: newStatus ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating user status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update user status'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showUserDetails(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [user.role.color, user.role.color.withOpacity(0.7)],
                ),
              ),
              child: Center(
                child: Text(
                  user.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    user.email,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Role', user.role.displayName),
              _buildDetailRow('Status', user.isActive ? 'Active' : 'Inactive'),
              if (user.studentId != null)
                _buildDetailRow('Student ID', user.studentId!),
              if (user.department != null)
                _buildDetailRow('Department', user.department!),
              if (user.phoneNumber != null)
                _buildDetailRow('Phone', user.phoneNumber!),
              _buildDetailRow(
                'Email Verified',
                user.emailVerified ? 'Yes' : 'No',
              ),
              if (user.createdAt != null)
                _buildDetailRow('Joined', _formatDate(user.createdAt!)),
              if (user.lastLoginAt != null)
                _buildDetailRow('Last Login', _formatDate(user.lastLoginAt!)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoading && !_hasAdminAccess) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('User Management'),
          backgroundColor: Colors.white.withOpacity(0.9),
          elevation: 0,
          foregroundColor: Colors.grey[800],
          iconTheme: IconThemeData(color: Colors.grey[800]),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppDimensions.spacingLg),
            child: Text(
              'Access denied. Only administrators can manage users.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppDimensions.fontSizeMd,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'User Management',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 0,
        foregroundColor: Colors.grey[800],
        iconTheme: IconThemeData(color: Colors.grey[800]),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFE3F2FD),
              const Color(0xFFF8F9FA),
              Colors.white,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Column(
          children: [
            // Search and Filter Section
            AnimatedBuilder(
              animation: _contentAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, (1 - _contentAnimation.value) * -30),
                  child: Opacity(
                    opacity: _contentAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(AppDimensions.spacingLg),
                      child: Column(
                        children: [
                          // Search Bar
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(0.9),
                                  Colors.white.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusLg,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 15,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(
                                color: Colors.white.withOpacity(0.5),
                                width: 1.5,
                              ),
                            ),
                            child: TextField(
                              onChanged: (value) =>
                                  setState(() => _searchQuery = value),
                              decoration: InputDecoration(
                                hintText: 'Search users...',
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: AppColors.primary,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: AppDimensions.spacingMd,
                                  vertical: AppDimensions.spacingMd,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: AppDimensions.spacingMd),

                          // Filters
                          Row(
                            children: [
                              // Role Filter
                              Expanded(
                                child: DropdownButtonFormField<UserRole?>(
                                  value: _selectedRole,
                                  hint: const Text('All Roles'),
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: AppDimensions.spacingMd,
                                      vertical: AppDimensions.spacingSm,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppDimensions.radiusMd,
                                      ),
                                      borderSide: BorderSide(
                                        color: Colors.grey[300]!,
                                      ),
                                    ),
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text('All Roles'),
                                    ),
                                    ...UserRole.values.map(
                                      (role) => DropdownMenuItem(
                                        value: role,
                                        child: Text(role.displayName),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) =>
                                      setState(() => _selectedRole = value),
                                ),
                              ),

                              const SizedBox(width: AppDimensions.spacingMd),

                              // Status Filter
                              FilterChip(
                                label: Text(
                                  _showActiveOnly ? 'Active Only' : 'All Users',
                                ),
                                selected: _showActiveOnly,
                                onSelected: (selected) =>
                                    setState(() => _showActiveOnly = selected),
                                backgroundColor: Colors.white,
                                selectedColor: AppColors.primary.withOpacity(
                                  0.1,
                                ),
                                checkmarkColor: AppColors.primary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // Users List
            Expanded(
              child: AnimatedBuilder(
                animation: _contentAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, (1 - _contentAnimation.value) * 50),
                    child: Opacity(
                      opacity: _contentAnimation.value,
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _filteredUsers.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(
                                    height: AppDimensions.spacingMd,
                                  ),
                                  Text(
                                    _searchQuery.isEmpty &&
                                            _selectedRole == null
                                        ? 'No users found'
                                        : 'No users match your filters',
                                    style: TextStyle(
                                      fontSize: AppDimensions.fontSizeLg,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadUsers,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(
                                  AppDimensions.spacingLg,
                                ),
                                itemCount: _filteredUsers.length,
                                itemBuilder: (context, index) {
                                  final user = _filteredUsers[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppDimensions.spacingMd,
                                    ),
                                    child: _buildUserCard(user),
                                  );
                                },
                              ),
                            ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showPromoteUserDialog,
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        elevation: 8,
        icon: const Icon(Icons.admin_panel_settings),
        label: const Text(
          'Promote to Admin',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildUserCard(UserModel user) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.white.withOpacity(0.95),
            Colors.white.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: [
          BoxShadow(
            color: user.role.color.withOpacity(0.1),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            blurRadius: 15,
            spreadRadius: -3,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showUserDetails(user),
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingLg),
            child: Column(
              children: [
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            user.role.color,
                            user.role.color.withOpacity(0.7),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: user.role.color.withOpacity(0.4),
                            blurRadius: 10,
                            spreadRadius: 2,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          user.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: AppDimensions.spacingMd),

                    // User Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.displayName,
                            style: TextStyle(
                              fontSize: AppDimensions.fontSizeLg,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[800],
                            ),
                          ),
                          Text(
                            user.email,
                            style: TextStyle(
                              fontSize: AppDimensions.fontSizeSm,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacingXs),
                          Row(
                            children: [
                              // Role Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      user.role.color.withOpacity(0.2),
                                      user.role.color.withOpacity(0.1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusSm,
                                  ),
                                  border: Border.all(
                                    color: user.role.color.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  user.role.displayName,
                                  style: TextStyle(
                                    fontSize: AppDimensions.fontSizeXs,
                                    fontWeight: FontWeight.w700,
                                    color: user.role.color,
                                  ),
                                ),
                              ),

                              const SizedBox(width: AppDimensions.spacingSm),

                              // Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: user.isActive
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusSm,
                                  ),
                                  border: Border.all(
                                    color: user.isActive
                                        ? Colors.green.withOpacity(0.3)
                                        : Colors.red.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  user.isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    fontSize: AppDimensions.fontSizeXs,
                                    fontWeight: FontWeight.w700,
                                    color: user.isActive
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Action Menu
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'view':
                            _showUserDetails(user);
                            break;
                          case 'role':
                            _showRoleChangeDialog(user);
                            break;
                          case 'make_admin':
                            _promoteToAdmin(user);
                            break;
                          case 'status':
                            _toggleUserStatus(user);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'view',
                          child: Text('View Details'),
                        ),
                        const PopupMenuItem(
                          value: 'role',
                          child: Text('Change Role'),
                        ),
                        if (!user.isAdmin()) // Only show for non-admin users
                          const PopupMenuItem(
                            value: 'make_admin',
                            child: Text('Make Admin'),
                          ),
                        PopupMenuItem(
                          value: 'status',
                          child: Text(
                            user.isActive ? 'Deactivate' : 'Activate',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPromoteUserDialog() {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        title: Row(
          children: [
            Icon(Icons.admin_panel_settings, color: AppColors.secondary),
            const SizedBox(width: 12),
            const Text(
              'Promote User to Admin',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the email address of the user you want to promote to Administrator.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'User Email',
                hintText: 'Enter email address',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _promoteUserByEmail(emailController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Promote'),
          ),
        ],
      ),
    );
  }

  Future<void> _promoteUserByEmail(String email) async {
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an email address'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      // Find user by email
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (userQuery.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User not found with this email address'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final userDoc = userQuery.docs.first;
      final userData = userDoc.data();
      final user = UserModel.fromFirestore(userData, userDoc.id);

      if (user.isAdmin()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User is already an Administrator'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        Navigator.of(context).pop();
        return;
      }

      // Promote to admin
      await _promoteToAdmin(user);
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Error promoting user by email: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to promote user'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showRoleChangeDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (context) {
        UserRole selectedRole = user.role;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              ),
              title: const Text('Change User Role'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: UserRole.values.map((role) {
                  return RadioListTile<UserRole>(
                    title: Text(role.displayName),
                    subtitle: Text(role.description),
                    value: role,
                    groupValue: selectedRole,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedRole = value);
                      }
                    },
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (selectedRole != user.role) {
                      _updateUserRole(user, selectedRole);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Update Role'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
