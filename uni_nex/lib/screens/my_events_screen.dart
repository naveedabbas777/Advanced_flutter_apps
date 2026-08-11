import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import '../models/event_model.dart';
import '../utils/app_router.dart';
import '../utils/theme_manager.dart';
import '../widgets/event_card.dart';

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  bool _isLoading = true;
  List<EventModel> _savedEvents = [];

  @override
  void initState() {
    super.initState();
    _loadSavedEvents();
  }

  Future<void> _loadSavedEvents() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      final savedIds = List<String>.from(
        (userDoc.data()?['preferences']?['savedEvents'] as List<dynamic>? ?? const [])
            .cast<dynamic>()
            .map((value) => value.toString()),
      );

      if (savedIds.isEmpty) {
        if (mounted) {
          setState(() {
            _savedEvents = [];
            _isLoading = false;
          });
        }
        return;
      }

      final eventsSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .orderBy('date')
          .get();

      final savedEvents = eventsSnapshot.docs
          .where((doc) => savedIds.contains(doc.id))
          .map((doc) => EventModel.fromFirestore(doc.data(), doc.id))
          .toList();

      savedEvents.sort((a, b) => a.date.compareTo(b.date));

      if (mounted) {
        setState(() {
          _savedEvents = savedEvents;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading saved events: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeSavedEvent(String eventId) async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) return;

      await FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).set(
        {
          'preferences': {
            'savedEvents': FieldValue.arrayRemove([eventId]),
          },
        },
        SetOptions(merge: true),
      );

      await _loadSavedEvents();
    } catch (e) {
      debugPrint('Error removing saved event: $e');
    }
  }

  void _openEventsScreen() {
    Navigator.of(context).pushNamed(AppRouter.events);
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
          : _savedEvents.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.spacingLg),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bookmark_border,
                          size: 72,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: AppDimensions.spacingMd),
                        Text(
                          'No saved events yet',
                          style: TextStyle(
                            fontSize: AppDimensions.fontSizeLg,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingSm),
                        Text(
                          'Save events from the events screen to see them here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: AppDimensions.spacingLg),
                        ElevatedButton.icon(
                          onPressed: _openEventsScreen,
                          icon: const Icon(Icons.event),
                          label: const Text('Browse Events'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSavedEvents,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppDimensions.spacingLg),
                    itemCount: _savedEvents.length,
                    itemBuilder: (context, index) {
                      final event = _savedEvents[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppDimensions.spacingMd),
                        child: Dismissible(
                          key: ValueKey(event.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: AppDimensions.spacingLg),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                            ),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          confirmDismiss: (_) async {
                            await _removeSavedEvent(event.id);
                            return false;
                          },
                          child: EventCard(
                            title: event.title,
                            date: event.date.toLocal().toString().split(' ')[0],
                            time: event.time,
                            location: event.location,
                            category: event.category,
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
