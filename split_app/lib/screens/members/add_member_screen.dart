import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:split_app/providers/auth_provider.dart';
import 'package:split_app/providers/group_provider.dart';

class AddMemberScreen extends StatefulWidget {
  final String groupId;

  AddMemberScreen({required this.groupId});

  @override
  _AddMemberScreenState createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _addMember() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
        final groupProvider = Provider.of<GroupProvider>(context, listen: false);

        if (authProvider.currentUserModel == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not logged in.')),
          );
          setState(() => _isLoading = false);
          return;
        }

        await groupProvider.inviteUserToGroup(
          groupId: widget.groupId,
          invitedBy: authProvider.currentUserModel!.uid,
          invitedByUsername: authProvider.currentUserModel!.username,
          invitedUserEmail: _emailController.text.trim(),
        );

        if (groupProvider.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(groupProvider.error!)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invitation sent successfully!')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Member'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Member Email',
                  hintText: 'Enter email of member to invite',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceVariant,
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an email address';
                  }
                  if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
                      .hasMatch(value)) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Consumer<GroupProvider>(
                builder: (context, groupProvider, child) {
                  return ElevatedButton.icon(
                    onPressed: groupProvider.isLoading ? null : _addMember,
                    icon: groupProvider.isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Icon(Icons.person_add),
                    label: Text(groupProvider.isLoading ? 'Sending Invitation...' : 'Send Invitation'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Theme.of(context).colorScheme.onSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  );
                },
              ),
              if (Provider.of<GroupProvider>(context).error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    Provider.of<GroupProvider>(context).error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
} 