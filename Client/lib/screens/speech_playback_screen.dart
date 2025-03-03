// lib/screens/speech_playback_screen.dart
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:vocallabs_flutter_app/utils/constants.dart';
import 'package:vocallabs_flutter_app/widgets/custom_button.dart';

class SpeechPlaybackScreen extends StatefulWidget {
  const SpeechPlaybackScreen({super.key});

  @override
  State<SpeechPlaybackScreen> createState() => _SpeechPlaybackScreenState();
}

class _SpeechPlaybackScreenState extends State<SpeechPlaybackScreen> {
  bool _isPlaying = false;
  double _sliderValue = 0.0;
  String _currentPosition = '00:00';
  final String _totalDuration = '05:30';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review Recording')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Speech Title',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Recorded Today at ${TimeOfDay.now().format(context)}',
                      style: AppTextStyles.body2,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Duration: $_totalDuration',
                      style: AppTextStyles.body2,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              // Waveform visualization
              Container(
                width: double.infinity,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: CustomPaint(
                  painter: WaveformPainter(
                    progress: _sliderValue,
                    activeColor: AppColors.primaryBlue,
                    inactiveColor: Colors.grey.shade300,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Playback controls
              Column(
                children: [
                  Slider(
                    value: _sliderValue,
                    activeColor: AppColors.primaryBlue,
                    inactiveColor: Colors.grey.shade300,
                    onChanged: (value) {
                      setState(() {
                        _sliderValue = value;
                        // Calculate current position based on slider value
                        int totalSeconds = _parseTimeToSeconds(_totalDuration);
                        int currentSeconds = (totalSeconds * value).round();
                        _currentPosition = _formatTime(currentSeconds);
                      });
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text(_currentPosition), Text(_totalDuration)],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.replay_10),
                        iconSize: 36,
                        onPressed: () {
                          // Rewind 10 seconds
                          double newValue =
                              _sliderValue -
                              (10 / _parseTimeToSeconds(_totalDuration));
                          setState(() {
                            _sliderValue = newValue < 0 ? 0 : newValue;
                            int currentSeconds =
                                (_parseTimeToSeconds(_totalDuration) *
                                        _sliderValue)
                                    .round();
                            _currentPosition = _formatTime(currentSeconds);
                          });
                        },
                      ),
                      const SizedBox(width: 20),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isPlaying = !_isPlaying;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(16),
                        ),
                        child: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          size: 40,
                        ),
                      ),
                      const SizedBox(width: 20),
                      IconButton(
                        icon: const Icon(Icons.forward_10),
                        iconSize: 36,
                        onPressed: () {
                          // Forward 10 seconds
                          double newValue =
                              _sliderValue +
                              (10 / _parseTimeToSeconds(_totalDuration));
                          setState(() {
                            _sliderValue = newValue > 1 ? 1 : newValue;
                            int currentSeconds =
                                (_parseTimeToSeconds(_totalDuration) *
                                        _sliderValue)
                                    .round();
                            _currentPosition = _formatTime(currentSeconds);
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              CustomButton(
                text: 'Save and Analyze',
                onPressed: () {
                  // Navigate to analysis results
                  Navigator.pushReplacementNamed(context, '/feedback');
                },
              ),
              const SizedBox(height: 12),
              CustomButton(
                text: 'Discard and Re-record',
                isOutlined: true,
                onPressed: () {
                  _showDiscardDialog();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  int _parseTimeToSeconds(String time) {
    List<String> parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _showDiscardDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Discard Recording?'),
            content: const Text(
              'Are you sure you want to discard this recording and start over?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, '/analysis');
                },
                child: const Text(
                  'Discard and Re-record',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  WaveformPainter({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint activePaint =
        Paint()
          ..color = activeColor
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;

    final Paint inactivePaint =
        Paint()
          ..color = inactiveColor
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;

    const double barWidth = 3;
    const double gap = 3;
    final int numBars = (size.width / (barWidth + gap)).floor();
    final double progressX = size.width * progress;

    // Draw a simulated waveform
    for (int i = 0; i < numBars; i++) {
      double x = i * (barWidth + gap);
      // Generate random but consistent heights using sine function
      double normalizedHeight = 0.1 + 0.8 * (0.5 + 0.5 * sin(i * 0.2));
      double height = size.height * normalizedHeight;
      double top = (size.height - height) / 2;

      canvas.drawLine(
        Offset(x, top),
        Offset(x, top + height),
        x < progressX ? activePaint : inactivePaint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
