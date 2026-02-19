import 'package:flutter/material.dart';

class VerifiedBadge extends StatelessWidget {
  final int? verified;
  final double size;

  const VerifiedBadge({
    super.key,
    required this.verified,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    if (verified == null || verified == 0) return const SizedBox.shrink();

    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.only(left: 3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: verified == 1
            ? const Color(0xFF1D9BF0)
            : const Color(0xFFFF6B35),
      ),
      child: Icon(
        Icons.check,
        size: size * 0.7,
        color: Colors.white,
      ),
    );
  }
}
