// lib/views/tenant/tenant_dashboard_screen.dart

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/auth_controller.dart';
import '../../models/user_model.dart';
import '../../models/payment_model.dart';
import '../../controllers/tenant_controller.dart';
import '../../models/emergency_log_model.dart';
import '../../services/database_helper.dart';
import '../../services/notification_service.dart';
import '../../services/sensor_service.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import '../shared/saran_kesan_screen.dart';
import '../shared/dashboard_timezone_card.dart';
import 'tools_screen.dart';
import 'change_password_screen.dart';
import 'tenant_map_screen.dart';

class TenantDashboardScreen extends StatefulWidget {
  const TenantDashboardScreen({super.key});

  @override
  State<TenantDashboardScreen> createState() => _TenantDashboardScreenState();
}

class _TenantDashboardScreenState extends State<TenantDashboardScreen> {
  final _auth = AuthController.to;
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const _TenantHomeTab(),
      const TenantMapScreen(),
      const ToolsScreen(),
      const _TenantProfileTab(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF1BC0BA).withOpacity(0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF1BC0BA)),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded, color: Color(0xFF1BC0BA)),
            label: 'Lokasi',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build_rounded, color: Color(0xFF1BC0BA)),
            label: 'Tools',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person_rounded, color: Color(0xFF1BC0BA)),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

// ─── Tab 1: Home ───────────────────────────────────────────────────────────────

class _TenantHomeTab extends StatefulWidget {
  const _TenantHomeTab();

  @override
  State<_TenantHomeTab> createState() => _TenantHomeTabState();
}

