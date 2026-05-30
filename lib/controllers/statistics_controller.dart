import 'package:get/get.dart';
import '../services/database_helper.dart';
import '../models/payment_model.dart';

class StatisticsController extends GetxController {
  final _db = DatabaseHelper();

  final currentMonth = Rx<DateTime>(DateTime.now());
  final isLoading = RxBool(false);
  
  final monthlyStats = Rx<Map<String, dynamic>>({});
  final trendData = RxList<Map<String, dynamic>>([]);
  final comparison = Rx<Map<String, dynamic>>({});
  final availableMonths = RxList<String>([]);
  final unpaidPayments = <PaymentModel>[].obs;
  
  final lastUpdated = Rx<DateTime>(DateTime.now());

  @override
  void onInit() {
    super.onInit();
    _loadAvailableMonths();
    loadStats();
  }

  Future<void> loadStats() async {
    isLoading.value = true;
    try {
      final yearMonth = _formatMonth(currentMonth.value);
      
      // Load stats
      final stats = await _db.getMonthlyStats(yearMonth);
      monthlyStats.value = stats;
      
      // Load trend (6 months)
      final trend = await _db.getMonthlyTrendData(6, yearMonth);
      trendData.value = trend;
      
      // Load comparison
      final prevMonth = _getPreviousMonth(currentMonth.value);
      final prevYearMonth = _formatMonth(prevMonth);
      final comp = await _db.getMonthlyComparison(yearMonth, prevYearMonth);
      comparison.value = comp;

      // Unpaid payments
      final unpaid = await _db.getUnpaidPaymentsByMonth(yearMonth);
      unpaidPayments.assignAll(unpaid);
      
      lastUpdated.value = DateTime.now();
    } catch (e) {
      Get.snackbar('Error', 'Gagal memuat statistik: $e', 
        snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  void goToPreviousMonth() {
    currentMonth.value = DateTime(
      currentMonth.value.year,
      currentMonth.value.month - 1,
    );
    loadStats();
  }

  void goToNextMonth() {
    final now = DateTime.now();
    final nextMonth = DateTime(
      currentMonth.value.year,
      currentMonth.value.month + 1,
    );
    
    // Check if next month > current month
    if (nextMonth.year > now.year || 
        (nextMonth.year == now.year && nextMonth.month > now.month)) {
      return; // Disable navigation
    }
    
    currentMonth.value = nextMonth;
    loadStats();
  }

  bool canGoToNextMonth() {
    final now = DateTime.now();
    final nextMonth = DateTime(
      currentMonth.value.year,
      currentMonth.value.month + 1,
    );
    return !(nextMonth.year > now.year || 
        (nextMonth.year == now.year && nextMonth.month > now.month));
  }

  bool get isCurrentMonthLatest => !canGoToNextMonth();

  Future<void> _loadAvailableMonths() async {
    final months = await _db.getAvailableMonths();
    availableMonths.value = months;
  }

  String _formatMonth(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  DateTime _getPreviousMonth(DateTime date) {
    return DateTime(date.year, date.month - 1);
  }
}
