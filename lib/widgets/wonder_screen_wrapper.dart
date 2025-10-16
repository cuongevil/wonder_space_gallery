import 'package:flutter/material.dart';

/// 🪄 WonderScreenWrapper
/// Tự động chừa khoảng trống vừa đủ để nội dung không bị AppBar mờ đè.
/// Dùng chung cho tất cả màn hình con trong MainScreen.
class WonderScreenWrapper extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final bool scrollable;

  const WonderScreenWrapper({
    super.key,
    required this.child,
    this.padding,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double topPadding = statusBarHeight + 30;

    final effectivePadding = padding ??
        EdgeInsets.fromLTRB(20, topPadding, 20, 32);

    if (scrollable) {
      return SafeArea(
        top: false, // đã xử lý topPadding riêng
        child: ListView(
          padding: effectivePadding,
          children: [child],
        ),
      );
    } else {
      return SafeArea(
        top: false,
        child: Padding(
          padding: effectivePadding,
          child: child,
        ),
      );
    }
  }
}
