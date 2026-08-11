import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide ImageSource;
import 'package:image_picker/image_picker.dart' as image_picker;
import '../models/lost_found_item_model.dart';
import '../models/campus_location_model.dart';
import '../models/user_model.dart';
import '../services/lost_found_service.dart';
import '../services/cloudinary_service.dart';
import '../utils/theme_manager.dart';

class ReportFoundItemScreen extends StatefulWidget {
  const ReportFoundItemScreen({super.key});

  @override
  State<ReportFoundItemScreen> createState() => _ReportFoundItemScreenState();
}

class _ReportFoundItemScreenState extends State<ReportFoundItemScreen>
    with TickerProviderStateMixin {
  late AnimationController _contentController;
  late Animation<double> _contentFade;
  late Animation<double> _contentSlide;

  final _formKey = GlobalKey<FormState>();
  final _itemNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _customLocationController = TextEditingController();
  final _contactController = TextEditingController();

  String _selectedCategory = LostFoundCategory.electronics;
  DateTime _foundDate = DateTime.now();
  bool _isSubmitting = false;
  UserModel? _currentUser;

  // Location selection
  List<CampusLocation> _campusLocations = [];
  bool _isLoadingLocations = true;
  CampusLocation? _selectedLocation;
  // 'dropdown', 'map', 'custom'
  String _locationMode = 'dropdown';
  // For map pin
  double? _pinnedLat;
  double? _pinnedLng;
  MapboxMap? _mapboxMap;
  // Image
  File? _selectedImage;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadCurrentUser();
    _loadLocations();
  }

  void _initAnimations() {
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 800), vsync: this,
    );
    _contentFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );
    _contentSlide = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOutBack),
    );
    Future.delayed(const Duration(milliseconds: 200), () {
      _contentController.forward();
    });
  }

  Future<void> _loadCurrentUser() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(firebaseUser.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _currentUser = UserModel.fromFirestore(doc.data()!, firebaseUser.uid);
        });
      }
    } catch (e) {
      debugPrint('Error loading current user: $e');
    }
  }

  Future<void> _loadLocations() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('locations').orderBy('name').get();
      if (mounted) {
        setState(() {
          _campusLocations = snapshot.docs
              .map((doc) => CampusLocation.fromFirestore(doc.data(), doc.id))
              .toList();
          _isLoadingLocations = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading locations: $e');
      if (mounted) setState(() => _isLoadingLocations = false);
    }
  }

  String get _resolvedLocation {
    switch (_locationMode) {
      case 'dropdown':
        return _selectedLocation?.name ?? '';
      case 'map':
        if (_pinnedLat != null && _pinnedLng != null) {
          return 'Pinned Location (${_pinnedLat!.toStringAsFixed(5)}, ${_pinnedLng!.toStringAsFixed(5)})';
        }
        return '';
      case 'custom':
        return _customLocationController.text.trim();
      default:
        return '';
    }
  }

  Future<void> _submitItem() async {
    if (!_formKey.currentState!.validate()) return;

    final location = _resolvedLocation;
    if (location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or enter a location'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to submit a report'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Upload image to Cloudinary if selected
      String? imageUrl;
      if (_selectedImage != null) {
        setState(() => _isUploadingImage = true);
        debugPrint('Starting Cloudinary upload for: ${_selectedImage!.path}');
        imageUrl = await CloudinaryService().uploadImage(
          _selectedImage!,
          folder: 'lost_found',
        );
        setState(() => _isUploadingImage = false);

        if (imageUrl == null && mounted) {
          // Show dialog letting user choose: retry, skip, or cancel
          final action = await showDialog<String>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.cloud_off, color: Colors.orange[700]),
                  const SizedBox(width: 10),
                  const Text('Image Upload Failed',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              content: const Text(
                'The photo could not be uploaded to the server. '
                'This may be due to a network issue.\n\n'
                'What would you like to do?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop('cancel'),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop('skip'),
                  child: const Text('Submit Without Photo'),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(ctx).pop('retry'),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry Upload'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );

          if (action == 'cancel' || action == null) {
            setState(() => _isSubmitting = false);
            return;
          }

          if (action == 'retry') {
            // Retry the upload once more
            setState(() => _isUploadingImage = true);
            imageUrl = await CloudinaryService().uploadImage(
              _selectedImage!,
              folder: 'lost_found',
            );
            setState(() => _isUploadingImage = false);

            if (imageUrl == null && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Upload failed again. Submitting without image.'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
          // action == 'skip' → continue with imageUrl = null
        }
      }

      final item = LostFoundItem(
        id: '',
        itemName: _itemNameController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        foundLocation: location,
        foundDate: _foundDate,
        finderUserId: _currentUser!.uid,
        finderName: _currentUser!.fullName,
        finderContact: _contactController.text.trim().isEmpty
            ? null : _contactController.text.trim(),
        imageUrl: imageUrl,
        status: LostFoundStatus.pending,
      );

      await LostFoundService().submitFoundItem(item);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(imageUrl != null
                ? 'Item submitted successfully with photo! It will be visible after admin approval.'
                : 'Item submitted successfully! It will be visible after admin approval.'),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error submitting item: $e');
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _foundDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _foundDate = picked);
  }

  @override
  void dispose() {
    _contentController.dispose();
    _itemNameController.dispose();
    _descriptionController.dispose();
    _customLocationController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Found Item',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        elevation: 0,
        foregroundColor: Colors.grey[800],
        iconTheme: IconThemeData(color: Colors.grey[800]),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [const Color(0xFFE3F2FD), const Color(0xFFF8F9FA), Colors.white],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: AnimatedBuilder(
          animation: _contentController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _contentSlide.value),
              child: Opacity(
                opacity: _contentFade.value,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppDimensions.spacingXl),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: AppDimensions.spacingXl),

                        // Item Name
                        _buildLabel('Item Name *'),
                        const SizedBox(height: AppDimensions.spacingSm),
                        _buildTextField(
                          controller: _itemNameController,
                          hint: 'e.g., iPhone 15, Blue Backpack, Student ID',
                          icon: Icons.inventory_2_outlined,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter the item name' : null,
                        ),
                        const SizedBox(height: AppDimensions.spacingLg),

                        // Category
                        _buildLabel('Category *'),
                        const SizedBox(height: AppDimensions.spacingSm),
                        _buildCategoryDropdown(),
                        const SizedBox(height: AppDimensions.spacingLg),

                        // Description
                        _buildLabel('Description *'),
                        const SizedBox(height: AppDimensions.spacingSm),
                        _buildTextField(
                          controller: _descriptionController,
                          hint: 'Describe the item (color, brand, distinguishing features...)',
                          icon: Icons.description_outlined,
                          maxLines: 4,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please describe the item' : null,
                        ),
                        const SizedBox(height: AppDimensions.spacingLg),

                        // Item Photo
                        _buildLabel('Item Photo (optional)'),
                        const SizedBox(height: AppDimensions.spacingSm),
                        _buildImagePicker(),
                        const SizedBox(height: AppDimensions.spacingLg),

                        // Location Section
                        _buildLabel('Where did you find it? *'),
                        const SizedBox(height: AppDimensions.spacingSm),
                        _buildLocationSection(),
                        const SizedBox(height: AppDimensions.spacingLg),

                        // Date Found
                        _buildLabel('Date Found *'),
                        const SizedBox(height: AppDimensions.spacingSm),
                        _buildDatePicker(),
                        const SizedBox(height: AppDimensions.spacingLg),

                        // Contact Info
                        _buildLabel('Your Contact Info (optional)'),
                        const SizedBox(height: AppDimensions.spacingSm),
                        _buildTextField(
                          controller: _contactController,
                          hint: 'Phone number or email for the owner to reach you',
                          icon: Icons.phone_outlined,
                        ),
                        const SizedBox(height: AppDimensions.spacingXxl),

                        // Submit
                        _buildSubmitButton(),
                        const SizedBox(height: AppDimensions.spacingXl),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── Image Picker ───
  Future<void> _pickImage(image_picker.ImageSource source) async {
    try {
      final picker = image_picker.ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (picked != null) {
        setState(() => _selectedImage = File(picked.path));
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not access camera/gallery'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildImagePicker() {
    if (_selectedImage != null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            child: Image.file(_selectedImage!, width: double.infinity, height: 200, fit: BoxFit.cover),
          ),
          Positioned(top: 8, right: 8, child: GestureDetector(
            onTap: () => setState(() => _selectedImage = null),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black54, shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          )),
          if (_isUploadingImage)
            Positioned.fill(child: Container(
              color: Colors.black38,
              child: const Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  SizedBox(height: 8),
                  Text('Uploading...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              )),
            )),
        ]),
      );
    }

    return Row(children: [
      Expanded(child: _imageOptionButton(Icons.camera_alt_rounded, 'Camera', () => _pickImage(image_picker.ImageSource.camera))),
      const SizedBox(width: 10),
      Expanded(child: _imageOptionButton(Icons.photo_library_rounded, 'Gallery', () => _pickImage(image_picker.ImageSource.gallery))),
    ]);
  }

  Widget _imageOptionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 28, color: AppColors.primary),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
        ]),
      ),
    );
  }

  // ─── Header Card ───
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingLg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: 0.9), Colors.white.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.1), blurRadius: 20, spreadRadius: 2, offset: const Offset(0, 6))],
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.15), AppColors.primary.withValues(alpha: 0.08)]),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          child: Icon(Icons.add_circle_outline, color: AppColors.primary, size: 28),
        ),
        const SizedBox(width: AppDimensions.spacingMd),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Found Something?', style: TextStyle(fontSize: AppDimensions.fontSizeXl, fontWeight: FontWeight.w800, color: Colors.grey[800])),
          const SizedBox(height: 4),
          Text('Fill in the details below. Your report will be reviewed by an admin before being published.',
            style: TextStyle(fontSize: AppDimensions.fontSizeSm, color: Colors.grey[600])),
        ])),
      ]),
    );
  }

  // ─── Category Dropdown ───
  Widget _buildCategoryDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedCategory,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd, vertical: AppDimensions.spacingSm),
        ),
        items: LostFoundCategory.all.map((cat) {
          return DropdownMenuItem(value: cat, child: Row(children: [
            Icon(LostFoundCategory.icon(cat), size: 20, color: LostFoundCategory.color(cat)),
            const SizedBox(width: 10),
            Text(LostFoundCategory.displayName(cat)),
          ]));
        }).toList(),
        onChanged: (v) { if (v != null) setState(() => _selectedCategory = v); },
      ),
    );
  }

  // ─── Location Section (dropdown / map / custom) ───
  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mode selector chips
        Row(children: [
          _buildModeChip('dropdown', Icons.list_rounded, 'Campus Location'),
          const SizedBox(width: 8),
          _buildModeChip('map', Icons.pin_drop_rounded, 'Pin on Map'),
          const SizedBox(width: 8),
          _buildModeChip('custom', Icons.edit_rounded, 'Custom'),
        ]),
        const SizedBox(height: AppDimensions.spacingMd),

        // Content based on mode
        if (_locationMode == 'dropdown') _buildLocationDropdown(),
        if (_locationMode == 'map') _buildMapPicker(),
        if (_locationMode == 'custom') _buildTextField(
          controller: _customLocationController,
          hint: 'e.g., Library 2nd Floor, Cafeteria, Room 301',
          icon: Icons.location_on_outlined,
          validator: (_locationMode == 'custom')
              ? (v) => (v == null || v.trim().isEmpty) ? 'Please enter a location' : null
              : null,
        ),
      ],
    );
  }

  Widget _buildModeChip(String mode, IconData icon, String label) {
    final isActive = _locationMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _locationMode = mode;
          if (mode != 'dropdown') _selectedLocation = null;
          if (mode != 'map') { _pinnedLat = null; _pinnedLng = null; }
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isActive ? LinearGradient(colors: [AppColors.primary, AppColors.secondary]) : null,
            color: isActive ? null : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(
              color: isActive ? Colors.transparent : AppColors.primary.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: isActive ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))] : null,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: isActive ? Colors.white : AppColors.primary),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : Colors.grey[700],
            ), textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }

  // ─── Location Dropdown ───
  Widget _buildLocationDropdown() {
    if (_isLoadingLocations) {
      return Container(
        padding: const EdgeInsets.all(AppDimensions.spacingLg),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: const Center(child: SizedBox(width: 24, height: 24,
          child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    if (_campusLocations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppDimensions.spacingLg),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text('No campus locations available. Use "Pin on Map" or "Custom" instead.',
            style: TextStyle(fontSize: 13, color: Colors.orange[800]))),
        ]),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedLocation?.id,
        isExpanded: true,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd, vertical: AppDimensions.spacingSm),
          prefixIcon: Icon(Icons.location_on_outlined, color: AppColors.primary, size: 20),
        ),
        hint: Text('Select a campus location', style: TextStyle(color: Colors.grey[400], fontSize: AppDimensions.fontSizeMd)),
        items: _campusLocations.map((loc) {
          return DropdownMenuItem(
            value: loc.id,
            child: Row(children: [
              Icon(loc.getCategoryIcon(), size: 18, color: loc.getCategoryColor()),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(loc.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  if (loc.address.isNotEmpty)
                    Text(loc.address, style: TextStyle(fontSize: 11, color: Colors.grey[500]), overflow: TextOverflow.ellipsis),
                ],
              )),
            ]),
          );
        }).toList(),
        onChanged: (id) {
          if (id != null) {
            setState(() {
              _selectedLocation = _campusLocations.firstWhere((l) => l.id == id);
            });
          }
        },
        selectedItemBuilder: (context) {
          return _campusLocations.map((loc) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Text(loc.name, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[800])),
            );
          }).toList();
        },
      ),
    );
  }

  // ─── Map Picker ───
  Widget _buildMapPicker() {
    return Column(children: [
      Container(
        height: 250,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          MapWidget(
            styleUri: MapboxStyles.MAPBOX_STREETS,
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(73.0479, 33.6844)),
              zoom: 14,
            ),
            onMapCreated: (map) => _mapboxMap = map,
          ),
          // Center pin overlay
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 36),
              child: Icon(Icons.location_pin, size: 42, color: AppColors.primary),
            ),
          ),
          // Shadow under pin
          Center(
            child: Container(
              width: 8, height: 4,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ]),
      ),
      const SizedBox(height: AppDimensions.spacingMd),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _confirmMapPin,
          icon: Icon(Icons.check_circle_outline, size: 20, color: _pinnedLat != null ? Colors.green : AppColors.primary),
          label: Text(
            _pinnedLat != null ? 'Location Pinned ✓' : 'Confirm Pin Location',
            style: TextStyle(fontWeight: FontWeight.w600,
              color: _pinnedLat != null ? Colors.green : AppColors.primary),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: _pinnedLat != null ? Colors.green : AppColors.primary, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
          ),
        ),
      ),
      if (_pinnedLat != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Lat: ${_pinnedLat!.toStringAsFixed(5)}, Lng: ${_pinnedLng!.toStringAsFixed(5)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic),
          ),
        ),
    ]);
  }

  Future<void> _confirmMapPin() async {
    if (_mapboxMap == null) return;
    try {
      final camera = await _mapboxMap!.getCameraState();
      final center = camera.center;
      setState(() {
        _pinnedLat = center.coordinates.lat.toDouble();
        _pinnedLng = center.coordinates.lng.toDouble();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location pinned at ${_pinnedLat!.toStringAsFixed(4)}, ${_pinnedLng!.toStringAsFixed(4)}'),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error getting map center: $e');
    }
  }

  // ─── Date Picker ───
  Widget _buildDatePicker() {
    return InkWell(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
          const SizedBox(width: AppDimensions.spacingMd),
          Text('${_foundDate.day}/${_foundDate.month}/${_foundDate.year}',
            style: TextStyle(fontSize: AppDimensions.fontSizeMd, color: Colors.grey[800], fontWeight: FontWeight.w500)),
          const Spacer(),
          Icon(Icons.edit_calendar, color: Colors.grey[400], size: 18),
        ]),
      ),
    );
  }

  // ─── Submit Button ───
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity, height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitItem,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary, foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
          shadowColor: AppColors.primary.withValues(alpha: 0.4),
        ),
        child: _isSubmitting
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.send, size: 20), SizedBox(width: 10),
                Text('Submit for Review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              ]),
      ),
    );
  }

  // ─── Shared Helpers ───
  Widget _buildLabel(String text) {
    return Text(text, style: TextStyle(
      fontSize: AppDimensions.fontSizeMd, fontWeight: FontWeight.w700,
      color: Colors.grey[800], letterSpacing: 0.3,
    ));
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: TextFormField(
        controller: controller, maxLines: maxLines, validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: AppDimensions.fontSizeMd),
          prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd, vertical: AppDimensions.spacingMd),
        ),
      ),
    );
  }
}
