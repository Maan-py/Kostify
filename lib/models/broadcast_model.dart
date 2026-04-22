// lib/models/broadcast_model.dart

class BroadcastMessageModel {
  final int? id;
  final String title;
  final String message;
  final String audience;
  final int? createdByUserId;
  final String? createdByName;
  final DateTime createdAt;
  final bool isRead;

  BroadcastMessageModel({
    this.id,
    required this.title,
    required this.message,
    this.audience = 'tenant',
    this.createdByUserId,
    this.createdByName,
    DateTime? createdAt,
    this.isRead = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'message': message,
      'audience': audience,
      'created_by_user_id': createdByUserId,
      'created_by_name': createdByName,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory BroadcastMessageModel.fromMap(Map<String, dynamic> map) {
    return BroadcastMessageModel(
      id: map['id'] as int?,
      title: map['title'] as String? ?? '',
      message: map['message'] as String? ?? '',
      audience: map['audience'] as String? ?? 'tenant',
      createdByUserId: map['created_by_user_id'] as int?,
      createdByName: map['created_by_name'] as String?,
      isRead: (map['is_read'] as int? ?? 0) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ??
              DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  BroadcastMessageModel copyWith({
    int? id,
    String? title,
    String? message,
    String? audience,
    int? createdByUserId,
    String? createdByName,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return BroadcastMessageModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      audience: audience ?? this.audience,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}
