import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

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

/// 🖼️ Màn hình chính Wonder Space Gallery (blur glass style)
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

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

    final randomHint =
    _searchHints[Random().nextInt(_searchHints.length)];

    return WonderScreenWrapper(
      scrollable: false,
      child: Stack(
        children: [
          // 🌈 Nền blur pastel phía sau
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFEDE8FF), Color(0xFFFFF4F2)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          Column(
            children: [
              // 💫 AppBar + Search bar dính liền (blur glass)
              ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    height: 92,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      border: const Border(
                        bottom: BorderSide(
                            color: Color(0xFFE6E0F5), width: 0.8),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 38, 16, 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepPurple.withOpacity(0.08),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (_) => _applyFilters(),
                          style: const TextStyle(fontSize: 15),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search_rounded,
                                color: Colors.deepPurpleAccent),
                            hintText: 'Tìm kiếm $randomHint...',
                            hintStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: Colors.transparent,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            suffixIcon: _searchCtrl.text.isNotEmpty
                                ? IconButton(
                              icon: const Icon(Icons.clear_rounded,
                                  color: Colors.grey, size: 20),
                              onPressed: () {
                                _searchCtrl.clear();
                                _applyFilters();
                              },
                            )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 🖼️ Danh sách ảnh (padding 10px sau search bar)
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _loadTrending(forceRefresh: true),
                  color: AppTheme.primary,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: ScaleTransition(
                      scale: _scaleAnim,
                      child: ListView(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                        children: [
                          _visible.isEmpty
                              ? const EmptyState()
                              : _GalleryGrid(items: _visible),
                          if (_loadingMore)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 🧩 Lưới ảnh
class _GalleryGrid extends StatelessWidget {
  final List<PromptItem> items;
  const _GalleryGrid({required this.items});

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: .9,
    ),
    itemCount: items.length,
    itemBuilder: (_, i) => _GalleryCard(item: items[i]),
  );
}

/// ❤️ Thẻ ảnh có nút yêu thích
class _GalleryCard extends StatefulWidget {
  final PromptItem item;
  const _GalleryCard({required this.item});

  @override
  State<_GalleryCard> createState() => _GalleryCardState();
}

class _GalleryCardState extends State<_GalleryCard> {
  bool _isFavorite = false;
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _syncFavorite();
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
      content: Text(
        _isFavorite ? '💖 Đã lưu vào yêu thích!' : '🗑️ Đã xóa khỏi yêu thích!',
      ),
    ));
  }

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
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: _toggleFavorite,
                child: Icon(
                  _isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: _isFavorite ? Colors.pinkAccent : Colors.white,
                  size: 26,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.all(6),
                child: Text(
                  widget.item.title,
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
  }

  Future<void> _showDetail(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList('favorites_local') ?? [];
    bool isFav = favs.contains(widget.item.id);
    final user = _auth.currentUser;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                Clipboard.setData(ClipboardData(text: widget.item.prompt));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✨ Đã sao chép!')),
                );
              },
              onShare: () =>
                  Share.share('${widget.item.title}\n\n${widget.item.prompt}'),
              onToggleFavorite: _toggleFavorite,
            ),
          ],
        ),
      ),
    );
  }
}
