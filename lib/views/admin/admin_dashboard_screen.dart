// lib/views/admin/admin_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../services/database_helper.dart';
import '../../utils/validators.dart';
import '../shared/saran_kesan_screen.dart';
import 'admin_broadcast_screen.dart';
import 'tenant_list_screen.dart';
import 'admin_chat_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;

  final GlobalKey<_AdminHomeTabState> _homeKey = GlobalKey<_AdminHomeTabState>();
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

  @override
  void initState() {
    super.initState();
    _loadStats();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadStats,
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
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: 'Kamar Kosong',
                              value: '${_stats['tenant_nonaktif'] ?? 0}',
                              icon: Icons.bed_outlined,
                              color: const Color(0xFF6B7280),
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

  const _PendapatanCard({
    required this.pendapatan,
    required this.bulan,
    required this.tagihanPending,
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
          const Text('Pendapatan Bulan Ini',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
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
                    color: Colors.orange.shade400.withOpacity(0.8),
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

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
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
          Icon(icon, color: color, size: 24),
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
