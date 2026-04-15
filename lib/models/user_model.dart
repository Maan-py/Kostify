// lib/models/user_model.dart

class UserModel {
  final int? id;
  final String username;
  final String password; // SHA-256 hashed
  final String role;     // 'admin' | 'tenant'
  final bool isActive;
  final String? nik;
  final String? namaLengkap;
  final String? alamat;
  final String? nomorKamar;
  final int? hargaSewa;       // dalam IDR
  final String? fotoProfilPath; // path lokal file
  final String? tanggalMasuk;   // format: yyyy-MM-dd
  final String? telepon;
  final DateTime? createdAt;

  const UserModel({
    this.id,
    required this.username,
    required this.password,
    required this.role,
    this.isActive = true,
    this.nik,
    this.namaLengkap,
    this.alamat,
    this.nomorKamar,
    this.hargaSewa,
    this.fotoProfilPath,
    this.tanggalMasuk,
    this.telepon,
    this.createdAt,
  });

  bool get isAdmin => role == 'admin';
  bool get isTenant => role == 'tenant';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'username': username,
      'password': password,
      'role': role,
      'is_active': isActive ? 1 : 0,
      'nik': nik,
      'nama_lengkap': namaLengkap,
      'alamat': alamat,
      'nomor_kamar': nomorKamar,
      'harga_sewa': hargaSewa,
      'foto_profil_path': fotoProfilPath,
      'tanggal_masuk': tanggalMasuk,
      'telepon': telepon,
      'created_at': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int?,
      username: map['username'] as String? ?? '',
      password: map['password'] as String? ?? '',
      role: map['role'] as String? ?? 'tenant',
      isActive: (map['is_active'] as int? ?? 1) == 1,
      nik: map['nik'] as String?,
      namaLengkap: map['nama_lengkap'] as String?,
      alamat: map['alamat'] as String?,
      nomorKamar: map['nomor_kamar'] as String?,
      hargaSewa: map['harga_sewa'] as int?,
      fotoProfilPath: map['foto_profil_path'] as String?,
      tanggalMasuk: map['tanggal_masuk'] as String?,
      telepon: map['telepon'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  UserModel copyWith({
    int? id,
    String? username,
    String? password,
    String? role,
    bool? isActive,
    String? nik,
    String? namaLengkap,
    String? alamat,
    String? nomorKamar,
    int? hargaSewa,
    String? fotoProfilPath,
    String? tanggalMasuk,
    String? telepon,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      nik: nik ?? this.nik,
      namaLengkap: namaLengkap ?? this.namaLengkap,
      alamat: alamat ?? this.alamat,
      nomorKamar: nomorKamar ?? this.nomorKamar,
      hargaSewa: hargaSewa ?? this.hargaSewa,
      fotoProfilPath: fotoProfilPath ?? this.fotoProfilPath,
      tanggalMasuk: tanggalMasuk ?? this.tanggalMasuk,
      telepon: telepon ?? this.telepon,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
