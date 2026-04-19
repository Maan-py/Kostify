// lib/utils/constants.dart
// ignore_for_file: constant_identifier_names

class AppConstants {
  // ─── App Info ───────────────────────────────────────────────────────────────
  static const String APP_NAME = 'Kostify';
  static const String APP_VERSION = '1.0.0';
  static const String PACKAGE_NAME = 'id.kostify.app';

  // ─── Admin Hardcoded ────────────────────────────────────────────────────────
  // Password admin di-hash SHA-256: 'admin123' -> hash di bawah
  // Ganti nilai ADMIN_PASSWORD_HASH dengan hash dari password yang diinginkan
  static const String ADMIN_USERNAME = 'admin';
  static const String ADMIN_PASSWORD_HASH =
      'ecd71870d1963316a97e3ac3408c9835ad8cf0f3c1bc703527c30265534f75ae'; // SHA-256 of 'admin123'

  // ─── API Keys (PLACEHOLDER — ganti dengan key asli) ─────────────────────────
  static const String GEMINI_API_KEY = 'YOUR_GEMINI_API_KEY_HERE';
  static const String EXCHANGE_RATE_API_KEY = 'YOUR_EXCHANGE_RATE_API_KEY_HERE';
  static const String TELEGRAM_BOT_TOKEN = 'YOUR_TELEGRAM_BOT_TOKEN_HERE';
  static const String TELEGRAM_CHAT_ID = 'YOUR_TELEGRAM_CHAT_ID_HERE';
  static const String GOOGLE_MAPS_API_KEY = 'YOUR_GOOGLE_MAPS_API_KEY_HERE';

  // ─── API Base URLs ───────────────────────────────────────────────────────────
  static const String GEMINI_BASE_URL =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';
  static const String EXCHANGE_RATE_BASE_URL =
      'https://v6.exchangerate-api.com/v6/$EXCHANGE_RATE_API_KEY/latest/';
  static const String TELEGRAM_BASE_URL =
      'https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage';

  // ─── Kos Info (bisa diedit admin nantinya, untuk sekarang hardcode) ──────────
  static const String KOS_NAME = 'Kos Bahagia Sejahtera';
  static const String KOS_ADDRESS = 'Jl. Contoh No. 123, Semarang, Jawa Tengah';
  static const double KOS_LATITUDE = -7.005145; // Koordinat Semarang
  static const double KOS_LONGITUDE = 110.438125;

  // ─── Database ────────────────────────────────────────────────────────────────
  static const String DB_NAME = 'kostify.db';
  static const int DB_VERSION = 1;

  // ─── Secure Storage Keys ─────────────────────────────────────────────────────
  static const String STORAGE_USER_ID = 'user_id';
  static const String STORAGE_USERNAME = 'username';
  static const String STORAGE_ROLE = 'role';
  static const String STORAGE_IS_LOGGED_IN = 'is_logged_in';
  static const String STORAGE_SAVED_USERNAME = 'saved_username';

  // ─── Sensor ──────────────────────────────────────────────────────────────────
  static const double SHAKE_THRESHOLD = 15.0;       // m/s² threshold guncangan
  static const int SHAKE_COOLDOWN_SECONDS = 5;       // Cooldown antar notif darurat
  static const int SHAKE_COUNT_REQUIRED = 3;         // Jumlah shake sebelum trigger

  // ─── Input Validation ────────────────────────────────────────────────────────
  static const int MAX_USERNAME_LENGTH = 30;
  static const int MAX_PASSWORD_LENGTH = 64;
  static const int MIN_PASSWORD_LENGTH = 6;
  static const int MAX_NAME_LENGTH = 100;
  static const int NIK_LENGTH = 16;
  static const int MAX_CHAT_LENGTH = 500;
  static const int MAX_SARAN_LENGTH = 1000;
  static const int MAX_ROOM_NUMBER = 999;

  // ─── HTTP Timeout ────────────────────────────────────────────────────────────
  static const int HTTP_TIMEOUT_SECONDS = 10;

