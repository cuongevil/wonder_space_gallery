import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ad_helper.dart';
import '../models/prompt_item.dart';
import '../services/firebase_image_resolver.dart';
import '../widgets/empty_state.dart';
import '../widgets/wonder_screen_wrapper.dart';

/// 💎 GalleryScreen — Glass Blur, Gradient, Hero Detail, Realtime Favorite Sync + Banner Ads + SafeArea Fix
class GalleryScreen extends StatefulWidget {
  final ValueChanged<ScrollDirection>? onScrollDirectionChanged;

  const GalleryScreen({super.key, this.onScrollDirectionChanged});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final int _batchSize = 20;

  List<PromptItem> _all = [];
  List<PromptItem> _visible = [];
  String? _error;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  // 🪄 BannerAd
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  final List<String> _searchHints = const [
    'Cảm hứng mới mỗi ngày ✨',
    'Không gian nghệ thuật 💜',
    'Sắc thái cuộc sống 🌈',
    'Góc nhìn sáng tạo 🌌',
    'Vẻ đẹp tinh tế 💫',
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _scaleAnim = Tween<double>(begin: 0.97, end: 1)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    _loadTrending();
    _scrollCtrl.addListener(_onScroll);
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: AdHelper.bannerAdUnitId,
      size: AdSize.mediumRectangle,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isBannerLoaded = true),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _isBannerLoaded = false;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  /// 📦 Load JSON trending từ Firebase Storage
  Future<void> _loadTrending({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      _all.clear();
      _visible.clear();
      _hasMore = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString('prompts_cache');

    try {
      final ref = FirebaseStorage.instance.ref('prompts/prompts_trending.json');
      final meta = await ref.getMetadata();
      final remoteUpdated = meta.updated?.toIso8601String() ?? '';
      final shouldReload =
          forceRefresh ||
              cachedJson == null ||
              prefs.getString('prompts_meta') != remoteUpdated;

      if (shouldReload) {
        final url = await ref.getDownloadURL();
        final res = await http.get(Uri.parse(url));
        _parseData(jsonDecode(res.body));
        prefs
          ..setString('prompts_cache', res.body)
          ..setString('prompts_meta', remoteUpdated);
      } else {
        _parseData(jsonDecode(cachedJson!));
      }
    } catch (e) {
      if (cachedJson != null) {
        _parseData(jsonDecode(cachedJson));
      } else {
        _error = 'Không thể tải dữ liệu: $e';
      }
    }

    setState(() => _loading = false);
    _animCtrl.forward(from: 0);
  }

  void _parseData(Map<String, dynamic> data) {
    final items =
        (data['items'] as List?)?.map((e) => PromptItem.fromJson(e)).toList() ??
            [];
    items.sort((a, b) => b.id.compareTo(a.id));
    _all = items;
    _visible = _all.take(_batchSize).toList();
    _hasMore = _all.length > _batchSize;
  }

  void _onScroll() {
    final direction = _scrollCtrl.position.userScrollDirection;
    widget.onScrollDirectionChanged?.call(direction);
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    await Future.delayed(const Duration(milliseconds: 300));
    final next = _visible.length + _batchSize;
    setState(() {
      _visible = _all.take(next).toList();
      _hasMore = _visible.length < _all.length;
      _loadingMore = false;
    });
  }

  void _applyFilters() {
    final q = _searchCtrl.text.toLowerCase().trim();
    _animCtrl.forward(from: 0);
    if (q.isEmpty) {
      setState(() => _visible = _all.take(_batchSize).toList());
      return;
    }
    final results = _all
        .where((it) =>
        (it.title + it.prompt + it.tags.join(' ')).toLowerCase().contains(q))
        .toList();
    setState(() => _visible = results.take(_batchSize).toList());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));

