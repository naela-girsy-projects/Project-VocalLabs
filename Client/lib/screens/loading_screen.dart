import 'package:flutter/material.dart';
import 'package:vocallabs_flutter_app/utils/constants.dart';
import 'dart:async';

class LoadingScreen extends StatefulWidget {
  final String message;

  const LoadingScreen({
    super.key,
    this.message = 'Analyzing your speech...',
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  String dots = '';
  late Timer dotsTimer;
  late Timer messageTimer;
  bool isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    dotsTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        dots = dots.length >= 3 ? '' : dots + '.';
      });
    });

    messageTimer = Timer(const Duration(seconds: 15), () {
      setState(() {
        isAnalyzing = true;
      });
    });
  }

  String get loadingMessage => isAnalyzing ? 'Analyzing speech' : 'Transcribing speech';

  @override
  void dispose() {
    dotsTimer.cancel();
    messageTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
              strokeWidth: 4,
            ),
            const SizedBox(height: 24),
            Text(
              widget.message,
              style: AppTextStyles.heading2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  loadingMessage,
                  style: AppTextStyles.body2,
                ),
                SizedBox(
                  width: 30,
                  child: Text(
                    dots,
                    style: AppTextStyles.body2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
