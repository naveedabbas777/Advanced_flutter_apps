import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:split_app/providers/auth_provider.dart';
import 'package:split_app/providers/group_provider.dart';

class AddMemberScreen extends StatefulWidget {
  final String groupId;

  const AddMemberScreen({super.key, required this.groupId});

  @override
  _AddMemberScreenState createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter an email address';
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+',
      caseSensitive: false,
    );
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  Future<void> _addMember() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
        final groupProvider = Provider.of<GroupProvider>(context, listen: false);

        if (authProvider.currentUserModel == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User not logged in.'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
          return;
        }

        await groupProvider.inviteUserToGroup(
          groupId: widget.groupId,
          invitedBy: authProvider.currentUserModel!.uid,
          invitedByUsername: authProvider.currentUserModel!.username,
          invitedByEmail: authProvider.currentUserModel!.email,
          invitedUserEmail: _emailController.text.trim().toLowerCase(),
        );

        if (groupProvider.error != null) {
          String errorMsg = groupProvider.error!;
          if (errorMsg.contains('User not found')) {
            errorMsg = 'No user found with this email. Please make sure your friend has registered and you entered the correct email.';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invitation sent successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Member'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invite New Member',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter the email address of the person you want to invite to the group.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email Address',
                            hintText: 'Enter member\'s email',
                            prefixIcon: const Icon(Icons.email),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceVariant,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                          enabled: !_isLoading,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _addMember(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _addMember,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.person_add),
                  label: Text(_isLoading ? 'Sending Invitation...' : 'Send Invitation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 