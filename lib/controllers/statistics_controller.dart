import 'package:get/get.dart';
import '../services/database_helper.dart';
import '../models/payment_model.dart';

class StatisticsController extends GetxController {
  final _db = DatabaseHelper();

  final currentMonth = ''.obs;
  final isLoading = true.obs;
  
  final monthlyStats = <String, dynamic>{}.obs;
  final comparison = <String, dynamic>{}.obs;
  final trend = <Map<String, dynamic>>[].obs;
  final availableMonths = <String>[].obs;
  final unpaidPayments = <PaymentModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    final now = DateTime.now();
    currentMonth.value = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _initData();
  }

  Future<void> _initData() async {
    await loadAvailableMonths();
    await loadStats(currentMonth.value);
  }

  Future<void> loadAvailableMonths() async {
    final months = await _db.getAvailableMonths();
    availableMonths.assignAll(months);
  }

  Future<void> loadStats(String month) async {
    isLoading.value = true;
    try {
      currentMonth.value = month;
      
      // Load current and previous month comparison
      final date = DateTime.tryParse('$month-01') ?? DateTime.now();
      final prevDate = DateTime(date.year, date.month - 1, 1);
      final prevMonthStr = '${prevDate.year}-${prevDate.month.toString().padLeft(2, '0')}';
      
      final comp = await _db.getMonthlyComparison(month, prevMonthStr);
      comparison.value = comp;
      
      // Monthly stats is just the current part of comparison
      monthlyStats.value = await _db.getMonthlyStats(month);
      
      // Trend data (6 months)
      final trendData = await _db.getMonthlyTrendData(6, month);
      trend.assignAll(trendData);

      // Unpaid payments
      final unpaid = await _db.getUnpaidPaymentsByMonth(month);
      unpaidPayments.assignAll(unpaid);
      
    } catch (e) {
      Get.snackbar('Error', 'Gagal memuat statistik: $e', 
        snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  void goToPreviousMonth() {
    final date = DateTime.tryParse('${currentMonth.value}-01') ?? DateTime.now();
    final prevDate = DateTime(date.year, date.month - 1, 1);
    final prevMonthStr = '${prevDate.year}-${prevDate.month.toString().padLeft(2, '0')}';
    loadStats(prevMonthStr);
  }

  void goToNextMonth() {
    final date = DateTime.tryParse('${currentMonth.value}-01') ?? DateTime.now();
    final now = DateTime.now();
    
    // Prevent going to future months
    if (date.year == now.year && date.month == now.month) return;
    
    final nextDate = DateTime(date.year, date.month + 1, 1);
    final nextMonthStr = '${nextDate.year}-${nextDate.month.toString().padLeft(2, '0')}';
    loadStats(nextMonthStr);
  }

  bool get isCurrentMonthLatest {
    final date = DateTime.tryParse('${currentMonth.value}-01') ?? DateTime.now();
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }
}
