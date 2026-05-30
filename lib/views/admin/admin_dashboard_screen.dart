// lib/views/admin/admin_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../services/database_helper.dart';
import '../../services/api_service.dart';
import '../../utils/validators.dart';
import '../shared/saran_kesan_screen.dart';
import 'admin_broadcast_screen.dart';
import 'admin_statistics_screen.dart';
import 'tenant_list_screen.dart';
import 'admin_chat_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;

  final GlobalKey<_AdminHomeTabState> _homeKey =
      GlobalKey<_AdminHomeTabState>();
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _AdminHomeTab(key: _homeKey),
      const TenantListScreen(),
      const AdminChatScreen(),
      const _AdminProfileTab(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          setState(() => _currentIndex = i);
          if (i == 0) {
            _homeKey.currentState?._loadStats();
          }
        },
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF8095E4).withOpacity(0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon:
                Icon(Icons.dashboard_rounded, color: Color(0xFF8095E4)),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outlined),
            selectedIcon: Icon(Icons.people_rounded, color: Color(0xFF8095E4)),
            label: 'Penghuni',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon:
                Icon(Icons.smart_toy_rounded, color: Color(0xFF8095E4)),
            label: 'Laporan & AI',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person_rounded, color: Color(0xFF8095E4)),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

// ─── Tab 1: Ringkasan Statistik ────────────────────────────────────────────────

class _AdminHomeTab extends StatefulWidget {
  const _AdminHomeTab({super.key});

  @override
  State<_AdminHomeTab> createState() => _AdminHomeTabState();
}

