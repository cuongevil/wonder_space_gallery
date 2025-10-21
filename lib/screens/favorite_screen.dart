// 💖 FavoriteScreen — TPBank Mobile 2025 (Glass + Gradient + Drag to Close + Glow Buttons + BannerAd)
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ad_helper.dart';
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

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

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
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: AdHelper.bannerAdUnitId,
      size: AdSize.mediumRectangle,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isBannerLoaded = true),
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          _isBannerLoaded = false;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _animCtrl.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  void _onScroll() {
    final dir = _scrollCtrl.position.userScrollDirection;
    widget.onScrollDirectionChanged?.call(dir);
  }

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
                _buildSearchBar(),
                const SizedBox(height: 16),
                _buildGrid(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.4), width: 0.8),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => _applyFilter(),
                style: const TextStyle(fontSize: 15, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Tìm trong ảnh yêu thích...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.85)),
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
  );

  Widget _buildGrid() => Expanded(
    child: RefreshIndicator(
      onRefresh: _loadFavorites,
      color: Colors.deepPurpleAccent,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: _filtered.isEmpty
              ? const EmptyState(
                  message: 'Chưa có ảnh nào trong mục yêu thích 💫',
                )
              : ListView(
                  controller: _scrollCtrl,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
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
                    if (_isBannerLoaded)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Center(child: AdWidget(ad: _bannerAd!)),
                      ),
                  ],
                ),
        ),
      ),
    ),
  );
}

class _FavoriteCard extends StatefulWidget {
  final PromptItem item;
  final VoidCallback onRemove;

  const _FavoriteCard({required this.item, required this.onRemove});

  @override
  State<_FavoriteCard> createState() => _FavoriteCardState();
}

class _FavoriteCardState extends State<_FavoriteCard> {
  bool _openingDetail = false; // ✅ Chặn click đúp

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            FutureBuilder<String>(
              future: resolveImage(widget.item.image),
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
                    colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
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
                child: Text(
                  widget.item.title,
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
                onTap: widget.onRemove,
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
    );
  }

  Future<void> _showDetail(BuildContext context) async {
    if (_openingDetail) return; // ✅ chặn click đúp
    setState(() => _openingDetail = true);

    // 🌀 Loading nhỏ trong lúc load ảnh
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.2),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );

    double dragOffset = 0.0;
    String? resolvedUrl;

    try {
      resolvedUrl = await resolveImage(widget.item.image);
    } catch (e) {
      debugPrint('⚠️ Lỗi khi load ảnh chi tiết: $e');
    }

    // Đóng loading
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

    if (!mounted) {
      _openingDetail = false;
      return;
    }

    // 💫 Hiển thị dialog chi tiết
    await showGeneralDialog(
      context: context,
      barrierLabel: "detail",
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, __, ___) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        return StatefulBuilder(
          builder: (context, setState) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (details) =>
                  setState(() => dragOffset += details.primaryDelta ?? 0),
              onVerticalDragEnd: (_) {
                if (dragOffset > 100) {
                  Navigator.of(context).pop();
                } else {
                  setState(() => dragOffset = 0);
                }
              },
              child: Transform.translate(
                offset: Offset(0, dragOffset * 0.4),
                child: Opacity(
                  opacity: (1 - (dragOffset / 200)).clamp(0.0, 1.0),
                  child: FadeTransition(
                    opacity: curved,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.96, end: 1.0).animate(curved),
                      child: _FavoriteDetailDialog(item: widget.item),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    // ✅ Cho phép click lại sau khi dialog đóng
    if (mounted) setState(() => _openingDetail = false);
  }
}

class _FavoriteDetailDialog extends StatelessWidget {
  final PromptItem item;

  const _FavoriteDetailDialog({required this.item});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomInset = media.viewPadding.bottom;

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.25),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        top: true, // ✅ tránh đè status bar
        bottom: true, // ✅ tránh đè thanh điều hướng
        child: Align(
          alignment: Alignment.center,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              bottomInset + 16, // ✅ chừa khoảng cách dưới
            ),
            child: Material(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(28),
              clipBehavior: Clip.antiAlias,
              elevation: 0,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: media.size.height * 0.88, // tránh tràn toàn màn hình
                  maxWidth: 600,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🌈 Header Gradient
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF5E2CED), Color(0xFFFF8B00)],
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
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),

                    // 🖼️ Ảnh preview
                    FutureBuilder<String>(
                      future: resolveImage(item.image),
                      builder: (_, snap) {
                        if (!snap.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(48),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: CachedNetworkImage(
                              imageUrl: snap.data!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),

                    // 🧾 Nội dung
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Scrollbar(
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
                    ),

                    // 💎 Buttons (bottom safe)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: _GlassButton(
                              icon: Icons.copy_rounded,
                              label: 'Sao chép',
                              onTap: () {
                                Clipboard.setData(
                                    ClipboardData(text: item.prompt));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✨ Đã sao chép prompt!'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _GlassButton(
                              icon: Icons.share_rounded,
                              label: 'Chia sẻ',
                              onTap: () => Share.share(
                                  '${item.title}\n\n${item.prompt}'),
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
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _GlassButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5E2CED), Color(0xFFFF8B00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.35), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    ),
  );
}
