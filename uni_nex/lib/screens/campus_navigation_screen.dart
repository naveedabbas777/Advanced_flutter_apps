import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../models/campus_location_model.dart';
import '../models/user_model.dart';
import '../widgets/location_card.dart';
import '../utils/theme_manager.dart';
import '../services/directions_service.dart';

class CampusNavigationScreen extends StatefulWidget {
  final String? initialEventName;
  final String? initialEventLocationLabel;
  final double? initialEventLatitude;
  final double? initialEventLongitude;

  const CampusNavigationScreen({
    super.key,
    this.initialEventName,
    this.initialEventLocationLabel,
    this.initialEventLatitude,
    this.initialEventLongitude,
  });

  @override
  State<CampusNavigationScreen> createState() => _CampusNavigationScreenState();
}

class _CampusNavigationScreenState extends State<CampusNavigationScreen>
    with TickerProviderStateMixin {
  static const String _directionMarkerImageId = 'custom-direction-marker';
  static const String _directionMarkerAssetPath = 'assets/marker.png';

  late AnimationController _mapController;
  late Animation<double> _mapAnimation;
  late AnimationController _contentController;
  late Animation<double> _contentAnimation;

  List<CampusLocation> _locations = [];
  CampusLocation? _defaultStartLocation;
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  CampusCategory? _selectedCategoryObj;
  bool _showMapView = false; // true = list view, false = map view
  UserModel? _currentUser;
  bool _isAdmin = false;

  // Map view mode
  String _mapStyleMode = 'street'; // 'street', 'satellite', 'terrain'
  bool _showLocationsList = true; // Show locations panel alongside map

  // Directions mode
  DirectionsResponse? _currentDirections;
  bool _showDirections = false;
  bool _isCalculatingDirections = false;
  TransportMode _transportMode = TransportMode.driving;
  geo.Position? _userLocation;
  bool _isGettingCurrentLocation = false;
  final Set<String> _favoriteLocationIds = <String>{};
  PolylineAnnotationManager? _polylineAnnotationManager;
  final List<PointAnnotation> _directionMarkers = [];
  CampusLocation? _selectedDestination;
  Uint8List? _directionMarkerBytes;

  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  final Map<String, CampusLocation> _annotationLocationById = {};
  late final OnPointAnnotationClickListener _annotationClickListener =
      _PointTapListener(_handleAnnotationTap);
  CampusLocation? _initialEventDestination;
  bool _initialEventNavigationTriggered = false;
  bool _isDirectionMarkerRegistered = false;

  String _getMapStyle() {
    switch (_mapStyleMode) {
      case 'satellite':
        return 'mapbox://styles/mapbox/satellite-v9';
      case 'terrain':
        return 'mapbox://styles/mapbox/outdoors-v12';
      default:
        return MapboxStyles.MAPBOX_STREETS;
    }
  }

  Future<void> _updateMapStyle(String style) async {
    try {
      if (_mapboxMap != null) {
        await _mapboxMap!.style.setStyleURI(_getMapStyle());
        _isDirectionMarkerRegistered = false;
        await _ensureDirectionMarkerRegistered();
      }
    } catch (e) {
      debugPrint('Error updating map style: $e');
    }
  }

  Future<bool> _ensureDirectionMarkerRegistered() async {
    if (_mapboxMap == null) return false;
    if (_isDirectionMarkerRegistered) return true;

    try {
      final bytes = await rootBundle.load(_directionMarkerAssetPath);
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final decodedImage = frame.image;

      final rawData = await decodedImage.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );

      if (rawData == null) {
        return false;
      }

      final mbxImage = MbxImage(
        width: decodedImage.width,
        height: decodedImage.height,
        data: rawData.buffer.asUint8List(),
      );

      await _mapboxMap!.style.addStyleImage(
        _directionMarkerImageId,
        1.0,
        mbxImage,
        false,
        <ImageStretches?>[],
        <ImageStretches?>[],
        null,
      );

      _isDirectionMarkerRegistered = true;
      return true;
    } catch (e) {
      debugPrint('Error registering direction marker image: $e');
      return false;
    }
  }

  Future<Uint8List?> _getDirectionMarkerBytes() async {
    if (_directionMarkerBytes != null) {
      return _directionMarkerBytes;
    }

    try {
      final bytes = await rootBundle.load(_directionMarkerAssetPath);
      // Resize marker image so route markers render at a consistent 40x40 size.
      final codec = await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(),
        targetWidth: 40,
        targetHeight: 40,
      );
      final frame = await codec.getNextFrame();
      final resizedBytes = await frame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (resizedBytes == null) {
        return null;
      }

      _directionMarkerBytes = resizedBytes.buffer.asUint8List();
      return _directionMarkerBytes;
    } catch (e) {
      debugPrint('Error loading direction marker bytes: $e');
      return null;
    }
  }

  final List<String> _categories = [
    'All',
    'building',
    'facility',
    'parking',
    'dining',
    'library',
    'sports',
    'medical',
    'transport',
  ];

  List<String> get _locationCategories =>
      _categories.where((category) => category != 'All').toList();

  @override
  void initState() {
    super.initState();
    _initializeInitialEventDestination();
    _initializeAnimations();
    _loadCurrentUserRole();
    _loadFavoriteLocationIds();
    _loadLocations();
  }

  Future<void> _loadFavoriteLocationIds() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data();
      final rawPreferences = data?['preferences'];
      final preferences = rawPreferences is Map
          ? Map<String, dynamic>.from(rawPreferences)
          : <String, dynamic>{};
      final favorites = List<String>.from(
        preferences['favoriteLocations'] ?? const <String>[],
      );

      if (!mounted) return;
      setState(() {
        _favoriteLocationIds
          ..clear()
          ..addAll(favorites);
      });
    } catch (e) {
      debugPrint('Error loading favorite locations for map: $e');
    }
  }

  void _initializeInitialEventDestination() {
    final latitude = widget.initialEventLatitude;
    final longitude = widget.initialEventLongitude;

    if (latitude == null || longitude == null) return;

    final eventName = (widget.initialEventName ?? '').trim();
    final locationLabel = (widget.initialEventLocationLabel ?? '').trim();

    _initialEventDestination = CampusLocation(
      id: 'event-destination',
      name: eventName.isEmpty ? 'Event Destination' : eventName,
      description: eventName.isEmpty
          ? 'Event destination selected from event details.'
          : 'Destination for "$eventName"',
      category: 'building',
      address: locationLabel.isEmpty ? 'Event location' : locationLabel,
      latitude: latitude,
      longitude: longitude,
      isAddedByAdmin: true,
      additionalInfo: {'source': 'event'},
    );
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

  void _initializeAnimations() {
    _mapController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _mapAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _mapController, curve: Curves.easeOut));

    _contentController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _contentAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );

    // Start animations
    _mapController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _contentController.forward();
    });
  }

  Future<void> _loadLocations() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('locations')
          .orderBy('name')
          .get();

      setState(() {
        _locations = snapshot.docs
            .map((doc) => CampusLocation.fromFirestore(doc.data(), doc.id))
            .toList();
        _defaultStartLocation = _locations
            .where((location) => location.isDefaultStartPoint)
            .firstOrNull;
        _isLoading = false;
      });
      _syncMapAnnotations();

      if (_mapboxMap != null && _defaultStartLocation != null) {
        await _goToLocation(
          _defaultStartLocation!.latitude,
          _defaultStartLocation!.longitude,
        );
      }
    } catch (e) {
      debugPrint('Error loading locations: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _pointAnnotationManager = await _mapboxMap!.annotations
        .createPointAnnotationManager();
    _pointAnnotationManager!.addOnPointAnnotationClickListener(
      _annotationClickListener,
    );
    // Initialize polyline annotation manager for directions
    _polylineAnnotationManager = await _mapboxMap!.annotations
        .createPolylineAnnotationManager();
    await _ensureDirectionMarkerRegistered();
    _syncMapAnnotations();

    // If directions were requested while list view was active, render them now.
    if (_showDirections && _currentDirections != null) {
      await _drawRouteOnMap(_currentDirections!);
      await _fitCameraToRoute(_currentDirections!);
    }

    _startInitialEventNavigationIfNeeded();
  }

  Future<void> _startInitialEventNavigationIfNeeded() async {
    if (_initialEventNavigationTriggered) return;
    if (_initialEventDestination == null) return;
    if (_mapboxMap == null || _pointAnnotationManager == null) return;

    _initialEventNavigationTriggered = true;

    final destination = _initialEventDestination!;
    setState(() {
      _selectedDestination = destination;
      _showMapView = false;
    });

    await _goToLocation(destination.latitude, destination.longitude);
    await _getDirections(destination);
  }

  bool _handleAnnotationTap(PointAnnotation annotation) {
    final location = _annotationLocationById[annotation.id];
    if (location != null) {
      _showLocationDetails(location);
    }
    return true;
  }

  Future<void> _syncMapAnnotations() async {
    if (_pointAnnotationManager == null) return;

    await _pointAnnotationManager!.deleteAll();
    _annotationLocationById.clear();

    for (final location in _filteredLocations) {
      final markerColor = location.getCategoryColor().value;
      final annotation = await _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(location.longitude, location.latitude),
          ),
          iconImage: 'marker-15',
          iconSize: 1.3,
          iconColor: markerColor,
          textField: location.name,
          textOffset: [0.0, 1.4],
          textSize: 12.0,
          textColor: markerColor,
        ),
      );
      _annotationLocationById[annotation.id] = location;
    }
  }

  void _updateSearchQuery(String value) {
    setState(() {
      _searchQuery = value;
    });
    _syncMapAnnotations();
  }

  void _updateCategory(String category, CampusCategory? categoryObj) {
    setState(() {
      _selectedCategory = category;
      _selectedCategoryObj = categoryObj;
    });
    _syncMapAnnotations();
  }

  Future<void> _showEnableLocationDialog() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Location is off'),
        content: const Text(
          'Turn on location services to get your current position on the map.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await geo.Geolocator.openLocationSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _goToCurrentLocation() async {
    if (_isGettingCurrentLocation) return;

    try {
      setState(() {
        _isGettingCurrentLocation = true;
      });

      final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _showEnableLocationDialog();
        return;
      }

      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }

      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is required.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );

      await _goToLocation(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('Error getting current location: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not get current location.'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGettingCurrentLocation = false;
        });
      }
    }
  }

  Future<void> _deleteLocation(String locationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('locations')
          .doc(locationId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete location: $e')),
        );
      }
    }
  }

  Future<bool> _addToFavorites(CampusLocation location) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to save favorites.'),
          backgroundColor: AppColors.error,
        ),
      );
      return false;
    }

    try {
      if (_favoriteLocationIds.contains(location.id)) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${location.name} is already in favorites.'),
            backgroundColor: AppColors.primary,
          ),
        );
        return true;
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {
          'preferences.favoriteLocations': FieldValue.arrayUnion([location.id]),
          'updatedAt': DateTime.now(),
        },
      );

      if (mounted) {
        setState(() {
          _favoriteLocationIds.add(location.id);
        });
      }

      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${location.name} added to favorites.'),
          backgroundColor: Colors.green,
        ),
      );
      return true;
    } catch (e) {
      debugPrint('Error adding favorite location: $e');
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not add location to favorites.'),
          backgroundColor: AppColors.error,
        ),
      );
      return false;
    }
  }

  Future<bool> _removeFromFavorites(CampusLocation location) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to manage favorites.'),
          backgroundColor: AppColors.error,
        ),
      );
      return false;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {
          'preferences.favoriteLocations': FieldValue.arrayRemove([
            location.id,
          ]),
          'updatedAt': DateTime.now(),
        },
      );

      if (mounted) {
        setState(() {
          _favoriteLocationIds.remove(location.id);
        });
      }

      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${location.name} removed from favorites.'),
          backgroundColor: AppColors.primary,
        ),
      );
      return true;
    } catch (e) {
      debugPrint('Error removing favorite location: $e');
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not remove location from favorites.'),
          backgroundColor: AppColors.error,
        ),
      );
      return false;
    }
  }

  void _showDeleteLocationConfirmation(String locationId, String locationName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Location'),
        content: Text('Are you sure you want to delete "$locationName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteLocation(locationId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _goToLocation(double latitude, double longitude) async {
    if (_mapboxMap == null) return;

    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(longitude, latitude)),
        zoom: 15.5,
      ),
      MapAnimationOptions(duration: 1000),
    );
  }

  Future<void> _addLocationAtCenter() async {
    if (!_isAdmin) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only admins can add locations.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_mapboxMap == null) return;

    final cameraState = await _mapboxMap!.getCameraState();
    final center = cameraState.center;

    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final addressController = TextEditingController();
    String selectedCategory = _locationCategories.first;
    bool isDefaultStartPoint = false;
    bool isSubmitting = false;

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppDimensions.spacingXl,
                right: AppDimensions.spacingXl,
                top: AppDimensions.spacingXl,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom +
                    AppDimensions.spacingXl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Location',
                    style: TextStyle(
                      fontSize: AppDimensions.fontSizeXxl,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: 'Address'),
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    items: _locationCategories
                        .map(
                          (category) => DropdownMenuItem(
                            value: category,
                            child: Text(category.capitalize()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      selectedCategory = value;
                    },
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isDefaultStartPoint,
                    onChanged: (value) {
                      setSheetState(() {
                        isDefaultStartPoint = value ?? false;
                      });
                    },
                    title: const Text('Set as Main Gate / Default Start Point'),
                    subtitle: const Text(
                      'This location will open as the default campus starting point.',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: AppDimensions.spacingLg),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacingMd),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  setSheetState(() => isSubmitting = true);
                                  if (nameController.text.trim().isEmpty ||
                                      addressController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Name and address are required.',
                                        ),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                    setSheetState(() => isSubmitting = false);
                                    return;
                                  }

                                  try {
                                    final locationRef = FirebaseFirestore
                                        .instance
                                        .collection('locations')
                                        .doc();

                                    final location = CampusLocation(
                                      id: locationRef.id,
                                      name: nameController.text.trim(),
                                      description: descriptionController.text
                                          .trim(),
                                      category: selectedCategory,
                                      address: addressController.text.trim(),
                                      latitude: center.coordinates.lat
                                          .toDouble(),
                                      longitude: center.coordinates.lng
                                          .toDouble(),
                                      isDefaultStartPoint: isDefaultStartPoint,
                                      isAddedByAdmin:
                                          true, // Mark locations added by admins
                                    );

                                    final batch = FirebaseFirestore.instance
                                        .batch();

                                    if (isDefaultStartPoint) {
                                      final previousDefaultSnapshot =
                                          await FirebaseFirestore.instance
                                              .collection('locations')
                                              .where(
                                                'isDefaultStartPoint',
                                                isEqualTo: true,
                                              )
                                              .get();

                                      for (final doc
                                          in previousDefaultSnapshot.docs) {
                                        batch.update(doc.reference, {
                                          'isDefaultStartPoint': false,
                                          'updatedAt': DateTime.now(),
                                        });
                                      }
                                    }

                                    batch.set(
                                      locationRef,
                                      location.toFirestore(),
                                    );
                                    await batch.commit();

                                    if (!mounted) return;
                                    Navigator.of(context).pop();
                                    await _loadLocations();
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Location added successfully.',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        this.context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to add location: $e',
                                          ),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (mounted) {
                                      setSheetState(() => isSubmitting = false);
                                    }
                                  }
                                },
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _getDirections(CampusLocation destination) async {
    try {
      setState(() {
        _isCalculatingDirections = true;
      });

      if (_showMapView) {
        // Directions must be displayed on map view, not list view.
        setState(() {
          _showMapView = false;
        });
      }

      final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable location services to get directions.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }

      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is required for directions.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      // Get user's current location
      _userLocation = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );

      if (_userLocation == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not get your location'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      // Get directions from Mapbox API
      DirectionsResponse? directions = await DirectionsService.getDirections(
        startLat: _userLocation!.latitude,
        startLng: _userLocation!.longitude,
        destLat: destination.latitude,
        destLng: destination.longitude,
        mode: _transportMode,
      );

      var effectiveMode = _transportMode;
      if (directions == null) {
        final fallbackModes = TransportMode.values
            .where((mode) => mode != _transportMode)
            .toList();

        for (final fallbackMode in fallbackModes) {
          final fallbackDirections = await DirectionsService.getDirections(
            startLat: _userLocation!.latitude,
            startLng: _userLocation!.longitude,
            destLat: destination.latitude,
            destLng: destination.longitude,
            mode: fallbackMode,
          );

          if (fallbackDirections != null) {
            directions = fallbackDirections;
            effectiveMode = fallbackMode;
            break;
          }
        }
      }

      if (directions == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not find route'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final usedFallbackMode = effectiveMode != _transportMode;

      setState(() {
        _currentDirections = directions;
        _showDirections = true;
        _selectedDestination = destination;
        _transportMode = effectiveMode;
      });

      if (usedFallbackMode && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No route in selected mode. Showing ${effectiveMode.displayName.toLowerCase()} route instead.',
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      }

      // Draw polyline and markers
      await _drawRouteOnMap(directions);

      // Move camera to show route
      await _fitCameraToRoute(directions);
    } catch (e) {
      debugPrint('Error getting directions: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCalculatingDirections = false;
        });
      }
    }
  }

  Future<void> _drawRouteOnMap(DirectionsResponse directions) async {
    if (_polylineAnnotationManager == null) return;

    final markerBytes = await _getDirectionMarkerBytes();
    final hasCustomMarker = markerBytes != null;

    // Clear existing polylines
    await _polylineAnnotationManager!.deleteAll();
    _directionMarkers.clear();

    // Convert route points to list of positions
    final positions = directions.route
        .map((latLng) => Position(latLng.longitude, latLng.latitude))
        .toList();

    // Draw polyline
    if (positions.isNotEmpty) {
      final lineString = LineString(coordinates: positions);
      await _polylineAnnotationManager!.create(
        PolylineAnnotationOptions(
          geometry: lineString,
          lineColor: AppColors.primary.value,
          lineWidth: 5.0,
          lineOpacity: 0.8,
        ),
      );
    }

    // Add start marker (user location)
    if (_userLocation != null) {
      final startMarker = await _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              _userLocation!.longitude,
              _userLocation!.latitude,
            ),
          ),
          image: markerBytes,
          iconImage: hasCustomMarker ? null : 'marker-15',
          iconSize: hasCustomMarker ? 1.0 : 2.2,
          iconColor: Colors.red.value,
          textField: 'My Location',
          textAnchor: TextAnchor.TOP,
          textOffset: [0.0, 1.6],
          textSize: 12.0,
          textColor: Colors.red.value,
        ),
      );
      _directionMarkers.add(startMarker);
    }

    // Add destination marker
    if (_selectedDestination != null) {
      final destMarker = await _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              _selectedDestination!.longitude,
              _selectedDestination!.latitude,
            ),
          ),
          image: markerBytes,
          iconImage: hasCustomMarker ? null : 'marker-15',
          iconSize: hasCustomMarker ? 1.0 : 2.2,
          iconColor: Colors.red.value,
          textField: _selectedDestination!.name,
          textAnchor: TextAnchor.TOP,
          textOffset: [0.0, 1.6],
          textSize: 12.0,
          textColor: Colors.red.value,
        ),
      );
      _directionMarkers.add(destMarker);
    }
  }

  Future<void> _fitCameraToRoute(DirectionsResponse directions) async {
    if (_mapboxMap == null || directions.route.isEmpty) return;

    // Calculate bounding box of route
    double minLat = directions.route[0].latitude;
    double maxLat = directions.route[0].latitude;
    double minLng = directions.route[0].longitude;
    double maxLng = directions.route[0].longitude;

    for (final point in directions.route) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    // Fly to bounding box with padding
    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;
    final distance = math.sqrt(
      math.pow(maxLat - minLat, 2) + math.pow(maxLng - minLng, 2),
    );

    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(centerLng, centerLat)),
        zoom: 15 - (distance * 50),
      ),
      MapAnimationOptions(duration: 1000),
    );
  }

  void _clearDirections() {
    setState(() {
      _currentDirections = null;
      _showDirections = false;
      _selectedDestination = null;
      _userLocation = null;
    });
    _directionMarkers.clear();
  }

  Future<void> _changeTransportMode(TransportMode mode) async {
    setState(() => _transportMode = mode);

    if (_selectedDestination != null && _userLocation != null) {
      final directions = await DirectionsService.getDirections(
        startLat: _userLocation!.latitude,
        startLng: _userLocation!.longitude,
        destLat: _selectedDestination!.latitude,
        destLng: _selectedDestination!.longitude,
        mode: mode,
      );

      if (directions != null) {
        setState(() => _currentDirections = directions);
        _drawRouteOnMap(directions);
        _fitCameraToRoute(directions);
      }
    }
  }

  List<CampusLocation> get _filteredLocations {
    return _locations.where((location) {
      final matchesSearch =
          location.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          location.description.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          location.address.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory =
          _selectedCategory == 'All' || location.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Campus Navigation',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 0,
        foregroundColor: Colors.grey[800],
        iconTheme: IconThemeData(color: Colors.grey[800]),
        actions: [
          IconButton(
            icon: Icon(_showMapView ? Icons.list : Icons.map),
            onPressed: () => setState(() => _showMapView = !_showMapView),
            tooltip: _showMapView ? 'List View' : 'Map View',
          ),
        ],
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
        child: _showMapView ? _buildListView() : _buildMapView(),
      ),
    );
  }

  Widget _buildListView() {
    return Column(
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
                          onChanged: _updateSearchQuery,
                          decoration: InputDecoration(
                            hintText: 'Search locations...',
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
                            final categoryObj = CampusCategory.defaultCategories
                                .where((cat) => cat.id == category)
                                .firstOrNull;

                            return Padding(
                              padding: const EdgeInsets.only(
                                right: AppDimensions.spacingSm,
                              ),
                              child: FilterChip(
                                label: Text(
                                  category == 'All'
                                      ? 'All Locations'
                                      : (categoryObj?.name ??
                                            category.capitalize()),
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                selected: isSelected,
                                onSelected: (selected) {
                                  _updateCategory(category, categoryObj);
                                },
                                backgroundColor: Colors.white,
                                selectedColor: AppColors.primary,
                                checkmarkColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusMd,
                                  ),
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

        // Locations List
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
                      : _filteredLocations.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.location_off,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: AppDimensions.spacingMd),
                              Text(
                                _searchQuery.isEmpty &&
                                        _selectedCategory == 'All'
                                    ? 'No locations found'
                                    : 'No locations match your search',
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
                          onRefresh: _loadLocations,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(
                              AppDimensions.spacingLg,
                            ),
                            itemCount: _filteredLocations.length,
                            itemBuilder: (context, index) {
                              final location = _filteredLocations[index];
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppDimensions.spacingMd,
                                ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    LocationCard(
                                      location: location,
                                      onTap: () =>
                                          _showLocationDetails(location),
                                    ),
                                    if (location.isDefaultStartPoint)
                                      Positioned(
                                        top: -8,
                                        right: 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.secondary,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: const Text(
                                            'Main Gate',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (location.isAddedByAdmin)
                                      Positioned(
                                        top: -8,
                                        right: location.isDefaultStartPoint
                                            ? 90
                                            : 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: const Text(
                                            'Admin',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (_isAdmin)
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkResponse(
                                            onTap: () =>
                                                _showDeleteLocationConfirmation(
                                                  location.id,
                                                  location.name,
                                                ),
                                            radius: 24,
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.red.withOpacity(
                                                  0.95,
                                                ),
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.12),
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
                          ),
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMapView() {
    final defaultCenter = Position(-122.4194, 37.7749);
    final locationCenter = _defaultStartLocation != null
        ? Position(
            _defaultStartLocation!.longitude,
            _defaultStartLocation!.latitude,
          )
        : _filteredLocations.isNotEmpty
        ? Position(
            _filteredLocations.first.longitude,
            _filteredLocations.first.latitude,
          )
        : defaultCenter;

    return AnimatedBuilder(
      animation: _mapAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _mapAnimation.value,
          child: Stack(
            children: [
              // Map Placeholder
              Container(
                margin: const EdgeInsets.all(AppDimensions.spacingLg),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.9),
                      Colors.white.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                  child: Stack(
                    children: [
                      MapWidget(
                        key: ValueKey('mapbox-map-${_mapStyleMode}'),
                        onMapCreated: _onMapCreated,
                        cameraOptions: CameraOptions(
                          center: Point(coordinates: locationCenter),
                          zoom: 13.5,
                        ),
                        styleUri: _getMapStyle(),
                      ),

                      // Fixed center pointer for admin add-location flow.
                      if (!_showDirections && !_isCalculatingDirections)
                        Center(
                          child: Icon(
                            Icons.add_location_alt,
                            color: AppColors.secondary,
                            size: 36,
                          ),
                        ),

                      // Map Legend
                      Positioned(
                        bottom: AppDimensions.spacingLg,
                        left: AppDimensions.spacingLg,
                        child: Container(
                          padding: const EdgeInsets.all(
                            AppDimensions.spacingMd,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusMd,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: 1,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: CampusCategory.defaultCategories
                                .take(4)
                                .map((category) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: category.color,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          category.name,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                })
                                .toList(),
                          ),
                        ),
                      ),

                      // Map Title
                      Positioned(
                        top: AppDimensions.spacingLg,
                        left: AppDimensions.spacingLg,
                        right: AppDimensions.spacingLg,
                        child: Container(
                          padding: const EdgeInsets.all(
                            AppDimensions.spacingMd,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusMd,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: 1,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.map,
                                color: AppColors.primary,
                                size: 24,
                              ),
                              const SizedBox(width: AppDimensions.spacingMd),
                              Expanded(
                                child: Text(
                                  'Campus Map',
                                  style: TextStyle(
                                    fontSize: AppDimensions.fontSizeLg,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ),
                              Text(
                                '${_filteredLocations.length} locations',
                                style: TextStyle(
                                  fontSize: AppDimensions.fontSizeSm,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // View mode toggle buttons
                      Positioned(
                        top: AppDimensions.spacingLg,
                        right: AppDimensions.spacingLg,
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusMd,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  _buildMapStyleButton('Street', 'street'),
                                  Divider(height: 1, color: Colors.grey[300]),
                                  _buildMapStyleButton(
                                    'Satellite',
                                    'satellite',
                                  ),
                                  Divider(height: 1, color: Colors.grey[300]),
                                  _buildMapStyleButton('Terrain', 'terrain'),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spacingMd),
                            Container(
                              decoration: BoxDecoration(
                                color: _showMapView
                                    ? AppColors.primary
                                    : Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusMd,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => setState(
                                    () => _showMapView = !_showMapView,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusMd,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Icon(
                                      Icons.list,
                                      color: _showMapView
                                          ? Colors.white
                                          : AppColors.primary,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_isCalculatingDirections)
                Positioned.fill(
                  child: Container(
                    margin: const EdgeInsets.all(AppDimensions.spacingLg),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.28),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusXl,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.spacingLg,
                          vertical: AppDimensions.spacingMd,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusLg,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: AppDimensions.spacingMd),
                            Text(
                              'Calculating route...',
                              style: TextStyle(
                                fontSize: AppDimensions.fontSizeSm,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Locations List Panel (Right side)
              if (_showLocationsList)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 280,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 15,
                          offset: const Offset(-4, 0),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(
                            AppDimensions.spacingMd,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            border: Border(
                              bottom: BorderSide(
                                color: AppColors.primary.withOpacity(0.2),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Locations',
                                      style: TextStyle(
                                        fontSize: AppDimensions.fontSizeMd,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    Text(
                                      '${_filteredLocations.length} found',
                                      style: TextStyle(
                                        fontSize: AppDimensions.fontSizeXs,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    setState(() => _showLocationsList = false),
                                iconSize: 20,
                              ),
                            ],
                          ),
                        ),
                        // Locations List
                        Expanded(
                          child: _filteredLocations.isEmpty
                              ? Center(
                                  child: Text(
                                    'No locations found',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: AppDimensions.fontSizeSm,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _filteredLocations.length,
                                  itemBuilder: (context, index) {
                                    final location = _filteredLocations[index];
                                    return Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () =>
                                            _showLocationDetails(location),
                                        child: Container(
                                          padding: const EdgeInsets.all(
                                            AppDimensions.spacingMd,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: Colors.grey[200]!,
                                              ),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: BoxDecoration(
                                                      color: location
                                                          .getCategoryColor(),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      location.name,
                                                      style: TextStyle(
                                                        fontSize: AppDimensions
                                                            .fontSizeSm,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.grey[800],
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                location.address ??
                                                    location.description ??
                                                    '',
                                                style: TextStyle(
                                                  fontSize:
                                                      AppDimensions.fontSizeXs,
                                                  color: Colors.grey[600],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
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
                ),

              // Toggle Locations Panel Button
              Positioned(
                right: _showLocationsList ? 290 : AppDimensions.spacingLg,
                bottom: AppDimensions.spacingLg,
                child: Material(
                  color: Colors.transparent,
                  child: InkResponse(
                    onTap: () => setState(
                      () => _showLocationsList = !_showLocationsList,
                    ),
                    radius: 24,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        _showLocationsList
                            ? Icons.chevron_right
                            : Icons.location_on,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),

              // Current Location Button
              Positioned(
                bottom: AppDimensions.spacingXl,
                right: AppDimensions.spacingXl,
                child: FloatingActionButton.extended(
                  heroTag: 'current-location',
                  onPressed: _isGettingCurrentLocation
                      ? null
                      : _goToCurrentLocation,
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  icon: _isGettingCurrentLocation
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.my_location),
                  label: Text(
                    _isGettingCurrentLocation ? 'Locating...' : 'My Location',
                  ),
                ),
              ),

              // Admin Add Location Button
              if (_isAdmin)
                Positioned(
                  bottom: AppDimensions.spacingXl,
                  left: AppDimensions.spacingXl,
                  child: FloatingActionButton.extended(
                    heroTag: 'add-location',
                    onPressed: _addLocationAtCenter,
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.add_location),
                    label: const Text('Add Location'),
                  ),
                ),

              // Directions Info Panel
              if (_showDirections && _currentDirections != null)
                Positioned(
                  bottom: AppDimensions.spacingXl,
                  left: AppDimensions.spacingLg,
                  right: AppDimensions.spacingLg,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusXl,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 15,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header with destination
                        Padding(
                          padding: const EdgeInsets.all(
                            AppDimensions.spacingMd,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: AppColors.primary,
                                size: 24,
                              ),
                              const SizedBox(width: AppDimensions.spacingMd),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Navigating to',
                                      style: TextStyle(
                                        fontSize: AppDimensions.fontSizeSm,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      _selectedDestination?.name ??
                                          'Destination',
                                      style: TextStyle(
                                        fontSize: AppDimensions.fontSizeMd,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: _clearDirections,
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: Colors.grey[200]),
                        // Route info and transport mode
                        Padding(
                          padding: const EdgeInsets.all(
                            AppDimensions.spacingMd,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Distance and Time
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Distance',
                                          style: TextStyle(
                                            fontSize: AppDimensions.fontSizeXs,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          _currentDirections!.formattedDistance,
                                          style: TextStyle(
                                            fontSize: AppDimensions.fontSizeLg,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Estimated Time',
                                          style: TextStyle(
                                            fontSize: AppDimensions.fontSizeXs,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          _currentDirections!.formattedDuration,
                                          style: TextStyle(
                                            fontSize: AppDimensions.fontSizeLg,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppDimensions.spacingMd),
                              // Transport mode toggle
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusMd,
                                  ),
                                ),
                                child: Row(
                                  children: TransportMode.values.map((mode) {
                                    final isSelected = _transportMode == mode;
                                    return Expanded(
                                      child: GestureDetector(
                                        onTap: () => _changeTransportMode(mode),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: AppDimensions.spacingSm,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? AppColors.primary
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              AppDimensions.radiusMd,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                mode == TransportMode.driving
                                                    ? Icons.directions_car
                                                    : mode ==
                                                          TransportMode.cycling
                                                    ? Icons.directions_bike
                                                    : Icons.directions_walk,
                                                color: isSelected
                                                    ? Colors.white
                                                    : Colors.grey[700],
                                                size: 18,
                                              ),
                                              const SizedBox(
                                                width: AppDimensions.spacingSm,
                                              ),
                                              Text(
                                                mode.displayName,
                                                style: TextStyle(
                                                  fontSize:
                                                      AppDimensions.fontSizeSm,
                                                  fontWeight: FontWeight.w600,
                                                  color: isSelected
                                                      ? Colors.white
                                                      : Colors.grey[700],
                                                ),
                                              ),
                                            ],
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
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showLocationDetails(CampusLocation location) {
    bool isFavorite = _favoriteLocationIds.contains(location.id);
    bool isFavoriteActionInProgress = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              minChildSize: 0.4,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white, Colors.white.withOpacity(0.95)],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppDimensions.radiusXl),
                    ),
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(AppDimensions.spacingXl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(
                                AppDimensions.spacingMd,
                              ),
                              decoration: BoxDecoration(
                                color: location.getCategoryColor().withOpacity(
                                  0.1,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusMd,
                                ),
                              ),
                              child: Icon(
                                location.getCategoryIcon(),
                                color: location.getCategoryColor(),
                                size: AppDimensions.iconLg,
                              ),
                            ),
                            const SizedBox(width: AppDimensions.spacingMd),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    location.name,
                                    style: TextStyle(
                                      fontSize: AppDimensions.fontSizeXxl,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  Text(
                                    location.category.capitalize(),
                                    style: TextStyle(
                                      fontSize: AppDimensions.fontSizeMd,
                                      color: location.getCategoryColor(),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (location.isDefaultStartPoint)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.secondary
                                              .withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          'Main Gate / Start Point',
                                          style: TextStyle(
                                            color: AppColors.secondary,
                                            fontSize: AppDimensions.fontSizeXs,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (location.isAddedByAdmin)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(
                                            0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          'Added by Admin',
                                          style: TextStyle(
                                            color: Colors.orange[700],
                                            fontSize: AppDimensions.fontSizeXs,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: AppDimensions.spacingLg),

                        // Address
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Colors.grey[600],
                              size: AppDimensions.iconMd,
                            ),
                            const SizedBox(width: AppDimensions.spacingSm),
                            Expanded(
                              child: Text(
                                location.address,
                                style: TextStyle(
                                  fontSize: AppDimensions.fontSizeMd,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (location.isDefaultStartPoint) ...[
                          const SizedBox(height: AppDimensions.spacingMd),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(
                              AppDimensions.spacingMd,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusMd,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.flag,
                                  color: AppColors.secondary,
                                  size: AppDimensions.iconMd,
                                ),
                                const SizedBox(width: AppDimensions.spacingSm),
                                Expanded(
                                  child: Text(
                                    'This is the main gate and default starting point for the campus map.',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: AppDimensions.spacingMd),

                        // Description
                        Text(
                          location.description,
                          style: TextStyle(
                            fontSize: AppDimensions.fontSizeMd,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: AppDimensions.spacingLg),

                        // Additional Info
                        if (location.additionalInfo.isNotEmpty) ...[
                          Text(
                            'Additional Information',
                            style: TextStyle(
                              fontSize: AppDimensions.fontSizeLg,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacingMd),
                          ...location.additionalInfo.entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppDimensions.spacingSm,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 100,
                                    child: Text(
                                      '${entry.key.capitalize()}:',
                                      style: TextStyle(
                                        fontSize: AppDimensions.fontSizeSm,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      entry.value.toString(),
                                      style: TextStyle(
                                        fontSize: AppDimensions.fontSizeSm,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],

                        const SizedBox(height: AppDimensions.spacingXxl),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _getDirections(location);
                                },
                                icon: const Icon(Icons.directions),
                                label: const Text('Get Directions'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppDimensions.spacingMd,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppDimensions.spacingMd),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: isFavoriteActionInProgress
                                    ? null
                                    : () async {
                                        setModalState(() {
                                          isFavoriteActionInProgress = true;
                                        });

                                        final success = isFavorite
                                            ? await _removeFromFavorites(
                                                location,
                                              )
                                            : await _addToFavorites(location);

                                        if (success) {
                                          setModalState(() {
                                            isFavorite = !isFavorite;
                                          });
                                        }

                                        setModalState(() {
                                          isFavoriteActionInProgress = false;
                                        });
                                      },
                                icon: isFavoriteActionInProgress
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        isFavorite
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                      ),
                                label: Text(
                                  isFavorite
                                      ? 'Remove Favorite'
                                      : 'Add to Favorites',
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: isFavorite
                                        ? AppColors.error
                                        : AppColors.primary,
                                  ),
                                  foregroundColor: isFavorite
                                      ? AppColors.error
                                      : AppColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppDimensions.spacingMd,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMapStyleButton(String label, String style) {
    final isSelected = _mapStyleMode == style;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _mapStyleMode = style;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.primary : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

class _PointTapListener extends OnPointAnnotationClickListener {
  final bool Function(PointAnnotation) _handler;

  _PointTapListener(this._handler);

  @override
  bool onPointAnnotationClick(PointAnnotation annotation) {
    return _handler(annotation);
  }
}