class _AdminHomeTabState extends State<_AdminHomeTab> {
  final _db = DatabaseHelper();
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  List<Map<String, dynamic>> _unpaidPayments = [];
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadUnpaidPayments();
  }

  Future<void> _loadUnpaidPayments() async {
    final now = DateTime.now();
    final ym = '${now.year}-${now.month.toString().padLeft(2, "0")}';
    final payments = await _db.getUnpaidPaymentsByFilter(ym, _selectedFilter);
    if (mounted) {
      setState(() => _unpaidPayments = payments);
    }
  }

  Future<void> _loadStats() async {
    final stats = await _db.getDashboardStats();
    if (mounted) {
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRefresh() async {
    await _loadStats();
    await _loadUnpaidPayments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: const Color(0xFF8095E4),
          child: CustomScrollView(
            slivers: [
              const SliverAppBar(
                expandedHeight: 100,
                floating: true,
                snap: true,
                backgroundColor: Colors.white,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  title: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selamat datang,',
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w400),
                      ),
                      Text(
                        'Administrator 👋',
                        style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF1A1A2E),
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF8095E4))),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Pendapatan bulan ini
                      _PendapatanCard(
                        pendapatan: _stats['pendapatan_bulan_ini'] as int? ?? 0,
                        bulan: _stats['bulan'] as String? ?? '',
                        tagihanPending: _stats['tagihan_pending'] as int? ?? 0,
                        diffPendapatan: _stats['diff_pendapatan'] as int? ?? 0,
                      ),
                      const SizedBox(height: 16),
                      // Grid statistik kamar
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: 'Kamar Terisi',
                              value: '${_stats['tenant_aktif'] ?? 0}',
                              icon: Icons.bed_rounded,
                              color: const Color(0xFF1BC0BA),
                              diff: _stats['diff_tenant_aktif'] as int? ?? 0,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: 'Kamar Kosong',
                              value: '${_stats['tenant_nonaktif'] ?? 0}',
                              icon: Icons.bed_outlined,
                              color: const Color(0xFF6B7280),
                              diff: _stats['diff_tenant_nonaktif'] as int? ?? 0,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: 'Total Kamar',
                              value: '${_stats['total_kamar'] ?? 15}',
                              icon: Icons.home_work_rounded,
                              color: const Color(0xFF8095E4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Tagihan Belum Dibayar Card
                      _UnpaidPaymentsCard(
                        unpaidPayments: _unpaidPayments,
                        selectedFilter: _selectedFilter,
                        onFilterChanged: (filter) {
                          setState(() => _selectedFilter = filter);
                          _loadUnpaidPayments();
                        },
                        onTenantTap: (tenant) => _showTenantDetail(context, tenant['user_id'] as int),
                        onSendReminder: _sendReminder,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Aksi Cepat',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Quick actions
                      Row(
                        children: [
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.person_add_rounded,
                              label: 'Tambah\nPenghuni',
                              color: const Color(0xFF8095E4),
                              onTap: () => Get.toNamed('/admin/add-tenant'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.search_rounded,
                              label: 'Cari\nPenghuni',
                              color: const Color(0xFF1BC0BA),
                              onTap: () {
                                // Switch ke tab penghuni
                                final state = context.findAncestorStateOfType<
                                    _AdminDashboardScreenState>();
                                state?.setState(() => state._currentIndex = 1);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.receipt_long_rounded,
                              label: 'Laporan\nAI',
                              color: const Color(0xFFFF9800),
                              onTap: () {
                                final state = context.findAncestorStateOfType<
                                    _AdminDashboardScreenState>();
                                state?.setState(() => state._currentIndex = 2);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.bar_chart_rounded,
                              label: 'Statistik Bulanan',
                              color: const Color(0xFFE91E63),
                              onTap: () => Get.to(() => const AdminStatisticsScreen()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: _QuickActionCard(
                          icon: Icons.campaign_rounded,
                          label: 'Broadcast ke\nTenant',
                          color: const Color(0xFF1BC0BA),
                          onTap: () =>
                              Get.to(() => const AdminBroadcastScreen()),
                        ),
                      ),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendReminder(Map<String, dynamic> payment) async {
    final userId = payment['user_id'] as int;
    final detail = await _db.getTenantDetailForPayment(userId);
    if (detail.isEmpty) return;

    final phone = detail['telepon'] as String? ?? '';
    if (phone.isEmpty) {
      Get.snackbar('Gagal', 'Tenant tidak memiliki nomor WhatsApp', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    final success = await ApiService().sendPaymentReminder(
      tenantName: payment['nama_lengkap'] ?? 'Tenant',
      nomorHP: phone,
      bulan: payment['bulan'] ?? '-',
      amount: payment['amount'] as int? ?? 0,
    );

    if (!success) {
      Get.snackbar('Gagal', 'Tidak dapat membuka WhatsApp', backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> _showTenantDetail(BuildContext context, int userId) async {
    final detail = await _db.getTenantDetailForPayment(userId);
    if (detail.isEmpty) return;

    if (!context.mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.8,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Detail Tenant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  )
                ],
              ),
              const SizedBox(height: 16),
              // Profil Singkat
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFF8095E4).withOpacity(0.2),
                    child: const Icon(Icons.person, color: Color(0xFF8095E4), size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(detail['nama_lengkap'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('@${detail['username'] ?? '-'}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('Kamar ${detail['nomor_kamar'] ?? '-'}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              // Riwayat Pembayaran
              const Text('Riwayat Pembayaran (6 Bulan Terakhir)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: (detail['payment_history'] as List).length,
                  itemBuilder: (context, index) {
                    final p = detail['payment_history'][index];
                    final isPaid = p['status'] == 'paid';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(p['bulan'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(AppValidators.formatRupiah(p['amount'] as int? ?? 0)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPaid ? const Color(0xFF1BC0BA).withOpacity(0.1) : const Color(0xFFFF9800).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(isPaid ? Icons.check_circle : Icons.warning_rounded, size: 14, color: isPaid ? const Color(0xFF1BC0BA) : const Color(0xFFFF9800)),
                            const SizedBox(width: 4),
                            Text(isPaid ? 'PAID' : 'PENDING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isPaid ? const Color(0xFF1BC0BA) : const Color(0xFFFF9800))),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final phone = detail['telepon'] as String? ?? '';
                        if (phone.isEmpty) {
                          Get.snackbar('Gagal', 'Tenant tidak memiliki nomor WhatsApp', backgroundColor: Colors.red, colorText: Colors.white);
                          return;
                        }
                        
                        // We take the latest unpaid payment amount
                        int amount = 0;
                        String bulan = '-';
                        final history = detail['payment_history'] as List?;
                        if (history != null && history.isNotEmpty) {
                          final unpaid = history.firstWhere((p) => p['status'] != 'paid', orElse: () => history.first);
                          amount = unpaid['amount'] as int? ?? 0;
                          bulan = unpaid['bulan'] ?? '-';
                        }

                        final success = await ApiService().sendPaymentReminder(
                          tenantName: detail['nama_lengkap'] ?? 'Tenant',
                          nomorHP: phone,
                          bulan: bulan,
                          amount: amount,
                        );

                        if (!success) {
                          Get.snackbar('Gagal', 'Tidak dapat membuka WhatsApp', backgroundColor: Colors.red, colorText: Colors.white);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1BC0BA), side: const BorderSide(color: Color(0xFF1BC0BA)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.message_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Kirim WhatsApp'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        Get.snackbar('Info', 'Fitur pembayaran akan datang!', backgroundColor: const Color(0xFF8095E4), colorText: Colors.white);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8095E4),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Tandai Bayar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Tab 4: Profil Admin ───────────────────────────────────────────────────────

class _AdminProfileTab extends StatelessWidget {
  const _AdminProfileTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title:
            const Text('Profil', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Avatar
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF8095E4).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.admin_panel_settings_rounded,
                  size: 44, color: Color(0xFF8095E4)),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Administrator',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E)),
            ),
          ),
          const Center(
            child: Text('admin', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          const SizedBox(height: 28),
          _ProfileMenuItem(
            icon: Icons.info_outline_rounded,
            label: 'Tentang Aplikasi',
            onTap: () => Get.toNamed('/about'),
          ),
          _ProfileMenuItem(
            icon: Icons.rate_review_rounded,
            label: 'Saran & Kesan TPM',
            onTap: () => Get.to(() => const SaranKesanScreen()),
          ),
          const SizedBox(height: 8),
          _ProfileMenuItem(
            icon: Icons.logout_rounded,
            label: 'Keluar',
            color: Colors.red.shade600,
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Keluar?'),
        content: const Text('Apakah kamu yakin ingin keluar dari Kostify?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              AuthController.to.logout();
            },
            child: Text('Keluar', style: TextStyle(color: Colors.red.shade600)),
          ),
        ],
      ),
    );
  }
}

// ─── Widget Components ─────────────────────────────────────────────────────────

class _PendapatanCard extends StatelessWidget {
  final int pendapatan;
  final String bulan;
  final int tagihanPending;
  final int diffPendapatan;

  const _PendapatanCard({
    required this.pendapatan,
    required this.bulan,
    required this.tagihanPending,
    this.diffPendapatan = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8095E4), Color(0xFF6B7FD7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Pendapatan Bulan Ini',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              if (diffPendapatan != 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: diffPendapatan > 0
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        diffPendapatan > 0
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        color: diffPendapatan > 0 ? Colors.greenAccent : Colors.redAccent,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        AppValidators.formatRupiah(diffPendapatan.abs()),
                        style: TextStyle(
                          color: diffPendapatan > 0 ? Colors.greenAccent : Colors.redAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            AppValidators.formatRupiah(pendapatan),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  bulan.isNotEmpty ? 'Per $bulan' : 'Bulan ini',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
              const Spacer(),
              if (tagihanPending > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$tagihanPending belum bayar',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Unpaid Payments Card ───────────────────────────────────────────────────

class _UnpaidPaymentsCard extends StatefulWidget {
  final List<Map<String, dynamic>> unpaidPayments;
  final String selectedFilter;
  final Function(String) onFilterChanged;
  final Function(Map<String, dynamic>) onTenantTap;
  final Function(Map<String, dynamic>) onSendReminder;

  const _UnpaidPaymentsCard({
    required this.unpaidPayments,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.onTenantTap,
    required this.onSendReminder,
  });

  @override
  State<_UnpaidPaymentsCard> createState() => _UnpaidPaymentsCardState();
}

class _UnpaidPaymentsCardState extends State<_UnpaidPaymentsCard> {
  Map<String, dynamic>? _selectedPayment;

  void _toggleSelectAll() {
    // Deprecated
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Filter
          Padding(
            padding: const EdgeInsets.all(20).copyWith(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tagihan Belum Dibayar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: widget.selectedFilter,
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563), fontWeight: FontWeight.w600),
                      onChanged: (v) {
                        _selectedPayment = null;
                        if (v != null) widget.onFilterChanged(v);
                      },
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Semua')),
                        DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                        DropdownMenuItem(value: 'pending', child: Text('Pending')),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          if (widget.unpaidPayments.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFF1BC0BA).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF1BC0BA)),
                    SizedBox(width: 12),
                    Text('Semua tagihan sudah lunas ✓', style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            )
          else ...[
            // List Items (Max 3)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.unpaidPayments.length > 3 ? 3 : widget.unpaidPayments.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final p = widget.unpaidPayments[i];
                final isOverdue = (p['hari_overdue'] as int? ?? 0) >= 30;
                final userId = p['user_id'] as int;
                final hari = p['hari_overdue'] as int? ?? 0;
                
                return InkWell(
                  onTap: () => widget.onTenantTap(p),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Row(
                      children: [
                        Radio<Map<String, dynamic>>(
                          value: p,
                          groupValue: _selectedPayment,
                          onChanged: (val) {
                            setState(() {
                              _selectedPayment = val;
                            });
                          },
                          activeColor: const Color(0xFF1BC0BA),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p['nama_lengkap'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text(AppValidators.formatRupiah(p['amount'] as int? ?? 0), style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(4)),
                              child: Text('Kamar ${p['nomor_kamar'] ?? '-'}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isOverdue ? const Color(0xFFFF6B6B).withOpacity(0.1) : const Color(0xFFFF9800).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(isOverdue ? '🔴 OVERDUE (${hari}h)' : '🟡 PENDING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isOverdue ? const Color(0xFFFF6B6B) : const Color(0xFFFF9800))),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                  ),
                );
              },
            ),
            
            const Divider(height: 1),
            // Footer Actions
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  if (_selectedPayment != null)
                    ElevatedButton.icon(
                      onPressed: () => widget.onSendReminder(_selectedPayment!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1BC0BA),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.message_rounded, size: 16),
                      label: const Text('Kirim WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  const Spacer(),
                  if (widget.unpaidPayments.length > 3)
                    TextButton(
                      onPressed: () => Get.toNamed('/admin/statistics'),
                      child: const Text('View All →', style: TextStyle(color: Color(0xFF8095E4), fontWeight: FontWeight.bold, fontSize: 12)),
                    )
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }
}


class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final int? diff;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.diff,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              if (diff != null && diff != 0)
                Row(
                  children: [
                    Icon(
                      diff! > 0 ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
                      color: diff! > 0 ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    Text(
                      diff!.abs().toString(),
                      style: TextStyle(
                        color: diff! > 0 ? Colors.green : Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ProfileMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF1A1A2E);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
