import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../utils/app_router.dart';
import '../utils/theme_manager.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _userModel;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _userModel = UserModel.fromFirestore(doc.data()!, firebaseUser.uid);
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRouter.login,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFE3F2FD),
            const Color(0xFFF8F9FA),
            Colors.white,
          ],
        ),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userModel == null
              ? const Center(child: Text('No profile found'))
              : ListView(
                  padding: const EdgeInsets.all(AppDimensions.spacingLg),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.spacingLg),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusLg,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 32,
                                  backgroundColor: AppColors.primary,
                                  backgroundImage:
                                      _userModel!.profileImageUrl != null
                                          ? NetworkImage(
                                              _userModel!.profileImageUrl!,
                                            )
                                          : null,
                                  child: _userModel!.profileImageUrl == null
                                      ? Text(
                                          _userModel!.initials,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 20,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: AppDimensions.spacingMd),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _userModel!.fullName,
                                        style: TextStyle(
                                          fontSize: AppDimensions.fontSizeXl,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(_userModel!.email),
                                      const SizedBox(height: 6),
                                      Chip(
                                        label: Text(
                                          _userModel!.role.displayName,
                                        ),
                                        backgroundColor: _userModel!.role.color
                                            .withOpacity(0.12),
                                        labelStyle: TextStyle(
                                          color: _userModel!.role.color,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppDimensions.spacingMd),
                            _infoCard('User ID', _userModel!.uid),
                            _infoCard('Full Name', _userModel!.fullName),
                            _infoCard('Email', _userModel!.email),
                            _infoCard('Role', _userModel!.role.displayName),
                            _infoCard(
                              'Role Description',
                              _userModel!.role.description,
                            ),
                            _infoCard(
                              'Student ID',
                              _userModel!.studentId ?? 'Not set',
                            ),
                            _infoCard(
                              'Department',
                              _userModel!.department ?? 'Not set',
                            ),
                            _infoCard(
                              'Phone',
                              _userModel!.phoneNumber ?? 'Not set',
                            ),
                            _infoCard(
                              'Email Verified',
                              _userModel!.emailVerified ? 'Yes' : 'No',
                            ),
                            _infoCard(
                              'Active Account',
                              _userModel!.isActive ? 'Yes' : 'No',
                            ),
                            _infoCard(
                              'Created At',
                              _formatDateTime(_userModel!.createdAt),
                            ),
                            _infoCard(
                              'Last Login',
                              _formatDateTime(_userModel!.lastLoginAt),
                            ),
                            _infoCard(
                              'Updated At',
                              _formatDateTime(_userModel!.updatedAt),
                            ),
                            if (_userModel!.preferences.isNotEmpty) ...[
                              const SizedBox(height: AppDimensions.spacingSm),
                              Text(
                                'Preferences',
                                style: TextStyle(
                                  fontSize: AppDimensions.fontSizeLg,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: AppDimensions.spacingSm),
                              ..._userModel!.preferences.entries.map(
                                (entry) => _infoCard(
                                  entry.key,
                                  entry.value.toString(),
                                ),
                              ),
                            ],
                          ],
                        ),
                    ),
                    const SizedBox(height: AppDimensions.spacingLg),
                    ElevatedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppDimensions.spacingMd,
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _infoCard(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingMd),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(
              '$title: ',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.grey[800],
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'Not set';
    return value.toLocal().toString().replaceFirst('.000', '');
  }
}
