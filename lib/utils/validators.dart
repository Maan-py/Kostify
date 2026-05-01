// lib/utils/validators.dart

import 'constants.dart';

class AppValidators {
  // ─── Pattern ───────────────────────────────────────────────────────────────
  static final RegExp _usernamePattern = RegExp(r'^[a-zA-Z0-9_]+$');
  static final RegExp _digitOnly = RegExp(r'^\d+$');
  static final RegExp _sqlInjection = RegExp(
    r"('|--|;|\/\*|\*\/|xp_|UNION|SELECT|INSERT|DELETE|DROP|UPDATE|ALTER)",
    caseSensitive: false,
  );
  static final RegExp _htmlTags = RegExp(r'<[^>]*>');
  static final RegExp _scriptInjection = RegExp(
    r'(javascript:|data:|vbscript:|on\w+=)',
    caseSensitive: false,
  );

  // ─── Sanitizer ─────────────────────────────────────────────────────────────

  /// Hapus karakter berbahaya, trim whitespace berlebih, batasi panjang.
  static String sanitize(String input, {int maxLength = 255}) {
    String result = input.trim();
    // Hapus null bytes & control chars (kecuali newline pada textarea)
    result = result.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
    // Batasi panjang — penting untuk paste artikel berita
    if (result.length > maxLength) {
      result = result.substring(0, maxLength);
    }
    return result;
  }

  /// Cek apakah input mengandung pola berbahaya (SQL/XSS injection).
  static bool _isDangerous(String value) {
    return _sqlInjection.hasMatch(value) ||
        _htmlTags.hasMatch(value) ||
        _scriptInjection.hasMatch(value);
  }

  // ─── Username ──────────────────────────────────────────────────────────────

  static String? validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Username tidak boleh kosong';
    }
    final trimmed = value.trim();
    if (trimmed.contains(' ')) {
      return 'Username tidak boleh mengandung spasi';
    }
    if (trimmed.length > AppConstants.MAX_USERNAME_LENGTH) {
      return 'Username maksimal ${AppConstants.MAX_USERNAME_LENGTH} karakter';
    }
    if (trimmed.length < 3) {
      return 'Username minimal 3 karakter';
    }
    if (!_usernamePattern.hasMatch(trimmed)) {
      return 'Username hanya boleh huruf, angka, dan underscore';
    }
    if (_isDangerous(trimmed)) {
      return 'Username mengandung karakter tidak valid';
    }
    return null;
  }

  // ─── Password ──────────────────────────────────────────────────────────────

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password tidak boleh kosong';
    }
    if (value.length < AppConstants.MIN_PASSWORD_LENGTH) {
      return 'Password minimal ${AppConstants.MIN_PASSWORD_LENGTH} karakter';
    }
    if (value.length > AppConstants.MAX_PASSWORD_LENGTH) {
      return 'Password maksimal ${AppConstants.MAX_PASSWORD_LENGTH} karakter';
    }
    // Tidak perlu cek SQL injection pada password karena akan di-hash
    return null;
  }

  static String? validateConfirmPassword(String? value, String password) {
    final passError = validatePassword(value);
    if (passError != null) return passError;
    if (value != password) return 'Konfirmasi password tidak cocok';
    return null;
  }

  // ─── NIK ───────────────────────────────────────────────────────────────────

  static String? validateNIK(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'NIK tidak boleh kosong';
    }
    final trimmed = value.trim();
    if (trimmed.length != AppConstants.NIK_LENGTH) {
      return 'NIK harus tepat ${AppConstants.NIK_LENGTH} digit';
    }
    if (!_digitOnly.hasMatch(trimmed)) {
      return 'NIK hanya boleh berisi angka';
    }
    return null;
  }

  // ─── Nama Lengkap ──────────────────────────────────────────────────────────

  static String? validateNamaLengkap(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nama lengkap tidak boleh kosong';
    }
    final trimmed = value.trim();
    if (trimmed.length > AppConstants.MAX_NAME_LENGTH) {
      return 'Nama maksimal ${AppConstants.MAX_NAME_LENGTH} karakter';
    }
    if (trimmed.length < 2) {
      return 'Nama terlalu pendek';
    }
    if (RegExp(r'\d').hasMatch(trimmed)) {
      return 'Nama hanya boleh berisi huruf';
    }
    if (!RegExp(r"^[A-Za-zÀ-ÿ][A-Za-zÀ-ÿ '\-]*$").hasMatch(trimmed)) {
      return 'Nama hanya boleh berisi huruf';
    }
    if (_isDangerous(trimmed)) {
      return 'Nama mengandung karakter tidak valid';
    }
    return null;
  }

  // ─── Harga Sewa ────────────────────────────────────────────────────────────

  static String? validateHargaSewa(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Harga sewa tidak boleh kosong';
    }
    final trimmed = value.trim().replaceAll('.', '').replaceAll(',', '');
    if (!_digitOnly.hasMatch(trimmed)) {
      return 'Harga sewa hanya boleh berisi angka';
    }
    final amount = int.tryParse(trimmed);
    if (amount == null || amount <= 0) {
      return 'Harga sewa harus lebih dari 0';
    }
    if (amount > 99999999) {
      return 'Harga sewa tidak valid';
    }
    return null;
  }

  // ─── Nomor Kamar ───────────────────────────────────────────────────────────

  static String? validateNomorKamar(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nomor kamar tidak boleh kosong';
    }
    final trimmed = value.trim();
    if (trimmed.length > 10) {
      return 'Nomor kamar terlalu panjang';
    }
    if (_isDangerous(trimmed)) {
      return 'Nomor kamar tidak valid';
    }
    return null;
  }

  // ─── Chat / Textarea ───────────────────────────────────────────────────────

  static String? validateChatMessage(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Pesan tidak boleh kosong';
    }
    if (value.length > AppConstants.MAX_CHAT_LENGTH) {
      return 'Pesan maksimal ${AppConstants.MAX_CHAT_LENGTH} karakter';
    }
    return null;
  }

  // ─── Generic Tidak Boleh Kosong ────────────────────────────────────────────

  static String? validateNotEmpty(String? value,
      {String fieldName = 'Field ini'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName tidak boleh kosong';
    }
    return null;
  }

  // ─── Helper: Format angka IDR ──────────────────────────────────────────────

  static String formatRupiah(int amount) {
    final str = amount.toString();
    final buffer = StringBuffer();
    int counter = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (counter > 0 && counter % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
      counter++;
    }
    return 'Rp ${buffer.toString().split('').reversed.join()}';
  }
}
