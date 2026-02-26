import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

import '../theme/app_theme.dart';

/// Full-screen map showing current location → destination with driving route.
class RouteMapScreen extends StatefulWidget {
  final double destLat;
  final double destLng;
  final String destLabel;

  /// Optional second destination (for collector: pickup → delivery).
  final double? dest2Lat;
  final double? dest2Lng;
  final String? dest2Label;

  const RouteMapScreen({
    super.key,
    required this.destLat,
    required this.destLng,
    required this.destLabel,
    this.dest2Lat,
    this.dest2Lng,
    this.dest2Label,
  });

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  final MapController _mapCtrl = MapController();

  LatLng? _currentPos;
  List<LatLng> _routePoints = [];
  List<LatLng> _routePoints2 = [];
  bool _loadingLocation = true;
  bool _loadingRoute = true;
  String? _error;
  String _distance = '';
  String _duration = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _getCurrentLocation();
    if (_currentPos != null) {
      await _fetchRoute();
    }
    if (mounted) setState(() => _loadingRoute = false);
  }

  Future<void> _getCurrentLocation() async {
    try {
      var status = await Permission.location.status;
      if (status.isDenied) {
        status = await Permission.location.request();
      }
      if (!status.isGranted) {
        setState(() {
          _error = 'Location permission denied';
          _loadingLocation = false;
        });
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _error = 'Location services disabled. Please enable GPS.';
          _loadingLocation = false;
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      setState(() {
        _currentPos = LatLng(pos.latitude, pos.longitude);
        _loadingLocation = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not get current location';
        _loadingLocation = false;
      });
    }
  }

  Future<void> _fetchRoute() async {
    if (_currentPos == null) return;

    try {
      // Route from current location to first destination
      final points = await _getOSRMRoute(
        _currentPos!,
        LatLng(widget.destLat, widget.destLng),
      );
      _routePoints = points ?? [];

      // If there's a second destination (collector scenario: pickup → delivery)
      if (widget.dest2Lat != null && widget.dest2Lng != null) {
        final points2 = await _getOSRMRoute(
          LatLng(widget.destLat, widget.destLng),
          LatLng(widget.dest2Lat!, widget.dest2Lng!),
        );
        _routePoints2 = points2 ?? [];
      }
    } catch (_) {
      // Route fetch failed, we'll still show markers
    }
  }

  Future<List<LatLng>?> _getOSRMRoute(LatLng from, LatLng to) async {
    final url =
        'https://router.project-osrm.org/route/v1/driving/'
        '${from.longitude},${from.latitude};'
        '${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson';

    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final routes = data['routes'] as List;
      if (routes.isNotEmpty) {
        final route = routes[0];
        // Parse distance and duration from first route
        if (_distance.isEmpty) {
          final distMeters = route['distance'] as num;
          final durSeconds = route['duration'] as num;
          final km = (distMeters / 1000).toStringAsFixed(1);
          final mins = (durSeconds / 60).ceil();
          _distance = '$km km';
          _duration = '$mins min';
        }

        final coords = route['geometry']['coordinates'] as List;
        return coords
            .map<LatLng>(
              (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
            )
            .toList();
      }
    }
    return null;
  }

  LatLngBounds _getBounds() {
    final points = <LatLng>[];
    if (_currentPos != null) points.add(_currentPos!);
    points.add(LatLng(widget.destLat, widget.destLng));
    if (widget.dest2Lat != null && widget.dest2Lng != null) {
      points.add(LatLng(widget.dest2Lat!, widget.dest2Lng!));
    }
    points.addAll(_routePoints);
    points.addAll(_routePoints2);

    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    // Add padding
    final latPad = (maxLat - minLat) * 0.15;
    final lngPad = (maxLng - minLng) * 0.15;
    return LatLngBounds(
      LatLng(minLat - latPad, minLng - lngPad),
      LatLng(maxLat + latPad, maxLng + lngPad),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dest = LatLng(widget.destLat, widget.destLng);
    final isLoading = _loadingLocation || _loadingRoute;

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ─────────────────────────────────────────────────────
          if (!_loadingLocation && _currentPos != null)
            FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: dest,
                initialZoom: 13,
                onMapReady: () {
                  // Fit bounds after map is ready
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (mounted) {
                      _mapCtrl.fitCamera(
                        CameraFit.bounds(
                          bounds: _getBounds(),
                          padding: const EdgeInsets.all(50),
                        ),
                      );
                    }
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.demetra.savefood',
                ),

                // Route polylines
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        color: Colors.blue.shade700,
                        strokeWidth: 5,
                      ),
                    ],
                  ),
                if (_routePoints2.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints2,
                        color: Colors.deepOrange,
                        strokeWidth: 5,
                        pattern: StrokePattern.dashed(segments: [12.0, 8.0]),
                      ),
                    ],
                  ),

                // Markers
                MarkerLayer(
                  markers: [
                    // Current location
                    if (_currentPos != null)
                      Marker(
                        point: _currentPos!,
                        width: 50,
                        height: 50,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.4),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.my_location,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Destination 1
                    Marker(
                      point: dest,
                      width: 50,
                      height: 60,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.dest2Lat != null ? 'Pickup' : 'Dest',
                              style: GoogleFonts.poppins(
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 36,
                          ),
                        ],
                      ),
                    ),

                    // Destination 2 (if collector)
                    if (widget.dest2Lat != null && widget.dest2Lng != null)
                      Marker(
                        point: LatLng(widget.dest2Lat!, widget.dest2Lng!),
                        width: 60,
                        height: 60,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.deepOrange,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Deliver',
                                style: GoogleFonts.poppins(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.location_on,
                              color: Colors.deepOrange,
                              size: 36,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),

          // Loading overlay
          if (isLoading)
            Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text(
                      _loadingLocation
                          ? 'Getting your location...'
                          : 'Loading route...',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Error state
          if (_error != null && _currentPos == null)
            Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_off,
                      size: 60,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _error = null;
                          _loadingLocation = true;
                          _loadingRoute = true;
                        });
                        _init();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),

          // ── Top bar ─────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                // Back button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                // Title card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.destLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_distance.isNotEmpty)
                          Text(
                            '$_distance  •  $_duration drive',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom info card ────────────────────────────────────────
          if (!isLoading && _currentPos != null)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Legend
                    Row(
                      children: [
                        _legendDot(Colors.blue, 'You'),
                        const SizedBox(width: 14),
                        _legendDot(
                          Colors.red,
                          widget.dest2Lat != null ? 'Pickup' : 'Destination',
                        ),
                        if (widget.dest2Lat != null) ...[
                          const SizedBox(width: 14),
                          _legendDot(Colors.deepOrange, 'Delivery'),
                        ],
                      ],
                    ),
                    if (_distance.isNotEmpty) ...[
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _infoTile(Icons.straighten, 'Distance', _distance),
                          Container(
                            height: 30,
                            width: 1,
                            color: Colors.grey.shade200,
                          ),
                          _infoTile(Icons.access_time, 'Duration', _duration),
                        ],
                      ),
                    ],
                    if (_routePoints.isEmpty && !_loadingRoute) ...[
                      const Divider(height: 20),
                      Text(
                        'Route could not be loaded. Markers are shown.',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // ── Re-center FAB ───────────────────────────────────────────
          if (!isLoading && _currentPos != null)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 140,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'recenter',
                backgroundColor: Colors.white,
                onPressed: () {
                  _mapCtrl.fitCamera(
                    CameraFit.bounds(
                      bounds: _getBounds(),
                      padding: const EdgeInsets.all(50),
                    ),
                  );
                },
                child: const Icon(
                  Icons.center_focus_strong,
                  color: Colors.blue,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
