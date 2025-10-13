import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_open_ad_manager.dart';
import 'favorite_screen.dart';

/// 🎨 Chủ đề pastel Wonder Space Gallery
class AppTheme {
  static const Color pink = Color(0xFFF8E8EE);
  static const Color lavender = Color(0xFFE4D4F0);
  static const Color cream = Color(0xFFFFF9F5);
  static const Color ink = Color(0xFF2E2A32);
  static const Color inkSoft = Color(0xFF6B6670);
  static const Color line = Color(0xFFE7E3EA);
  static const Color primary = Color(0xFF7C6DB0);
  static const Color primarySoft = Color(0xFFA596CC);

  static ThemeData light() {
    final base = ThemeData(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        background: cream,
        surface: Colors.white,
        primary: primary,
      ),
      scaffoldBackgroundColor: cream,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontFamily: 'Nunito', fontSize: 15),
      ),
    );
  }
}

/// 🧩 Model dữ liệu prompt
class PromptItem {
  final String id;
  final String title;
  final String image;
  final String prompt;
  final List<String> tags;
  final String? category;

  PromptItem({
    required this.id,
    required this.title,
    required this.image,
    required this.prompt,
    required this.tags,
    this.category,
  });

  factory PromptItem.fromJson(Map<String, dynamic> j) => PromptItem(
    id: (j['id'] ?? '').toString(),
    title: (j['title'] ?? '').toString(),
    image: (j['image'] ?? '').toString(),
    prompt: (j['prompt'] ?? '').toString(),
    tags: ((j['tags'] ?? []) as List).map((e) => e.toString()).toList(),
    category: j['category']?.toString(),
  );
}

