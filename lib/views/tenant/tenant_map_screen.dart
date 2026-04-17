// lib/views/tenant/tenant_map_screen.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/auth_controller.dart';
import '../../utils/constants.dart';

class TenantMapScreen extends StatefulWidget {
  const TenantMapScreen({super.key});

  @override
  State<TenantMapScreen> createState() => _TenantMapScreenState();
}

class _TenantMapScreenState extends State<TenantMapScreen> {
  GoogleMapController? _mapController;
  Position? _userPosition;
  bool _isLoadingLocation = false;
  bool _locationPermissionDenied = false;
  String? _locationError;
  double? _distanceKm;

  static const _kosLatLng = LatLng(
    AppConstants.KOS_LATITUDE,
    AppConstants.KOS_LONGITUDE,
  );

  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _setupMarkers();
    _getUserLocation();
  }

  void _setupMarkers() {
    _markers = {
      Marker(
        markerId: const MarkerId('kos'),
        position: _kosLatLng,
        infoWindow: InfoWindow(
          title: AppConstants.KOS_NAME,
          snippet: AppConstants.KOS_ADDRESS,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
      ),
    };
  }

  Future<void> _getUserLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      // Cek permission
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

      // Cek apakah GPS aktif
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoadingLocation = false;
          _locationError = 'GPS tidak aktif. Aktifkan lokasi di perangkat.';
        });
        return;
      }

      // Dapatkan posisi
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Hitung jarak ke kos
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
              markerId: const MarkerId('user'),
              position: LatLng(position.latitude, position.longitude),
              infoWindow: const InfoWindow(title: 'Posisi Kamu'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure),
            ),
          );
        });

        // Fit bounds agar kos dan user terlihat
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
    if (_mapController == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        userLatLng.latitude < _kosLatLng.latitude
            ? userLatLng.latitude
            : _kosLatLng.latitude,
        userLatLng.longitude < _kosLatLng.longitude
            ? userLatLng.longitude
            : _kosLatLng.longitude,
      ),
      northeast: LatLng(
        userLatLng.latitude > _kosLatLng.latitude
            ? userLatLng.latitude
            : _kosLatLng.latitude,
        userLatLng.longitude > _kosLatLng.longitude
            ? userLatLng.longitude
            : _kosLatLng.longitude,
      ),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }

  void _centerToKos() {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        const CameraPosition(target: _kosLatLng, zoom: 16),
      ),
    );
  }

  void _animateToUser() {
    if (_mapController == null || _userPosition == null) return;
    _mapController!.animateCamera(
      CameraUpdate.newLatLng(LatLng(_userPosition!.latitude, _userPosition!.longitude)),
    );
  }

  Future<void> _openInMaps() async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${AppConstants.KOS_LATITUDE},${AppConstants.KOS_LONGITUDE}'
      '&travelmode=driving',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka Google Maps.')),
        );
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
                GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: _kosLatLng,
                    zoom: 15,
                  ),
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    if (_userPosition != null) {
                      _fitBounds(LatLng(
                          _userPosition!.latitude, _userPosition!.longitude));
                    }
                  },
                ),

                // Loading overlay
                if (_isLoadingLocation)
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
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Color(0xFF8095E4)),
                            ),
                            SizedBox(width: 8),
                            Text('Mencari lokasi...',
                                style: TextStyle(fontSize: 12)),
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
                      onPressed: _openInMaps,
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