  // ─── Foto Profil ─────────────────────────────────────────────────────────────
  static const int MAX_IMAGE_SIZE_KB = 500; // Max 500KB setelah compress
  static const int IMAGE_QUALITY = 75;      // Kualitas kompresi

  // ─── Mata Uang yang Didukung ─────────────────────────────────────────────────
  static const List<Map<String, String>> SUPPORTED_CURRENCIES = [
    {'code': 'IDR', 'name': 'Rupiah Indonesia', 'symbol': 'Rp'},
    {'code': 'USD', 'name': 'US Dollar', 'symbol': '\$'},
    {'code': 'EUR', 'name': 'Euro', 'symbol': '€'},
    {'code': 'JPY', 'name': 'Yen Jepang', 'symbol': '¥'},
    {'code': 'SGD', 'name': 'Dolar Singapura', 'symbol': 'S\$'},
    {'code': 'MYR', 'name': 'Ringgit Malaysia', 'symbol': 'RM'},
  ];

  // ─── Zona Waktu ──────────────────────────────────────────────────────────────
  static const List<Map<String, String>> TIMEZONES = [
    {'id': 'WIB',    'name': 'Waktu Indonesia Barat', 'tz': 'Asia/Jakarta',  'offset': '+7'},
    {'id': 'WITA',   'name': 'Waktu Indonesia Tengah','tz': 'Asia/Makassar', 'offset': '+8'},
    {'id': 'WIT',    'name': 'Waktu Indonesia Timur', 'tz': 'Asia/Jayapura', 'offset': '+9'},
    {'id': 'London', 'name': 'London (GMT/BST)',       'tz': 'Europe/London', 'offset': '0/+1'},
  ];

  // ─── Game ────────────────────────────────────────────────────────────────────
  static const double GRAVITY = 600.0;         // pixel/s² gravity Flappy Bird
  static const double JUMP_VELOCITY = -280.0;  // Kecepatan lompat (tap)
  static const double PIPE_SPEED = 180.0;      // Kecepatan pipa bergerak
  static const double PIPE_GAP = 160.0;        // Celah antara pipa atas dan bawah
  static const double GYRO_SENSITIVITY = 0.6;  // Sensitivitas gyroscope
}

// ─── Warna Tema Kostify ───────────────────────────────────────────────────────
class AppColors {
  static const int _primaryHex = 0xFF8095E4;
  static const int _secondaryHex = 0xFF1BC0BA;

  // Primary palette
  static const primaryColor = _ColorSwatch(_primaryHex);
  static const secondaryColor = _ColorSwatch(_secondaryHex);

  // Semantic
  static const successColor = _ColorSwatch(0xFF4CAF50);
  static const warningColor = _ColorSwatch(0xFFFF9800);
  static const dangerColor = _ColorSwatch(0xFFE53935);
  static const infoColor = _ColorSwatch(0xFF2196F3);

  // Neutral
  static const backgroundLight = _ColorSwatch(0xFFF5F6FA);
  static const surfaceLight = _ColorSwatch(0xFFFFFFFF);
  static const textPrimary = _ColorSwatch(0xFF1A1A2E);
  static const textSecondary = _ColorSwatch(0xFF6B7280);
  static const divider = _ColorSwatch(0xFFE5E7EB);

  // Status chip colors
  static const activeChip = _ColorSwatch(0xFF1BC0BA);
  static const inactiveChip = _ColorSwatch(0xFFE53935);
  static const pendingChip = _ColorSwatch(0xFFFF9800);
}

// Simple color helper
class _ColorSwatch {
  final int value;
  const _ColorSwatch(this.value);

  // ignore: non_constant_identifier_names
  int get toInt => value;
}

// ─── Role Enum ───────────────────────────────────────────────────────────────
enum UserRole { admin, tenant }

extension UserRoleExtension on UserRole {
  String get name => this == UserRole.admin ? 'Admin' : 'Penyewa';
}