/// 🖼️ Màn hình chính Wonder Space Gallery
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _q = TextEditingController();
  final ScrollController _scroll = ScrollController();
  List<PromptItem> all = [];
  List<PromptItem> visible = [];
  String? updatedAt;
  bool loading = true;
  bool isLoadingMore = false;
  bool hasMore = true;
  String? error;
  final int batchSize = 30;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));

    _loadTrending();
    _scroll.addListener(_onScroll);
    AppOpenAdManager.showAdIfAllowed();
  }

  @override
  void dispose() {
    _q.dispose();
    _scroll.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<int> _countFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList('favorites') ?? []).length;
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadTrending({bool bustCache = false}) async {
    setState(() {
      loading = true;
      all.clear();
      visible.clear();
      hasMore = true;
      _fadeCtrl.reset();
    });

    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString('prompts_cache');
    try {
      final ref = FirebaseStorage.instance.ref('prompts/prompts_trending.json');
      final meta = await ref.getMetadata();
      final remoteUpdated = meta.updated?.toIso8601String() ?? '';
      final shouldReload =
          bustCache ||
          cachedJson == null ||
          prefs.getString('prompts_meta') != remoteUpdated;

      if (shouldReload) {
        final url = await ref.getDownloadURL();
        final res = await http.get(Uri.parse(url));
        final data = jsonDecode(res.body);
        _parseData(data);
        prefs.setString('prompts_cache', res.body);
        prefs.setString('prompts_meta', remoteUpdated);
      } else {
        _parseData(jsonDecode(cachedJson!));
      }
    } catch (e) {
      if (cachedJson != null) _parseData(jsonDecode(cachedJson));
      error = 'Không thể tải dữ liệu: $e';
    }

    setState(() => loading = false);
    _fadeCtrl.forward();
  }

  void _parseData(Map<String, dynamic> data) {
    final items = ((data['items'] ?? []) as List)
        .map((e) => PromptItem.fromJson(e))
        .toList();
    items.sort((a, b) => b.id.compareTo(a.id));
    all = items;
    visible = all.take(batchSize).toList();
    hasMore = all.length > batchSize;
  }

  Future<void> _loadMore() async {
    if (isLoadingMore || !hasMore) return;
    setState(() => isLoadingMore = true);
    await Future.delayed(const Duration(milliseconds: 200));
    final next = visible.length + batchSize;
    setState(() {
      visible = all.take(next).toList();
      hasMore = visible.length < all.length;
      isLoadingMore = false;
    });
  }

  void _applyFilters() {
    final q = _q.text.toLowerCase();
    if (q.isEmpty) {
      setState(() => visible = all.take(batchSize).toList());
      return;
    }
    final results = all
        .where((it) => (it.title + it.prompt).toLowerCase().contains(q))
        .toList();
    setState(() => visible = results.take(batchSize).toList());
  }

  Future<void> _onRefresh() async => _loadTrending(bustCache: true);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            '🎨 Thư Viện Ảnh',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          actions: [
            FutureBuilder<int>(
              future: _countFavorites(),
              builder: (context, snap) {
                final count = snap.data ?? 0;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Xem danh sách yêu thích 💖',
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FavoriteScreen(),
                          ),
                        );
                        setState(() {});
                      },
                      icon: const Icon(
                        Icons.favorite_rounded,
                        color: Colors.pinkAccent,
                      ),
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
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : (error != null)
            ? Center(child: Text(error!))
            : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: AppTheme.cream,
                    child: TextField(
                      controller: _q,
                      onChanged: (_) => _applyFilters(),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Tìm kiếm...',
                      ),
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _onRefresh,
                      color: AppTheme.primary,
                      child: ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        children: [
                          visible.isEmpty
                              ? const _EmptyState()
                              : _GalleryGrid(
                                  items: visible,
                                  rootContext: context,
                                ),
                          if (isLoadingMore)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GalleryGrid extends StatelessWidget {
  final List<PromptItem> items;
  final BuildContext rootContext;

  const _GalleryGrid({required this.items, required this.rootContext});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
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
}

/// 🧩 Card ảnh pastel có ❤️
class _GalleryCard extends StatefulWidget {
  final PromptItem item;

  const _GalleryCard({required this.item});

  @override
  State<_GalleryCard> createState() => _GalleryCardState();
}

class _GalleryCardState extends State<_GalleryCard> {
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadFavoriteStatus();
  }

  Future<void> _loadFavoriteStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final favList = prefs.getStringList('favorites') ?? [];
    setState(() => _isFavorite = favList.contains(widget.item.id));
  }

  Future<void> _toggleFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    final favList = prefs.getStringList('favorites') ?? [];
    setState(() => _isFavorite = !_isFavorite);
    if (_isFavorite)
      favList.add(widget.item.id);
    else
      favList.remove(widget.item.id);
    await prefs.setStringList('favorites', favList);
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
              future: _resolveImage(widget.item.image),
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

  void _showDetail(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    var favList = prefs.getStringList('favorites') ?? [];
    bool isFavorite = favList.contains(widget.item.id);

    showGeneralDialog(
      context: context,
      barrierLabel: "Chi tiết ảnh",
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) {
        return GestureDetector(
          onVerticalDragUpdate: (details) {
            if (details.primaryDelta != null && details.primaryDelta! > 20) {
              Navigator.of(context).pop();
            }
          },
          child: Center(
            child: Dialog(
              insetPadding: const EdgeInsets.all(16),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: StatefulBuilder(
                builder: (context, setDialogState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                widget.item.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
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
                      FutureBuilder<String>(
                        future: _resolveImage(widget.item.image),
                        builder: (context, snap) {
                          if (!snap.hasData) {
                            return const Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(),
                            );
                          }
                          return CachedNetworkImage(
                            imageUrl: snap.data!,
                            fit: BoxFit.cover,
                          );
                        },
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.copy_rounded),
                              label: const Text('Sao chép'),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: widget.item.prompt),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✨ Đã sao chép!'),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primarySoft,
                              ),
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.share_rounded),
                              label: const Text('Chia sẻ'),
                              onPressed: () => Share.share(
                                '${widget.item.title}\n\n${widget.item.prompt}',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                              ),
                            ),
                            ElevatedButton.icon(
                              icon: Icon(
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
                                setDialogState(() => isFavorite = !isFavorite);
                                setState(
                                  () => _isFavorite = isFavorite,
                                ); // 🔥 Đồng bộ card ngoài
                                if (isFavorite) {
                                  favList.add(widget.item.id);
                                } else {
                                  favList.remove(widget.item.id);
                                }
                                await prefs.setStringList('favorites', favList);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isFavorite
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
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_not_supported, size: 48, color: AppTheme.inkSoft),
          SizedBox(height: 8),
          Text(
            'Không tìm thấy ảnh phù hợp',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4),
          Text('Hãy thử từ khóa khác nhé.'),
        ],
      ),
    ),
  );
}

/// Resolve ảnh từ Firebase
Future<String> _resolveImage(String path) async {
  if (path.startsWith('http')) return path;
  final ref = FirebaseStorage.instance.ref(path);
  return ref.getDownloadURL();
}
