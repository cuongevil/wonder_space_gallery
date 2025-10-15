import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/prompt_item.dart';
import '../theme/app_theme.dart';
import '../services/firebase_image_resolver.dart';

/// 💖 Màn hình ảnh yêu thích
class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({super.key});

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  List<PromptItem> favorites = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  /// 🔹 Load danh sách yêu thích từ cache
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

  /// 🔹 Xóa ảnh khỏi danh sách yêu thích
  Future<void> _removeFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favList = prefs.getStringList('favorites') ?? [];
    favList.remove(id);
    await prefs.setStringList('favorites', favList);
    setState(() => favorites.removeWhere((e) => e.id == id));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('💔 Đã xóa khỏi yêu thích')),
    );
  }

  /// 🔹 Đếm tổng số yêu thích
  Future<int> _countFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList('favorites') ?? []).length;
  }

  /// 🔹 Hiển thị chi tiết popup
  void _showFavoriteDetail(BuildContext context, PromptItem item) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favList = prefs.getStringList('favorites') ?? [];
    bool isFavorite = favList.contains(item.id);

    showGeneralDialog(
      context: context,
      barrierLabel: "Chi tiết ảnh yêu thích",
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => Center(
        child: Dialog(
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: Colors.white,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: StatefulBuilder(
            builder: (context, setDialogState) => ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
                maxWidth: 500,
              ),
              child: FutureBuilder<String>(
                future: resolveImage(item.image),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 🔹 Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: const BoxDecoration(
                          color: AppTheme.cream,
                          borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

                      // 🔹 Ảnh chính
                      CachedNetworkImage(
                        imageUrl: snap.data!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),

                      // 🔹 Prompt mô tả
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

                      // 🔹 Các nút hành động
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
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✨ Đã sao chép prompt!'),
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
                              onPressed: () =>
                                  Share.share('${item.title}\n\n${item.prompt}'),
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
                                        () => isFavorite = !isFavorite);
                                if (!isFavorite) {
                                  await _removeFavorite(item.id);
                                  Navigator.pop(context);
                                } else {
                                  favList.add(item.id);
                                  await prefs.setStringList(
                                      'favorites', favList);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 🧩 UI chính
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('💖 Ảnh yêu thích'),
          actions: [
            FutureBuilder<int>(
              future: _countFavorites(),
              builder: (context, snap) {
                final count = snap.data ?? 0;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      onPressed: _loadFavorites,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: AppTheme.inkSoft,
                      ),
                      tooltip: 'Tải lại danh sách',
                    ),
                    if (count > 0)
                      Positioned(
                        right: 6,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
        body: favorites.isEmpty
            ? const Center(
          child: Text(
            'Chưa có ảnh nào được lưu 💕',
            style: TextStyle(color: AppTheme.inkSoft),
          ),
        )
            : GridView.builder(
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
                            child:
                            CircularProgressIndicator(strokeWidth: 2),
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
      ),
    );
  }
}
