import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:split_app/providers/auth_provider.dart';
import 'package:split_app/providers/group_provider.dart';

class CreateGroupScreen extends StatefulWidget {
  @override
  _CreateGroupScreenState createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _groupNameController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  String? _validateGroupName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a group name';
    }
    if (value.length < 3) {
      return 'Group name must be at least 3 characters long';
    }
    if (value.length > 50) {
      return 'Group name must be less than 50 characters';
    }
    if (!RegExp(r'^[a-zA-Z0-9\s\-_]+$').hasMatch(value)) {
      return 'Group name can only contain letters, numbers, spaces, hyphens, and underscores';
    }
    return null;
  }

  Future<void> _createGroup() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isCreating = true);
      
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);

      if (authProvider.currentUserModel == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not logged in.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isCreating = false);
        return;
      }

      try {
        await groupProvider.createGroup(
          _groupNameController.text.trim(),
          authProvider.currentUserModel!,
        );

        if (groupProvider.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(groupProvider.error!),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Group created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(); // Go back to the previous screen
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create group: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Group'),
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
                          'Group Details',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _groupNameController,
                          decoration: InputDecoration(
                            labelText: 'Group Name',
                            hintText: 'Enter the group name',
                            prefixIcon: const Icon(Icons.group),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceVariant,
                          ),
                          validator: _validateGroupName,
                          enabled: !_isCreating,
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'The creator will automatically become the group admin.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _isCreating ? null : _createGroup,
                  icon: _isCreating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add_circle),
                  label: Text(_isCreating ? 'Creating Group...' : 'Create Group'),
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