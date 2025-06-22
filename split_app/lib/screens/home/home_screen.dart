import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/group_provider.dart';
import 'package:split_app/models/group_model.dart';
import '../groups/create_group_screen.dart';
import '../groups/group_details_screen.dart';
import '../direct_chat/direct_chat_screen.dart';
import '../direct_chat/user_search_screen.dart';
import 'package:badges/badges.dart' as badges;
import 'package:intl/intl.dart';
import 'archived_screen.dart';

// Import the tab bodies as separate widgets
import 'tabs/groups_tab.dart';
import 'tabs/messages_tab.dart';

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    GroupsTab(),
    MessagesTab(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? 'Groups' : 'Messages'),
        actions: [
          IconButton(
            icon: Icon(Icons.archive_outlined),
            tooltip: 'Archived',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ArchivedScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.mail_outline),
            tooltip: 'Invitations',
            onPressed: () {
              Navigator.pushNamed(context, '/invitations');
            },
          ),
          IconButton(
            icon: Icon(Icons.person),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
        ],
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => CreateGroupScreen()));
              },
              child: const Icon(Icons.add),
              tooltip: 'Create Group',
            )
          : FloatingActionButton(
              onPressed: () {
                final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
                final currentUserId = authProvider.currentUser?.uid;
                if (currentUserId != null) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => UserSearchScreen(currentUserId: currentUserId)));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Cannot start a new chat. User not logged in."))
                  );
                }
              },
              child: const Icon(Icons.message),
              tooltip: 'New Message',
            ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Groups',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble),
            label: 'Messages',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}