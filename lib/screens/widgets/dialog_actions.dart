import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class DialogActions extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onToggleFavorite;

  const DialogActions({
    super.key,
    required this.isFavorite,
    required this.onCopy,
    required this.onShare,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
    child: Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.copy_rounded),
          label: const Text('Sao chép'),
          onPressed: onCopy,
          style:
          ElevatedButton.styleFrom(backgroundColor: AppTheme.primarySoft),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.share_rounded),
          label: const Text('Chia sẻ'),
          onPressed: onShare,
          style:
          ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.favorite_rounded, color: Colors.white),
          label: Text(isFavorite ? 'Bỏ yêu thích' : 'Yêu thích'),
          style: ElevatedButton.styleFrom(
            backgroundColor:
            isFavorite ? Colors.pinkAccent : AppTheme.lavender,
          ),
          onPressed: onToggleFavorite,
        ),
      ],
    ),
  );
}
