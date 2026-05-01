// lib/services/chat_context_service.dart

import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/payment_model.dart';
import '../utils/constants.dart';
import '../utils/validators.dart';
import 'database_helper.dart';

class ChatContextService {
  static final ChatContextService _instance = ChatContextService._internal();
  factory ChatContextService() => _instance;
  ChatContextService._internal();

  final _db = DatabaseHelper();

  /// Siapkan konteks untuk Admin ChatBot - dengan data detail tentang tenants dan pembayaran
  Future<String> getAdminChatContext() async {
    try {
      final stats = await _db.getDashboardStats();
      final allTenants = await _db.getAllTenants();
      
      // Hitung payment details
      final paymentDetails = await _getPaymentDetails();
      
      // Hitung income trend (3 bulan terakhir)
      final incomeTrend = await _getIncomeTrend();
      
      // Format tenant list dengan status pembayaran
      final tenantInfo = await _formatTenantPaymentInfo(allTenants);

      final context = '''
Kamu adalah KosBot, asisten AI untuk sistem manajemen kos bernama Kostify.

=== INFORMASI KOS ===
Nama: ${AppConstants.KOS_NAME}
Alamat: ${AppConstants.KOS_ADDRESS}
Total Kamar: ${stats['total_kamar']} kamar
Total Penghuni: ${stats['total_tenant']} orang

=== STATUS PENGHUNI SAAT INI ===
Penghuni Aktif: ${stats['tenant_aktif']} orang
Penghuni Nonaktif: ${stats['tenant_nonaktif']} orang

=== INFORMASI PEMBAYARAN BULAN INI (${stats['bulan']}) ===
Total Pendapatan: ${AppValidators.formatRupiah(stats['pendapatan_bulan_ini'] as int? ?? 0)}
Tagihan Pending: ${stats['tagihan_pending']} tagihan
Status: ${paymentDetails['summary']}

=== DETAIL PEMBAYARAN PENGHUNI ===
${tenantInfo['details']}

=== ANALISIS PEMBAYARAN ===
- Sudah Bayar: ${paymentDetails['paid_count']} penghuni
- Belum Bayar: ${paymentDetails['pending_count']} penghuni
- Terlambat: ${paymentDetails['overdue_count']} penghuni
- Total Tagihan Pending: ${AppValidators.formatRupiah(paymentDetails['pending_amount'] as int? ?? 0)}

=== TREND PENDAPATAN (3 BULAN TERAKHIR) ===
${incomeTrend}

=== INSTRUKSI ===
1. Ketika ditanya "siapa yang belum bayar", berikan DAFTAR SPESIFIK nama penghuni dengan status mereka
2. Ketika ditanya tentang pendapatan, berikan RINCIAN berapa dari siapa dan breakdown per tenant
3. Ketika ditanya tentang statistik, gunakan data yang tersedia di atas
4. Jawab SELALU dengan data SPESIFIK dan RINCIAN, bukan jawaban umum
5. Gunakan Bahasa Indonesia yang profesional dan ramah
6. Jika ada pertanyaan teknis tentang sistem, jawab dengan helpful
''';

      return context;
    } catch (e) {
      return _getFallbackAdminContext();
    }
  }

  /// Siapkan konteks untuk Tenant ChatBot - dengan data personal mereka
  Future<String> getTenantChatContext(int userId) async {
    try {
      final tenant = await _db.getUserById(userId);
      if (tenant == null) return _getFallbackTenantContext();

      final payments = await _db.getPaymentsByUser(userId);
      final latestPayment = await _db.getLatestPayment(userId);
      
      // Format payment history
      final paymentHistory = _formatPaymentHistory(payments);
      
      // Hitung statistik personal
      final stats = _calculateTenantStats(payments);

      final context = '''
Kamu adalah KosBot, asisten AI asistan personal untuk penghuni kos Kostify.

=== INFORMASI KOS ===
Nama Kos: ${AppConstants.KOS_NAME}
Alamat: ${AppConstants.KOS_ADDRESS}

=== INFORMASI PENGHUNI ===
Nama: ${tenant.namaLengkap}
Kamar: ${tenant.nomorKamar ?? 'N/A'}
Biaya Sewa Bulanan: ${AppValidators.formatRupiah(tenant.hargaSewa ?? 0)}
Telepon: ${tenant.telepon ?? '-'}
Tanggal Masuk: ${tenant.tanggalMasuk ?? '-'}

=== STATUS PEMBAYARAN SAAT INI ===
Status Terakhir: ${latestPayment?.status.label ?? 'Belum ada'}
Bulan: ${latestPayment?.bulan ?? 'N/A'}
Jumlah: ${AppValidators.formatRupiah(latestPayment?.amount ?? 0)}
${latestPayment?.paidAt != null ? 'Dibayar Tanggal: ${DateFormat('dd MMM yyyy', 'id_ID').format(latestPayment!.paidAt!)}' : ''}

=== RIWAYAT PEMBAYARAN ===
${paymentHistory}

=== STATISTIK PEMBAYARAN ===
${stats}

=== INSTRUKSI ===
1. Jawab pertanyaan tentang BIAYA SEWA mereka dengan SPESIFIK
2. Berikan UPDATE terkini tentang status pembayaran mereka
3. Jika ditanya "berapa biaya", katakan PASTI: "Rp ${AppValidators.formatRupiah(tenant.hargaSewa ?? 0)} per bulan"
4. Ingatkan tentang pembayaran yang pending jika ada
5. Gunakan Bahasa Indonesia yang ramah dan santai
6. Jika ada pertanyaan umum tentang kos, jawab dengan helpful
''';

      return context;
    } catch (e) {
      return _getFallbackTenantContext();
    }
  }