class _TenantHomeTabState extends State<_TenantHomeTab>
    with WidgetsBindingObserver {
  final _auth = AuthController.to;
  final _sensor = SensorService();
  final _api = ApiService();
  final _db = DatabaseHelper();
  final _tenantController = Get.put(TenantController());

  bool _shakeActive = false;
  bool _emergencySent = false;
  bool _latestPaymentLoaded = false;
  bool _broadcastNotificationsLoaded = false;
  late final Timer _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startShakeDetection();
    // Auto-refresh payment data setiap 30 detik
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        final user = _auth.currentUser.value;
        if (user != null) {
          _tenantController.fetchLatestPayment(user.id!);
        }
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sensor.stopShakeDetection();
    _autoRefreshTimer.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncPendingPayments();
    }
  }

  Future<void> _syncPendingPayments() async {
    final user = _auth.currentUser.value;
    if (user == null) return;

    final payments = await _db.getPaymentsByUser(user.id!);
    bool hasUpdate = false;
    for (var payment in payments) {
      if (payment.status == PaymentStatus.pending && payment.orderId != null) {
        final statusResult =
            await _api.checkMidtransTransactionStatus(payment.orderId!);
        if (statusResult != null) {
          final statusMidtrans = statusResult['transaction_status'];
          if (statusMidtrans == 'settlement' || statusMidtrans == 'capture') {
            await _db.updatePaymentStatus(payment.id!, PaymentStatus.paid);
            hasUpdate = true;
          }
        }
      }
    }

    if (hasUpdate && mounted) {
      await _tenantController.fetchLatestPayment(user.id!);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Pembayaran berhasil diperbarui menjadi Lunas!'),
          backgroundColor: Color(0xFF1BC0BA),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _syncBroadcastNotifications() async {
    if (_broadcastNotificationsLoaded) return;

    final user = _auth.currentUser.value;
    if (user == null) return;

    _broadcastNotificationsLoaded = true;

    final undelivered = await _db.getUndeliveredBroadcasts(user.id!);
    for (final broadcast in undelivered) {
      await NotificationService.instance.showBroadcastNotification(
        title: broadcast.title,
        body: broadcast.message,
        payload: broadcast.id?.toString(),
      );
      await _db.markBroadcastDelivered(broadcast.id!, user.id!);
    }
  }

  void _startShakeDetection() {
    _sensor.startShakeDetection(_onShakeDetected);
  }

  Future<void> _onShakeDetected() async {
    if (_shakeActive) return;
    setState(() => _shakeActive = true);

    // Countdown 3 detik sebelum kirim
    bool cancelled = false;
    if (mounted) {
      cancelled = await _showEmergencyCountdown();
    }

    if (!cancelled) {
      await _sendEmergency();
    }

    if (mounted)
      setState(() {
        _shakeActive = false;
      });
    if (mounted)
      setState(() {
        _shakeActive = false;
      });
  }

  Future<bool> _showEmergencyCountdown() async {
    bool cancelled = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _EmergencyCountdownDialog(
        onCancel: () {
          cancelled = true;
          Navigator.pop(ctx);
        },
        onConfirm: () => Navigator.pop(ctx),
      ),
    );
    return cancelled;
  }

  Future<void> _sendEmergency() async {
    final user = _auth.currentUser.value;
    if (user == null) return;

    final now = DateTime.now();
    final msg =
        'Sinyal darurat dari ${user.namaLengkap ?? user.username}, kamar ${user.nomorKamar ?? "-"}';

    // Simpan ke DB dulu
    await _db.createEmergencyLog(
      EmergencyLogModel(userId: user.id!, message: msg, timestamp: now),
    );

    // Kirim ke Telegram
    final sent = await _api.sendTelegramAlert(
      tenantName: user.namaLengkap ?? user.username,
      nomorKamar: user.nomorKamar ?? '-',
      timestamp: now,
    );

    if (mounted) {
      setState(() => _emergencySent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(sent
              ? '🚨 Sinyal darurat berhasil dikirim ke admin!'
              : '⚠️ Sinyal disimpan. Akan dikirim saat ada koneksi internet.'),
          backgroundColor: sent ? Colors.red.shade700 : Colors.orange.shade700,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      // Reset setelah 10 detik
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted) setState(() => _emergencySent = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Obx(() {
          final user = _auth.currentUser.value;
          if (user == null)
            return const Center(child: CircularProgressIndicator());

          if (!_latestPaymentLoaded) {
            _tenantController.fetchLatestPayment(user.id!).whenComplete(() {
              if (mounted) setState(() => _latestPaymentLoaded = true);
            });
          }

          if (!_broadcastNotificationsLoaded) {
            _syncBroadcastNotifications();
          }

          return RefreshIndicator(
            onRefresh: () async {
              await _auth.refreshUser();
              await _syncPendingPayments();
            },
            color: const Color(0xFF1BC0BA),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting
                  _GreetingHeader(user: user),
                  const SizedBox(height: 20),

                  // Kartu kamar
                  _RoomCard(user: user),
                  const SizedBox(height: 16),

                  // Akses broadcast
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Get.toNamed('/tenant/broadcast'),
                      icon: const Icon(Icons.campaign_rounded, size: 18),
                      label: const Text('Broadcast Pengumuman'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B7FD7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Kartu pembayaran
                  _PaymentCard(key: UniqueKey(), userId: user.id!),
                  const SizedBox(height: 16),

                  // Emergency button
                  _EmergencyCard(
                    isActive: _shakeActive,
                    isSent: _emergencySent,
                    onManualPress: _onShakeDetected,
                  ),
                  const SizedBox(height: 16),

                  // Info kos
                  _KosInfoCard(),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Tab 4: Profil Tenant ──────────────────────────────────────────────────────

class _TenantProfileTab extends StatefulWidget {
  const _TenantProfileTab();

  @override
  State<_TenantProfileTab> createState() => _TenantProfileTabState();
}

class _TenantProfileTabState extends State<_TenantProfileTab> {
  final _auth = AuthController.to;
  final _db = DatabaseHelper();
  final _picker = ImagePicker();
  bool _isUploadingPhoto = false;

  Future<void> _pickAndUploadPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded,
                    color: Color(0xFF8095E4)),
                title: const Text('Ambil Foto'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: Color(0xFF8095E4)),
                title: const Text('Pilih dari Galeri'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;
    setState(() => _isUploadingPhoto = true);

    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 80);
      if (picked == null) return;

      // Validasi ekstensi
      final ext = picked.path.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png'].contains(ext)) {
        throw Exception('Format tidak didukung. Gunakan JPG atau PNG.');
      }

      // Compress
      final compressed = await FlutterImageCompress.compressWithFile(
        picked.path,
        quality: AppConstants.IMAGE_QUALITY,
        minWidth: 400,
        minHeight: 400,
      );
      if (compressed == null) throw Exception('Gagal memproses foto');

      // Cek ukuran
      if (compressed.lengthInBytes > AppConstants.MAX_IMAGE_SIZE_KB * 1024) {
        throw Exception(
            'Ukuran foto terlalu besar. Maksimal ${AppConstants.MAX_IMAGE_SIZE_KB}KB.');
      }

      // Simpan ke direktori app
      final dir = await getApplicationDocumentsDirectory();
      final userId = _auth.currentUser.value?.id;
      final savePath = '${dir.path}/profil_$userId.jpg';
      await File(savePath).writeAsBytes(compressed);

      // Update DB
      await _db.updateFotoProfil(userId!, savePath);
      await _auth.refreshUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Foto profil berhasil diperbarui!'),
            backgroundColor: const Color(0xFF1BC0BA),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Keluar?'),
        content: const Text('Apakah kamu yakin ingin keluar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _auth.logout();
            },
            child: Text('Keluar', style: TextStyle(color: Colors.red.shade600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Profil Saya',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Obx(() {
        final user = _auth.currentUser.value;
        if (user == null)
          return const Center(child: CircularProgressIndicator());
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Foto Profil
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                    child: CircleAvatar(
                      radius: 52,
                      backgroundColor:
                          const Color(0xFF1BC0BA).withOpacity(0.12),
                      backgroundImage: user.fotoProfilPath != null &&
                              File(user.fotoProfilPath!).existsSync()
                          ? FileImage(File(user.fotoProfilPath!))
                          : null,
                      child: _isUploadingPhoto
                          ? const CircularProgressIndicator(
                              color: Color(0xFF1BC0BA))
                          : user.fotoProfilPath == null
                              ? Text(
                                  (user.namaLengkap?.isNotEmpty == true
                                          ? user.namaLengkap![0]
                                          : user.username[0])
                                      .toUpperCase(),
                                  style: const TextStyle(
                                      fontSize: 36,
                                      color: Color(0xFF1BC0BA),
                                      fontWeight: FontWeight.w700),
                                )
                              : null,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1BC0BA),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                user.namaLengkap ?? user.username,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E)),
              ),
            ),
            Center(
              child: Text('@${user.username}',
                  style: const TextStyle(color: Color(0xFF6B7280))),
            ),
            const SizedBox(height: 6),
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: user.isActive
                      ? const Color(0xFF1BC0BA).withOpacity(0.1)
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  user.isActive ? '● Aktif' : '● Nonaktif',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: user.isActive
                        ? const Color(0xFF0F6E56)
                        : Colors.red.shade700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Info detail
            _ProfileInfoCard(user: user),
            const SizedBox(height: 16),

            // Menu
            _ProfileMenuItem(
                icon: Icons.rate_review_rounded,
                label: 'Saran & Kesan TPM',
                onTap: () => Get.to(() => const SaranKesanScreen())),
            const SizedBox(height: 8),
            _ProfileMenuItem(
                icon: Icons.lock_rounded,
                label: 'Ubah Password',
                onTap: () => Get.to(() => const ChangePasswordScreen())),
            const SizedBox(height: 8),
            _ProfileMenuItem(
                icon: Icons.logout_rounded,
                label: 'Keluar',
                color: Colors.red.shade600,
                onTap: () => _confirmLogout(context)),
          ],
        );
      }),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  final UserModel user;
  const _GreetingHeader({required this.user});

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat pagi';
    if (h < 15) return 'Selamat siang';
    if (h < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  @override
  Widget build(BuildContext context) {
    final firstName = (user.namaLengkap ?? user.username).split(' ').first;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_getGreeting(),
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
              Text(firstName,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8095E4))),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const DashboardTimezoneCard(accentColor: Color(0xFF8095E4)),
      ],
    );
  }
}

