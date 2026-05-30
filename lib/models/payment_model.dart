// lib/models/payment_model.dart

enum PaymentStatus { paid, pending, overdue }

extension PaymentStatusExtension on PaymentStatus {
  String get label {
    switch (this) {
      case PaymentStatus.paid:
        return 'Lunas';
      case PaymentStatus.pending:
        return 'Belum Bayar';
      case PaymentStatus.overdue:
        return 'Terlambat';
    }
  }

  String get value {
    switch (this) {
      case PaymentStatus.paid:
        return 'paid';
      case PaymentStatus.pending:
        return 'pending';
      case PaymentStatus.overdue:
        return 'overdue';
    }
  }

  static PaymentStatus fromString(String s) {
    switch (s) {
      case 'paid':
        return PaymentStatus.paid;
      case 'overdue':
        return PaymentStatus.overdue;
      default:
        return PaymentStatus.pending;
    }
  }
}

class PaymentModel {
  final int? id;
  final int userId;
  final int amount;
  final PaymentStatus status;
  final String bulan;   // format: 'yyyy-MM' (misal '2025-06')
  final DateTime? createdAt;
  final DateTime? paidAt;
  final String? keterangan;
  final String? orderId;   // Midtrans Order ID
  final String? snapUrl;   // Midtrans Snap URL

  final String? userName;
  final String? nomorKamar;

  const PaymentModel({
    this.id,
    required this.userId,
    required this.amount,
    required this.status,
    required this.bulan,
    this.createdAt,
    this.paidAt,
    this.keterangan,
    this.orderId,
    this.snapUrl,
    this.userName,
    this.nomorKamar,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'amount': amount,
      'status': status.value,
      'bulan': bulan,
      'created_at': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'paid_at': paidAt?.toIso8601String(),
      'keterangan': keterangan,
      'order_id': orderId,
      'snap_url': snapUrl,
    };
  }

  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      id: map['id'] as int?,
      userId: map['user_id'] as int? ?? 0,
      amount: map['amount'] as int? ?? 0,
      status: PaymentStatusExtension.fromString(map['status'] as String? ?? 'pending'),
      bulan: map['bulan'] as String? ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      paidAt: map['paid_at'] != null
          ? DateTime.tryParse(map['paid_at'] as String)
          : null,
      keterangan: map['keterangan'] as String?,
      orderId: map['order_id'] as String?,
      snapUrl: map['snap_url'] as String?,
      userName: map['user_name'] as String?,
      nomorKamar: map['nomor_kamar'] as String?,
    );
  }

  PaymentModel copyWith({
    int? id,
    int? userId,
    int? amount,
    PaymentStatus? status,
    String? bulan,
    DateTime? createdAt,
    DateTime? paidAt,
    String? keterangan,
    String? orderId,
    String? snapUrl,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      bulan: bulan ?? this.bulan,
      createdAt: createdAt ?? this.createdAt,
      paidAt: paidAt ?? this.paidAt,
      keterangan: keterangan ?? this.keterangan,
      orderId: orderId ?? this.orderId,
      snapUrl: snapUrl ?? this.snapUrl,
    );
  }
}
