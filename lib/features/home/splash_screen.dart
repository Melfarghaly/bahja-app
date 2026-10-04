import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: BahgaMark(size: 72)));
}

/// The brand mark: a coral dot in a teal rounded square.
class BahgaMark extends StatelessWidget {
  const BahgaMark({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppColors.teal,
      borderRadius: BorderRadius.circular(size * 0.28),
    ),
    alignment: Alignment.center,
    child: Container(
      width: size * 0.3,
      height: size * 0.3,
      decoration: const BoxDecoration(
        color: AppColors.coral,
        shape: BoxShape.circle,
      ),
    ),
  );
}
