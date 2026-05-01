// lib/views/admin/tenant_detail_screen.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../models/user_model.dart';
import '../../models/payment_model.dart';
import '../../services/database_helper.dart';
import '../../services/api_service.dart';
import '../../utils/validators.dart';
import '../../utils/constants.dart';

class TenantDetailScreen extends StatefulWidget {
  const TenantDetailScreen({super.key});

  @override
  State<TenantDetailScreen> createState() => _TenantDetailScreenState();
}

class _TenantDetailScreenState extends State<TenantDetailScreen> {
  final _db = DatabaseHelper();
  final _api = ApiService();

  late UserModel _tenant;
  List<PaymentModel> _payments = [];
  bool _isLoading = true;
  bool _isSendingReminder = false;

  @override
  void initState() {
    super.initState();
    _tenant = Get.arguments as UserModel;
    _refreshTenant();
    _loadPayments();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncMidtransPayments();
    });
  }

  Future<void> _syncMidtransPayments() async {
    final payments = await _db.getPaymentsByUser(_tenant.id!);
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
    if (hasUpdate) {
      _loadPayments();
    }
  }

  Future<void> _loadPayments() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final payments = await _db.getPaymentsByUser(_tenant.id!);
    if (!mounted) return;
    setState(() {
      _payments = payments;
      _isLoading = false;
    });
  }

  Future<void> _refreshTenant() async {
    final updated = await _db.getUserById(_tenant.id!);
    if (updated != null && mounted) setState(() => _tenant = updated);
  }

  Future<void> _markPaid(PaymentModel payment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tandai Lunas?'),
        content: Text(
          'Tandai pembayaran bulan ${payment.bulan} sebagai LUNAS?\n\n'
          '${AppValidators.formatRupiah(payment.amount)}',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1BC0BA),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Tandai Lunas'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _db.updatePaymentStatus(payment.id!, PaymentStatus.paid);
    _loadPayments();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Pembayaran bulan ${payment.bulan} ditandai lunas.'),
        backgroundColor: const Color(0xFF1BC0BA),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  Future<void> _addPayment() async {
    final now = DateTime.now();
    DateTime selectedBillingDate = DateTime(now.year, now.month, 1);
    String selectedBulan =
        '${selectedBillingDate.year}-${selectedBillingDate.month.toString().padLeft(2, '0')}';
    final amountCtrl = TextEditingController(
      text: _tenant.hargaSewa?.toString() ?? '',
    );

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Tambah Tagihan'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    FocusManager.instance.primaryFocus?.unfocus();
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedBillingDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked == null) return;
                    selectedBillingDate = DateTime(picked.year, picked.month, 1);
                    selectedBulan =
                        '${selectedBillingDate.year}-${selectedBillingDate.month.toString().padLeft(2, '0')}';
                    if (!ctx.mounted) return;
                    setDialogState(() {});
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Tanggal Tagihan *',
                      hintText: 'Pilih dengan kalender',
                      prefixIcon: Icon(Icons.calendar_month_rounded),
                    ),
                    child: Text(
                      selectedBulan,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 12,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(12),
                  ],
                  decoration: const InputDecoration(
                      labelText: 'Jumlah (IDR)', counterText: ''),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Batal')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8095E4),
                    foregroundColor: Colors.white,
                    elevation: 0),
                child: const Text('Tambah'),
              ),
            ],
          ),
        ),
      );

      if (result != true) return;

      final bulan = selectedBulan.trim();
      final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;

      if (bulan.isEmpty || amount <= 0) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Data tidak valid'), backgroundColor: Colors.red),
          );
        return;
      }

      if (_tenant.tanggalMasuk != null) {
        final masukDate = DateTime.tryParse(_tenant.tanggalMasuk!);
        if (masukDate != null) {
          final masukBulanStr = '${masukDate.year}-${masukDate.month.toString().padLeft(2, '0')}';
          if (bulan.compareTo(masukBulanStr) < 0) {
             if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(
                   content: Text('Tidak dapat menambah tagihan sebelum bulan tanggal masuk.'),
                   backgroundColor: Colors.red,
                 ),
               );
             }
             return;
          }
        }
      }

      // Validasi apakah tagihan untuk bulan tersebut sudah ada
      final exists = await _db.isPaymentExists(_tenant.id!, bulan);
      if (exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tagihan untuk bulan tersebut sudah ada.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      await _db.createPayment(PaymentModel(
        userId: _tenant.id!,
        amount: amount,
        status: PaymentStatus.pending,
        bulan: bulan,
        createdAt: DateTime.now(),
      ));
      _loadPayments();
    } finally {
      amountCtrl.dispose();
    }
  }

  Future<void> _sendTelegramReminder() async {
    final pendingPayments =
        _payments.where((p) => p.status == PaymentStatus.pending).toList();
    if (pendingPayments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Tidak ada tagihan pending untuk dikirim.')),
      );
      return;
    }

    setState(() => _isSendingReminder = true);
    final latest = pendingPayments.first;
    final sent = await _api.sendPaymentReminder(
      nomorHP: _tenant.telepon ?? '',
      tenantName: _tenant.namaLengkap ?? _tenant.username,
      bulan: latest.bulan,
      amount: latest.amount,
    );
    if (mounted) {
      setState(() => _isSendingReminder = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(sent
            ? '✅ WhatsApp dibuka untuk kirim reminder!'
            : '⚠️ Gagal buka WhatsApp. Cek nomor HP tenant.'),
        backgroundColor:
            sent ? const Color(0xFF1BC0BA) : Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  Future<void> _editNomorKamar() async {
    final availableRooms = await _db.getAvailableRooms();
    const allRooms = AppConstants.ROOM_LABELS;
    final currentRoom = (_tenant.nomorKamar ?? '').trim();

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
                      final borderColor =
                          isSelected ? primary : (canSelect ? success : danger);
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
                  elevation: 0),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (result == null || result == currentRoom) return;
    await _db.updateNomorKamar(_tenant.id!, result);
    await _refreshTenant();
  }

  Future<void> _deleteTenant() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Pengguna?'),
        content: Text(
          'Akun ${_tenant.namaLengkap ?? _tenant.username} akan dihapus permanen, termasuk data tagihan terkait.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final deleted = await _db.deleteTenant(_tenant.id!);
    if (!mounted) return;

    if (deleted > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Pengguna ${_tenant.namaLengkap ?? _tenant.username} berhasil dihapus.'),
          backgroundColor: const Color(0xFF1BC0BA),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      Get.back(result: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Gagal menghapus pengguna.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(_tenant.namaLengkap ?? _tenant.username,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Color(0xFF8095E4)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_rounded, color: Colors.red),
            tooltip: 'Hapus Pengguna',
            onPressed: _deleteTenant,
          ),
          IconButton(
            icon: Icon(
              _tenant.isActive
                  ? Icons.block_rounded
                  : Icons.check_circle_rounded,
              color: _tenant.isActive ? Colors.red : Colors.green,
            ),
            tooltip: _tenant.isActive ? 'Nonaktifkan' : 'Aktifkan',
            onPressed: () async {
              await _db.toggleTenantStatus(_tenant.id!, !_tenant.isActive);
              await _refreshTenant();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8095E4)))
          : RefreshIndicator(
              onRefresh: () async {
                await _syncMidtransPayments();
                await _loadPayments();
                await _refreshTenant();
              },
              color: const Color(0xFF8095E4),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Info Card ──
                    _InfoCard(tenant: _tenant, onEditKamar: _editNomorKamar),
                    const SizedBox(height: 16),

                    // ── Actions ──
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.add_circle_rounded,
                            label: 'Tambah Tagihan',
                            color: const Color(0xFF8095E4),
                            onTap: _addPayment,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.send_rounded,
                            label: _isSendingReminder
                                ? 'Mengirim...'
                                : 'Kirim Reminder',
                            color: const Color(0xFF1BC0BA),
                            onTap: _isSendingReminder
                                ? null
                                : _sendTelegramReminder,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Riwayat Pembayaran ──
                    Row(
                      children: [
                        const Text('Riwayat Pembayaran',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A2E))),
                        const Spacer(),
                        Text('${_payments.length} tagihan',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF6B7280))),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (_payments.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 40, color: Color(0xFF9CA3AF)),
                            SizedBox(height: 8),
                            Text('Belum ada tagihan',
                                style: TextStyle(
                                    color: Color(0xFF6B7280), fontSize: 13)),
                          ],
                        ),
                      )
                    else
                      ...(_payments.map((p) => _PaymentItem(
                            payment: p,
                            onMarkPaid: p.status != PaymentStatus.paid
                                ? () => _markPaid(p)
                                : null,
                          ))),
                  ],
                ),
              ),
            ),
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final UserModel tenant;
  final VoidCallback onEditKamar;
  const _InfoCard({required this.tenant, required this.onEditKamar});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF8095E4).withOpacity(0.12),
                backgroundImage: tenant.fotoProfilPath != null &&
                        tenant.fotoProfilPath!.trim().isNotEmpty &&
                        File(tenant.fotoProfilPath!).existsSync()
                    ? FileImage(File(tenant.fotoProfilPath!))
                    : null,
                child: (tenant.fotoProfilPath == null ||
                        tenant.fotoProfilPath!.trim().isEmpty ||
                        !File(tenant.fotoProfilPath!).existsSync())
                    ? Text(
                        (tenant.namaLengkap?.isNotEmpty == true
                                ? tenant.namaLengkap![0]
                                : tenant.username[0])
                            .toUpperCase(),
                        style: const TextStyle(
                            fontSize: 22,
                            color: Color(0xFF8095E4),
                            fontWeight: FontWeight.w700),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tenant.namaLengkap ?? '-',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF1A1A2E))),
                    Text('@${tenant.username}',
                        style: const TextStyle(
                            color: Color(0xFF6B7280), fontSize: 12)),
                  ],
                ),
              ),
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
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _Row(label: 'NIK', value: tenant.nik ?? '-'),
          _Row(label: 'Telepon', value: tenant.telepon ?? '-'),
          _Row(label: 'Alamat', value: tenant.alamat ?? '-'),
          _Row(label: 'Tanggal Masuk', value: tenant.tanggalMasuk ?? '-'),
          _Row(
            label: 'Sewa/bulan',
            value: tenant.hargaSewa != null
                ? AppValidators.formatRupiah(tenant.hargaSewa!)
                : '-',
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const SizedBox(
                  width: 110,
                  child: Text('Kamar',
                      style:
                          TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
              const Text(': ', style: TextStyle(color: Color(0xFF6B7280))),
              Text(
                tenant.nomorKamar ?? '-',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E)),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onEditKamar,
                child: const Icon(Icons.edit_rounded,
                    size: 14, color: Color(0xFF8095E4)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 110,
              child: Text(label,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
          const Text(': ', style: TextStyle(color: Color(0xFF6B7280))),
          Expanded(
              child: Text(value,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF1A1A2E)))),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _ActionButton(
      {required this.icon,
      required this.label,
      required this.color,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: onTap != null ? color.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: onTap != null
                  ? color.withOpacity(0.3)
                  : Colors.grey.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: onTap != null ? color : Colors.grey, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: onTap != null ? color : Colors.grey,
                )),
          ],
        ),
      ),
    );
  }
}

class _PaymentItem extends StatelessWidget {
  final PaymentModel payment;
  final VoidCallback? onMarkPaid;
  const _PaymentItem({required this.payment, this.onMarkPaid});

  @override
  Widget build(BuildContext context) {
    final isPaid = payment.status == PaymentStatus.paid;
    final isOverdue = payment.status == PaymentStatus.overdue;

    Color statusColor = isPaid
        ? const Color(0xFF1BC0BA)
        : isOverdue
            ? Colors.red
            : Colors.orange;
    String statusLabel = isPaid
        ? 'Lunas'
        : isOverdue
            ? 'Terlambat'
            : 'Belum Bayar';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
              color: statusColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payment.bulan,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF1A1A2E))),
                Text(AppValidators.formatRupiah(payment.amount),
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(statusLabel,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statusColor)),
              ),
              if (!isPaid && onMarkPaid != null) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onMarkPaid,
                  child: const Text('Tandai Lunas',
                      style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF8095E4),
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
