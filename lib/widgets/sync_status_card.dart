import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SyncStatusCard extends StatelessWidget {
  final DateTime lastSavedAt;

  const SyncStatusCard({
    super.key,
    required this.lastSavedAt,
  });

  String _getTimeAgo() {
    final diff = DateTime.now().difference(lastSavedAt);
    if (diff.inSeconds < 45) {
      return 'Updated just now';
    } else if (diff.inMinutes < 60) {
      return 'Updated ${diff.inMinutes}m ago';
    } else {
      return 'Updated ${diff.inHours}h ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.tableBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Green Checkmark Icon Badge
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.mintBadgeBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.mintCheck,
              size: 22,
            ),
          ),

          const SizedBox(width: 14),

          // Label and timestamp
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'All changes saved',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getTimeAgo(),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Live sync indicator dot
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.liveGreenDot,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
