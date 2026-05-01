// lib/services/sensor_service.dart

import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import '../utils/constants.dart';

/// Callback types
typedef ShakeCallback = void Function();
typedef GyroCallback = void Function(double x, double y, double z);

class SensorService {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  // ─── Shake Detection ─────────────────────────────────────────────────────
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  ShakeCallback? _onShake;

  DateTime? _lastShakeTime;
  int _shakeCount = 0;
  DateTime? _shakeWindowStart;
  bool _isShakeDetectionEnabled = true;
  static const _shakeWindowMs = 2500; // Window deteksi shake (ms)

  /// Mulai listen accelerometer untuk deteksi guncangan darurat.
  void startShakeDetection(ShakeCallback onShake) {
    _onShake = onShake;
    _accelSubscription?.cancel();

    _accelSubscription = accelerometerEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen(
      _onAccelerometer,
      onError: (e) {
        // Sensor tidak tersedia — silent fail
      },
      cancelOnError: false,
    );
  }

  void _onAccelerometer(AccelerometerEvent event) {
    if (!_isShakeDetectionEnabled) return;

    // Hitung magnitude percepatan (hapus gravitasi dengan perkiraan)
    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    // Nilai ~9.8 adalah gravitasi normal. Threshold di atas gravitasi.
    if (magnitude > AppConstants.SHAKE_THRESHOLD) {
      final now = DateTime.now();

      // Cooldown: cek apakah sudah lewat SHAKE_COOLDOWN_SECONDS sejak shake terakhir dikirim
      if (_lastShakeTime != null) {
        final diff = now.difference(_lastShakeTime!).inSeconds;
        if (diff < AppConstants.SHAKE_COOLDOWN_SECONDS) return;
      }

      // Hitung shake dalam window waktu
      if (_shakeWindowStart == null ||
          now.difference(_shakeWindowStart!).inMilliseconds > _shakeWindowMs) {
        _shakeWindowStart = now;
        _shakeCount = 1;
      } else {
        _shakeCount++;
      }

      // Trigger hanya jika shake count cukup (anti getaran tidak disengaja)
      if (_shakeCount >= AppConstants.SHAKE_COUNT_REQUIRED) {
        _shakeCount = 0;
        _shakeWindowStart = null;
        _lastShakeTime = now;
        _onShake?.call();
      }
    }
  }

  void stopShakeDetection() {
    _accelSubscription?.cancel();
    _accelSubscription = null;
    _onShake = null;
  }

  /// Aktif/nonaktifkan trigger emergency shake tanpa mematikan stream sensor.
  void setShakeDetectionEnabled(bool enabled) {
    _isShakeDetectionEnabled = enabled;

    // Reset state supaya tidak ada trigger tertunda saat diaktifkan kembali.
    if (!enabled) {
      _shakeCount = 0;
      _shakeWindowStart = null;
    }
  }

  // ─── Gyroscope ─────────────────────────────────────────────────────────────
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  GyroCallback? _onGyro;
  bool _isGyroAvailable = false;

  Future<bool> checkGyroAvailability() async {
    try {
      // Coba subscribe sebentar untuk cek ketersediaan
      final completer = Completer<bool>();
      final sub = gyroscopeEventStream().listen(
        (_) {
          if (!completer.isCompleted) completer.complete(true);
        },
        onError: (_) {
          if (!completer.isCompleted) completer.complete(false);
        },
        cancelOnError: true,
      );

      // Timeout 1 detik
      Future.delayed(const Duration(seconds: 1), () {
        if (!completer.isCompleted) completer.complete(false);
      });

      _isGyroAvailable = await completer.future;
      await sub.cancel();
      return _isGyroAvailable;
    } catch (e) {
      _isGyroAvailable = false;
      return false;
    }
  }

  void startGyroscope(GyroCallback onGyro) {
    _onGyro = onGyro;
    _gyroSubscription?.cancel();

    _gyroSubscription = gyroscopeEventStream(
      samplingPeriod: SensorInterval.gameInterval, // ~50Hz untuk game
    ).listen(
      (event) => _onGyro?.call(event.x, event.y, event.z),
      onError: (_) {},
      cancelOnError: false,
    );
  }

  void stopGyroscope() {
    _gyroSubscription?.cancel();
    _gyroSubscription = null;
    _onGyro = null;
  }

  // ─── Cleanup ───────────────────────────────────────────────────────────────

  void disposeAll() {
    stopShakeDetection();
    stopGyroscope();
  }

  bool get isGyroAvailable => _isGyroAvailable;
}
