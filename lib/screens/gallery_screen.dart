// 💎 GalleryScreen — nền trong suốt, dùng gradient của MainScreen
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/prompt_item.dart';
import '../services/app_open_ad_manager.dart';
import '../services/firebase_image_resolver.dart';
import '../theme/app_theme.dart';
import '../widgets/wonder_screen_wrapper.dart';
import 'widgets/dialog_actions.dart';
import 'widgets/dialog_header.dart';
import 'widgets/empty_state.dart';

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

  final int _batchSize = 30;
  List<PromptItem> _all = [];
  List<PromptItem> _visible = [];
  String? _error;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  final List<String> _searchHints = [
    'Giáng Sinh pastel',
    'Bé gái Việt Nam',
    'Chân dung điện ảnh',
    'Thành phố về đêm',
    'Ảnh vintage',
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
    AppOpenAdManager.showAdIfAllowed();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

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
      final shouldReload = forceRefresh ||
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
    await Future.delayed(const Duration(milliseconds: 250));
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
          // 🪟 Nền trong suốt — lộ gradient của MainScreen
          Positioned.fill(
            child: Container(color: Colors.transparent),
          ),

          // 🌸 Nội dung chính
          SafeArea(
            top: false,
            bottom: true,
            child: Column(
              children: [
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                          const Icon(Icons.search_rounded,
                              color: Colors.white, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (_) => _applyFilters(),
                              style: const TextStyle(
                                  fontSize: 15, color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Tìm kiếm $randomHint...',
                                hintStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.85)),
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
                ),
                const SizedBox(height: 16),

                // Grid hiển thị ảnh
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _loadTrending(forceRefresh: true),
                    color: Colors.deepPurpleAccent,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: ScaleTransition(
                        scale: _scaleAnim,
                        child: ListView(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          children: [
                            _visible.isEmpty
                                ? const EmptyState()
                                : _GalleryGrid(items: _visible),
                            if (_loadingMore)
                              const Padding(
                                padding: EdgeInsets.all(20),
                                child: Center(
                                    child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                              ),
                          ],
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

/// 🧩 Grid ảnh
class _GalleryGrid extends StatelessWidget {
  final List<PromptItem> items;
  const _GalleryGrid({required this.items});

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: .9,
    ),
    itemCount: items.length,
    itemBuilder: (_, i) => _GalleryCard(item: items[i]),
  );
}

/// ❤️ Card ảnh
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

  @override
  void initState() {
    super.initState();
    _syncFavorite();
    _heartCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  Future<void> _syncFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    final favLocal = prefs.getStringList('favorites_local') ?? [];
    final user = _auth.currentUser;
    if (user != null) {
      final snapshot = await _firestore
          .collection('favorites')
          .doc(user.uid)
          .collection('items')
          .get();
      final favOnline = snapshot.docs.map((d) => d.id).toList();
      final merged = {...favLocal, ...favOnline}.toList();
      await prefs.setStringList('favorites_local', merged);
      _isFavorite = merged.contains(widget.item.id);
    } else {
      _isFavorite = favLocal.contains(widget.item.id);
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favs = prefs.getStringList('favorites_local') ?? [];
    final user = _auth.currentUser;

    setState(() => _isFavorite = !_isFavorite);
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: Colors.deepPurpleAccent.withOpacity(0.85),
      content: Text(
        _isFavorite ? '💖 Đã lưu vào yêu thích!' : '🗑️ Đã xóa khỏi yêu thích!',
        style: const TextStyle(color: Colors.white),
      ),
    ));
  }

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
                      width: double.infinity,
                    ),
                  );
                },
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.35)
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: ScaleTransition(
                  scale: Tween(begin: 1.0, end: 1.3)
                      .animate(CurvedAnimation(
                      parent: _heartCtrl, curve: Curves.elasticOut)),
                  child: GestureDetector(
                    onTap: _toggleFavorite,
                    child: Icon(
                      _isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color:
                      _isFavorite ? Colors.pinkAccent : Colors.white70,
                      size: 26,
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
                    widget.item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDetail(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList('favorites_local') ?? [];
    bool isFav = favs.contains(widget.item.id);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.3),
      pageBuilder: (_, __, ___) => Center(
        child: Hero(
          tag: widget.item.id,
          child: Dialog(
            backgroundColor: Colors.white.withOpacity(0.9),
            insetPadding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DialogHeader(title: widget.item.title),
                FutureBuilder<String>(
                  future: resolveImage(widget.item.image),
                  builder: (_, snap) => snap.hasData
                      ? CachedNetworkImage(imageUrl: snap.data!)
                      : const Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      widget.item.prompt,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.inkSoft,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1, color: AppTheme.line),
                DialogActions(
                  isFavorite: isFav,
                  onCopy: () {
                    Clipboard.setData(
                        ClipboardData(text: widget.item.prompt));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✨ Đã sao chép!')),
                    );
                  },
                  onShare: () => Share.share(
                      '${widget.item.title}\n\n${widget.item.prompt}'),
                  onToggleFavorite: _toggleFavorite,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