class _RoomCard extends StatelessWidget {
  final UserModel user;

  _RoomCard({required this.user});

  final _db = DatabaseHelper();
  final _api = ApiService();

  DateTime? _nextPaymentDeadline() {
    final masuk = DateTime.tryParse(user.tanggalMasuk ?? '');
    if (masuk == null) return null;

    final now = DateTime.now();
    final dueDay = masuk.day;

    DateTime buildDeadline(int year, int month, int day) {
      final lastDay = DateTime(year, month + 1, 0).day;
      final safeDay = day > lastDay ? lastDay : day;
      return DateTime(year, month, safeDay);
    }

    var deadline = buildDeadline(now.year, now.month, dueDay);
    final today = DateTime(now.year, now.month, now.day);

    if (deadline.isBefore(today)) {
      deadline = buildDeadline(now.year, now.month + 1, dueDay);
    }

    return deadline;
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  /// Fungsi untuk menangani proses pembayaran dengan Midtrans
  Future<void> _handlePayment(
      BuildContext context, PaymentModel pendingPayment) async {
    if (user.id == null || pendingPayment.amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data tagihan tidak valid.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Tampilkan loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF1BC0BA)),
      ),
    );

    try {
      // Generate Order ID unik: ORDER-{userId}-{timestamp}
      final now = DateTime.now();
      final orderId = 'ORDER-${user.id}-${now.millisecondsSinceEpoch}';

      // Ambil nama pelanggan
      final customerName = user.namaLengkap ?? 'Tenant ${user.id}';

      // Panggil API Midtrans Snap
      final result = await _api.getMidtransSnapUrl(
        orderId: orderId,
        amount: pendingPayment.amount,
        customerName: customerName,
      );

      // Tutup loading dialog
      if (context.mounted) Navigator.pop(context);

      if (!result.success) {
        // Error dari Midtrans
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Gagal membuat transaksi.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      // Update payment record yang sedang di proses dengan orderId dan snapUrl baru
      final updatedPayment = pendingPayment.copyWith(
        orderId: orderId,
        snapUrl: result.redirectUrl,
      );
      await _db.updatePaymentRecord(updatedPayment);

      // Buka Midtrans Snap URL di external browser
      final snapUrl = result.redirectUrl!;
      final uri = Uri.parse(snapUrl);

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tidak bisa membuka URL: $snapUrl'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deadline = _nextPaymentDeadline();
    final _tenantController = Get.put(TenantController());
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF6B7FD7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.home_work_rounded,
                  color: Colors.white70, size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Kamar Kamu',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text(
                      'No. ${user.nomorKamar ?? "-"}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800),
                    ),
                    Text(
                      AppConstants.KOS_NAME,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Sewa/bulan',
                      style: TextStyle(color: Colors.white60, fontSize: 10)),
                  Text(
                    user.hargaSewa != null
                        ? AppValidators.formatRupiah(user.hargaSewa!)
                        : '-',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_note_rounded,
                    color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    deadline != null
                        ? 'Deadline pembayaran: ${_formatDate(deadline)}'
                        : 'Deadline pembayaran: -',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Obx(() {
            // Ambil data tagihan terbaru dari controller
            final payment = _tenantController.latestPayment.value;

            // LOGIKA 1: Kalau admin belum buat tagihan (data null), jangan munculin apa-apa
            if (payment == null) {
              return const SizedBox.shrink();
            }

            // LOGIKA 2: Kalau statusnya belum lunas, munculin tombol bayar
            if (payment.status != PaymentStatus.paid) {
              return SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _handlePayment(context, payment),
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('Bayar Sekarang'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              );
            }

            // Kalau sudah lunas, tombol tidak ditampilkan.
            return const SizedBox.shrink();
          })
        ],
      ),
    );
  }
}

