// lib/services/connectivity_service.dart

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ConnectivityService extends GetxService {
  static ConnectivityService get to => Get.find();

  final RxBool isOnline = true.obs;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  void onInit() {
    super.onInit();
    _checkInitial();
    _listenToChanges();
  }

  Future<void> _checkInitial() async {
    final result = await Connectivity().checkConnectivity();
    isOnline.value = !result.contains(ConnectivityResult.none);
  }

  void _listenToChanges() {
    _subscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      final wasOnline = isOnline.value;
      isOnline.value = !result.contains(ConnectivityResult.none);

      // Tampilkan snackbar saat status berubah
      if (!wasOnline && isOnline.value) {
        _showSnack('Koneksi internet tersambung kembali', Colors.green.shade700);
      } else if (wasOnline && !isOnline.value) {
        _showSnack('Tidak ada koneksi internet. Beberapa fitur mungkin tidak berfungsi.', Colors.orange.shade700);
      }
    });
  }

  void _showSnack(String message, Color color) {
    Get.snackbar(
      '',
      message,
      titleText: const SizedBox.shrink(),
      backgroundColor: color,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(12),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
      isDismissible: true,
    );
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }

  /// Cek apakah saat ini online
  Future<bool> checkConnection() async {
    final result = await Connectivity().checkConnectivity();
    isOnline.value = !result.contains(ConnectivityResult.none);
    return isOnline.value;
  }
}
