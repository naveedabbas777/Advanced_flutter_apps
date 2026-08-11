import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/campus_location_model.dart';
import '../models/event_model.dart';
import '../models/user_model.dart';
import '../utils/theme_manager.dart';
import '../widgets/event_card.dart';
import '../widgets/location_card.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onLocationTap;
  final VoidCallback? onEventTap;

  const DashboardScreen({
    super.key,
    this.onLocationTap,
    this.onEventTap,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  UserModel? _currentUser;
  List<EventModel> _topEvents = [];
  List<CampusLocation> _latestLocations = [];
  List<_DashboardMessage> _messages = [];
  EventModel? _nearestEvent;
  bool _isLoading = true;

  // Keys for scroll-to-section
  final _eventsKey = GlobalKey();
  final _locationsKey = GlobalKey();
  final _messagesKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
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

      final eventsSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .orderBy('date')
          .limit(5)
          .get();

      final locationsSnapshot = await FirebaseFirestore.instance
          .collection('locations')
          .orderBy('createdAt', descending: true)
          .limit(3)
          .get();

      final currentUser = userDoc.exists
          ? UserModel.fromFirestore(userDoc.data()!, firebaseUser.uid)
          : null;

      final topEvents = eventsSnapshot.docs
          .map((doc) => EventModel.fromFirestore(doc.data(), doc.id))
          .toList();

      final latestLocations = locationsSnapshot.docs
          .map((doc) => CampusLocation.fromFirestore(doc.data(), doc.id))
          .toList();

      final messages = <_DashboardMessage>[];
      for (final event in topEvents.reversed.take(3)) {
        messages.add(
          _DashboardMessage(
            title: 'Event added',
            message: '${event.title} was added to the campus events list.',
            timestamp: event.createdAt ?? event.date,
            icon: Icons.event,
            color: AppColors.primary,
          ),
        );
      }
      for (final location in latestLocations) {
        messages.add(
          _DashboardMessage(
            title: 'Location added',
            message: '${location.name} was added as a campus location.',
            timestamp: location.createdAt ?? DateTime.now(),
            icon: Icons.place,
            color: AppColors.secondary,
          ),
        );
      }
      messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (mounted) {
        setState(() {
          _currentUser = currentUser;
          _topEvents = topEvents;
          _latestLocations = latestLocations;
          _messages = messages.take(5).toList();
          _nearestEvent = _getNearestEvent(topEvents);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDateTime(DateTime value) {
    return value.toLocal().toString().replaceFirst('.000', '');
  }

  EventModel? _getNearestEvent(List<EventModel> events) {
    final now = DateTime.now();
    final upcomingEvents = events.where((event) => event.date.isAfter(now)).toList();
    if (upcomingEvents.isEmpty) return null;
    upcomingEvents.sort((a, b) => a.date.compareTo(b.date));
    return upcomingEvents.first;
  }

  String _getDaysUntil(DateTime eventDate) {
    final now = DateTime.now();
    final difference = eventDate.difference(now).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';
    return '$difference days away';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentUser == null) {
      return const Center(child: Text('No user profile found'));
    }

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
      child: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.spacingLg),
          children: [
            _buildUserHeader(),
            const SizedBox(height: AppDimensions.spacingLg),
            _buildSummaryRow(),
            const SizedBox(height: AppDimensions.spacingXl),
            if (_nearestEvent != null) ...[
              _buildNearestEventCard(),
              const SizedBox(height: AppDimensions.spacingXl),
            ],
            _buildSectionHeader('Top 5 Events', Icons.event, key: _eventsKey),
            const SizedBox(height: AppDimensions.spacingMd),
            if (_topEvents.isEmpty)
              _buildEmptyState('No events found')
            else
              ..._topEvents.map(
                (event) => Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.spacingMd),
                  child: EventCard(
                    title: event.title,
                    date: event.date.toLocal().toString().split(' ')[0],
                    time: event.time,
                    location: event.location,
                    category: event.category,
                    onTap: widget.onEventTap,
                  ),
                ),
              ),
            const SizedBox(height: AppDimensions.spacingXl),
            _buildSectionHeader('Latest 3 Locations', Icons.place, key: _locationsKey),
            const SizedBox(height: AppDimensions.spacingMd),
            if (_latestLocations.isEmpty)
              _buildEmptyState('No locations found')
            else
              ..._latestLocations.map(
                (location) => Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.spacingMd),
                  child: LocationCard(
                    location: location,
                    onTap: widget.onLocationTap,
                  ),
                ),
              ),
            const SizedBox(height: AppDimensions.spacingXl),
            _buildSectionHeader('Latest Messages', Icons.notifications_active, messageCount: _messages.length, key: _messagesKey),
            const SizedBox(height: AppDimensions.spacingMd),
            if (_messages.isEmpty)
              _buildEmptyState('No activity yet')
            else
              ..._messages.map(
                (message) => Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.spacingMd),
                  child: Container(
                    padding: const EdgeInsets.all(AppDimensions.spacingMd),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: message.color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(message.icon, color: message.color),
                        ),
                        const SizedBox(width: AppDimensions.spacingMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.title,
                                style: TextStyle(
                                  fontSize: AppDimensions.fontSizeMd,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                message.message,
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatDateTime(message.timestamp),
                                style: TextStyle(
                                  fontSize: AppDimensions.fontSizeXs,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserHeader() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingLg),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.primary,
            backgroundImage: _currentUser!.profileImageUrl != null
                ? NetworkImage(_currentUser!.profileImageUrl!)
                : null,
            child: _currentUser!.profileImageUrl == null
                ? Text(
                    _currentUser!.initials,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentUser!.fullName,
                  style: TextStyle(
                    fontSize: AppDimensions.fontSizeXl,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentUser!.email,
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 6),
                Chip(
                  label: Text(_currentUser!.role.displayName),
                  backgroundColor: _currentUser!.role.color.withOpacity(0.12),
                  labelStyle: TextStyle(
                    color: _currentUser!.role.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
        alignment: 0.0, // align to top
      );
    }
  }

  Widget _buildSummaryRow() {
    return Row(
      children: [
        Expanded(child: _summaryCard('Events', _topEvents.length.toString(), Icons.event, onTap: () => _scrollToSection(_eventsKey))),
        const SizedBox(width: AppDimensions.spacingMd),
        Expanded(child: _summaryCard('Locations', _latestLocations.length.toString(), Icons.place, onTap: () => _scrollToSection(_locationsKey))),
        const SizedBox(width: AppDimensions.spacingMd),
        Expanded(child: _summaryCard('Messages', _messages.length.toString(), Icons.notifications, onTap: () => _scrollToSection(_messagesKey))),
      ],
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, {VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        splashColor: AppColors.primary.withOpacity(0.1),
        highlightColor: AppColors.primary.withOpacity(0.05),
        child: Ink(
          padding: const EdgeInsets.all(AppDimensions.spacingMd),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: AppDimensions.fontSizeXl,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontSize: AppDimensions.fontSizeXs,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, {int? messageCount, Key? key}) {
    return Row(
      key: key,
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: AppDimensions.spacingSm),
        Text(
          title,
          style: TextStyle(
            fontSize: AppDimensions.fontSizeLg,
            fontWeight: FontWeight.w800,
            color: Colors.grey[800],
          ),
        ),
        if (messageCount != null) ...[
          const SizedBox(width: AppDimensions.spacingSm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              messageCount.toString(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spacingLg),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildNearestEventCard() {
    if (_nearestEvent == null) {
      return const SizedBox.shrink();
    }

    final daysUntil = _getDaysUntil(_nearestEvent!.date);
    final eventDate = _nearestEvent!.date.toLocal().toString().split(' ')[0];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.15),
            AppColors.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onEventTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Next Event',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingMd),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        daysUntil,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                Text(
                  _nearestEvent!.title,
                  style: TextStyle(
                    fontSize: AppDimensions.fontSizeXl,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey[800],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      eventDate,
                      style: TextStyle(
                        fontSize: AppDimensions.fontSizeSm,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingLg),
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      _nearestEvent!.time,
                      style: TextStyle(
                        fontSize: AppDimensions.fontSizeSm,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _nearestEvent!.location,
                        style: TextStyle(
                          fontSize: AppDimensions.fontSizeSm,
                          color: Colors.grey[700],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
}

class _DashboardMessage {
  final String title;
  final String message;
  final DateTime timestamp;
  final IconData icon;
  final Color color;

  const _DashboardMessage({
    required this.title,
    required this.message,
    required this.timestamp,
    required this.icon,
    required this.color,
  });
}
