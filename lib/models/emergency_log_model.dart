// lib/models/emergency_log_model.dart

class EmergencyLogModel {
  final int? id;
  final int userId;
  final String message;
  final DateTime timestamp;
  final bool isSentToTelegram;

  const EmergencyLogModel({
    this.id,
    required this.userId,
    required this.message,
    required this.timestamp,
    this.isSentToTelegram = false,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'is_sent_to_telegram': isSentToTelegram ? 1 : 0,
    };
  }

  factory EmergencyLogModel.fromMap(Map<String, dynamic> map) {
    return EmergencyLogModel(
      id: map['id'] as int?,
      userId: map['user_id'] as int? ?? 0,
      message: map['message'] as String? ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      isSentToTelegram: (map['is_sent_to_telegram'] as int? ?? 0) == 1,
    );
  }
}
