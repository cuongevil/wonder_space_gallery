import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_not_supported, size: 48, color: AppTheme.inkSoft),
          SizedBox(height: 8),
          Text(
            'Không tìm thấy ảnh phù hợp',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4),
          Text('Hãy thử từ khóa khác nhé.'),
        ],
      ),
    ),
  );
}
