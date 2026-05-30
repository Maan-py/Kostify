import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../controllers/statistics_controller.dart';
import '../../utils/validators.dart';

class AdminStatisticsScreen extends StatelessWidget {
  const AdminStatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Register controller if not already registered
    final StatisticsController controller = Get.put(StatisticsController());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Statistik Bulanan', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF8095E4)));
        }

        final monthlyStats = controller.monthlyStats.value;
        final comp = controller.comparison.value;
        final isCurrentLatest = controller.isCurrentMonthLatest;
        final nowStr = DateFormat('HH:mm:ss').format(controller.lastUpdated.value);

        // Check empty state
        final bool isEmpty = (monthlyStats['total_tenant'] as int? ?? 0) == 0 &&
            (monthlyStats['pendapatan'] as int? ?? 0) == 0;

        return RefreshIndicator(
          onRefresh: controller.loadStats,
          color: const Color(0xFF8095E4),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1 & 2. Header & Month Navigation
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: controller.goToPreviousMonth,
                    ),
                    Text(
                      _formatMonthYear(controller.currentMonth.value),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_right_rounded, 
                        color: isCurrentLatest ? Colors.grey : Colors.black),
                      onPressed: isCurrentLatest ? null : controller.goToNextMonth,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (isEmpty)
                  _buildEmptyState()
                else ...[
                  // 3. Quick Stats Cards (Grid 2x2)
                  _buildQuickStats(comp),
                  const SizedBox(height: 20),

                  // 4. Chart 1: Bar Chart - Pendapatan Trend
                  _buildBarChartCard(controller),
                  const SizedBox(height: 20),

                  // 5. Chart 2: Line Chart - Kamar Terisi vs Kosong
                  _buildLineChartCard(controller),
                  const SizedBox(height: 20),

                  // 6 & 7. Pie Chart and Progress Indicator
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildPieChartCard(monthlyStats)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildCircularProgressCard(monthlyStats)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 8. Card: Unpaid Tagihan
                  _buildUnpaidCard(controller),
                  const SizedBox(height: 20),
                ],

                // 9. Last Updated Footer
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Last updated: $nowStr', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF6B7280)),
                        onPressed: controller.loadStats,
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.only(left: 8),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      }),
    );
  }

  String _formatMonthYear(DateTime date) {
    return DateFormat('MMMM yyyy').format(date);
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Column(
        children: [
          Icon(Icons.inbox_rounded, size: 64, color: Color(0xFF9CA3AF)),
          SizedBox(height: 16),
          Text(
            'Belum ada data untuk periode ini',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
          ),
          SizedBox(height: 8),
          Text(
            'Mulai dengan menambah penghuni atau mencatat pembayaran',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(Map<String, dynamic> comp) {
    final diffRev = comp['diff_revenue'] as int? ?? 0;
    final diffAktif = comp['diff_active_tenants'] as int? ?? 0;
    final diffUnpaid = comp['diff_unpaid'] as int? ?? 0;
    
    // We can calculate diff occupancy if we want, but let's just use diffAktif for Empty
    final totalRooms = 13; // AppConstants.ROOM_LABELS.length
    final prevAktif = comp['previous_active_tenants'] as int? ?? 0;
    final prevOccupancy = totalRooms > 0 ? (prevAktif / totalRooms) * 100 : 0.0;
    final currAktif = comp['current_active_tenants'] as int? ?? 0;
    final currOccupancy = totalRooms > 0 ? (currAktif / totalRooms) * 100 : 0.0;
    final diffOccupancy = currOccupancy - prevOccupancy;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Pendapatan',
                value: AppValidators.formatRupiah(comp['current_revenue'] as int? ?? 0),
                diff: diffRev,
                diffFormat: (d) => AppValidators.formatRupiah(d.abs()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: 'Kamar Terisi',
                value: '${comp['current_active_tenants'] ?? 0}',
                diff: diffAktif,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Kamar Kosong',
                value: '${totalRooms - currAktif}',
                diff: -diffAktif, // Inverse of active tenants diff
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: 'Occupancy Rate',
                value: '${currOccupancy.toStringAsFixed(1)}%',
                diffDouble: diffOccupancy,
                diffFormat: (d) => '${d.abs().toStringAsFixed(1)}%',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBarChartCard(StatisticsController controller) {
    final trend = controller.trendData.reversed.toList(); // Earliest to latest

    double maxY = 0;
    for (var m in trend) {
      double r = (m['revenue'] as int? ?? 0).toDouble();
      if (r > maxY) maxY = r;
    }
    if (maxY == 0) maxY = 10000;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tren Pendapatan (6 Bulan)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY * 1.2,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => Colors.black87,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        AppValidators.formatRupiah(rod.toY.toInt()),
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      );
                    },
                  )
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index < 0 || index >= trend.length) return const SizedBox();
                        String b = trend[index]['bulan'] ?? '';
                        if (b.length >= 7) b = '${b.substring(5, 7)}/${b.substring(2, 4)}';
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(b, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index < 0 || index >= trend.length) return const SizedBox();
                        final rev = trend[index]['revenue'] as int? ?? 0;
                        if (rev == 0) return const SizedBox();
                        // Format compact e.g. 1.5M or 500K
                        String compact = NumberFormat.compactCurrency(locale: 'id_ID', symbol: '').format(rev);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Text(compact, style: const TextStyle(fontSize: 9, color: Color(0xFF8095E4), fontWeight: FontWeight.bold)),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
                barGroups: List.generate(trend.length, (index) {
                  final rev = trend[index]['revenue'] as int? ?? 0;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: rev.toDouble(),
                        color: const Color(0xFF8095E4),
                        width: 16,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChartCard(StatisticsController controller) {
    final trend = controller.trendData.reversed.toList();
    
    List<FlSpot> terisiSpots = [];
    List<FlSpot> kosongSpots = [];
    
    double maxY = 13; // Max rooms
    
    for (int i = 0; i < trend.length; i++) {
      terisiSpots.add(FlSpot(i.toDouble(), (trend[i]['active_tenants'] as int? ?? 0).toDouble()));
      kosongSpots.add(FlSpot(i.toDouble(), (trend[i]['empty_rooms'] as int? ?? 0).toDouble()));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Trend Kamar (6 Bulan)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Row(
                children: [
                  _LegendIndicator(color: const Color(0xFF1BC0BA), label: 'Terisi'),
                  const SizedBox(width: 8),
                  _LegendIndicator(color: const Color(0xFF6B7280), label: 'Kosong'),
                ],
              )
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY + 2,
                gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 5),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index < 0 || index >= trend.length) return const SizedBox();
                        String b = trend[index]['bulan'] ?? '';
                        if (b.length >= 7) b = '${b.substring(5, 7)}/${b.substring(2, 4)}';
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(b, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: terisiSpots,
                    isCurved: true,
                    color: const Color(0xFF1BC0BA),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: const Color(0xFF1BC0BA).withOpacity(0.1)),
                  ),
                  LineChartBarData(
                    spots: kosongSpots,
                    isCurved: true,
                    color: const Color(0xFF6B7280),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChartCard(Map<String, dynamic> stats) {
    final tenantAktif = stats['tenant_aktif'] as int? ?? 0;
    final tenantNonAktif = stats['tenant_nonaktif'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          const Text('Tenant Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: (tenantAktif == 0 && tenantNonAktif == 0)
              ? const Center(child: Text('N/A', style: TextStyle(color: Colors.grey)))
              : PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 25,
                    sections: [
                      if (tenantAktif > 0)
                        PieChartSectionData(
                          color: const Color(0xFF1BC0BA),
                          value: tenantAktif.toDouble(),
                          title: '$tenantAktif',
                          radius: 35,
                          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      if (tenantNonAktif > 0)
                        PieChartSectionData(
                          color: const Color(0xFF6B7280),
                          value: tenantNonAktif.toDouble(),
                          title: '$tenantNonAktif',
                          radius: 35,
                          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                    ],
                  ),
                ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendIndicator(color: const Color(0xFF1BC0BA), label: 'Aktif'),
              const SizedBox(width: 8),
              _LegendIndicator(color: const Color(0xFF6B7280), label: 'Kosong'),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCircularProgressCard(Map<String, dynamic> stats) {
    final occupancy = stats['occupancy_rate'] as double? ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          const Text('Occupancy', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          SizedBox(
            height: 110,
            width: 110,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: occupancy / 100,
                  strokeWidth: 10,
                  backgroundColor: const Color(0xFFE5E7EB),
                  color: const Color(0xFF8095E4),
                ),
                Center(
                  child: Text(
                    '${occupancy.toStringAsFixed(1)}%\nTerisi',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _buildUnpaidCard(StatisticsController controller) {
    final unpaid = controller.unpaidPayments;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tagihan Belum Dibayar (Bulan Ini)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          if (unpaid.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1BC0BA).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF1BC0BA)),
                  SizedBox(width: 12),
                  Text('Semua tagihan sudah lunas ✓', style: TextStyle(color: Color(0xFF1A1A2E))),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: unpaid.length,
              separatorBuilder: (ctx, i) => const Divider(),
              itemBuilder: (ctx, i) {
                final p = unpaid[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFFF9800).withOpacity(0.1),
                    child: const Icon(Icons.warning_rounded, color: Color(0xFFFF9800), size: 20),
                  ),
                  title: Text(p.userName ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text('Kamar ${p.nomorKamar ?? '-'}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(AppValidators.formatRupiah(p.amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(p.status.name.toUpperCase(), style: const TextStyle(fontSize: 10, color: Color(0xFFFF9800), fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final int? diff;
  final double? diffDouble;
  final String Function(dynamic)? diffFormat;

  const _StatCard({
    required this.title,
    required this.value,
    this.diff,
    this.diffDouble,
    this.diffFormat,
  });

  @override
  Widget build(BuildContext context) {
    bool isPositive = false;
    bool isZero = true;
    String diffText = '';
    
    if (diff != null) {
      isPositive = diff! > 0;
      isZero = diff == 0;
      diffText = diffFormat != null ? diffFormat!(diff!) : diff!.abs().toString();
    } else if (diffDouble != null) {
      isPositive = diffDouble! > 0;
      isZero = diffDouble == 0;
      diffText = diffFormat != null ? diffFormat!(diffDouble!) : diffDouble!.abs().toString();
    }

    final color = isZero ? Colors.grey : (isPositive ? const Color(0xFF1BC0BA) : const Color(0xFFFF6B6B));
    final icon = isZero ? Icons.remove_rounded : (isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                isZero ? '0' : diffText,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class _LegendIndicator extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendIndicator({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
      ],
    );
  }
}
