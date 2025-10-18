import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final String? message;
  const EmptyState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.image_outlined, color: Colors.white70, size: 60),
        const SizedBox(height: 16),
        Text(
          message ?? 'Chưa có nội dung hiển thị 💫',
          style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }
}
