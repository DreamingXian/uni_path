import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Result returned when user confirms a location.
class LocationResult {
  final double latitude;
  final double longitude;
  final String? displayName; // reverse-geocoded address from Nominatim

  const LocationResult({
    required this.latitude,
    required this.longitude,
    this.displayName,
  });
}

class LocationPickerScreen extends StatefulWidget {
  /// Pre-fill if editing an existing location.
  final LatLng? initialPosition;

  const LocationPickerScreen({super.key, this.initialPosition});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  // Default center: Malaysia (TARUMT area)
  static const LatLng _defaultCenter = LatLng(3.1390, 101.6869);

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  LatLng? _pinned;          // currently pinned location
  bool _isSearching = false;
  bool _isLoadingLocation = false;
  List<_NominatimResult> _searchResults = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null) {
      _pinned = widget.initialPosition;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Search (Nominatim)
  // -----------------------------------------------------------------------
  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    // Debounce 600 ms to avoid spamming Nominatim
    _debounce = Timer(const Duration(milliseconds: 600), () => _searchNominatim(query));
  }

  Future<void> _searchNominatim(String query) async {
    setState(() => _isSearching = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}'
        '&format=json&limit=5&addressdetails=1',
      );
      final response = await http.get(uri, headers: {
        'User-Agent': 'UniPathApp/1.0 (uni-path student project)',
      });
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        setState(() {
          _searchResults = data.map((e) => _NominatimResult.fromJson(e)).toList();
        });
      }
    } catch (_) {
      // Silently fail — user can still tap the map
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectSearchResult(_NominatimResult result) {
    final pos = LatLng(result.lat, result.lon);
    setState(() {
      _pinned = pos;
      _searchResults = [];
      _searchController.text = result.displayName;
    });
    _mapController.move(pos, 16.0);
    FocusScope.of(context).unfocus();
  }

  // -----------------------------------------------------------------------
  // Tap to pin
  // -----------------------------------------------------------------------
  void _onMapTap(TapPosition _, LatLng latlng) {
    setState(() {
      _pinned = latlng;
      _searchResults = [];
    });
  }

  // -----------------------------------------------------------------------
  // Current Location
  // -----------------------------------------------------------------------
  Future<void> _goToCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      // 1. Check if device GPS/location service is turned on
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('GPS is off. Please enable Location Services.'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => Geolocator.openLocationSettings(),
              ),
            ),
          );
        }
        return;
      }

      // 2. Check / request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied.')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location permission permanently denied.'),
              action: SnackBarAction(
                label: 'App Settings',
                onPressed: () => Geolocator.openAppSettings(),
              ),
            ),
          );
        }
        return;
      }

      // 3. Get position with a 15-second timeout
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Location request timed out'),
      );

      final latlng = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() => _pinned = latlng);
        _mapController.move(latlng, 17.0);
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('timed out')
            ? 'Location request timed out. Try again.'
            : 'Could not get location: ${e.toString()}';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  // -----------------------------------------------------------------------
  // Confirm
  // -----------------------------------------------------------------------
  Future<void> _confirmLocation() async {
    if (_pinned == null) return;

    // Reverse geocode to get a readable address
    String? displayName;
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${_pinned!.latitude}&lon=${_pinned!.longitude}'
        '&format=json',
      );
      final response = await http.get(uri, headers: {
        'User-Agent': 'UniPathApp/1.0 (uni-path student project)',
      });
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        displayName = data['display_name'] as String?;
      }
    } catch (_) {}

    if (mounted) {
      Navigator.pop(
        context,
        LocationResult(
          latitude: _pinned!.latitude,
          longitude: _pinned!.longitude,
          displayName: displayName,
        ),
      );
    }
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location',
            style: TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A237E)),
        actions: [
          if (_pinned != null)
            TextButton(
              onPressed: _confirmLocation,
              child: const Text('Confirm',
                  style: TextStyle(color: Color(0xFF6A1B9A), fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Stack(
        children: [
          // ---- MAP ----
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialPosition ?? _defaultCenter,
              initialZoom: widget.initialPosition != null ? 16.0 : 13.0,
              onTap: _onMapTap,
            ),
            children: [
              // OpenStreetMap tile layer — free, no API key
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.uni_path.app',
              ),
              // Pin marker
              if (_pinned != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _pinned!,
                      width: 48,
                      height: 48,
                      child: const Icon(
                        Icons.location_pin,
                        color: Color(0xFF6A1B9A),
                        size: 48,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // ---- SEARCH BAR OVERLAY ----
          Positioned(
            top: 12, left: 12, right: 12,
            child: Column(
              children: [
                // Search input
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search for a place...',
                      prefixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : const Icon(Icons.search, color: Color(0xFF6A1B9A)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchResults = []);
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),

                // Search results dropdown
                if (_searchResults.isNotEmpty)
                  Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(12),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final r = _searchResults[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined, color: Color(0xFF6A1B9A)),
                          title: Text(r.displayName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13)),
                          onTap: () => _selectSearchResult(r),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // ---- CURRENT LOCATION FAB ----
          Positioned(
            bottom: _pinned != null ? 90 : 24,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'location_btn',
              backgroundColor: Colors.white,
              onPressed: _isLoadingLocation ? null : _goToCurrentLocation,
              child: _isLoadingLocation
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6A1B9A)),
                    )
                  : const Icon(Icons.my_location, color: Color(0xFF6A1B9A)),
            ),
          ),

          // ---- CONFIRM BOTTOM BAR (when pinned) ----
          if (_pinned != null)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_pin, color: Color(0xFF6A1B9A), size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${_pinned!.latitude.toStringAsFixed(5)}, '
                            '${_pinned!.longitude.toStringAsFixed(5)}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _pinned = null),
                          child: const Text('Clear', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6A1B9A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _confirmLocation,
                        child: const Text('Use This Location', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nominatim result model
// ---------------------------------------------------------------------------
class _NominatimResult {
  final double lat;
  final double lon;
  final String displayName;

  const _NominatimResult({
    required this.lat,
    required this.lon,
    required this.displayName,
  });

  factory _NominatimResult.fromJson(Map<String, dynamic> json) => _NominatimResult(
        lat: double.parse(json['lat'].toString()),
        lon: double.parse(json['lon'].toString()),
        displayName: json['display_name'] ?? '',
      );
}
