// lib/views/admin/tenant_detail_screen.dart

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
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);
    final payments = await _db.getPaymentsByUser(_tenant.id!);
    if (mounted) setState(() { _payments = payments; _isLoading = false; });
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
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
    final bulanCtrl = TextEditingController(
      text: '${now.year}-${now.month.toString().padLeft(2, '0')}',
    );
    final amountCtrl = TextEditingController(
      text: _tenant.hargaSewa?.toString() ?? '',
    );

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder( // ← gunakan StatefulBuilder
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Tambah Tagihan'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: bulanCtrl,
                  maxLength: 7,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')),
                    LengthLimitingTextInputFormatter(7),
                  ],
                  decoration: const InputDecoration(labelText: 'Bulan (yyyy-MM)', counterText: ''),
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
                  decoration: const InputDecoration(labelText: 'Jumlah (IDR)', counterText: ''),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8095E4), foregroundColor: Colors.white, elevation: 0),
                child: const Text('Tambah'),
              ),
            ],
          ),
        ),
      );

      if (result != true) return;

      final bulan = bulanCtrl.text.trim();
      final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;

      if (bulan.isEmpty || amount <= 0) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data tidak valid'), backgroundColor: Colors.red),
        );
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
      bulanCtrl.dispose(); // ← dispose di finally, dijamin setelah dialog tutup
      amountCtrl.dispose();
    }
  }

  Future<void> _sendTelegramReminder() async {
    final pendingPayments = _payments.where((p) => p.status == PaymentStatus.pending).toList();
    if (pendingPayments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada tagihan pending untuk dikirim.')),
      );
      return;
    }

    setState(() => _isSendingReminder = true);
    final latest = pendingPayments.first;
    final sent = await _api.sendPaymentReminder(
      tenantName: _tenant.namaLengkap ?? _tenant.username,
      bulan: latest.bulan,
      amount: latest.amount,
    );
    if (mounted) {
      setState(() => _isSendingReminder = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(sent ? '✅ Reminder dikirim ke Telegram!' : '⚠️ Gagal kirim. Cek konfigurasi Telegram.'),
        backgroundColor: sent ? const Color(0xFF1BC0BA) : Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  Future<void> _editNomorKamar() async {
    final ctrl = TextEditingController(text: _tenant.nomorKamar ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Nomor Kamar'),
        content: TextField(
          controller: ctrl,
          maxLength: 10,
          inputFormatters: [
            LengthLimitingTextInputFormatter(10),
            FilteringTextInputFormatter.deny(RegExp(r'''['";\\<>]''')),
          ],
          decoration: const InputDecoration(labelText: 'Nomor Kamar', hintText: 'cth: A1, 101, B-2', counterText: ''),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8095E4), foregroundColor: Colors.white, elevation: 0),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null) return;
    await _db.updateNomorKamar(_tenant.id!, result);
    await _refreshTenant();
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
            icon: Icon(
              _tenant.isActive ? Icons.block_rounded : Icons.check_circle_rounded,
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
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8095E4)))
          : RefreshIndicator(
              onRefresh: () async { await _loadPayments(); await _refreshTenant(); },
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
                            label: _isSendingReminder ? 'Mengirim...' : 'Kirim Reminder',
                            color: const Color(0xFF1BC0BA),
                            onTap: _isSendingReminder ? null : _sendTelegramReminder,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Riwayat Pembayaran ──
                    Row(
                      children: [
                        const Text('Riwayat Pembayaran',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                        const Spacer(),
                        Text('${_payments.length} tagihan',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
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
                            Icon(Icons.receipt_long_outlined, size: 40, color: Color(0xFF9CA3AF)),
                            SizedBox(height: 8),
                            Text('Belum ada tagihan',
                                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                          ],
                        ),
                      )
                    else
                      ...(_payments.map((p) => _PaymentItem(
                        payment: p,
                        onMarkPaid: p.status != PaymentStatus.paid ? () => _markPaid(p) : null,
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
                child: Text(
                  (tenant.namaLengkap?.isNotEmpty == true
                          ? tenant.namaLengkap![0]
                          : tenant.username[0])
                      .toUpperCase(),
                  style: const TextStyle(fontSize: 22, color: Color(0xFF8095E4), fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tenant.namaLengkap ?? '-',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1A1A2E))),
                    Text('@${tenant.username}',
                        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tenant.isActive ? const Color(0xFF1BC0BA).withOpacity(0.1) : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tenant.isActive ? 'Aktif' : 'Nonaktif',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: tenant.isActive ? const Color(0xFF0F6E56) : Colors.red.shade700,
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
            value: tenant.hargaSewa != null ? AppValidators.formatRupiah(tenant.hargaSewa!) : '-',
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const SizedBox(width: 110, child: Text('Kamar', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
              const Text(': ', style: TextStyle(color: Color(0xFF6B7280))),
              Text(
                tenant.nomorKamar ?? '-',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onEditKamar,
                child: const Icon(Icons.edit_rounded, size: 14, color: Color(0xFF8095E4)),
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
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
          const Text(': ', style: TextStyle(color: Color(0xFF6B7280))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFF1A1A2E)))),
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
  const _ActionButton({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: onTap != null ? color.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: onTap != null ? color.withOpacity(0.3) : Colors.grey.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: onTap != null ? color : Colors.grey, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
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

    Color statusColor = isPaid ? const Color(0xFF1BC0BA) : isOverdue ? Colors.red : Colors.orange;
    String statusLabel = isPaid ? 'Lunas' : isOverdue ? 'Terlambat' : 'Belum Bayar';

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
              color: statusColor, size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payment.bulan,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1A1A2E))),
                Text(AppValidators.formatRupiah(payment.amount),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
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
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
              ),
              if (!isPaid && onMarkPaid != null) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onMarkPaid,
                  child: const Text('Tandai Lunas',
                      style: TextStyle(fontSize: 10, color: Color(0xFF8095E4), fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
