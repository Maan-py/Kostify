// lib/controllers/tenant_controller.dart

import 'package:get/get.dart';

import '../models/user_model.dart';
import '../models/payment_model.dart';
import '../services/database_helper.dart';

class TenantController extends GetxController {
  static TenantController get to => Get.find();

  final _db = DatabaseHelper();

  final RxList<UserModel> tenants = <UserModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString searchQuery = ''.obs;
  final Rx<bool?> filterActive = Rx<bool?>(null); // null = semua

  @override
  void onInit() {
    super.onInit();
    loadTenants();
  }

  Future<void> loadTenants() async {
    isLoading.value = true;
    try {
      List<UserModel> result;
      if (searchQuery.value.trim().isNotEmpty) {
        result = await _db.searchTenants(searchQuery.value);
        if (filterActive.value != null) {
          result = result.where((t) => t.isActive == filterActive.value).toList();
        }
      } else {
        result = await _db.getAllTenants(isActive: filterActive.value);
      }
      tenants.value = result;
    } finally {
      isLoading.value = false;
    }
  }

  void setSearch(String query) {
    searchQuery.value = query;
    loadTenants();
  }

  void setFilter(bool? active) {
    filterActive.value = active;
    loadTenants();
  }

  Future<void> toggleStatus(int userId, bool currentStatus) async {
    await _db.toggleTenantStatus(userId, !currentStatus);
    await loadTenants();
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    return _db.getDashboardStats();
  }

  // Statistik: jumlah aktif, nonaktif, total
  int get activeCount => tenants.where((t) => t.isActive).length;
  int get inactiveCount => tenants.where((t) => !t.isActive).length;
}
