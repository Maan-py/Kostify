// lib/views/tenant/tenant_map_screen.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/auth_controller.dart';
import '../../utils/constants.dart';

class TenantMapScreen extends StatefulWidget {
  const TenantMapScreen({super.key});

  @override
  State<TenantMapScreen> createState() => _TenantMapScreenState();
}

class _TenantMapScreenState extends State<TenantMapScreen> {
  final MapController _mapController = MapController();
  Position? _userPosition;
  bool _isLoadingLocation = false;
  bool _isLoadingRoute = false;
  bool _locationPermissionDenied = false;
  String? _locationError;
  double? _distanceKm;

  static final _kosLatLng = LatLng(
    AppConstants.KOS_LATITUDE,
    AppConstants.KOS_LONGITUDE,
  );

  List<Marker> _markers = [];
  List<Polyline> _polylines = [];

  @override
  void initState() {
    super.initState();
    _setupMarkers();
    _getUserLocation();
  }

  void _setupMarkers() {
    _markers = [
      Marker(
        point: _kosLatLng,
        width: 40,
        height: 40,
        child: const Icon(Icons.home_work_rounded,
            color: Color(0xFF8095E4), size: 32),
      ),
    ];
  }

  Future<void> _getUserLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationPermissionDenied = true;
            _isLoadingLocation = false;
            _locationError = 'Izin lokasi ditolak.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationPermissionDenied = true;
          _isLoadingLocation = false;
          _locationError =
              'Izin lokasi diblokir permanen. Aktifkan di Pengaturan.';
        });
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoadingLocation = false;
          _locationError = 'GPS tidak aktif. Aktifkan lokasi di perangkat.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final distanceM = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        AppConstants.KOS_LATITUDE,
        AppConstants.KOS_LONGITUDE,
      );

      if (mounted) {
        setState(() {
          _userPosition = position;
          _distanceKm = distanceM / 1000;
          _isLoadingLocation = false;
          _markers.add(
            Marker(
              point: LatLng(position.latitude, position.longitude),
              width: 36,
              height: 36,
              child: const Icon(Icons.my_location_rounded,
                  color: Color(0xFF4EA3FF), size: 28),
            ),
          );
        });

        _fitBounds(LatLng(position.latitude, position.longitude));
        _animateToUser();
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          if (e.toString().contains('TimeoutException')) {
            _locationError = 'Timeout mendapatkan lokasi. Pastikan GPS aktif.';
          } else {
            _locationError = 'Gagal mendapatkan lokasi.';
          }
        });
      }
    }
  }

  void _fitBounds(LatLng userLatLng) {
    final center = LatLng((userLatLng.latitude + _kosLatLng.latitude) / 2,
        (userLatLng.longitude + _kosLatLng.longitude) / 2);
    _mapController.move(center, 13);
  }

  void _fitBoundsForPoints(List<LatLng> points) {
    if (points.isEmpty) return;
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    _mapController.move(center, 13);
  }

  void _centerToKos() {
    _mapController.move(_kosLatLng, 16);
  }

  void _animateToUser() {
    if (_userPosition == null) return;
    _mapController.move(
        LatLng(_userPosition!.latitude, _userPosition!.longitude), 15);
  }

  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> polylineCoordinates = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int b;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      final dLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dLat;

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      final dLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dLng;

      polylineCoordinates.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return polylineCoordinates;
  }

  bool _isBillingOrKeyIssue(String message) {
    final lower = message.toLowerCase();
    return lower.contains('billing') ||
        lower.contains('request_denied') ||
        lower.contains('api key') ||
        lower.contains('missing_api_key') ||
        lower.contains('missing_api');
  }

  Future<void> _openExternalNavigation() async {
    final origin = _userPosition != null
        ? '${_userPosition!.latitude},${_userPosition!.longitude}'
        : null;
    final destination =
        '${AppConstants.KOS_LATITUDE},${AppConstants.KOS_LONGITUDE}';

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '${origin != null ? '&origin=$origin' : ''}'
      '&destination=$destination'
      '&travelmode=driving',
    );

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuka Google Maps.')),
      );
    }
  }

  Future<Map<String, dynamic>> _fetchRouteFromOsrm({
    required String origin,
    required String destination,
  }) async {
    final originParts = origin.split(',');
    final destinationParts = destination.split(',');
    if (originParts.length != 2 || destinationParts.length != 2) {
      throw Exception('Koordinat tidak valid.');
    }

    final originLat = originParts[0].trim();
    final originLng = originParts[1].trim();
    final destinationLat = destinationParts[0].trim();
    final destinationLng = destinationParts[1].trim();

    final osrmUri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '$originLng,$originLat;$destinationLng,$destinationLat'
      '?overview=full&geometries=polyline&steps=false',
    );

    final osrmResponse = await http.get(osrmUri).timeout(
          const Duration(seconds: AppConstants.HTTP_TIMEOUT_SECONDS),
        );

    if (osrmResponse.statusCode != 200) {
      throw Exception('Gagal menghubungi layanan rute OSM.');
    }

    final osrmData = jsonDecode(osrmResponse.body) as Map<String, dynamic>;
    final code = osrmData['code'] as String?;
    final routes = osrmData['routes'] as List?;

    if (code != 'Ok' || routes == null || routes.isEmpty) {
      throw Exception('Rute OSM tidak ditemukan.');
    }

    final firstRoute = routes.first as Map<String, dynamic>;
    final encodedPoints = firstRoute['geometry'] as String?;
    if (encodedPoints == null || encodedPoints.isEmpty) {
      throw Exception('Rute OSM kosong.');
    }

    final distanceMeter = (firstRoute['distance'] as num?)?.toDouble();
    final durationSecond = (firstRoute['duration'] as num?)?.toDouble();

    return {
      'encodedPoints': encodedPoints,
      'distanceMeter': distanceMeter,
      'durationSecond': durationSecond,
    };
  }

  String _formatDurationMinutes(double seconds) {
    final totalMinutes = (seconds / 60).round();
    if (totalMinutes < 60) return '$totalMinutes menit';

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (minutes == 0) return '$hours jam';
    return '$hours jam $minutes menit';
  }

  Future<void> _showRouteOnMap() async {
    if (_isLoadingRoute) return;

    if (_userPosition == null) {
      await _getUserLocation();
    }

    if (_userPosition == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lokasi kamu belum tersedia.')),
        );
      }
      return;
    }

    setState(() {
      _isLoadingRoute = true;
    });

    try {
      final origin = '${_userPosition!.latitude},${_userPosition!.longitude}';
      final destination =
          '${AppConstants.KOS_LATITUDE},${AppConstants.KOS_LONGITUDE}';

      // Prioritas rute OSM agar tetap bisa tampil tanpa billing Google.
      try {
        final osrmRoute = await _fetchRouteFromOsrm(
          origin: origin,
          destination: destination,
        );

        final routePoints =
            _decodePolyline(osrmRoute['encodedPoints'] as String);
        if (routePoints.isEmpty) {
          throw Exception('Rute OSM kosong.');
        }

        final distanceMeter = osrmRoute['distanceMeter'] as double?;
        final durationSecond = osrmRoute['durationSecond'] as double?;

        if (mounted) {
          setState(() {
            _polylines = [
              Polyline(
                points: routePoints,
                strokeWidth: 5.0,
                color: const Color(0xFF8095E4),
              ),
            ];
          });

          _fitBoundsForPoints(routePoints);

          if (distanceMeter != null && durationSecond != null) {
            final distanceText = _formatDistance(distanceMeter / 1000);
            final durationText = _formatDurationMinutes(durationSecond);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text('Rute tampil: $distanceText • $durationText (OSM)')),
            );
          }
        }
        return;
      } on Exception {
        // Lanjut ke Google Directions jika OSM sedang bermasalah.
      }

      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=$origin'
        '&destination=$destination'
        '&mode=driving'
        '&language=id'
        '&key=${AppConstants.GOOGLE_MAPS_API_KEY}',
      );

      final response = await http.get(uri).timeout(
            const Duration(seconds: AppConstants.HTTP_TIMEOUT_SECONDS),
          );

      if (response.statusCode != 200) {
        throw Exception('Gagal memuat rute.');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final status = data['status'] as String?;

      if (status != 'OK' || (data['routes'] as List).isEmpty) {
        final errorMessage = data['error_message'] as String?;
        final combinedError = [status, errorMessage]
            .whereType<String>()
            .where((v) => v.trim().isNotEmpty)
            .join(': ');
        throw Exception(
            combinedError.isEmpty ? 'Rute tidak ditemukan.' : combinedError);
      }

      final firstRoute = (data['routes'] as List).first as Map<String, dynamic>;
      final encodedPoints = (firstRoute['overview_polyline']
          as Map<String, dynamic>)['points'] as String;
      final routePoints = _decodePolyline(encodedPoints);

      if (routePoints.isEmpty) {
        throw Exception('Rute kosong.');
      }

      final firstLeg =
          ((firstRoute['legs'] as List).first as Map<String, dynamic>);
      final distanceText =
          (firstLeg['distance'] as Map<String, dynamic>)['text'] as String?;
      final durationText =
          (firstLeg['duration'] as Map<String, dynamic>)['text'] as String?;

      if (mounted) {
        setState(() {
          _polylines = [
            Polyline(
              points: routePoints,
              strokeWidth: 5.0,
              color: const Color(0xFF8095E4),
            ),
          ];
        });

        _fitBoundsForPoints(routePoints);

        if (distanceText != null && durationText != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Rute tampil: $distanceText • $durationText')),
          );
        }
      }
    } on Exception catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      if (_isBillingOrKeyIssue(message)) {
        await _openExternalNavigation();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Rute di aplikasi tidak tersedia (billing Google Maps belum aktif). Navigasi dibuka di Google Maps.'),
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menampilkan rute: $message')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRoute = false;
        });
      }
    }
  }

  String _formatDistance(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthController.to.currentUser.value;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Lokasi Kos',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon:
                const Icon(Icons.my_location_rounded, color: Color(0xFF8095E4)),
            tooltip: 'Perbarui Lokasi',
            onPressed: _isLoadingLocation ? null : _getUserLocation,
          ),
        ],
      ),
      body: Column(
        children: [
          // Info bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.home_work_rounded,
                    color: Color(0xFF8095E4), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppConstants.KOS_NAME,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFF1A1A2E))),
                      Text(
                        AppConstants.KOS_ADDRESS,
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF6B7280)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (_distanceKm != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8095E4).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatDistance(_distanceKm!),
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8095E4)),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Error / loading bar
          if (_locationError != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.orange.shade50,
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_locationError!,
                        style: TextStyle(
                            fontSize: 11, color: Colors.orange.shade800)),
                  ),
                  if (_locationPermissionDenied)
                    TextButton(
                      onPressed: () => Geolocator.openAppSettings(),
                      child: const Text('Buka Pengaturan',
                          style: TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            ),

          // Map
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _kosLatLng,
                    initialZoom: 15,
                    maxZoom: 18,
                    minZoom: 3,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.example.kostify',
                    ),
                    if (_polylines.isNotEmpty)
                      PolylineLayer(polylines: _polylines),
                    if (_markers.isNotEmpty) MarkerLayer(markers: _markers),
                  ],
                ),

                // Loading overlay
                if (_isLoadingLocation || _isLoadingRoute)
                  Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 8)
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Color(0xFF8095E4)),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isLoadingRoute
                                  ? 'Memuat rute...'
                                  : 'Mencari lokasi...',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Center to kos button
                Positioned(
                  bottom: 90,
                  right: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'center_kos',
                    onPressed: _centerToKos,
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.home_work_rounded,
                        color: Color(0xFF8095E4)),
                  ),
                ),
              ],
            ),
          ),

          // Bottom bar — info + navigate button
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  // Kamar info
                  if (user?.nomorKamar != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8095E4).withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.bedroom_parent_rounded,
                                color: Color(0xFF8095E4), size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Kamar kamu: No. ${user!.nomorKamar}',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Navigate button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isLoadingRoute ? null : _showRouteOnMap,
                      icon: const Icon(Icons.navigation_rounded, size: 20),
                      label: const Text('Navigasi ke Kos',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8095E4),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
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
