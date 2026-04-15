// lib/controllers/auth_controller.dart

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user_model.dart';
import '../services/database_helper.dart';
import '../utils/constants.dart';
import '../utils/validators.dart';

class AuthController extends GetxController {
  static AuthController get to => Get.find();

  final _db = DatabaseHelper();
  final _auth = LocalAuthentication();
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // ─── State ─────────────────────────────────────────────────────────────────
  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  final RxBool isLoading = false.obs;
  final RxBool isBiometricAvailable = false.obs;
  final RxString errorMessage = ''.obs;

  bool get isLoggedIn => currentUser.value != null;
  bool get isAdmin => currentUser.value?.isAdmin ?? false;

  @override
  void onInit() {
    super.onInit();
    _checkBiometricAvailability();
    _restoreSession();
  }

  // ─── Biometric ─────────────────────────────────────────────────────────────

  Future<void> _checkBiometricAvailability() async {
    try {
      final isAvailable = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      isBiometricAvailable.value = isAvailable && isDeviceSupported;
    } on PlatformException {
      isBiometricAvailable.value = false;
    }
  }

  /// Autentikasi biometric. Kembalikan true jika berhasil, false jika gagal/tidak tersedia.
  Future<bool> authenticateBiometric() async {
    if (!isBiometricAvailable.value) return true; // Langsung allow jika tidak ada biometric

    try {
      final List<BiometricType> availableBiometrics =
          await _auth.getAvailableBiometrics();

      if (availableBiometrics.isEmpty) return true; // Tidak ada biometric terdaftar

      return await _auth.authenticate(
        localizedReason: 'Verifikasi identitas untuk masuk ke Kostify',
        options: const AuthenticationOptions(
          biometricOnly: false,  // Boleh fallback ke PIN device
          stickyAuth: true,      // Tetap tampil walau app pindah background
          sensitiveTransaction: false,
        ),
      );
    } on PlatformException catch (e) {
      // Biometric locked atau error lain — tampilkan pesan, tapi jangan crash
      errorMessage.value = _parseBiometricError(e.code);
      return false;
    }
  }

  String _parseBiometricError(String code) {
    switch (code) {
      case 'NotEnrolled':
        return 'Tidak ada sidik jari/wajah terdaftar di perangkat ini.';
      case 'LockedOut':
        return 'Terlalu banyak percobaan. Coba lagi nanti.';
      case 'PermanentlyLockedOut':
        return 'Biometrik terkunci. Gunakan PIN perangkat untuk membuka.';
      default:
        return 'Autentikasi biometrik gagal. Coba lagi.';
    }
  }

  // ─── Login ─────────────────────────────────────────────────────────────────

  Future<LoginResult> login(String username, String password) async {
    errorMessage.value = '';

    // Validasi input
    final userError = AppValidators.validateUsername(username);
    if (userError != null) return LoginResult(success: false, message: userError);

    final passError = AppValidators.validatePassword(password);
    if (passError != null) return LoginResult(success: false, message: passError);

    isLoading.value = true;
    try {
      // Biometric dulu sebelum cek DB
      final bioOk = await authenticateBiometric();
      if (!bioOk) {
        return LoginResult(
          success: false,
          message: errorMessage.value.isNotEmpty
              ? errorMessage.value
              : 'Autentikasi biometrik diperlukan.',
        );
      }

      // Cek DB
      final user = await _db.getUserByCredentials(username.trim(), password);
      if (user == null) {
        return LoginResult(
          success: false,
          message: 'Username atau password salah, atau akun tidak aktif.',
        );
      }

      // Simpan session
      await _saveSession(user);
      currentUser.value = user;

      return LoginResult(success: true, user: user);
    } catch (e) {
      return LoginResult(
        success: false,
        message: 'Terjadi kesalahan. Coba lagi.',
      );
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Session ───────────────────────────────────────────────────────────────

  Future<void> _saveSession(UserModel user) async {
    await _storage.write(key: AppConstants.STORAGE_USER_ID, value: user.id.toString());
    await _storage.write(key: AppConstants.STORAGE_USERNAME, value: user.username);
    await _storage.write(key: AppConstants.STORAGE_ROLE, value: user.role);
    await _storage.write(key: AppConstants.STORAGE_IS_LOGGED_IN, value: 'true');
  }

  Future<void> _restoreSession() async {
    try {
      final isLoggedIn = await _storage.read(key: AppConstants.STORAGE_IS_LOGGED_IN);
      if (isLoggedIn != 'true') return;

      final userIdStr = await _storage.read(key: AppConstants.STORAGE_USER_ID);
      if (userIdStr == null) return;

      final userId = int.tryParse(userIdStr);
      if (userId == null) return;

      final user = await _db.getUserById(userId);
      if (user != null && user.isActive) {
        currentUser.value = user;
      } else {
        await clearSession();
      }
    } catch (e) {
      await clearSession();
    }
  }

  Future<void> logout() async {
    isLoading.value = true;
    await clearSession();
    currentUser.value = null;
    isLoading.value = false;
    Get.offAllNamed('/login');
  }

  Future<void> clearSession() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      // Storage error — lanjutkan saja
    }
  }

  // ─── Refresh current user dari DB ─────────────────────────────────────────

  Future<void> refreshUser() async {
    final id = currentUser.value?.id;
    if (id == null) return;
    final updated = await _db.getUserById(id);
    if (updated != null) currentUser.value = updated;
  }
}

class LoginResult {
  final bool success;
  final String? message;
  final UserModel? user;

  LoginResult({required this.success, this.message, this.user});
}
