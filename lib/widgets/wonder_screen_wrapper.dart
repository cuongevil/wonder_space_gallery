import 'package:flutter/material.dart';

/// 🪄 WonderScreenWrapper — giữ bố cục cách AppBar, padding tự động
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
    final effectivePadding = padding ?? EdgeInsets.fromLTRB(20, topPadding, 20, 32);

    if (scrollable) {
      return SafeArea(
        top: false,
        child: ListView(padding: effectivePadding, children: [child]),
      );
    } else {
      return SafeArea(
        top: false,
        child: Padding(padding: effectivePadding, child: child),
      );
    }
  }
}
