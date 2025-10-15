import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class DialogHeader extends StatelessWidget {
  final String title;
  const DialogHeader({required this.title, super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: const BoxDecoration(
      color: AppTheme.cream,
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style:
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, color: AppTheme.inkSoft),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    ),
  );
}