    final randomHint = _searchHints[Random().nextInt(_searchHints.length)];

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
                _buildSearchBar(randomHint),
                const SizedBox(height: 16),
                _buildGallery(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(String hint) => ClipRRect(
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
                onChanged: (_) => _applyFilters(),
                style: const TextStyle(fontSize: 15, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm $hint...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.85)),
                  border: InputBorder.none,
                ),
              ),
            ),
            if (_searchCtrl.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  _applyFilters();
                },
                child: const Icon(Icons.clear_rounded,
                    color: Colors.white70, size: 20),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _buildGallery() => Expanded(
    child: RefreshIndicator(
      onRefresh: () => _loadTrending(forceRefresh: true),
      color: Colors.deepPurpleAccent,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: ListView(
            controller: _scrollCtrl,
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            physics: const BouncingScrollPhysics(),
            children: [
              _visible.isEmpty
                  ? const EmptyState()
                  : _GalleryGrid(
                items: _visible,
                bannerAd: _isBannerLoaded ? _bannerAd : null,
              ),
              if (_loadingMore)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 🖼️ Grid + Banner
class _GalleryGrid extends StatelessWidget {
  final List<PromptItem> items;
  final BannerAd? bannerAd;

  const _GalleryGrid({required this.items, this.bannerAd});

  @override
  Widget build(BuildContext context) {
    final totalCount =
    bannerAd == null ? items.length : items.length + items.length ~/ 10;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: .9,
      ),
      itemCount: totalCount,
      itemBuilder: (_, index) {
        if (bannerAd != null && index != 0 && index % 10 == 0) {
          return Container(
            alignment: Alignment.center,
            margin: const EdgeInsets.all(4),
            child: AdWidget(ad: bannerAd!),
          );
        }
        final realIndex = bannerAd == null ? index : index - (index ~/ 10);
        return _GalleryCard(item: items[realIndex]);
      },
    );
  }
}

/// 📸 Thẻ ảnh + popup chi tiết
class _GalleryCard extends StatefulWidget {
  final PromptItem item;
  const _GalleryCard({required this.item});

  @override
  State<_GalleryCard> createState() => _GalleryCardState();
}

class _GalleryCardState extends State<_GalleryCard>
    with SingleTickerProviderStateMixin {
  bool _isFavorite = false;
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  late AnimationController _heartCtrl;
  StreamSubscription? _favSubscription;
  final ValueNotifier<bool> _favVN = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _initFavoriteListener();
  }

  @override
  void dispose() {
    _favSubscription?.cancel();
    _heartCtrl.dispose();
    _favVN.dispose();
    super.dispose();
  }

  Future<void> _initFavoriteListener() async {
    final prefs = await SharedPreferences.getInstance();
    final user = _auth.currentUser;
    if (user == null) {
      final favLocal = prefs.getStringList('favorites_local') ?? [];
      final v = favLocal.contains(widget.item.id);
      setState(() => _isFavorite = v);
      _favVN.value = v;
      return;
    }

    final userRef =
    _firestore.collection('favorites').doc(user.uid).collection('items');
    _favSubscription = userRef.snapshots().listen((snapshot) async {
      final favOnline = snapshot.docs.map((d) => d.id).toList();
      final favLocal = prefs.getStringList('favorites_local') ?? [];
      final merged = {...favLocal, ...favOnline}.toList();
      await prefs.setStringList('favorites_local', merged);
      final newFav = merged.contains(widget.item.id);
      if (mounted) {
        if (newFav != _isFavorite) setState(() => _isFavorite = newFav);
        _favVN.value = newFav;
      }
    });
  }

  Future<void> _toggleFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favs = prefs.getStringList('favorites_local') ?? [];
    final user = _auth.currentUser;

    setState(() => _isFavorite = !_isFavorite);
    _favVN.value = _isFavorite;
    _heartCtrl.forward(from: 0);

    if (_isFavorite) {
      favs.add(widget.item.id);
      if (user != null) {
        await _firestore
            .collection('favorites')
            .doc(user.uid)
            .collection('items')
            .doc(widget.item.id)
            .set({'createdAt': FieldValue.serverTimestamp()});
      }
    } else {
      favs.remove(widget.item.id);
      if (user != null) {
        await _firestore
            .collection('favorites')
            .doc(user.uid)
            .collection('items')
            .doc(widget.item.id)
            .delete();
      }
    }
    await prefs.setStringList('favorites_local', favs);
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(20),
    child: Stack(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showDetail(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: FutureBuilder<String>(
              future: resolveImage(widget.item.image),
              builder: (_, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2));
                }
                return Hero(
                  tag: widget.item.id,
                  child: CachedNetworkImage(
                    imageUrl: snap.data!,
                    fit: BoxFit.cover,
                  ),
                );
              },
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: _toggleFavorite,
            behavior: HitTestBehavior.opaque,
            child: ScaleTransition(
              scale: Tween(begin: 1.0, end: 1.3).animate(
                CurvedAnimation(
                    parent: _heartCtrl, curve: Curves.elasticOut),
              ),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: _isFavorite
                      ? Colors.pinkAccent
                      : Colors.white.withOpacity(0.9),
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  bool _openingDetail = false; // ✅ Flag chặn click đúp

  Future<void> _showDetail(BuildContext context) async {
    // ✅ Ngăn click đúp khi dialog đang mở
    if (_openingDetail) return;
    setState(() => _openingDetail = true);

    // 🌀 Hiển thị loading nhẹ trong lúc load ảnh
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.2),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );

    double dragOffset = 0.0;
    String? resolvedUrl;

    try {
      resolvedUrl = await resolveImage(widget.item.image);
    } catch (e) {
      debugPrint('⚠️ Lỗi khi load ảnh chi tiết: $e');
    }

    // Đóng dialog loading
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

    if (!mounted) {
      _openingDetail = false;
      return;
    }

    // 💫 Hiển thị dialog chi tiết
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Ảnh chi tiết',
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, __, ___) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (details) =>
                  setDialogState(() => dragOffset += details.primaryDelta ?? 0),
              onVerticalDragEnd: (_) {
                if (dragOffset > 100) {
                  Navigator.of(context).pop();
                } else {
                  setDialogState(() => dragOffset = 0);
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
                      child: _DetailDialog(
                        item: widget.item,
                        favNotifier: _favVN,
                        toggleFavorite: _toggleFavorite,
                        resolvedUrl: resolvedUrl,
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

    // ✅ Cho phép click lại sau khi dialog đóng
    if (mounted) setState(() => _openingDetail = false);
  }
}

class _DetailDialog extends StatelessWidget {
  final PromptItem item;
  final ValueNotifier<bool> favNotifier;
  final Future<void> Function() toggleFavorite;
  final String? resolvedUrl;

  const _DetailDialog({
    required this.item,
    required this.favNotifier,
    required this.toggleFavorite,
    this.resolvedUrl,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomInset = media.viewPadding.bottom; // 🔹 dùng viewPadding thay vì padding

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.25),
      resizeToAvoidBottomInset: false, // ✅ tránh layout tự co giãn khi bàn phím bật
      body: SafeArea(
        top: true, // ✅ bật lại SafeArea phía trên
        bottom: true,
        child: Align(
          alignment: Alignment.center, // ✅ căn giữa dialog trong vùng an toàn
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              bottomInset + 16, // ✅ luôn cách thanh điều hướng 16px
            ),
            child: Material(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(28),
              clipBehavior: Clip.antiAlias,
              elevation: 0,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: media.size.height * 0.88,
                  maxWidth: 600,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🌈 Header gradient
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
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 22),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),

                    // 🖼️ Ảnh preview
                    if (resolvedUrl != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Hero(
                          tag: item.id,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: CachedNetworkImage(
                              imageUrl: resolvedUrl!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),

                    // 🧾 Prompt nội dung
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

                    // 💎 Buttons
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ValueListenableBuilder<bool>(
                            valueListenable: favNotifier,
                            builder: (_, isFavorite, __) {
                              return _GlassButton(
                                icon: isFavorite
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                label:
                                isFavorite ? 'Đã thích' : 'Yêu thích',
                                onTap: () async {
                                  await toggleFavorite();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isFavorite
                                            ? '❌ Đã xóa khỏi yêu thích'
                                            : '💖 Đã thêm vào yêu thích',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          _GlassButton(
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
                          _GlassButton(
                            icon: Icons.share_rounded,
                            label: 'Chia sẻ',
                            onTap: () => Share.share(
                                '${item.title}\n\n${item.prompt}'),
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

/// ✨ Nút kính mờ gradient (GlassButton)
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
        border:
        Border.all(color: Colors.white.withOpacity(0.35), width: 0.8),
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