class _PaymentCard extends StatefulWidget {
  final int userId;
  const _PaymentCard({super.key, required this.userId});

  @override
  State<_PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends State<_PaymentCard> {
  final _db = DatabaseHelper();
  List<dynamic> _payments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await _db.getPaymentsByUser(widget.userId);
    if (mounted) setState(() => _payments = p.take(3).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.receipt_long_rounded,
                  color: Color(0xFF8095E4), size: 18),
              SizedBox(width: 8),
              Text('Riwayat Pembayaran',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF1A1A2E))),
            ],
          ),
          const SizedBox(height: 12),
          if (_payments.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('Belum ada data pembayaran',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
              ),
            )
          else
            ..._payments.map((p) => _PaymentRow(payment: p)),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  // UPDATE: Ganti 'dynamic' menjadi 'PaymentModel' agar extension terbaca
  // re-update
  final PaymentModel payment;
  const _PaymentRow({required this.payment});

  @override
  Widget build(BuildContext context) {
    // UPDATE: Bandingkan langsung dengan enum, lebih aman dan efisien
    final isPaid = payment.status == PaymentStatus.paid;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(payment.bulan,
                style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E))),
          ),
          Text(AppValidators.formatRupiah(payment.amount),
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isPaid
                  ? const Color(0xFF1BC0BA).withOpacity(0.1)
                  : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isPaid ? 'Lunas' : 'Belum',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color:
                    isPaid ? const Color(0xFF0F6E56) : Colors.orange.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  final bool isActive;
  final bool isSent;
  final VoidCallback onManualPress;

  const _EmergencyCard(
      {required this.isActive,
      required this.isSent,
      required this.onManualPress});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? Colors.red.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isActive ? Colors.red.shade300 : const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                Icon(Icons.sos_rounded, color: Colors.red.shade600, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tombol Darurat',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF1A1A2E))),
                Text(
                  isSent
                      ? '✓ Sinyal dikirim ke admin'
                      : 'Kocok ponsel 5x atau tekan tombol',
                  style: TextStyle(
                    fontSize: 11,
                    color: isSent
                        ? const Color(0xFF0F6E56)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isActive ? null : onManualPress,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? Colors.red.shade100 : Colors.red.shade600,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isActive ? 'Mengirim...' : 'SOS',
                style: TextStyle(
                  color: isActive ? Colors.red.shade700 : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KosInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.apartment_rounded, color: Color(0xFF8095E4), size: 18),
              SizedBox(width: 8),
              Text('Info Kos',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(icon: Icons.home, label: AppConstants.KOS_NAME),
          const SizedBox(height: 6),
          _InfoRow(
              icon: Icons.location_on_outlined,
              label: AppConstants.KOS_ADDRESS),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF6B7280)),
        const SizedBox(width: 6),
        Expanded(
            child: Text(label,
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
      ],
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  final UserModel user;
  const _ProfileInfoCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          _DetailRow(label: 'NIK', value: user.nik ?? '-'),
          _DetailRow(label: 'Kamar', value: user.nomorKamar ?? '-'),
          _DetailRow(label: 'Alamat KTP', value: user.alamat ?? '-'),
          _DetailRow(label: 'Telepon', value: user.telepon ?? '-'),
          _DetailRow(label: 'Tanggal Masuk', value: user.tanggalMasuk ?? '-'),
          _DetailRow(
              label: 'Sewa/bulan',
              value: user.hargaSewa != null
                  ? AppValidators.formatRupiah(user.hargaSewa!)
                  : '-'),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ),
          const Text(': ', style: TextStyle(color: Color(0xFF6B7280))),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A2E))),
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _ProfileMenuItem(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF1A1A2E);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ListTile(
        leading: Icon(icon, color: c, size: 22),
        title: Text(label,
            style: TextStyle(color: c, fontWeight: FontWeight.w500)),
        trailing: Icon(Icons.chevron_right_rounded, color: c.withOpacity(0.5)),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ─── Emergency Countdown Dialog ──────────────────────────────────────────────

class _EmergencyCountdownDialog extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  const _EmergencyCountdownDialog(
      {required this.onCancel, required this.onConfirm});

  @override
  State<_EmergencyCountdownDialog> createState() =>
      _EmergencyCountdownDialogState();
}

class _EmergencyCountdownDialogState extends State<_EmergencyCountdownDialog> {
  int _countdown = 3;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _countdown--);
      if (_countdown <= 0) {
        widget.onConfirm();
        return false;
      }
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.red.shade50,
      title: const Text('🚨 DARURAT!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$_countdown',
            style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w900,
                color: Colors.red.shade700),
          ),
          const Text(
              'Sinyal darurat akan dikirim ke admin dalam hitungan mundur.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13)),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: widget.onCancel,
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.grey.shade700,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Batalkan — Ini Tidak Sengaja'),
          ),
        ),
      ],
    );
  }
}
