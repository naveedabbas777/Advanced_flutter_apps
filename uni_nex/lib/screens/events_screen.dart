import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../models/event_model.dart';
import '../models/campus_location_model.dart';
import '../models/user_model.dart';
import '../screens/campus_navigation_screen.dart';
import '../utils/theme_manager.dart';
import '../widgets/event_card.dart';

class AllEventsScreen extends StatefulWidget {
  const AllEventsScreen({super.key});

  @override
  State<AllEventsScreen> createState() => _AllEventsScreenState();
}

class _AllEventsScreenState extends State<AllEventsScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  UserModel? _currentUser;
  bool _isAdmin = false;
  bool _isLoadingLocations = true;
  List<CampusLocation> _campusLocations = [];

  final List<String> _categories = const [
    'All',
    'academic',
    'cultural',
    'sports',
    'social',
    'workshop',
    'conference',
    'other',
  ];

  DateTime get _startOfToday => DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  @override
  void initState() {
    super.initState();
    _loadCurrentUserRole();
    _loadCampusLocations();
  }

  Future<void> _loadCurrentUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) return;

      final model = UserModel.fromFirestore(doc.data()!, user.uid);
      if (mounted) {
        setState(() {
          _currentUser = model;
          _isAdmin = model.isAdmin();
        });
      }
    } catch (e) {
      debugPrint('Error loading user role: $e');
    }
  }

  Future<void> _loadCampusLocations() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('locations')
          .orderBy('name')
          .get();

      if (!mounted) return;
      setState(() {
        _campusLocations = snapshot.docs
            .map((doc) => CampusLocation.fromFirestore(doc.data(), doc.id))
            .toList();
        _isLoadingLocations = false;
      });
    } catch (e) {
      debugPrint('Error loading campus locations: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingLocations = false;
      });
    }
  }

  Future<void> _deleteEvent(String eventId) async {
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete event: $e')),
        );
      }
    }
  }

  void _showDeleteConfirmation(String eventId, String eventTitle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "$eventTitle"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteEvent(eventId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAdminOnlyMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Only admins can add events.'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _showCreateEventDialog() {
    if (!_isAdmin) {
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
    CampusLocation? selectedCampusLocation;
    double? taggedLatitude;
    double? taggedLongitude;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final canSubmit = titleController.text.trim().isNotEmpty &&
                descriptionController.text.trim().isNotEmpty &&
                timeController.text.trim().isNotEmpty &&
                locationController.text.trim().isNotEmpty &&
                (taggedLatitude != null && taggedLongitude != null) &&
                !isSubmitting;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              ),
              title: Row(
                children: [
                  Icon(Icons.event_available, color: AppColors.primary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Add New Event',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Event Title',
                        hintText: 'Enter event title',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Enter event description',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
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
                        child: Text('${selectedDate.toLocal()}'.split(' ')[0]),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),
                    TextField(
                      controller: timeController,
                      decoration: const InputDecoration(
                        labelText: 'Time',
                        hintText: 'e.g. 2:00 PM - 4:00 PM',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),
                    DropdownButtonFormField<CampusLocation?>(
                      value: selectedCampusLocation,
                      decoration: const InputDecoration(
                        labelText: 'Choose from Added Locations',
                      ),
                      items: [
                        const DropdownMenuItem<CampusLocation?>(
                          value: null,
                          child: Text('Select a campus location'),
                        ),
                        ..._campusLocations.map(
                          (location) => DropdownMenuItem<CampusLocation?>(
                            value: location,
                            child: Text(location.name),
                          ),
                        ),
                      ],
                      onChanged: (location) {
                        setState(() {
                          selectedCampusLocation = location;
                          if (location != null) {
                            locationController.text = location.name;
                            locationTagController.text =
                                locationTagController.text.isEmpty
                                    ? location.name
                                    : locationTagController.text;
                            taggedLatitude = location.latitude;
                            taggedLongitude = location.longitude;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        hintText: 'Event location or campus spot',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppDimensions.spacingSm),
                    TextField(
                      controller: locationTagController,
                      decoration: const InputDecoration(
                        labelText: 'Location Tag',
                        hintText: 'Label shown on map, e.g. Main Hall',
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
                            selectedCampusLocation = null;
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
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: _categories
                          .where((cat) => cat != 'All')
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(category.capitalize()),
                            ),
                          )
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
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: !canSubmit
                      ? null
                      : () async {
                          setState(() => isSubmitting = true);
                          final wasCreated = await _createEvent(
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
                          );

                          if (!dialogContext.mounted) return;
                          setState(() => isSubmitting = false);

                          if (!wasCreated) return;

                          Navigator.of(dialogContext).pop();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${titleController.text.trim()} created successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _createEvent(
    String title,
    String description,
    DateTime date,
    String time,
    String location,
    String category, {
    String? locationTag,
    double? latitude,
    double? longitude,
  }) async {
    if (!_isAdmin) {
      _showAdminOnlyMessage();
      return false;
    }

    if (title.isEmpty || description.isEmpty || time.isEmpty || location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: AppColors.error,
        ),
      );
      return false;
    }

    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please tag the event on the map or select an added location.'),
          backgroundColor: AppColors.error,
        ),
      );
      return false;
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

      await FirebaseFirestore.instance.collection('events').doc(event.id).set(event.toFirestore());
      return true;
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
      return false;
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

  void _openEventDirections(EventModel event) {
    if (event.latitude == null || event.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This event has no tagged map location.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CampusNavigationScreen(
          initialEventName: event.title,
          initialEventLocationLabel: event.locationTag ?? event.location,
          initialEventLatitude: event.latitude,
          initialEventLongitude: event.longitude,
        ),
      ),
    );
  }

  String _eventLocationText(EventModel event) {
    final tag = event.locationTag?.trim();
    final base = event.location;

    if (tag != null && tag.isNotEmpty) {
      return '$base • #$tag';
    }

    final hasMapLocation = event.latitude != null && event.longitude != null;
    return hasMapLocation ? '$base • Tagged on map' : base;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'All Events',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white.withOpacity(0.95),
        elevation: 0,
        foregroundColor: Colors.grey[800],
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
            Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingLg),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: const InputDecoration(
                        hintText: 'Search events...',
                        prefixIcon: Icon(Icons.search),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: AppDimensions.spacingMd,
                          vertical: AppDimensions.spacingMd,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
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
                            onSelected: (_) => setState(() => _selectedCategory = category),
                            backgroundColor: Colors.white,
                            selectedColor: AppColors.primary,
                            checkmarkColor: Colors.white,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('events')
                    .orderBy('date')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Failed to load events: ${snapshot.error}'),
                    );
                  }

                  final events = snapshot.data?.docs
                          .map((doc) => EventModel.fromFirestore(doc.data(), doc.id))
                          .where((event) {
                            final matchesSearch =
                                event.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                                event.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                              event.location.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                              (event.locationTag ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
                            final matchesCategory =
                                _selectedCategory == 'All' || event.category == _selectedCategory;
                            return matchesSearch && matchesCategory;
                          })
                          .toList() ??
                      [];

                  events.sort((a, b) {
                    final aUpcoming = !a.date.isBefore(_startOfToday);
                    final bUpcoming = !b.date.isBefore(_startOfToday);
                    if (aUpcoming != bUpcoming) {
                      return aUpcoming ? -1 : 1;
                    }
                    return a.date.compareTo(b.date);
                  });

                  if (events.isEmpty) {
                    return Center(
                      child: Text(
                        _searchQuery.isEmpty && _selectedCategory == 'All'
                            ? 'No events available yet'
                            : 'No events match your search',
                        style: TextStyle(
                          fontSize: AppDimensions.fontSizeLg,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(AppDimensions.spacingLg),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      final hasMapLocation = event.latitude != null && event.longitude != null;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppDimensions.spacingMd),
                        child: Stack(
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => EventDetailsPage(event: event),
                                  ),
                                );
                              },
                              child: EventCard(
                                title: event.title,
                                date: event.date.toLocal().toString().split(' ')[0],
                                time: event.time,
                                location: _eventLocationText(event),
                                category: event.category,
                              ),
                            ),
                            if (hasMapLocation)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkResponse(
                                    onTap: () => _openEventDirections(event),
                                    radius: 24,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.95),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.12),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.place,
                                        color: AppColors.secondary,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (_isAdmin)
                              Positioned(
                                top: 8,
                                right: hasMapLocation ? 48 : 8,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkResponse(
                                    onTap: () => _showDeleteConfirmation(event.id, event.title),
                                    radius: 24,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.95),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.12),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: _showCreateEventDialog,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add Event'),
            )
          : null,
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

class EventDetailsPage extends StatefulWidget {
  final EventModel event;

  const EventDetailsPage({super.key, required this.event});

  @override
  State<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _annotationManager;

  bool get _hasTaggedLocation =>
      widget.event.latitude != null && widget.event.longitude != null;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _annotationManager = await mapboxMap.annotations.createPointAnnotationManager();

    if (!_hasTaggedLocation) return;

    await _annotationManager!.create(
      PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(widget.event.longitude!, widget.event.latitude!),
        ),
        iconImage: 'marker-15',
        iconSize: 1.5,
        iconColor: AppColors.primary.value,
      ),
    );
  }

  void _openCampusMap() {
    if (!_hasTaggedLocation) {
      _showDirectionsInfo();
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CampusNavigationScreen(
          initialEventName: widget.event.title,
          initialEventLocationLabel:
              widget.event.locationTag ?? widget.event.location,
          initialEventLatitude: widget.event.latitude,
          initialEventLongitude: widget.event.longitude,
        ),
      ),
    );
  }

  void _showDirectionsInfo() {
    if (_hasTaggedLocation) {
      _openCampusMap();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This event has no tagged map location.'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _saveToMyEvents() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;

    await FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).set(
      {
        'preferences': {
          'savedEvents': FieldValue.arrayUnion([widget.event.id]),
        },
      },
      SetOptions(merge: true),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.event.title} saved to My Events'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Details'),
        backgroundColor: Colors.white.withOpacity(0.95),
        foregroundColor: Colors.grey[800],
        elevation: 0,
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
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.spacingLg),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
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
                    Text(
                      widget.event.title,
                      style: TextStyle(
                        fontSize: AppDimensions.fontSizeXxl,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingSm),
                    Text(
                      widget.event.description,
                      style: TextStyle(
                        fontSize: AppDimensions.fontSizeMd,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),
                    _infoRow(Icons.calendar_today, widget.event.date.toLocal().toString().split(' ')[0]),
                    _infoRow(Icons.access_time, widget.event.time),
                    _infoRow(Icons.location_on, widget.event.location),
                    if (widget.event.locationTag != null && widget.event.locationTag!.trim().isNotEmpty)
                      _infoRow(Icons.tag, '#${widget.event.locationTag!.trim()}'),
                    _infoRow(Icons.category, widget.event.category.capitalize()),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spacingLg),
              if (_hasTaggedLocation) ...[
                Text(
                  'Tagged Location',
                  style: TextStyle(
                    fontSize: AppDimensions.fontSizeLg,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                Container(
                  height: 260,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      MapWidget(
                        key: ValueKey('event-map-${widget.event.id}'),
                        onMapCreated: _onMapCreated,
                        cameraOptions: CameraOptions(
                          center: Point(
                            coordinates: Position(widget.event.longitude!, widget.event.latitude!),
                          ),
                          zoom: 15.0,
                        ),
                        styleUri: MapboxStyles.MAPBOX_STREETS,
                      ),
                      const Center(
                        child: Icon(
                          Icons.place,
                          color: AppColors.secondary,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                Text(
                  'Coordinates: ${widget.event.latitude!.toStringAsFixed(6)}, ${widget.event.longitude!.toStringAsFixed(6)}',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: AppDimensions.spacingXl),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showDirectionsInfo,
                      icon: const Icon(Icons.directions),
                      label: const Text('Directions'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingMd),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingMd),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openCampusMap,
                      icon: const Icon(Icons.map),
                      label: const Text('Open Campus Map'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.primary),
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingMd),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _saveToMyEvents,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Save to My Events'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.secondary),
                    foregroundColor: AppColors.secondary,
                    padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingMd),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingSm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: AppDimensions.fontSizeMd,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