  /// Dapatkan detail payment status untuk semua penghuni
  Future<Map<String, dynamic>> _getPaymentDetails() async {
    try {
      final allTenants = await _db.getAllTenants();
      int paidCount = 0, pendingCount = 0, overdueCount = 0;
      int pendingAmount = 0;
      
      final now = DateTime.now();
      final bulanIni = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      for (var tenant in allTenants) {
        final payment = await _db.getPaymentByUserAndBulan(tenant.id!, bulanIni);
        if (payment != null) {
          if (payment.status == PaymentStatus.paid) paidCount++;
          else if (payment.status == PaymentStatus.pending) {
            pendingCount++;
            pendingAmount += payment.amount;
          } else if (payment.status == PaymentStatus.overdue) {
            overdueCount++;
            pendingAmount += payment.amount;
          }
        }
      }

      return {
        'paid_count': paidCount,
        'pending_count': pendingCount,
        'overdue_count': overdueCount,
        'pending_amount': pendingAmount,
        'summary': pendingCount > 0 || overdueCount > 0
            ? '$pendingCount pending + $overdueCount terlambat = ${pendingCount + overdueCount} belum bayar'
            : 'Semua penghuni sudah bayar ✓',
      };
    } catch (e) {
      return {
        'paid_count': 0,
        'pending_count': 0,
        'overdue_count': 0,
        'pending_amount': 0,
        'summary': 'Tidak dapat memuat data',
      };
    }
  }

  /// Format informasi tenant dengan status pembayaran mereka
  Future<Map<String, String>> _formatTenantPaymentInfo(List<UserModel> tenants) async {
    try {
      final now = DateTime.now();
      final bulanIni = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      
      final details = <String>[];
      
      for (var tenant in tenants) {
        final payment = await _db.getPaymentByUserAndBulan(tenant.id!, bulanIni);
        final status = payment?.status.label ?? 'Tidak ada tagihan';
        final statusIcon = payment != null 
            ? (payment.status == PaymentStatus.paid ? '✓' : payment.status == PaymentStatus.pending ? '⏳' : '⚠️')
            : '?';
        
        details.add('$statusIcon ${tenant.namaLengkap} (${tenant.nomorKamar}) - $status');
      }

      return {
        'details': details.join('\n'),
      };
    } catch (e) {
      return {'details': 'Tidak dapat memuat detail penghuni'};
    }
  }

  /// Hitung trend pendapatan 3 bulan terakhir
  Future<String> _getIncomeTrend() async {
    try {
      final trend = <String>[];
      final now = DateTime.now();
      final db = await _db.database;
      
      for (int i = 2; i >= 0; i--) {
        final date = DateTime(now.year, now.month - i, 1);
        final bulan = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        
        final result = await db.rawQuery(
          "SELECT COALESCE(SUM(amount), 0) as total FROM payments WHERE status = 'paid' AND paid_at LIKE ?",
          ['$bulan%'],
        );
        final income = (result.first['total'] as int?) ?? 0;
        final bulanName = DateFormat('MMMM yyyy', 'id_ID').format(date);
        
        trend.add('$bulanName: ${AppValidators.formatRupiah(income)}');
      }
      
      return trend.join('\n');
    } catch (e) {
      return 'Tidak dapat memuat trend pendapatan';
    }
  }

  /// Format riwayat pembayaran penghuni
  String _formatPaymentHistory(List<PaymentModel> payments) {
    if (payments.isEmpty) {
      return '(Belum ada riwayat pembayaran)';
    }

    final recent = payments.take(6).toList(); // Ambil 6 terbaru
    final lines = <String>[];
    
    for (var p in recent) {
      final icon = p.status == PaymentStatus.paid ? '✓' : p.status == PaymentStatus.pending ? '⏳' : '⚠️';
      lines.add('$icon ${p.bulan}: ${AppValidators.formatRupiah(p.amount)} - ${p.status.label}');
    }
    
    return lines.join('\n');
  }

  /// Hitung statistik pembayaran personal
  String _calculateTenantStats(List<PaymentModel> payments) {
    if (payments.isEmpty) return 'Belum ada riwayat pembayaran.';

    final paid = payments.where((p) => p.status == PaymentStatus.paid).length;
    final pending = payments.where((p) => p.status == PaymentStatus.pending).length;
    final overdue = payments.where((p) => p.status == PaymentStatus.overdue).length;
    
    final totalPaid = payments
        .where((p) => p.status == PaymentStatus.paid)
        .fold<int>(0, (sum, p) => sum + p.amount);

    return '''Total Riwayat: ${payments.length} bulan
Sudah Bayar: $paid bulan
Belum Bayar: $pending bulan
Terlambat: $overdue bulan
Total Dibayar: ${AppValidators.formatRupiah(totalPaid)}''';
  }

  /// Fallback context untuk admin jika terjadi error
  String _getFallbackAdminContext() {
    return '''
Kamu adalah KosBot, asisten AI untuk sistem manajemen kos Kostify.
Nama Kos: ${AppConstants.KOS_NAME}
Alamat: ${AppConstants.KOS_ADDRESS}

Maaf, terjadi kesalahan saat memuat data. Berikan informasi umum tentang kos dan coba bantu dengan yang terbaik.
''';
  }

  /// Fallback context untuk tenant jika terjadi error
  String _getFallbackTenantContext() {
    return '''
Kamu adalah KosBot, asisten AI untuk penghuni kos Kostify.
Alamat Kos: ${AppConstants.KOS_ADDRESS}

Maaf, terjadi kesalahan saat memuat data pribadi. Berikan jawaban umum tentang kos dengan friendly.
''';
  }
}
