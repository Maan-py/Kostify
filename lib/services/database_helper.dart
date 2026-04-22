// lib/services/database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../models/broadcast_model.dart';
import '../models/user_model.dart';
import '../models/payment_model.dart';
import '../models/emergency_log_model.dart';
import '../utils/constants.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    await _ensureBroadcastTables(_database!);
    return _database!;
  }

  // ─── Init & Setup ──────────────────────────────────────────────────────────

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.DB_NAME);

    return await openDatabase(
      path,
      version: AppConstants.DB_VERSION,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        await _ensureBroadcastTables(db);
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabel Users
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'tenant',
        is_active INTEGER NOT NULL DEFAULT 1,
        nik TEXT,
        nama_lengkap TEXT,
        alamat TEXT,
        nomor_kamar TEXT,
        harga_sewa INTEGER,
        foto_profil_path TEXT,
        tanggal_masuk TEXT,
        telepon TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Tabel Payments
    await db.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        bulan TEXT NOT NULL,
        created_at TEXT NOT NULL,
        paid_at TEXT,
        keterangan TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Tabel Emergency Logs
    await db.execute('''
      CREATE TABLE emergency_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        message TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        is_sent_to_telegram INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Tabel Broadcasts
    await _ensureBroadcastTables(db);

    // Insert akun Admin (hardcoded, SHA-256 hashed)
    await _insertDefaultAdmin(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS broadcast_messages (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          message TEXT NOT NULL,
          audience TEXT NOT NULL DEFAULT 'tenant',
          created_by_user_id INTEGER,
          created_by_name TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (created_by_user_id) REFERENCES users (id) ON DELETE SET NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS broadcast_deliveries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          broadcast_id INTEGER NOT NULL,
          user_id INTEGER NOT NULL,
          delivered_at TEXT NOT NULL,
          read_at TEXT,
          UNIQUE(broadcast_id, user_id),
          FOREIGN KEY (broadcast_id) REFERENCES broadcast_messages (id) ON DELETE CASCADE,
          FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
        )
      ''');
    }
  }

  Future<void> _ensureBroadcastTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS broadcast_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        audience TEXT NOT NULL DEFAULT 'tenant',
        created_by_user_id INTEGER,
        created_by_name TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (created_by_user_id) REFERENCES users (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS broadcast_deliveries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        broadcast_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        delivered_at TEXT NOT NULL,
        read_at TEXT,
        UNIQUE(broadcast_id, user_id),
        FOREIGN KEY (broadcast_id) REFERENCES broadcast_messages (id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _insertDefaultAdmin(Database db) async {
    final passwordHash = sha256.convert(utf8.encode('admin123')).toString();

    await db.insert('users', {
      'username': AppConstants.ADMIN_USERNAME,
      'password': passwordHash,
      'role': 'admin',
      'is_active': 1,
      'nama_lengkap': 'Administrator Kostify',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // ─── Helper hash ───────────────────────────────────────────────────────────

  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  // ─── USER CRUD ─────────────────────────────────────────────────────────────

  Future<UserModel?> getUserByCredentials(
      String username, String password) async {
    try {
      final db = await database;
      final hash = DatabaseHelper.hashPassword(password);
      final maps = await db.query(
        'users',
        where: 'username = ? AND password = ?',
        whereArgs: [username.trim(), hash],
        limit: 1,
      );
      if (maps.isEmpty) return null;
      final user = UserModel.fromMap(maps.first);
      if (!user.isActive) return null; // Akun nonaktif tidak bisa login
      return user;
    } catch (e) {
      return null;
    }
  }

  Future<UserModel?> getUserById(int id) async {
    try {
      final db = await database;
      final maps =
          await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
      if (maps.isEmpty) return null;
      return UserModel.fromMap(maps.first);
    } catch (e) {
      return null;
    }
  }

  Future<UserModel?> getUserByUsername(String username) async {
    try {
      final db = await database;
      final maps = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: [username.trim()],
        limit: 1,
      );
      if (maps.isEmpty) return null;
      return UserModel.fromMap(maps.first);
    } catch (e) {
      return null;
    }
  }

  Future<List<UserModel>> getAllTenants({bool? isActive}) async {
    try {
      final db = await database;
      String where = "role = 'tenant'";
      List<dynamic> whereArgs = [];
      if (isActive != null) {
        where += ' AND is_active = ?';
        whereArgs.add(isActive ? 1 : 0);
      }
      final maps = await db.query(
        'users',
        where: where,
        whereArgs: whereArgs.isEmpty ? null : whereArgs,
        orderBy: 'nama_lengkap ASC',
      );
      return maps.map((m) => UserModel.fromMap(m)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<UserModel>> searchTenants(String query) async {
    try {
      final db = await database;
      final sanitized = query.trim().replaceAll(RegExp(r'''['";\\]'''), '');
      final limited =
          sanitized.length > 50 ? sanitized.substring(0, 50) : sanitized;
      if (limited.isEmpty) return getAllTenants();

      final maps = await db.query(
        'users',
        where:
            "role = 'tenant' AND (nama_lengkap LIKE ? OR nik LIKE ? OR username LIKE ?)",
        whereArgs: ['%$limited%', '%$limited%', '%$limited%'],
        orderBy: 'nama_lengkap ASC',
      );
      return maps.map((m) => UserModel.fromMap(m)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> changePassword({
    required int userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    final db = await database;
    // Verifikasi password lama
    final result = await db.query(
      'users',
      where: 'id = ? AND password = ?',
      whereArgs: [userId, DatabaseHelper.hashPassword(oldPassword)],
    );
    if (result.isEmpty) return false;
    // Update password baru
    await db.update(
      'users',
      {'password': DatabaseHelper.hashPassword(newPassword)},
      where: 'id = ?',
      whereArgs: [userId],
    );
    return true;
  }

  Future<int> createTenant(UserModel user) async {
    try {
      final db = await database;
      // Cek duplikat username sebelum insert
      final existing = await getUserByUsername(user.username);
      if (existing != null) throw Exception('Username sudah digunakan');
      return await db.insert('users', user.toMap());
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw Exception('Username sudah digunakan');
      }
      rethrow;
    }
  }

  Future<int> updateUser(UserModel user) async {
    try {
      final db = await database;
      return await db.update(
        'users',
        user.toMap(),
        where: 'id = ?',
        whereArgs: [user.id],
      );
    } catch (e) {
      return 0;
    }
  }

  Future<int> toggleTenantStatus(int userId, bool isActive) async {
    try {
      final db = await database;
      return await db.update(
        'users',
        {'is_active': isActive ? 1 : 0},
        where: 'id = ? AND role = ?',
        whereArgs: [userId, 'tenant'],
      );
    } catch (e) {
      return 0;
    }
  }

  Future<int> deleteTenant(int userId) async {
    try {
      final db = await database;
      return await db.delete(
        'users',
        where: 'id = ? AND role = ?',
        whereArgs: [userId, 'tenant'],
      );
    } catch (e) {
      return 0;
    }
  }

  Future<int> updateFotoProfil(int userId, String path) async {
    try {
      final db = await database;
      return await db.update(
        'users',
        {'foto_profil_path': path},
        where: 'id = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      return 0;
    }
  }

  Future<int> updateNomorKamar(int userId, String nomorKamar) async {
    try {
      final db = await database;
      return await db.update(
        'users',
        {'nomor_kamar': nomorKamar},
        where: 'id = ? AND role = ?',
        whereArgs: [userId, 'tenant'],
      );
    } catch (e) {
      return 0;
    }
  }

  // ─── Get Available Rooms ──────────────────────────────────────────────────

  /// Get list of available room numbers (not assigned to any tenant yet)
  Future<List<String>> getAvailableRooms() async {
    try {
      final db = await database;
      // Get all room numbers that are already occupied
      final occupiedMaps = await db.query(
        'users',
        columns: ['nomor_kamar'],
        where:
            "role = 'tenant' AND nomor_kamar IS NOT NULL AND nomor_kamar != ''",
        distinct: true,
      );

      final occupiedRooms = <String>{};
      for (var map in occupiedMaps) {
        final room = map['nomor_kamar'] as String?;
        if (room != null && room.isNotEmpty) {
          occupiedRooms.add(room);
        }
      }

      // Generate all possible room numbers (total 15 kamar)
      // Format: A1-A5, B1-B5, C1-C5
      final allRooms = <String>[];
      const roomPrefixes = ['A', 'B', 'C'];
      for (final prefix in roomPrefixes) {
        for (int i = 1; i <= 5; i++) {
          allRooms.add('$prefix$i');
        }
      }

      // Filter available rooms (not occupied)
      final availableRooms =
          allRooms.where((room) => !occupiedRooms.contains(room)).toList();
      return availableRooms;
    } catch (e) {
      return [];
    }
  }

  // ─── PAYMENT CRUD ──────────────────────────────────────────────────────────

  Future<int> createPayment(PaymentModel payment) async {
    try {
      final db = await database;
      return await db.insert('payments', payment.toMap());
    } catch (e) {
      return -1;
    }
  }

  Future<List<PaymentModel>> getPaymentsByUser(int userId) async {
    try {
      final db = await database;
      final maps = await db.query(
        'payments',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'bulan DESC',
      );
      return maps.map((m) => PaymentModel.fromMap(m)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<PaymentModel?> getPaymentByUserAndBulan(
      int userId, String bulan) async {
    try {
      final db = await database;
      final maps = await db.query(
        'payments',
        where: 'user_id = ? AND bulan = ?',
        whereArgs: [userId, bulan],
        limit: 1,
      );
      if (maps.isEmpty) return null;
      return PaymentModel.fromMap(maps.first);
    } catch (e) {
      return null;
    }
  }

  Future<bool> isPaymentExists(int userId, String bulan) async {
    try {
      final db = await database;
      final maps = await db.query(
        'payments',
        where: 'user_id = ? AND bulan = ?',
        whereArgs: [userId, bulan],
        limit: 1,
      );
      return maps.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<int> updatePaymentStatus(int paymentId, PaymentStatus status) async {
    try {
      final db = await database;
      return await db.update(
        'payments',
        {
          'status': status.value,
          if (status == PaymentStatus.paid)
            'paid_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [paymentId],
      );
    } catch (e) {
      return 0;
    }
  }

  /// Statistik: Total pendapatan bulan ini (dari payment yang lunas)
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final db = await database;
      final now = DateTime.now();
      final bulanIni = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      // Total tenant
      final totalTenantResult = await db.rawQuery(
        "SELECT COUNT(*) as count FROM users WHERE role = 'tenant'",
      );
      final totalTenant = (totalTenantResult.first['count'] as int?) ?? 0;

      // Tenant aktif
      final aktifResult = await db.rawQuery(
        "SELECT COUNT(*) as count FROM users WHERE role = 'tenant' AND is_active = 1",
      );
      final tenantAktif = (aktifResult.first['count'] as int?) ?? 0;

      // Pendapatan bulan ini
      final pendapatanResult = await db.rawQuery(
        "SELECT COALESCE(SUM(amount), 0) as total FROM payments WHERE status = 'paid' AND bulan = ?",
        [bulanIni],
      );
      final pendapatanBulanIni = (pendapatanResult.first['total'] as int?) ?? 0;

      // Tagihan pending
      final pendingResult = await db.rawQuery(
        "SELECT COUNT(*) as count FROM payments WHERE status = 'pending' AND bulan = ?",
        [bulanIni],
      );
      final tagihantPending = (pendingResult.first['count'] as int?) ?? 0;

      return {
        'total_tenant': totalTenant,
        'tenant_aktif': tenantAktif,
        'tenant_nonaktif': (15 - tenantAktif).clamp(0, 15),
        'total_kamar': 15, // ← hardcode 15 kamar
        'pendapatan_bulan_ini': pendapatanBulanIni,
        'tagihan_pending': tagihantPending,
        'bulan': bulanIni,
      };
    } catch (e) {
      return {
        'total_tenant': 0,
        'tenant_aktif': 0,
        'tenant_nonaktif': 0,
        'pendapatan_bulan_ini': 0,
        'tagihan_pending': 0,
        'bulan': '',
      };
    }
  }

  // ─── EMERGENCY LOG CRUD ────────────────────────────────────────────────────

  Future<int> createEmergencyLog(EmergencyLogModel log) async {
    try {
      final db = await database;
      return await db.insert('emergency_logs', log.toMap());
    } catch (e) {
      return -1;
    }
  }

  Future<List<EmergencyLogModel>> getEmergencyLogs({int limit = 50}) async {
    try {
      final db = await database;
      final maps = await db.query(
        'emergency_logs',
        orderBy: 'timestamp DESC',
        limit: limit,
      );
      return maps.map((m) => EmergencyLogModel.fromMap(m)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<int> markEmergencyLogSent(int logId) async {
    try {
      final db = await database;
      return await db.update(
        'emergency_logs',
        {'is_sent_to_telegram': 1},
        where: 'id = ?',
        whereArgs: [logId],
      );
    } catch (e) {
      return 0;
    }
  }

  // ─── BROADCAST CRUD ───────────────────────────────────────────────────────

  Future<int> createBroadcast(BroadcastMessageModel broadcast) async {
    try {
      final db = await database;
      return await db.insert('broadcast_messages', broadcast.toMap());
    } catch (e) {
      return -1;
    }
  }

  Future<List<BroadcastMessageModel>> getBroadcastInbox(int userId,
      {int limit = 50}) async {
    try {
      final db = await database;
      final maps = await db.rawQuery('''
        SELECT b.*, CASE WHEN d.read_at IS NULL THEN 0 ELSE 1 END AS is_read
        FROM broadcast_messages b
        LEFT JOIN broadcast_deliveries d
          ON d.broadcast_id = b.id AND d.user_id = ?
        WHERE b.audience IN ('tenant', 'all')
        ORDER BY b.created_at DESC
        LIMIT ?
      ''', [userId, limit]);
      return maps.map((m) => BroadcastMessageModel.fromMap(m)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<BroadcastMessageModel>> getAllBroadcasts({int limit = 50}) async {
    try {
      final db = await database;
      final maps = await db.query(
        'broadcast_messages',
        orderBy: 'created_at DESC',
        limit: limit,
      );
      return maps.map((m) => BroadcastMessageModel.fromMap(m)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<BroadcastMessageModel>> getUndeliveredBroadcasts(int userId,
      {int limit = 20}) async {
    try {
      final db = await database;
      final maps = await db.rawQuery('''
        SELECT b.*
        FROM broadcast_messages b
        LEFT JOIN broadcast_deliveries d
          ON d.broadcast_id = b.id AND d.user_id = ?
        WHERE b.audience IN ('tenant', 'all')
          AND d.id IS NULL
        ORDER BY b.created_at DESC
        LIMIT ?
      ''', [userId, limit]);
      return maps.map((m) => BroadcastMessageModel.fromMap(m)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<int> markBroadcastDelivered(int broadcastId, int userId) async {
    try {
      final db = await database;
      return await db.insert(
        'broadcast_deliveries',
        {
          'broadcast_id': broadcastId,
          'user_id': userId,
          'delivered_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } catch (e) {
      return 0;
    }
  }

  Future<int> markBroadcastRead(int broadcastId, int userId) async {
    try {
      final db = await database;
      final updated = await db.update(
        'broadcast_deliveries',
        {'read_at': DateTime.now().toIso8601String()},
        where: 'broadcast_id = ? AND user_id = ?',
        whereArgs: [broadcastId, userId],
      );

      if (updated > 0) return updated;

      return await db.insert('broadcast_deliveries', {
        'broadcast_id': broadcastId,
        'user_id': userId,
        'delivered_at': DateTime.now().toIso8601String(),
        'read_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      return 0;
    }
  }

  Future<int> markAllBroadcastsRead(int userId) async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();
      return await db.rawUpdate('''
        UPDATE broadcast_deliveries
        SET read_at = ?
        WHERE user_id = ?
      ''', [now, userId]);
    } catch (e) {
      return 0;
    }
  }

  Future<int> getUnreadBroadcastCount(int userId) async {
    try {
      final db = await database;
      final result = await db.rawQuery('''
        SELECT COUNT(*) as count
        FROM broadcast_messages b
        LEFT JOIN broadcast_deliveries d
          ON d.broadcast_id = b.id AND d.user_id = ?
        WHERE b.audience IN ('tenant', 'all')
          AND d.read_at IS NULL
      ''', [userId]);
      return (result.first['count'] as int?) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // ─── Utility ───────────────────────────────────────────────────────────────

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// Reset database — hanya untuk keperluan debug, jangan expose ke user
  Future<void> resetDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.DB_NAME);
    await deleteDatabase(path);
    _database = null;
  }
}
