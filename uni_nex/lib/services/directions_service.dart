import 'package:http/http.dart' as http;
import 'dart:convert';

class DirectionsResponse {
  final double distance; // in meters
  final double duration; // in seconds
  final List<LatLng> route; // polyline coordinates
  final String encodedPolyline;

  DirectionsResponse({
    required this.distance,
    required this.duration,
    required this.route,
    required this.encodedPolyline,
  });

  String get formattedDistance {
    if (distance >= 1000) {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    }
    return '${distance.toStringAsFixed(0)} m';
  }

  String get formattedDuration {
    final minutes = (duration / 60).toInt();
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }
}

class LatLng {
  final double latitude;
  final double longitude;

  LatLng(this.latitude, this.longitude);

  factory LatLng.fromList(List<dynamic> list) {
    return LatLng(list[1], list[0]); // Mapbox returns [lng, lat]
  }

  @override
  String toString() => 'LatLng($latitude, $longitude)';
}

enum TransportMode {
  driving,
  cycling,
  walking;

  String toMapboxParam() {
    switch (this) {
      case TransportMode.driving:
        return 'driving';
      case TransportMode.cycling:
        return 'cycling';
      case TransportMode.walking:
        return 'walking';
    }
  }

  String get displayName {
    switch (this) {
      case TransportMode.driving:
        return 'Driving';
      case TransportMode.cycling:
        return 'Cycling';
      case TransportMode.walking:
        return 'Walking';
    }
  }
}

class DirectionsService {
  static const String _mapboxAccessToken = 'pk.eyJ1IjoiYXdhaXN2ZWVyIiwiYSI6ImNtbTM3ZzNkZDBjbW4ycXNlZTU0dXNhbGUifQ.jc-drltLU8W4IG8eEJCB6Q';
  static const String _baseUrl = 'https://api.mapbox.com/directions/v5/mapbox';

  static Future<DirectionsResponse?> getDirections({
    required double startLat,
    required double startLng,
    required double destLat,
    required double destLng,
    TransportMode mode = TransportMode.driving,
  }) async {
    try {
      final coordinates = '$startLng,$startLat;$destLng,$destLat';
      final url =
          '$_baseUrl/${mode.toMapboxParam()}/$coordinates?alternatives=false&geometries=geojson&overview=full&steps=true&access_token=$_mapboxAccessToken';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json['routes'] == null || (json['routes'] as List).isEmpty) {
          return null;
        }

        final route = json['routes'][0];
        final geometry = route['geometry'];
        final coordinates = geometry['coordinates'] as List<dynamic>;

        final polylineCoordinates = coordinates
            .map((coord) => LatLng.fromList(coord as List<dynamic>))
            .toList();

        return DirectionsResponse(
          distance: (route['distance'] as num).toDouble(),
          duration: (route['duration'] as num).toDouble(),
          route: polylineCoordinates,
          encodedPolyline: route['geometry']['coordinates'].toString(),
        );
      }

      return null;
    } catch (e) {
      print('Error getting directions: $e');
      return null;
    }
  }
}
