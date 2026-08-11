import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/campus_location_model.dart';
import '../utils/theme_manager.dart';
import '../widgets/location_card.dart';
import 'campus_navigation_screen.dart';

class FavoriteLocationsScreen extends StatefulWidget {
  const FavoriteLocationsScreen({super.key});

  @override
  State<FavoriteLocationsScreen> createState() => _FavoriteLocationsScreenState();
}

class _FavoriteLocationsScreenState extends State<FavoriteLocationsScreen> {
  bool _isLoading = true;
  List<CampusLocation> _favoriteLocations = [];

  @override
  void initState() {
    super.initState();
    _loadFavoriteLocations();
  }

  Future<void> _loadFavoriteLocations() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _favoriteLocations = [];
            _isLoading = false;
          });
        }
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data() ?? <String, dynamic>{};
        final rawPreferences = userData['preferences'];
        final preferences = rawPreferences is Map
          ? Map<String, dynamic>.from(rawPreferences)
          : <String, dynamic>{};

      final favoriteIds = List<String>.from(
        preferences['favoriteLocations'] ?? const <String>[],
      );

      if (favoriteIds.isEmpty) {
        if (mounted) {
          setState(() {
            _favoriteLocations = [];
            _isLoading = false;
          });
        }
        return;
      }

      final locationsRef = FirebaseFirestore.instance.collection('locations');
      final allDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

      for (var i = 0; i < favoriteIds.length; i += 10) {
        final chunk = favoriteIds.sublist(
          i,
          i + 10 > favoriteIds.length ? favoriteIds.length : i + 10,
        );

        final snapshot = await locationsRef
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        allDocs.addAll(snapshot.docs);
      }

      final idToLocation = {
        for (final doc in allDocs)
          doc.id: CampusLocation.fromFirestore(doc.data(), doc.id),
      };

      final orderedFavorites = favoriteIds
          .map((id) => idToLocation[id])
          .whereType<CampusLocation>()
          .toList();

      if (mounted) {
        setState(() {
          _favoriteLocations = orderedFavorites;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading favorite locations: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeFavorite(CampusLocation location) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'preferences.favoriteLocations': FieldValue.arrayRemove([location.id]),
        'updatedAt': DateTime.now(),
      });

      if (!mounted) return;
      setState(() {
        _favoriteLocations.removeWhere((item) => item.id == location.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${location.name} removed from favorites.'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      debugPrint('Error removing favorite location: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not remove favorite location.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _openOnMap(CampusLocation location) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CampusNavigationScreen(
          initialEventName: location.name,
          initialEventLocationLabel: location.address,
          initialEventLatitude: location.latitude,
          initialEventLongitude: location.longitude,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _favoriteLocations.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.spacingXl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.favorite_border,
                        size: 56,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(height: AppDimensions.spacingMd),
                      Text(
                        'No favorite locations yet',
                        style: TextStyle(
                          fontSize: AppDimensions.fontSizeLg,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[800],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppDimensions.spacingSm),
                      Text(
                        'Add favorites from the map location details and they will appear here.',
                        style: TextStyle(
                          fontSize: AppDimensions.fontSizeSm,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadFavoriteLocations,
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppDimensions.spacingLg),
                  itemCount: _favoriteLocations.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppDimensions.spacingMd),
                  itemBuilder: (context, index) {
                    final location = _favoriteLocations[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LocationCard(
                          location: location,
                          onTap: () => _openOnMap(location),
                        ),
                        const SizedBox(height: AppDimensions.spacingSm),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _openOnMap(location),
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
                                onPressed: () => _removeFavorite(location),
                                icon: const Icon(Icons.favorite),
                                label: const Text('Remove'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  side: BorderSide(color: AppColors.error),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppDimensions.spacingMd,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
      ),
    );
  }
}
