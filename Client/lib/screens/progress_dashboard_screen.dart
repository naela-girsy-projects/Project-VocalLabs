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
    _tabController = TabController(length: 2, vsync: this);
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
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildWeeklyView(), _buildMonthlyView()],
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

        // Debug log to verify fetched data
        print('Fetched weekly speech data: ${snapshot.data}');

        // Process the weekly data
        final weeklyData = _processWeeklyData(snapshot.data!);

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
  return StreamBuilder<List<Map<String, dynamic>>>(
    stream: _streamMonthlySpeechData(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
        return const Center(child: Text('No data available for this month.'));
      }

      // Debug log to verify fetched data
      print('Fetched monthly speech data: ${snapshot.data}');

      // Process the monthly data
      final monthlyData = _processMonthlyData(snapshot.data!);

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
                    SizedBox(
                      height: 200,
                      child: LineChart(_generateMonthlyScoreData(monthlyData)),
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
      horizontalInterval: 20,
      verticalInterval: 1,
      getDrawingHorizontalLine: (value) {
        return FlLine(
          color: Colors.grey.shade300.withOpacity(0.5),
          strokeWidth: 0.8,
        );
      },
      getDrawingVerticalLine: (value) {
        return FlLine(
          color: Colors.grey.shade300.withOpacity(0.5),
          strokeWidth: 0.8,
        );
      },
    ),
    titlesData: FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: 1, // Set interval to 1 to remove unnecessary scales
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
          interval: 20,
          getTitlesWidget: (value, meta) {
            return Text(
              value.toInt().toString(),
              style: const TextStyle(color: AppColors.lightText, fontSize: 12),
            );
          },
        ),
      ),
      topTitles: AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      rightTitles: AxisTitles(
        sideTitles: SideTitles(showTitles: false),
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
  );
}

  LineChartData _generateMonthlyScoreData(Map<String, double> monthlyData) {
  print('Monthly data for graph: $monthlyData'); // Debug log

  final spots = monthlyData.entries
      .map((entry) => FlSpot(
            double.parse(entry.key.split(' ')[1]) - 1,
            entry.value,
          ))
      .toList();

  return LineChartData(
    gridData: FlGridData(
      show: true,
      drawVerticalLine: true,
      horizontalInterval: 20,
      verticalInterval: 1,
      getDrawingHorizontalLine: (value) {
        return FlLine(
          color: Colors.grey.shade300.withOpacity(0.5),
          strokeWidth: 0.8,
        );
      },
      getDrawingVerticalLine: (value) {
        return FlLine(
          color: Colors.grey.shade300.withOpacity(0.5),
          strokeWidth: 0.8,
        );
      },
    ),
    titlesData: FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: 1, // Set interval to 1 to remove unnecessary scales
          getTitlesWidget: (value, meta) {
            const style = TextStyle(color: AppColors.lightText, fontSize: 12);
            String text = '';
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
          interval: 20,
          getTitlesWidget: (value, meta) {
            return Text(
              value.toInt().toString(),
              style: const TextStyle(color: AppColors.lightText, fontSize: 12),
            );
          },
        ),
      ),
      topTitles: AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      rightTitles: AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
    ),
    borderData: FlBorderData(
      show: true,
      border: Border.all(color: Colors.grey.shade300, width: 1),
    ),
    minX: 0,
    maxX: 3,
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

Stream<List<Map<String, dynamic>>> _streamMonthlySpeechData() {
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

Map<String, double> _processWeeklyData(List<Map<String, dynamic>> data) {
  final Map<String, double> weeklyData = {
    'Mon': 0.0,
    'Tue': 0.0,
    'Wed': 0.0,
    'Thu': 0.0,
    'Fri': 0.0,
    'Sat': 0.0,
    'Sun': 0.0,
  };

  final Map<String, int> countData = {
    'Mon': 0,
    'Tue': 0,
    'Wed': 0,
    'Thu': 0,
    'Fri': 0,
    'Sat': 0,
    'Sun': 0,
  };

  for (var speech in data) {
    final dateField = speech['date'];
    DateTime date;

    if (dateField is Timestamp) {
      date = dateField.toDate();
    } else if (dateField is DateTime) {
      date = dateField;
    } else {
      continue; // Skip if date is not a valid type
    }

    final day = date.weekday;
    final score = speech['overall_score'] as double? ?? 0.0;

    switch (day) {
      case DateTime.monday:
        weeklyData['Mon'] = weeklyData['Mon']! + score;
        countData['Mon'] = countData['Mon']! + 1;
        break;
      case DateTime.tuesday:
        weeklyData['Tue'] = weeklyData['Tue']! + score;
        countData['Tue'] = countData['Tue']! + 1;
        break;
      case DateTime.wednesday:
        weeklyData['Wed'] = weeklyData['Wed']! + score;
        countData['Wed'] = countData['Wed']! + 1;
        break;
      case DateTime.thursday:
        weeklyData['Thu'] = weeklyData['Thu']! + score;
        countData['Thu'] = countData['Thu']! + 1;
        break;
      case DateTime.friday:
        weeklyData['Fri'] = weeklyData['Fri']! + score;
        countData['Fri'] = countData['Fri']! + 1;
        break;
      case DateTime.saturday:
        weeklyData['Sat'] = weeklyData['Sat']! + score;
        countData['Sat'] = countData['Sat']! + 1;
        break;
      case DateTime.sunday:
        weeklyData['Sun'] = weeklyData['Sun']! + score;
        countData['Sun'] = countData['Sun']! + 1;
        break;
    }
  }

  // Calculate average scores
  weeklyData.forEach((key, value) {
    if (countData[key]! > 0) {
      weeklyData[key] = value / countData[key]!;
    }
  });

  return weeklyData;
}

Map<String, double> _processMonthlyData(List<Map<String, dynamic>> data) {
  final Map<String, double> monthlyData = {
    'Week 1': 0.0,
    'Week 2': 0.0,
    'Week 3': 0.0,
    'Week 4': 0.0,
  };

  final Map<String, int> countData = {
    'Week 1': 0,
    'Week 2': 0,
    'Week 3': 0,
    'Week 4': 0,
  };

  for (var speech in data) {
    final dateField = speech['date'];
    DateTime date;

    if (dateField is Timestamp) {
      date = dateField.toDate();
    } else if (dateField is DateTime) {
      date = dateField;
    } else {
      continue; // Skip if date is not a valid type
    }

    final week = (date.day - 1) ~/ 7;
    final score = speech['overall_score'] as double? ?? 0.0;

    switch (week) {
      case 0:
        monthlyData['Week 1'] = monthlyData['Week 1']! + score;
        countData['Week 1'] = countData['Week 1']! + 1;
        break;
      case 1:
        monthlyData['Week 2'] = monthlyData['Week 2']! + score;
        countData['Week 2'] = countData['Week 2']! + 1;
        break;
      case 2:
        monthlyData['Week 3'] = monthlyData['Week 3']! + score;
        countData['Week 3'] = countData['Week 3']! + 1;
        break;
      case 3:
        monthlyData['Week 4'] = monthlyData['Week 4']! + score;
        countData['Week 4'] = countData['Week 4']! + 1;
        break;
    }
  }

  // Calculate average scores
  monthlyData.forEach((key, value) {
    if (countData[key]! > 0) {
      monthlyData[key] = value / countData[key]!;
    }
  });

  return monthlyData;
}
    }