// 💖 FavoriteScreen — TPBank Mobile 2025 (Glass + Gradient + Hide BottomBar + Glow Buttons)
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/prompt_item.dart';
import '../services/firebase_image_resolver.dart';
import '../widgets/empty_state.dart';
import '../widgets/wonder_screen_wrapper.dart';

class FavoriteScreen extends StatefulWidget {
  final ValueChanged<ScrollDirection>? onScrollDirectionChanged;

  const FavoriteScreen({super.key, this.onScrollDirectionChanged});

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  List<PromptItem> _all = [];
  List<PromptItem> _filtered = [];

  bool _loading = true;
  bool _refreshing = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _scaleAnim = Tween<double>(
      begin: 0.97,
      end: 1,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    _scrollCtrl.addListener(_onScroll);
    _loadFavorites();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final dir = _scrollCtrl.position.userScrollDirection;
    widget.onScrollDirectionChanged?.call(dir);
  }

  /// 🔹 Load danh sách yêu thích từ cache
  Future<void> _loadFavorites() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final favIds = prefs.getStringList('favorites_local') ?? [];
    final cachedJson = prefs.getString('prompts_cache');

    if (cachedJson != null) {
      final items = PromptItem.parseListFromCache(
        cachedJson,
      ).where((p) => favIds.contains(p.id)).toList();
      setState(() {
        _all = items;
        _filtered = items;
        _loading = false;
      });
      _animCtrl.forward(from: 0);
    } else {
      setState(() => _loading = false);
    }
  }

  /// 🔹 Lọc ảnh theo từ khóa
  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    _animCtrl.forward(from: 0);
    if (q.isEmpty) {
      setState(() => _filtered = _all);
    } else {
      setState(() {
        _filtered = _all
            .where(
              (it) => (it.title + it.prompt + it.tags.join(' '))
                  .toLowerCase()
                  .contains(q),
            )
            .toList();
      });
    }
  }

  /// 🔹 Xoá ảnh khỏi yêu thích
  Future<void> _removeFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList('favorites_local') ?? [];
    favs.remove(id);
    await prefs.setStringList('favorites_local', favs);
    setState(() {
      _all.removeWhere((p) => p.id == id);
      _filtered.removeWhere((p) => p.id == id);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('🗑️ Đã xoá khỏi yêu thích')));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return WonderScreenWrapper(
      scrollable: false,
      child: Stack(
        children: [
          Positioned.fill(child: Container(color: Colors.transparent)),
          SafeArea(
            top: false,
            bottom: true,
            child: Column(
              children: [
                const SizedBox(height: 8),

                // 🌈 Search bar mờ kiểu TPBank
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (_) => _applyFilter(),
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Tìm trong ảnh yêu thích...',
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          if (_searchCtrl.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                _applyFilter();
                              },
                              child: const Icon(
                                Icons.clear_rounded,
                                color: Colors.white70,
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 💫 Lưới ảnh có hiệu ứng
                Expanded(
                  child: RefreshIndicator(
                    color: Colors.deepPurpleAccent,
                    onRefresh: () async {
                      setState(() => _refreshing = true);
                      await _loadFavorites();
                      await Future.delayed(const Duration(milliseconds: 500));
                      setState(() => _refreshing = false);
                    },
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: ScaleTransition(
                        scale: _scaleAnim,
                        child: _filtered.isEmpty
                            ? const EmptyState(
                                message:
                                    'Chưa có ảnh nào trong mục yêu thích 💫',
                              )
                            : GridView.builder(
                                controller: _scrollCtrl,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                      childAspectRatio: 0.9,
                                    ),
                                itemCount: _filtered.length,
                                itemBuilder: (_, i) {
                                  final item = _filtered[i];
                                  return _FavoriteCard(
                                    item: item,
                                    onRemove: () => _removeFavorite(item.id),
                                  );
                                },
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 🧩 Card ảnh yêu thích
class _FavoriteCard extends StatelessWidget {
  final PromptItem item;
  final VoidCallback onRemove;

  const _FavoriteCard({required this.item, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              FutureBuilder<String>(
                future: resolveImage(item.image),
                builder: (_, snap) {
                  if (!snap.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  return CachedNetworkImage(
                    imageUrl: snap.data!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  );
                },
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.4),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black87, Colors.transparent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(
                      Icons.delete_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierLabel: "detail",
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.2),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (dialogCtx, anim, _, __) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        double dragOffset = 0.0;

        return StatefulBuilder(
          builder: (ctx, setState) {
            return GestureDetector(
              onVerticalDragUpdate: (details) {
                setState(() => dragOffset += details.primaryDelta ?? 0);
              },
              onVerticalDragEnd: (details) {
                if (dragOffset > 100) {
                  Navigator.of(ctx).pop(); // 👈 Vuốt đủ xa => đóng popup
                } else {
                  setState(() => dragOffset = 0); // Reset vị trí
                }
              },
              child: Transform.translate(
                offset: Offset(0, dragOffset * 0.4),
                child: Opacity(
                  opacity: (1 - (dragOffset / 200)).clamp(0.0, 1.0),
                  child: ScaleTransition(
                    scale: Tween(begin: 0.96, end: 1.0).animate(curved),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 40 - dragOffset * 0.05,
                        sigmaY: 40 - dragOffset * 0.05,
                      ),
                      child: Dialog(
                        insetPadding: const EdgeInsets.all(16),
                        backgroundColor: Colors.white.withOpacity(
                          0.85 - dragOffset * 0.001,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.5),
                            width: 1.2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 🌈 Header
                              Container(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  12,
                                  14,
                                ),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFF5E2CED),
                                      Color(0xFFFF8B00),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                      onPressed: () =>
                                          Navigator.of(dialogCtx).pop(),
                                    ),
                                  ],
                                ),
                              ),

                              // 🖼️ Ảnh hiển thị
                              FutureBuilder<String>(
                                future: resolveImage(item.image),
                                builder: (_, snap) => snap.hasData
                                    ? Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          child: CachedNetworkImage(
                                            imageUrl: snap.data!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                          ),
                                        ),
                                      )
                                    : const Padding(
                                        padding: EdgeInsets.all(48),
                                        child: CircularProgressIndicator(),
                                      ),
                              ),

                              // ✨ Nội dung prompt
                              Flexible(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 8,
                                  ),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    child: Text(
                                      item.prompt,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: Color(0xFF3B2667),
                                        height: 1.8,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // 🪄 Nút hành động
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  4,
                                  16,
                                  18,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _GlassButton(
                                      icon: Icons.copy_rounded,
                                      label: 'Sao chép',
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF5E2CED),
                                          Color(0xFFFF8B00),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      onTap: () {
                                        Clipboard.setData(
                                          ClipboardData(text: item.prompt),
                                        );
                                        ScaffoldMessenger.of(
                                          dialogCtx,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              '✨ Đã sao chép prompt!',
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    _GlassButton(
                                      icon: Icons.share_rounded,
                                      label: 'Chia sẻ',
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF5E2CED),
                                          Color(0xFFFF8B00),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      onTap: () => Share.share(
                                        '${item.title}\n\n${item.prompt}',
                                      ),
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
            );
          },
        );
      },
    );
  }
}

// ✨ Glass Button Gradient + Press Effect
class _GlassButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final LinearGradient? gradient;

  const _GlassButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.gradient,
  });

  @override
  State<_GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<_GlassButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 150),
        scale: _pressed ? 0.95 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            gradient:
                widget.gradient ??
                LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.25),
                    Colors.white.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.35), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.deepPurple.withOpacity(_pressed ? 0.25 : 0.15),
                blurRadius: _pressed ? 25 : 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (Rect bounds) {
                  return const LinearGradient(
                    colors: [Colors.white, Color(0xFFFFE1A0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds);
                },
                child: Icon(widget.icon, size: 18),
              ),
              const SizedBox(width: 6),
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (Rect bounds) {
                  return const LinearGradient(
                    colors: [Colors.white, Color(0xFFFFE1A0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds);
                },
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
