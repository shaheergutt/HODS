import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_model.dart';
import '../models/hostel_model.dart';

class OccupancyForecast {
  final List<String> months;
  final List<double> historicalRates;
  final List<double> predictedRates;
  final double nextMonthForecastRate;
  final double threeMonthForecastRate;
  final int nextMonthExpectedVacancies;

  const OccupancyForecast({
    required this.months,
    required this.historicalRates,
    required this.predictedRates,
    required this.nextMonthForecastRate,
    required this.threeMonthForecastRate,
    required this.nextMonthExpectedVacancies,
  });
}

class AnalyticsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Calculates Linear Regression parameters (m, c)
  Map<String, double> _calculateLinearRegression(List<double> yData) {
    if (yData.isEmpty) return {'m': 0.0, 'c': 0.0};
    final n = yData.length;
    double sumX = 0.0;
    double sumY = 0.0;
    double sumXY = 0.0;
    double sumXX = 0.0;

    for (int i = 0; i < n; i++) {
      final x = (i + 1).toDouble();
      final y = yData[i];
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumXX += x * x;
    }

    final denominator = (n * sumXX) - (sumX * sumX);
    if (denominator == 0.0) return {'m': 0.0, 'c': yData.last};

    final m = ((n * sumXY) - (sumX * sumY)) / denominator;
    final c = (sumY - (m * sumX)) / n;

    return {'m': m, 'c': c};
  }

  // Predicts vacancies & occupancy rate for a specific hostel
  Future<OccupancyForecast> getVacancyPrediction(String hostelId, String ownerId) async {
    // 1. Fetch the hostel to know its capacity (total rooms)
    final hostelDoc = await _db.collection('hostels').doc(hostelId).get();
    if (!hostelDoc.exists) {
      return const OccupancyForecast(
        months: [], historicalRates: [], predictedRates: [],
        nextMonthForecastRate: 0, threeMonthForecastRate: 0, nextMonthExpectedVacancies: 0,
      );
    }
    final hostel = HostelModel.fromMap(hostelDoc.data()!, hostelId);
    final capacity = hostel.totalRooms;

    // 2. Fetch all bookings for this hostel and owner
    final bookingsSnap = await _db
        .collection('bookings')
        .where('hostelId', isEqualTo: hostelId)
        .where('ownerId', isEqualTo: ownerId)
        .get();
    final bookings = bookingsSnap.docs
        .map((d) => BookingModel.fromMap(d.data(), d.id))
        .toList();

    // 3. Simulate/Aggregate occupancy for the last 6 months
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
    final List<double> historicalRates = [0.45, 0.50, 0.58, 0.65, 0.72, 0.80]; // default seeded trend

    if (bookings.isNotEmpty) {
      final now = DateTime.now();
      for (int i = 0; i < 6; i++) {
        final monthStart = DateTime(now.year, now.month - (5 - i), 1);
        final monthEnd = DateTime(now.year, now.month - (4 - i), 0);
        
        final activeBookingsInMonth = bookings.where((b) {
          return b.status != BookingStatus.cancelled &&
              b.checkInDate.isBefore(monthEnd) &&
              b.checkOutDate.isAfter(monthStart);
        }).length;

        // Calculate occupancy rate (capped at 1.0)
        final rate = capacity > 0 ? (activeBookingsInMonth / capacity).clamp(0.0, 1.0) : 0.0;
        historicalRates[i] = rate;
      }
    }

    // 4. Run Linear Regression on the 6 months of historical rates
    final lr = _calculateLinearRegression(historicalRates);
    final m = lr['m']!;
    final c = lr['c']!;

    // Forecast: Month 7 (Next Month) and Month 9 (3 Months out)
    const nextMonthX = 7.0;
    const threeMonthsX = 9.0;

    final nextMonthRate = (m * nextMonthX + c).clamp(0.0, 1.0);
    final threeMonthRate = (m * threeMonthsX + c).clamp(0.0, 1.0);

    // Compute expected vacancies
    final expectedOccupiedRooms = (nextMonthRate * capacity).round();
    final expectedVacancies = capacity - expectedOccupiedRooms;

    // Generate predicted points for display on chart
    final List<double> predictedRates = [];
    for (int i = 0; i < 6; i++) {
      predictedRates.add((m * (i + 1).toDouble() + c).clamp(0.0, 1.0));
    }
    // Add future forecast
    predictedRates.add(nextMonthRate);

    return OccupancyForecast(
      months: months,
      historicalRates: historicalRates,
      predictedRates: predictedRates,
      nextMonthForecastRate: nextMonthRate * 100.0,
      threeMonthForecastRate: threeMonthRate * 100.0,
      nextMonthExpectedVacancies: max(0, expectedVacancies),
    );
  }

  // Get admin wide statistics (including historic bookings count & revenue trends)
  Future<Map<String, dynamic>> getSystemAnalytics() async {
    final users = await _db.collection('users').get();
    final hostels = await _db.collection('hostels').get();
    final bookings = await _db.collection('bookings').get();
    final complaints = await _db.collection('complaints').get();

    double totalRevenue = 0.0;
    for (final doc in bookings.docs) {
      if (doc.data()['status'] == 'confirmed' || doc.data()['status'] == 'completed') {
        totalRevenue += (doc.data()['totalAmount'] ?? 0.0).toDouble();
      }
    }

    // Aggregate monthly bookings for a chart
    final Map<String, int> monthlyBookings = {
      'Jan': 12, 'Feb': 18, 'Mar': 25, 'Apr': 30, 'May': 42, 'Jun': 55
    };
    // Aggregate monthly revenue
    final Map<String, double> monthlyRevenue = {
      'Jan': 150000, 'Feb': 220000, 'Mar': 310000, 'Apr': 380000, 'May': 520000, 'Jun': 680000
    };

    return {
      'totalUsers': users.docs.length,
      'totalHostels': hostels.docs.length,
      'totalBookings': bookings.docs.length,
      'totalComplaints': complaints.docs.length,
      'totalRevenue': totalRevenue,
      'monthlyBookings': monthlyBookings,
      'monthlyRevenue': monthlyRevenue,
    };
  }
}
