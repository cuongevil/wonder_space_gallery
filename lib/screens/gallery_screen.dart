import 'dart:async';
import 'dart:convert';
import 'dart:ui'; // 👈 Dành cho hiệu ứng mờ nền

import 'package:cached_network_image/cached_network_image.dart';
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
import 'favorite_screen.dart';
import 'widgets/dialog_actions.dart';
import 'widgets/dialog_header.dart';
import 'widgets/empty_state.dart';

/// 🖼️ Màn hình chính Wonder Space Gallery
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

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
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

  /// 🔥 Load dữ liệu trending từ Firebase hoặc cache
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
    _animCtrl.forward();
  }

  /// 🧩 Parse danh sách prompt
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
    await Future.delayed(const Duration(milliseconds: 200));
    final next = _visible.length + _batchSize;
    setState(() {
      _visible = _all.take(next).toList();
      _hasMore = _visible.length < _all.length;
      _loadingMore = false;
    });
  }

  void _applyFilters() {
    final q = _searchCtrl.text.toLowerCase().trim();
    if (q.isEmpty) {
      setState(() => _visible = _all.take(_batchSize).toList());
      return;
    }
    final results = _all
        .where(
          (it) => (it.title + it.prompt + it.tags.join(' '))
              .toLowerCase()
              .contains(q),
        )
        .toList();
    setState(() => _visible = results.take(_batchSize).toList());
  }

  Future<int> _favoriteCount() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList('favorites') ?? []).length;
  }

  @override
  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.cream,
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => _applyFilters(),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Tìm kiếm...',
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(_applyFilters);
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadTrending(forceRefresh: true),
            color: AppTheme.primary,
            child: ListView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
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
      ],
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

/// 🧩 Card ảnh pastel có ❤️
class _GalleryCard extends StatefulWidget {
  final PromptItem item;

  const _GalleryCard({required this.item});

  @override
  State<_GalleryCard> createState() => _GalleryCardState();
}

class _GalleryCardState extends State<_GalleryCard>
    with SingleTickerProviderStateMixin {
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _syncFavorite();
  }

  Future<void> _syncFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    final fav = prefs.getStringList('favorites') ?? [];
    setState(() => _isFavorite = fav.contains(widget.item.id));
  }

  Future<void> _toggleFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    final fav = prefs.getStringList('favorites') ?? [];
    setState(() => _isFavorite = !_isFavorite);
    _isFavorite ? fav.add(widget.item.id) : fav.remove(widget.item.id);
    await prefs.setStringList('favorites', fav);
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
                  size: 28,
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

  /// 💫 Popup chi tiết ảnh — slide + zoom + fade + blur động + vuốt đóng + bounce
  Future<void> _showDetail(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    var fav = prefs.getStringList('favorites') ?? [];
    bool isFav = fav.contains(widget.item.id);

    double dragOffset = 0.0;
    const double dragToCloseThreshold = 140;

    final bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    showGeneralDialog(
      context: context,
      barrierLabel: "Chi tiết ảnh",
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 450),
      transitionBuilder: (context, animation, secondary, child) {
        final slideTween = Tween(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        final fadeTween = Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut));
        final scaleTween = Tween(
          begin: 0.96,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutBack));

        return SlideTransition(
          position: animation.drive(slideTween),
          child: FadeTransition(
            opacity: animation.drive(fadeTween),
            child: ScaleTransition(
              scale: animation.drive(scaleTween),
              child: child,
            ),
          ),
        );
      },
      pageBuilder: (_, __, ___) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Stack(
            children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 100),
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
                      setDialogState(() {
                        dragOffset = bounceAnim.value;
                      });
                    });
                    await bounceCtrl.forward(from: 0);
                  }
                },
                child: Opacity(
                  opacity: (1 - (dragOffset / 300)).clamp(0.6, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, dragOffset > 0 ? dragOffset * 0.5 : 0),
                    child: Center(
                      child: Dialog(
                        insetPadding: const EdgeInsets.all(16),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
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
                                  ClipboardData(text: widget.item.prompt),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✨ Đã sao chép!'),
                                  ),
                                );
                              },
                              onShare: () => Share.share(
                                '${widget.item.title}\n\n${widget.item.prompt}',
                              ),
                              onToggleFavorite: () async {
                                setDialogState(() => isFav = !isFav);
                                setState(() => _isFavorite = isFav);
                                isFav
                                    ? fav.add(widget.item.id)
                                    : fav.remove(widget.item.id);
                                await prefs.setStringList('favorites', fav);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isFav
                                          ? '💖 Đã lưu vào yêu thích!'
                                          : '🗑️ Đã xóa khỏi yêu thích!',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 🎬 Hiệu ứng slide + fade khi mở FavoriteScreen
Route _createFavoriteRoute() {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) =>
        const FavoriteScreen(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.1, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeOutCubic;

      final slide = Tween(
        begin: begin,
        end: end,
      ).chain(CurveTween(curve: curve));
      final fade = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).chain(CurveTween(curve: curve));

      return SlideTransition(
        position: animation.drive(slide),
        child: FadeTransition(opacity: animation.drive(fade), child: child),
      );
    },
    transitionDuration: const Duration(milliseconds: 400),
    reverseTransitionDuration: const Duration(milliseconds: 250),
  );
}
