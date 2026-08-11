import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../models/event_model.dart';
import '../models/user_model.dart';
import '../widgets/event_card.dart';
import '../utils/theme_manager.dart';

class EventManagementScreen extends StatefulWidget {
  const EventManagementScreen({super.key});

  @override
  State<EventManagementScreen> createState() => _EventManagementScreenState();
}

class _EventManagementScreenState extends State<EventManagementScreen>
    with TickerProviderStateMixin {
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;
  late AnimationController _contentController;
  late Animation<double> _contentAnimation;

  List<EventModel> _events = [];
  bool _isLoading = true;
  bool _canCreateEvents = false;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'academic',
    'cultural',
    'sports',
    'social',
    'workshop',
    'conference',
    'other'
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadCurrentUserRole();
    _loadEvents();
  }

  Future<void> _loadCurrentUserRole() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (!doc.exists) return;

      final model = UserModel.fromFirestore(doc.data()!, firebaseUser.uid);
      if (mounted) {
        setState(() {
          _canCreateEvents = model.isAdmin();
        });
      }
    } catch (e) {
      debugPrint('Error loading user role for event creation: $e');
    }
  }

  void _showAdminOnlyMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Only admins can add events.'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _initializeAnimations() {
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.elasticOut),
    );

    _contentController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _contentAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );

    // Start animations
    _fabController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _contentController.forward();
    });
  }

  Future<void> _loadEvents() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('events')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _events = snapshot.docs
            .map((doc) => EventModel.fromFirestore(doc.data(), doc.id))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading events: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteEvent(EventModel event) async {
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(event.id)
          .delete();

      setState(() {
        _events.removeWhere((e) => e.id == event.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${event.title} deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting event: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete event'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(EventModel event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteEvent(event);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  List<EventModel> get _filteredEvents {
    return _events.where((event) {
      final matchesSearch = event.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                          event.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                          event.location.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                          (event.locationTag ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' || event.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  String _eventLocationText(EventModel event) {
    final tag = event.locationTag?.trim();
    if (tag == null || tag.isEmpty) {
      return event.location;
    }
    return '${event.location} • #$tag';
  }

  @override
  void dispose() {
    _fabController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Event Management',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
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
                              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
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
                              onChanged: (value) => setState(() => _searchQuery = value),
                              decoration: InputDecoration(
                                hintText: 'Search events...',
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

                          // Category Filter
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _categories.map((category) {
                                final isSelected = _selectedCategory == category;
                                return Padding(
                                  padding: const EdgeInsets.only(right: AppDimensions.spacingSm),
                                  child: FilterChip(
                                    label: Text(
                                      category == 'All' ? 'All Events' : category.capitalize(),
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(() => _selectedCategory = category);
                                    },
                                    backgroundColor: Colors.white,
                                    selectedColor: AppColors.primary,
                                    checkmarkColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                                      side: BorderSide(
                                        color: AppColors.primary.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // Events List
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
                          : _filteredEvents.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.event_busy,
                                        size: 64,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: AppDimensions.spacingMd),
                                      Text(
                                        _searchQuery.isEmpty && _selectedCategory == 'All'
                                            ? 'No events created yet'
                                            : 'No events found',
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
                                  onRefresh: _loadEvents,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.all(AppDimensions.spacingLg),
                                    itemCount: _filteredEvents.length,
                                    itemBuilder: (context, index) {
                                      final event = _filteredEvents[index];
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: AppDimensions.spacingMd),
                                        child: Dismissible(
                                          key: Key(event.id),
                                          direction: DismissDirection.endToStart,
                                          background: Container(
                                            alignment: Alignment.centerRight,
                                            padding: const EdgeInsets.only(right: AppDimensions.spacingLg),
                                            decoration: BoxDecoration(
                                              color: AppColors.error,
                                              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                                            ),
                                            child: const Icon(
                                              Icons.delete,
                                              color: Colors.white,
                                              size: 28,
                                            ),
                                          ),
                                          confirmDismiss: (direction) async {
                                            _showDeleteConfirmation(event);
                                            return false; // Don't dismiss immediately
                                          },
                                          child: EventCard(
                                            title: event.title,
                                            date: event.date.toString().split(' ')[0],
                                            time: event.time,
                                            location: _eventLocationText(event),
                                            category: event.category,
                                          ),
                                        ),
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

      // Floating Action Button
      floatingActionButton: _canCreateEvents
          ? AnimatedBuilder(
              animation: _fabAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _fabAnimation.value,
                  child: FloatingActionButton.extended(
                    onPressed: () => _showCreateEventDialog(),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 8,
                    icon: const Icon(Icons.add),
                    label: const Text(
                      'Create Event',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                );
              },
            )
          : null,
    );
  }

  void _showCreateEventDialog() {
    if (!_canCreateEvents) {
      _showAdminOnlyMessage();
      return;
    }

    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final locationController = TextEditingController();
    final locationTagController = TextEditingController();
    final timeController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedCategory = 'academic';
    double? taggedLatitude;
    double? taggedLongitude;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              ),
              title: Row(
                children: [
                  Icon(Icons.event, color: AppColors.primary),
                  const SizedBox(width: 12),
                  const Text(
                    'Create New Event',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Event Title',
                        hintText: 'Enter event title',
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),

                    // Description
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Enter event description',
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),

                    // Date
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => selectedDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          '${selectedDate.toLocal()}'.split(' ')[0],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),

                    // Time
                    TextField(
                      controller: timeController,
                      decoration: const InputDecoration(
                        labelText: 'Time',
                        hintText: 'e.g., 2:00 PM - 4:00 PM',
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),

                    // Location
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        hintText: 'Enter event location',
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingSm),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final taggedLocation = await _pickLocationOnMap();
                          if (taggedLocation == null) return;

                          setState(() {
                            taggedLatitude = taggedLocation.latitude;
                            taggedLongitude = taggedLocation.longitude;
                            if (locationController.text.trim().isEmpty) {
                              locationController.text = taggedLocation.label;
                            }
                            if (locationTagController.text.trim().isEmpty) {
                              locationTagController.text = taggedLocation.label;
                            }
                          });
                        },
                        icon: const Icon(Icons.map),
                        label: const Text('Tag Location on Map'),
                      ),
                    ),
                    if (taggedLatitude != null && taggedLongitude != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppDimensions.spacingSm),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppDimensions.spacingSm),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                          ),
                          child: Text(
                            'Tagged: ${taggedLatitude!.toStringAsFixed(6)}, ${taggedLongitude!.toStringAsFixed(6)}',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: AppDimensions.spacingMd),

                    // Location Tag
                    TextField(
                      controller: locationTagController,
                      decoration: const InputDecoration(
                        labelText: 'Location Tag',
                        hintText: 'e.g., Main Auditorium',
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),

                    // Category
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                      ),
                      items: _categories
                          .where((cat) => cat != 'All')
                          .map((category) => DropdownMenuItem(
                                value: category,
                                child: Text(category.capitalize()),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedCategory = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => _createEvent(
                    titleController.text.trim(),
                    descriptionController.text.trim(),
                    selectedDate,
                    timeController.text.trim(),
                    locationController.text.trim(),
                    selectedCategory,
                    locationTag: locationTagController.text.trim().isEmpty
                        ? null
                        : locationTagController.text.trim(),
                    latitude: taggedLatitude,
                    longitude: taggedLongitude,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _createEvent(
    String title,
    String description,
    DateTime date,
    String time,
    String location,
    String category,
    {String? locationTag,
    double? latitude,
    double? longitude}
  ) async {
    if (!_canCreateEvents) {
      _showAdminOnlyMessage();
      return;
    }

    if (title.isEmpty || description.isEmpty || time.isEmpty || location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      final event = EventModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        description: description,
        date: date,
        time: time,
        location: location,
        locationTag: locationTag,
        latitude: latitude,
        longitude: longitude,
        category: category,
      );

      await FirebaseFirestore.instance
          .collection('events')
          .doc(event.id)
          .set(event.toFirestore());

      setState(() {
        _events.insert(0, event);
      });

      Navigator.of(context).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating event: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create event'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<_TaggedLocation?> _pickLocationOnMap() async {
    MapboxMap? pickerMap;
    final labelController = TextEditingController();

    return showModalBottomSheet<_TaggedLocation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: AppDimensions.spacingSm),
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.spacingLg,
                  AppDimensions.spacingMd,
                  AppDimensions.spacingLg,
                  AppDimensions.spacingSm,
                ),
                child: Row(
                  children: [
                    Icon(Icons.place, color: AppColors.primary),
                    const SizedBox(width: AppDimensions.spacingSm),
                    const Text(
                      'Tag Event Location',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingLg),
                child: TextField(
                  controller: labelController,
                  decoration: const InputDecoration(
                    labelText: 'Location label (optional)',
                    hintText: 'e.g., Main Auditorium',
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingLg),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                      ),
                      child: MapWidget(
                        key: const ValueKey('event-location-picker-map'),
                        onMapCreated: (mapboxMap) {
                          pickerMap = mapboxMap;
                        },
                        cameraOptions: CameraOptions(
                          center: Point(coordinates: Position(73.0479, 33.6844)),
                          zoom: 14.0,
                        ),
                        styleUri: MapboxStyles.MAPBOX_STREETS,
                      ),
                    ),
                    const Center(
                      child: Icon(
                        Icons.location_pin,
                        size: 40,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingLg),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingMd),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (pickerMap == null) return;
                          final cameraState = await pickerMap!.getCameraState();
                          final center = cameraState.center;
                          final latitude = center.coordinates.lat.toDouble();
                          final longitude = center.coordinates.lng.toDouble();

                          final label = labelController.text.trim().isEmpty
                              ? 'Pinned (${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)})'
                              : labelController.text.trim();

                          if (!context.mounted) return;
                          Navigator.of(context).pop(
                            _TaggedLocation(
                              label: label,
                              latitude: latitude,
                              longitude: longitude,
                            ),
                          );
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Use This Point'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TaggedLocation {
  final String label;
  final double latitude;
  final double longitude;

  const _TaggedLocation({
    required this.label,
    required this.latitude,
    required this.longitude,
  });
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
