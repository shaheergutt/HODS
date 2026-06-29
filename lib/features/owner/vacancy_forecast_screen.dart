import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_colors.dart';
import '../../models/hostel_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/hostel_provider.dart';
import '../../services/analytics_service.dart';

// FutureProvider for fetching vacancy predictions
final vacancyForecastProvider = FutureProvider.family<OccupancyForecast, String>((ref, hostelId) async {
  final user = ref.read(currentUserProvider).value;
  final ownerId = user?.uid ?? '';
  return AnalyticsService().getVacancyPrediction(hostelId, ownerId);
});

class VacancyForecastScreen extends ConsumerStatefulWidget {
  const VacancyForecastScreen({super.key});

  @override
  ConsumerState<VacancyForecastScreen> createState() => _VacancyForecastScreenState();
}

class _VacancyForecastScreenState extends ConsumerState<VacancyForecastScreen> {
  HostelModel? _selectedHostel;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final hostelsAsync = ref.watch(allHostelsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Vacancy Forecast AI', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/owner');
            }
          },
        ),
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.textSecondary))),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User session expired', style: TextStyle(color: AppColors.textSecondary)));
          }

          return hostelsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading hostels: $err', style: const TextStyle(color: AppColors.textSecondary))),
            data: (hostels) {
              final myHostels = hostels.where((h) => h.ownerId == user.uid).toList();

              if (myHostels.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bar_chart_outlined, size: 80, color: AppColors.textHint),
                        SizedBox(height: 16),
                        Text('No Hostels Registered', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text('You need to add a hostel and have active bookings to view occupancy forecasting.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                      ],
                    ),
                  ),
                );
              }

              // Auto-select first hostel if none is selected
              _selectedHostel ??= myHostels.first;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hostel selector
                    const Text('Select Hostel to Analyze', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<HostelModel>(
                          dropdownColor: AppColors.surface,
                          value: _selectedHostel,
                          isExpanded: true,
                          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                          items: myHostels.map((h) {
                            return DropdownMenuItem(
                              value: h,
                              child: Text(h.name),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedHostel = val;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Loading predictions
                    ref.watch(vacancyForecastProvider(_selectedHostel!.id)).when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (err, _) => Center(child: Text('Error computing metrics: $err', style: const TextStyle(color: AppColors.textSecondary))),
                      data: (forecast) => _buildForecastContent(forecast),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildForecastContent(OccupancyForecast forecast) {
    final nextMonthRate = forecast.nextMonthForecastRate;
    final lastMonthRate = forecast.historicalRates.isNotEmpty ? forecast.historicalRates.last * 100.0 : 50.0;
    final isUpwardTrend = nextMonthRate >= lastMonthRate;
    final pctChange = (nextMonthRate - lastMonthRate).abs();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Grid of metric cards
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Next Month Forecast',
                value: '${nextMonthRate.toStringAsFixed(1)}%',
                icon: Icons.auto_graph,
                color: isUpwardTrend ? AppColors.success : AppColors.error,
                subtitle: Row(
                  children: [
                    Icon(
                      isUpwardTrend ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 12,
                      color: isUpwardTrend ? AppColors.success : AppColors.error,
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        '${pctChange.toStringAsFixed(1)}% vs last mo',
                        style: TextStyle(
                          color: isUpwardTrend ? AppColors.success : AppColors.error,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: 'Expected Vacancies',
                value: '${forecast.nextMonthExpectedVacancies}',
                icon: Icons.door_front_door_outlined,
                color: AppColors.primaryLight,
                subtitle: const Text(
                  'Vacant rooms next month',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // fl_chart visual trends
        Container(
          padding: const EdgeInsets.fromLTRB(12, 20, 20, 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.0),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text(
                      'Occupancy Rate Trends (%)',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 8, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text('Historical', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                        SizedBox(width: 12),
                        Icon(Icons.circle, size: 8, color: AppColors.secondary),
                        SizedBox(width: 4),
                        Text('AI Forecast', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (val) => const FlLine(color: AppColors.border, strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 20,
                          getTitlesWidget: (val, meta) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              '${val.toInt()}%',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                            ),
                          ),
                          reservedSize: 36,
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (val, meta) {
                            final idx = val.toInt();
                            if (idx < 0 || idx >= forecast.months.length + 1) return const SizedBox();
                            final month = idx == forecast.months.length ? 'Next' : forecast.months[idx];
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                month,
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: 6,
                    minY: 0,
                    maxY: 100,
                    lineBarsData: [
                      // Historical Line (Months 0-5)
                      LineChartBarData(
                        spots: List.generate(
                          forecast.historicalRates.length,
                          (i) => FlSpot(i.toDouble(), forecast.historicalRates[i] * 100.0),
                        ),
                        isCurved: true,
                        color: AppColors.primary,
                        barWidth: 4,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.primary.withValues(alpha: 0.1),
                        ),
                      ),
                      // Predicted Line (dashed line starting from last historical point to forecast point)
                      LineChartBarData(
                        spots: [
                          FlSpot(5, forecast.historicalRates.last * 100.0),
                          FlSpot(6, forecast.nextMonthForecastRate),
                        ],
                        isCurved: false,
                        dashArray: [5, 5],
                        color: AppColors.secondary,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // AI Recommendations & Insights
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.surface, AppColors.cardColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.insights, color: AppColors.secondary, size: 24),
                  SizedBox(width: 8),
                  Text('AI Forecasting Insights', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _generateRecommendationText(isUpwardTrend, forecast.nextMonthExpectedVacancies, nextMonthRate),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: AppColors.primaryLight, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tip: Set up "Tourist Mode" (Daily Bookings) in settings to fill sudden mid-month vacancies.',
                        style: TextStyle(color: AppColors.primaryLight, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Widget subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          subtitle,
        ],
      ),
    );
  }

  String _generateRecommendationText(bool isUpwardTrend, int expectedVacancies, double nextMonthRate) {
    final name = _selectedHostel?.name ?? 'your hostel';
    if (isUpwardTrend) {
      if (expectedVacancies <= 2) {
        return 'Occupancy for $name is projected to peak at ${nextMonthRate.toStringAsFixed(1)}% next month. Since you are near full capacity, we recommend maintaining your current rates. You can prioritize premium listings or review reservations to ensure smooth check-ins.';
      } else {
        return 'We forecast an upward occupancy shift to ${nextMonthRate.toStringAsFixed(1)}% next month for $name. Demand is growing steadily. Consider hosting promotional campaigns or reaching out to student matching groups to lock in the remaining $expectedVacancies room vacancies early.';
      }
    } else {
      if (nextMonthRate < 40) {
        return 'A significant decline in occupancy (${nextMonthRate.toStringAsFixed(1)}%) is forecasted for $name next month. Action is required. We strongly recommend reducing the price per month slightly or promoting daily tourist accommodations to attract flexible travelers and reduce vacancies.';
      } else {
        return 'Occupancy is projected to dip slightly to ${nextMonthRate.toStringAsFixed(1)}% next month, leaving approximately $expectedVacancies rooms vacant. To stabilize your bookings, you can feature your hostel in AI recommendations or resolve pending complaints to boost guest reviews.';
      }
    }
  }
}
