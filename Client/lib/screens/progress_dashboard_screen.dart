// lib/screens/progress_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:vocallabs_flutter_app/utils/constants.dart';
import 'package:vocallabs_flutter_app/widgets/card_layout.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProgressDashboardScreen extends StatefulWidget {
  const ProgressDashboardScreen({super.key});

  @override
  State<ProgressDashboardScreen> createState() =>
      _ProgressDashboardScreenState();
}

class _ProgressDashboardScreenState extends State<ProgressDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryBlue,
          unselectedLabelColor: AppColors.lightText,
          indicatorColor: AppColors.primaryBlue,
          tabs: const [
            Tab(text: 'WEEKLY'),
            Tab(text: 'MONTHLY'),
            Tab(text: 'YEARLY'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildWeeklyView(), _buildMonthlyView(), _buildYearlyView()],
      ),
    );
  }

  Widget _buildWeeklyView() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _streamSpeechData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No data available for this week.'));
        }

        // Process the weekly data
        final weeklyData = _processWeeklyData(snapshot.data!);

        if (weeklyData.isEmpty) {
          return const Center(child: Text('No data available for this week.'));
        }

        // Calculate metrics
        final totalSpeeches = snapshot.data!.length;

        // Calculate total duration in seconds
        final totalDurationInSeconds = snapshot.data!
            .map((speech) {
              final duration = speech['actual_duration'] as String? ?? '0:00';
              final parts = duration.split(':');
              if (parts.length == 2) {
                final minutes = int.tryParse(parts[0]) ?? 0;
                final seconds = int.tryParse(parts[1]) ?? 0;
                return minutes * 60 + seconds;
              }
              return 0;
            })
            .reduce((a, b) => a + b);

        // Calculate average duration
        final avgDurationInSeconds =
            totalSpeeches > 0 ? totalDurationInSeconds / totalSpeeches : 0;
        final avgDurationMinutes = (avgDurationInSeconds ~/ 60).toString();
        final avgDurationSeconds = (avgDurationInSeconds % 60).round().toString().padLeft(2, '0');

        return SingleChildScrollView(
          child: Padding(
            padding: AppPadding.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Text(
                  'This Week\'s Performance',
                  style: AppTextStyles.heading2,
                ),
                const SizedBox(height: 20),
                CardLayout(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overall Score Trend',
                        style: AppTextStyles.body1.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 200,
                        child: LineChart(_generateWeeklyScoreData(weeklyData)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Speech Metrics', style: AppTextStyles.heading2),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Speeches',
                        value: '$totalSpeeches',
                        icon: Icons.mic,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Avg. Duration',
                        value: '$avgDurationMinutes:$avgDurationSeconds',
                        icon: Icons.timer,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Areas for Improvement', style: AppTextStyles.heading2),
                const SizedBox(height: 16),
                CardLayout(
                  child: Column(
                    children: [
                      _buildImprovementItem(
                        title: 'Volume Consistency',
                        subtitle: 'Work on maintaining consistent volume levels',
                        icon: Icons.volume_up,
                        color: AppColors.warning,
                        percentage: 68,
                      ),
                      const Divider(height: 24),
                      _buildImprovementItem(
                        title: 'Speech Duration',
                        subtitle: 'Try to keep speeches within target duration',
                        icon: Icons.timer,
                        color: AppColors.error,
                        percentage: 45,
                      ),
                      const Divider(height: 24),
                      _buildImprovementItem(
                        title: 'Pronunciation',
                        subtitle: 'Overall pronunciation clarity is improving',
                        icon: Icons.record_voice_over,
                        color: AppColors.success,
                        percentage: 82,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMonthlyView() {
    return SingleChildScrollView(
      child: Padding(
        padding: AppPadding.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              'This Month\'s Performance',
              style: AppTextStyles.heading2,
            ),
            const SizedBox(height: 20),
            CardLayout(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overall Score Trend',
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(height: 200, child: LineChart(_monthlyScoreData())),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Monthly Metrics', style: AppTextStyles.heading2),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Total Speeches',
                    value: '23',
                    icon: Icons.mic,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Avg. Duration',
                    value: '5:15',
                    icon: Icons.timer,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Total Filler Words',
                    value: '85',
                    icon: Icons.text_fields,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Avg. Pace',
                    value: '145 wpm',
                    icon: Icons.speed,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Areas for Improvement', style: AppTextStyles.heading2),
            const SizedBox(height: 16),
            CardLayout(
              child: Column(
                children: [
                  _buildImprovementItem(
                    title: 'Volume Consistency',
                    subtitle: 'Work on maintaining consistent volume levels',
                    icon: Icons.volume_up,
                    color: AppColors.warning,
                    percentage: 68,
                  ),
                  const Divider(height: 24),
                  _buildImprovementItem(
                    title: 'Speech Duration',
                    subtitle: 'Try to keep speeches within target duration',
                    icon: Icons.timer,
                    color: AppColors.error,
                    percentage: 45,
                  ),
                  const Divider(height: 24),
                  _buildImprovementItem(
                    title: 'Pronunciation',
                    subtitle: 'Overall pronunciation clarity is improving',
                    icon: Icons.record_voice_over,
                    color: AppColors.success,
                    percentage: 82,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearlyView() {
    return SingleChildScrollView(
      child: Padding(
        padding: AppPadding.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              'This Year\'s Performance',
              style: AppTextStyles.heading2,
            ),
            const SizedBox(height: 20),
            CardLayout(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overall Score Trend',
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(height: 200, child: LineChart(_yearlyScoreData())),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Yearly Metrics', style: AppTextStyles.heading2),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Total Speeches',
                    value: '245',
                    icon: Icons.mic,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Avg. Duration',
                    value: '6:00',
                    icon: Icons.timer,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Improvement Rate',
                    value: '+15%',
                    icon: Icons.trending_up,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Best Score',
                    value: '92',
                    icon: Icons.star,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Yearly Progress Highlights',
              style: AppTextStyles.heading2,
            ),
            const SizedBox(height: 16),
            CardLayout(
              child: Column(
                children: [
                  _buildImprovementItem(
                    title: 'Overall Performance',
                    subtitle: 'Significant improvement in speaking confidence',
                    icon: Icons.trending_up,
                    color: AppColors.success,
                    percentage: 88,
                  ),
                  const Divider(height: 24),
                  _buildImprovementItem(
                    title: 'Consistent Practice',
                    subtitle: 'Maintained regular practice schedule',
                    icon: Icons.calendar_today,
                    color: AppColors.primaryBlue,
                    percentage: 92,
                  ),
                  const Divider(height: 24),
                  _buildImprovementItem(
                    title: 'Speech Quality',
                    subtitle: 'Enhanced overall delivery and content structure',
                    icon: Icons.assessment,
                    color: AppColors.accent,
                    percentage: 85,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return CardLayout(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppTextStyles.body2),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImprovementItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required int percentage,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.body1.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: AppTextStyles.body2),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: AppColors.lightBlue,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 5,
                borderRadius: BorderRadius.circular(3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  LineChartData _weeklyScoreData() {
    List<FlSpot> spots = [
      const FlSpot(0, 75),
      const FlSpot(1, 78),
      const FlSpot(2, 76),
      const FlSpot(3, 80),
      const FlSpot(4, 82),
      const FlSpot(5, 85),
      const FlSpot(6, 83),
    ];

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 10,
        getDrawingHorizontalLine: (value) {
          return FlLine(color: Colors.grey.shade200, strokeWidth: 1);
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              const style = TextStyle(color: AppColors.lightText, fontSize: 12);
              String text;
              switch (value.toInt()) {
                case 0:
                  text = 'Mon';
                  break;
                case 1:
                  text = 'Tue';
                  break;
                case 2:
                  text = 'Wed';
                  break;
                case 3:
                  text = 'Thu';
                  break;
                case 4:
                  text = 'Fri';
                  break;
                case 5:
                  text = 'Sat';
                  break;
                case 6:
                  text = 'Sun';
                  break;
                default:
                  text = '';
              }
              return Text(text, style: style);
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 10,
            reservedSize: 30,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toInt().toString(),
                style: const TextStyle(
                  color: AppColors.lightText,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: 6,
      minY: 60,
      maxY: 100,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: AppColors.primaryBlue,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 4,
                color: AppColors.primaryBlue,
                strokeWidth: 2,
                strokeColor: Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            color: AppColors.primaryBlue.withOpacity(0.2),
          ),
        ),
      ],
    );
  }

  LineChartData _monthlyScoreData() {
    List<FlSpot> spots = [
      const FlSpot(0, 77),
      const FlSpot(1, 80),
      const FlSpot(2, 82),
      const FlSpot(3, 85),
    ];

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 10,
        getDrawingHorizontalLine: (value) {
          return FlLine(color: Colors.grey.shade200, strokeWidth: 1);
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              const style = TextStyle(color: AppColors.lightText, fontSize: 12);
              String text;
              switch (value.toInt()) {
                case 0:
                  text = 'Week 1';
                  break;
                case 1:
                  text = 'Week 2';
                  break;
                case 2:
                  text = 'Week 3';
                  break;
                case 3:
                  text = 'Week 4';
                  break;
                default:
                  text = '';
              }
              return Text(text, style: style);
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 10,
            reservedSize: 30,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toInt().toString(),
                style: const TextStyle(
                  color: AppColors.lightText,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: 3,
      minY: 60,
      maxY: 100,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: AppColors.primaryBlue,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 4,
                color: AppColors.primaryBlue,
                strokeWidth: 2,
                strokeColor: Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            color: AppColors.primaryBlue.withOpacity(0.2),
          ),
        ),
      ],
    );
  }

  LineChartData _yearlyScoreData() {
    List<FlSpot> spots = [
      const FlSpot(0, 70),
      const FlSpot(1, 72),
      const FlSpot(2, 75),
      const FlSpot(3, 78),
      const FlSpot(4, 80),
      const FlSpot(5, 82),
      const FlSpot(6, 81),
      const FlSpot(7, 83),
      const FlSpot(8, 85),
      const FlSpot(9, 84),
      const FlSpot(10, 86),
      const FlSpot(11, 85),
    ];

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 10,
        getDrawingHorizontalLine: (value) {
          return FlLine(color: Colors.grey.shade200, strokeWidth: 1);
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              const style = TextStyle(color: AppColors.lightText, fontSize: 12);
              String text;
              switch (value.toInt()) {
                case 0:
                  text = 'Jan';
                  break;
                case 3:
                  text = 'Apr';
                  break;
                case 6:
                  text = 'Jul';
                  break;
                case 9:
                  text = 'Oct';
                  break;
                default:
                  text = '';
              }
              return Text(text, style: style);
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 10,
            reservedSize: 30,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toInt().toString(),
                style: const TextStyle(
                  color: AppColors.lightText,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: 11,
      minY: 60,
      maxY: 100,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: AppColors.primaryBlue,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 4,
                color: AppColors.primaryBlue,
                strokeWidth: 2,
                strokeColor: Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            color: AppColors.primaryBlue.withOpacity(0.2),
          ),
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _fetchSpeechData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return [];
    }

    try {
      final speechesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('speeches')
          .get();

      final data = speechesSnapshot.docs.map((doc) => doc.data()).toList();
      print('Fetched speech data: $data'); // Debug log
      return data;
    } catch (e) {
      print('Error fetching speech data: $e');
      return [];
    }
  }

  Map<String, double> _processWeeklyData(List<Map<String, dynamic>> speeches) {
  final now = DateTime.now();
  final lastWeek = now.subtract(const Duration(days: 7));

  // Initialize a map to store scores for each day
  final Map<int, List<double>> dailyScores = {};

  for (var speech in speeches) {
    final recordedAt = speech['recorded_at'];
    DateTime? recordedDate;

    // Check the type of recorded_at and convert it to DateTime
    if (recordedAt is Timestamp) {
      recordedDate = recordedAt.toDate();
    } else if (recordedAt is String) {
      if (recordedAt == "firestore.SERVER_TIMESTAMP") {
        // Assign a fallback value (e.g., current date and time)
        recordedDate = now;
      } else {
        try {
          recordedDate = DateTime.parse(recordedAt);
        } catch (e) {
          print('Error parsing recorded_at: $e');
          continue; // Skip this speech if parsing fails
        }
      }
    }

    if (recordedDate != null && recordedDate.isAfter(lastWeek)) {
      final dayOfWeek = recordedDate.weekday; // 1 = Monday, 7 = Sunday
      final score = speech['proficiency_score'] as double? ?? 0.0;

      if (!dailyScores.containsKey(dayOfWeek)) {
        dailyScores[dayOfWeek] = [];
      }
      dailyScores[dayOfWeek]!.add(score);
    }
  }

  // Calculate average score for each day
  final Map<String, double> weeklyAverages = {};
  for (var entry in dailyScores.entries) {
    final dayOfWeek = entry.key;
    final scores = entry.value;
    final averageScore = scores.reduce((a, b) => a + b) / scores.length;

    // Map dayOfWeek to a string (e.g., "Mon", "Tue")
    final dayName = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][dayOfWeek - 1];
    weeklyAverages[dayName] = averageScore;
  }

  print('Processed weekly data: $weeklyAverages'); // Debug log
  return weeklyAverages;
}

  Map<int, double> _processMonthlyData(List<Map<String, dynamic>> speeches) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    // Initialize a map to store scores for each week
    final Map<int, List<double>> weeklyScores = {};

    for (var speech in speeches) {
      final recordedAt = (speech['recorded_at'] as Timestamp?)?.toDate();
      if (recordedAt != null && recordedAt.isAfter(firstDayOfMonth)) {
        final weekOfMonth = ((recordedAt.day - 1) ~/ 7) + 1; // Calculate week of the month
        final score = speech['proficiency_score'] as double? ?? 0.0;

        if (!weeklyScores.containsKey(weekOfMonth)) {
          weeklyScores[weekOfMonth] = [];
        }
        weeklyScores[weekOfMonth]!.add(score);
      }
    }

    // Calculate average score for each week
    final Map<int, double> monthlyAverages = {};
    for (var entry in weeklyScores.entries) {
      final weekOfMonth = entry.key;
      final scores = entry.value;
      final averageScore = scores.reduce((a, b) => a + b) / scores.length;

      monthlyAverages[weekOfMonth] = averageScore;
    }

    return monthlyAverages;
  }

  Map<int, double> _processYearlyData(List<Map<String, dynamic>> speeches) {
    final now = DateTime.now();
    final firstDayOfYear = DateTime(now.year, 1, 1);

    // Initialize a map to store scores for each month
    final Map<int, List<double>> monthlyScores = {};

    for (var speech in speeches) {
      final recordedAt = (speech['recorded_at'] as Timestamp?)?.toDate();
      if (recordedAt != null && recordedAt.isAfter(firstDayOfYear)) {
        final month = recordedAt.month; // 1 = January, 12 = December
        final score = speech['proficiency_score'] as double? ?? 0.0;

        if (!monthlyScores.containsKey(month)) {
          monthlyScores[month] = [];
        }
        monthlyScores[month]!.add(score);
      }
    }

    // Calculate average score for each month
    final Map<int, double> yearlyAverages = {};
    for (var entry in monthlyScores.entries) {
      final month = entry.key;
      final scores = entry.value;
      final averageScore = scores.reduce((a, b) => a + b) / scores.length;

      yearlyAverages[month] = averageScore;
    }

    return yearlyAverages;
  }

  LineChartData _generateWeeklyScoreData(Map<String, double> weeklyData) {
  print('Weekly data for graph: $weeklyData'); // Debug log

  final spots = weeklyData.entries
      .map((entry) => FlSpot(
            ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .indexOf(entry.key)
                .toDouble(),
            entry.value,
          ))
      .toList();

  return LineChartData(
    gridData: FlGridData(
      show: true,
      drawVerticalLine: true,
      horizontalInterval: 20, // Grid lines every 20 units
      verticalInterval: 1, // Grid lines every 1 unit on X-axis
      getDrawingHorizontalLine: (value) {
        return FlLine(
          color: Colors.grey.shade300.withOpacity(0.5), // Lighter gray
          strokeWidth: 0.8, // Thinner lines
        );
      },
      getDrawingVerticalLine: (value) {
        return FlLine(
          color: Colors.grey.shade300.withOpacity(0.5), // Lighter gray
          strokeWidth: 0.8, // Thinner lines
        );
      },
    ),
    titlesData: FlTitlesData(
      show: true,
      rightTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: 1, // Ensure labels are only shown for integer values
          getTitlesWidget: (value, meta) {
            const style = TextStyle(color: AppColors.lightText, fontSize: 12);
            String text = '';
            switch (value.toInt()) {
              case 0:
                text = 'Mon';
                break;
              case 1:
                text = 'Tue';
                break;
              case 2:
                text = 'Wed';
                break;
              case 3:
                text = 'Thu';
                break;
              case 4:
                text = 'Fri';
                break;
              case 5:
                text = 'Sat';
                break;
              case 6:
                text = 'Sun';
                break;
              default:
                text = '';
            }
            return Text(text, style: style);
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: 20, // Only show labels for multiples of 20
          reservedSize: 30,
          getTitlesWidget: (value, meta) {
            // Only show labels for multiples of 20
            if (value % 20 == 0) {
              return Text(
                value.toInt().toString(),
                style: const TextStyle(
                  color: AppColors.lightText,
                  fontSize: 12,
                ),
              );
            }
            return const SizedBox.shrink(); // Hide other labels
          },
        ),
      ),
    ),
    borderData: FlBorderData(
      show: true,
      border: Border.all(color: Colors.grey.shade300, width: 1),
    ),
    minX: 0,
    maxX: 6,
    minY: 0,
    maxY: 100,
    lineBarsData: [
      LineChartBarData(
        spots: spots,
        isCurved: true,
        color: AppColors.primaryBlue,
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            return FlDotCirclePainter(
              radius: 4,
              color: AppColors.primaryBlue,
              strokeWidth: 2,
              strokeColor: Colors.white,
            );
          },
        ),
        belowBarData: BarAreaData(
          show: true,
          color: AppColors.primaryBlue.withOpacity(0.2),
        ),
      ),
    ],
    lineTouchData: LineTouchData(
      touchTooltipData: LineTouchTooltipData(
        tooltipBgColor: Colors.white,
        tooltipRoundedRadius: 8,
        getTooltipItems: (touchedSpots) {
          return touchedSpots.map((spot) {
            final day = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][spot.x.toInt()];
            return LineTooltipItem(
              '$day\nScore: ${spot.y.toStringAsFixed(1)}',
              const TextStyle(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.bold,
              ),
            );
          }).toList();
        },
      ),
      handleBuiltInTouches: true,
    ),
  );
}

  Stream<List<Map<String, dynamic>>> _streamSpeechData() {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return const Stream.empty();
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('speeches')
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList());
}
}
