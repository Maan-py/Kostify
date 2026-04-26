// lib/views/admin/tenant_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../models/user_model.dart';
import '../../services/database_helper.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';

class TenantListScreen extends StatefulWidget {
  const TenantListScreen({super.key});

  @override
  State<TenantListScreen> createState() => _TenantListScreenState();
}

class _TenantListScreenState extends State<TenantListScreen> {
  final _db = DatabaseHelper();
  final _searchCtrl = TextEditingController();

  List<UserModel> _tenants = [];
  bool _isLoading = false;
  bool? _filterActive; // null = semua, true = aktif, false = nonaktif

  @override
  void initState() {
    super.initState();
    _loadTenants();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTenants() async {
    setState(() => _isLoading = true);
    List<UserModel> result;

    final query = _searchCtrl.text.trim();
    if (query.isNotEmpty) {
      result = await _db.searchTenants(query);
      if (_filterActive != null) {
        result = result.where((t) => t.isActive == _filterActive).toList();
      }
    } else {
      result = await _db.getAllTenants(isActive: _filterActive);
    }

    if (mounted)
      setState(() {
        _tenants = result;
        _isLoading = false;
      });
  }

  Future<void> _toggleStatus(UserModel tenant) async {
    final newStatus = !tenant.isActive;
    final label = newStatus ? 'mengaktifkan' : 'menonaktifkan';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${newStatus ? 'Aktifkan' : 'Nonaktifkan'} Akun?'),
        content: Text(
          'Kamu akan $label akun ${tenant.namaLengkap ?? tenant.username}.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              newStatus ? 'Aktifkan' : 'Nonaktifkan',
              style: TextStyle(color: newStatus ? Colors.green : Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _db.toggleTenantStatus(tenant.id!, newStatus);
    _loadTenants();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Akun ${tenant.namaLengkap ?? tenant.username} berhasil ${newStatus ? 'diaktifkan' : 'dinonaktifkan'}.',
          ),
          backgroundColor:
              newStatus ? Colors.green.shade700 : Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _editNomorKamar(UserModel tenant) async {
    final availableRooms = await _db.getAvailableRooms();
    const allRooms = AppConstants.ROOM_LABELS;
    final currentRoom = (tenant.nomorKamar ?? '').trim();

    final selectableRooms = {
      ...availableRooms,
      if (currentRoom.isNotEmpty) currentRoom,
    };

    if (selectableRooms.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada kamar yang tersedia.')),
        );
      }
      return;
    }

    String selectedRoom =
        currentRoom.isNotEmpty ? currentRoom : availableRooms.first;

    final primary = Color(AppColors.primaryColor.toInt);
    final success = Color(AppColors.successColor.toInt);
    final danger = Color(AppColors.dangerColor.toInt);

    if (!mounted) return;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Nomor Kamar'),
          content: SizedBox(
            width: 340,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Pilih kamar dari visual mapping (13 kamar).',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(AppColors.textSecondary.toInt),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allRooms.map((room) {
                      final isCurrent = room == currentRoom;
                      final canSelect = selectableRooms.contains(room);
                      final isSelected = selectedRoom == room;

                        final bgColor = canSelect
                            ? success.withOpacity(0.12)
                            : danger.withOpacity(0.12);
                        final borderColor = isSelected
                          ? primary
                            : (canSelect ? success : danger);
                          final textColor = canSelect ? success : danger;

                      return InkWell(
                        onTap: canSelect
                            ? () => setDialogState(() => selectedRoom = room)
                            : null,
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 70,
                          height: 68,
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 8),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: borderColor,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      canSelect
                                          ? Icons.check_circle_rounded
                                          : Icons.block_rounded,
                                      size: 16,
                                      color: canSelect
                                          ? success.withOpacity(0.9)
                                          : danger.withOpacity(0.9),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      room,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isCurrent)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Icon(
                                    Icons.bookmark_rounded,
                                    size: 12,
                                    color: primary.withOpacity(0.95),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, selectedRoom),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8095E4),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (result == null || result == currentRoom) return;

    await _db.updateNomorKamar(tenant.id!, result);
    _loadTenants();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Manajemen Penghuni',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon:
                const Icon(Icons.person_add_rounded, color: Color(0xFF8095E4)),
            tooltip: 'Tambah Penghuni',
            onPressed: () async {
              await Get.toNamed('/admin/add-tenant');
              _loadTenants();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search + Filter
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchCtrl,
                  maxLength: 50,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(50),
                    FilteringTextInputFormatter.deny(RegExp(r'''['";\\<>]''')),
                  ],
                  onChanged: (_) => _loadTenants(),
                  decoration: InputDecoration(
                    hintText: 'Cari nama, NIK, username...',
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Color(0xFF8095E4)),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchCtrl.clear();
                              _loadTenants();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF5F6FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),
                // Filter chips
                Row(
                  children: [
                    _FilterChip(
                      label: 'Semua',
                      selected: _filterActive == null,
                      onTap: () => setState(() {
                        _filterActive = null;
                        _loadTenants();
                      }),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Aktif',
                      selected: _filterActive == true,
                      color: const Color(0xFF1BC0BA),
                      onTap: () => setState(() {
                        _filterActive = true;
                        _loadTenants();
                      }),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Nonaktif',
                      selected: _filterActive == false,
                      color: Colors.red.shade600,
                      onTap: () => setState(() {
                        _filterActive = false;
                        _loadTenants();
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF8095E4)))
                : _tenants.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _loadTenants,
                        color: const Color(0xFF8095E4),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _tenants.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (ctx, i) => _TenantCard(
                            tenant: _tenants[i],
                            onToggleStatus: () => _toggleStatus(_tenants[i]),
                            onEditKamar: () => _editNomorKamar(_tenants[i]),
                            onDetail: () => Get.toNamed('/admin/tenant-detail',
                                arguments: _tenants[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            _searchCtrl.text.isNotEmpty
                ? 'Penghuni tidak ditemukan'
                : 'Belum ada penghuni',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          ),
          if (_searchCtrl.text.isEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                await Get.toNamed('/admin/add-tenant');
                _loadTenants();
              },
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('Tambah Penghuni'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8095E4),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Tenant Card ───────────────────────────────────────────────────────────────

class _TenantCard extends StatelessWidget {
  final UserModel tenant;
  final VoidCallback onToggleStatus;
  final VoidCallback onEditKamar;
  final VoidCallback onDetail;

  const _TenantCard({
    required this.tenant,
    required this.onToggleStatus,
    required this.onEditKamar,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: InkWell(
        onTap: onDetail,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFF8095E4).withOpacity(0.12),
                    child: Text(
                      (tenant.namaLengkap?.isNotEmpty == true
                              ? tenant.namaLengkap![0]
                              : tenant.username[0])
                          .toUpperCase(),
                      style: const TextStyle(
                          color: Color(0xFF8095E4),
                          fontWeight: FontWeight.w700,
                          fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tenant.namaLengkap ?? tenant.username,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF1A1A2E),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${tenant.username}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: tenant.isActive
                          ? const Color(0xFF1BC0BA).withOpacity(0.1)
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tenant.isActive ? 'Aktif' : 'Nonaktif',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: tenant.isActive
                            ? const Color(0xFF0F6E56)
                            : Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFF3F4F6)),
              const SizedBox(height: 10),
              // Info row
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.bedroom_parent_rounded,
                    label: 'Kamar: ${tenant.nomorKamar ?? '-'}',
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.payments_rounded,
                    label: tenant.hargaSewa != null
                        ? AppValidators.formatRupiah(tenant.hargaSewa!)
                        : '-',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onEditKamar,
                    icon: const Icon(Icons.edit_rounded, size: 14),
                    label: const Text('Edit Kamar',
                        style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF8095E4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: onToggleStatus,
                    icon: Icon(
                      tenant.isActive
                          ? Icons.block_rounded
                          : Icons.check_circle_rounded,
                      size: 14,
                    ),
                    label: Text(
                      tenant.isActive ? 'Nonaktifkan' : 'Aktifkan',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          tenant.isActive ? Colors.red.shade600 : Colors.green,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: const Color(0xFF6B7280)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label,
      required this.selected,
      this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF8095E4);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.12) : const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c : const Color(0xFFE5E7EB)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? c : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}
