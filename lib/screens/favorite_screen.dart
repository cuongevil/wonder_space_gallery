import 'dart:convert';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/prompt_item.dart';
import '../services/firebase_image_resolver.dart';
import '../theme/app_theme.dart';

/// 💖 Màn hình ảnh yêu thích (phiên bản content-only)
class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({super.key});

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen>
    with TickerProviderStateMixin {
  List<PromptItem> favorites = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favIds = prefs.getStringList('favorites') ?? [];
    final cachedJson = prefs.getString('prompts_cache');
    if (cachedJson == null) return;
    final data = jsonDecode(cachedJson) as Map<String, dynamic>;
    final allItems = ((data['items'] ?? []) as List)
        .map((e) => PromptItem.fromJson(e))
        .toList();
    setState(() {
      favorites = allItems.where((e) => favIds.contains(e.id)).toList();
    });
  }

  Future<void> _removeFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favList = prefs.getStringList('favorites') ?? [];
    favList.remove(id);
    await prefs.setStringList('favorites', favList);
    setState(() => favorites.removeWhere((e) => e.id == id));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('💔 Đã xóa khỏi yêu thích')));
  }

  /// 💫 Popup chi tiết ảnh có drag-to-close + hiệu ứng blur
  void _showFavoriteDetail(BuildContext context, PromptItem item) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favList = prefs.getStringList('favorites') ?? [];
    bool isFavorite = favList.contains(item.id);
    double dragOffset = 0.0;
    const double dragToCloseThreshold = 140;
    final bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    showGeneralDialog(
      context: context,
      barrierLabel: "Chi tiết ảnh yêu thích",
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 450),
      transitionBuilder: (context, animation, _, child) {
        final fade = Tween(begin: 0.0, end: 1.0).animate(animation);
        final slide = Tween(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOut));
        final scale = Tween(
          begin: 0.97,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutBack));

        return FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: animation.drive(slide),
            child: ScaleTransition(scale: animation.drive(scale), child: child),
          ),
        );
      },
      pageBuilder: (_, __, ___) => StatefulBuilder(
        builder: (context, setDialogState) => Stack(
          children: [
            // 🌫️ Nền blur động
            AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: (1 - (dragOffset / 250)).clamp(0.2, 0.8),
              child: Container(
                color: Colors.black.withOpacity(0.4),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: (8 - dragOffset / 30).clamp(0.0, 8.0),
                    sigmaY: (8 - dragOffset / 30).clamp(0.0, 8.0),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),

            // 🖼️ Dialog ảnh chi tiết
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (details) {
                dragOffset += details.delta.dy;
                if (dragOffset > 0) setDialogState(() {});
              },
              onVerticalDragEnd: (_) async {
                if (dragOffset > dragToCloseThreshold) {
                  Navigator.of(context).pop();
                } else if (dragOffset > 0) {
                  final bounceAnim = Tween<double>(begin: dragOffset, end: 0)
                      .animate(
                        CurvedAnimation(
                          parent: bounceCtrl,
                          curve: Curves.elasticOut,
                        ),
                      );
                  bounceCtrl.addListener(() {
                    setDialogState(() => dragOffset = bounceAnim.value);
                  });
                  await bounceCtrl.forward(from: 0);
                }
              },
              child: Opacity(
                opacity: (1 - (dragOffset / 300)).clamp(0.6, 1.0),
                child: Transform.translate(
                  offset: Offset(0, dragOffset * 0.5),
                  child: Center(
                    child: Dialog(
                      insetPadding: const EdgeInsets.all(16),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.9,
                          maxWidth: 500,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: const BoxDecoration(
                                color: AppTheme.cream,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: AppTheme.inkSoft,
                                    ),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ],
                              ),
                            ),
                            // Ảnh
                            FutureBuilder<String>(
                              future: resolveImage(item.image),
                              builder: (context, snap) => snap.hasData
                                  ? CachedNetworkImage(
                                      imageUrl: snap.data!,
                                      fit: BoxFit.cover,
                                    )
                                  : const Padding(
                                      padding: EdgeInsets.all(32),
                                      child: CircularProgressIndicator(),
                                    ),
                            ),
                            // Prompt mô tả
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  item.prompt,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: AppTheme.inkSoft,
                                    height: 1.6,
                                  ),
                                ),
                              ),
                            ),
                            const Divider(height: 1, color: AppTheme.line),
                            // Nút hành động
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 10,
                                runSpacing: 8,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(text: item.prompt),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            '✨ Đã sao chép prompt!',
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.copy_rounded),
                                    label: const Text('Sao chép'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primarySoft,
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () => Share.share(
                                      '${item.title}\n\n${item.prompt}',
                                    ),
                                    icon: const Icon(Icons.share_rounded),
                                    label: const Text('Chia sẻ'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    icon: const Icon(
                                      Icons.favorite_rounded,
                                      color: Colors.white,
                                    ),
                                    label: Text(
                                      isFavorite ? 'Bỏ yêu thích' : 'Yêu thích',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isFavorite
                                          ? Colors.pinkAccent
                                          : AppTheme.lavender,
                                    ),
                                    onPressed: () async {
                                      setDialogState(
                                        () => isFavorite = !isFavorite,
                                      );
                                      if (!isFavorite) {
                                        await _removeFavorite(item.id);
                                        Navigator.pop(context);
                                      } else {
                                        favList.add(item.id);
                                        await prefs.setStringList(
                                          'favorites',
                                          favList,
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🧩 Nội dung chính (content-only, không Scaffold)
  @override
  Widget build(BuildContext context) {
    if (favorites.isEmpty) {
      return const Center(
        child: Text(
          'Chưa có ảnh nào được lưu 💕',
          style: TextStyle(color: AppTheme.inkSoft),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFavorites,
      color: AppTheme.primary,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: .9,
        ),
        itemCount: favorites.length,
        itemBuilder: (_, i) {
          final item = favorites[i];
          return GestureDetector(
            onTap: () => _showFavoriteDetail(context, item),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  FutureBuilder<String>(
                    future: resolveImage(item.image),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }
                      return CachedNetworkImage(
                        imageUrl: snap.data!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      );
                    },
                  ),
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: Icon(
                      Icons.favorite_rounded,
                      color: Colors.pinkAccent,
                      size: 26,
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
