import 'dart:convert';

/// 🌈 Model đại diện cho 1 prompt (ảnh + nội dung)
class PromptItem {
  final String id;
  final String title;
  final String image;
  final String prompt;
  final List<String> tags;
  final String? category;

  const PromptItem({
    required this.id,
    required this.title,
    required this.image,
    required this.prompt,
    required this.tags,
    this.category,
  });

  factory PromptItem.fromJson(Map<String, dynamic> j) => PromptItem(
    id: j['id']?.toString() ?? '',
    title: j['title']?.toString() ?? '',
    image: j['image']?.toString() ?? '',
    prompt: j['prompt']?.toString() ?? '',
    tags: (j['tags'] is List)
        ? (j['tags'] as List).map((e) => e.toString()).toList()
        : [],
    category: j['category']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'image': image,
    'prompt': prompt,
    'tags': tags,
    'category': category,
  };

  /// 🔹 Parse toàn bộ danh sách Prompt từ JSON string lưu trong SharedPreferences
  static List<PromptItem> listFromJsonString(String jsonStr) {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final items = (data['items'] ?? []) as List<dynamic>;
    return items.map((e) => PromptItem.fromJson(e)).toList();
  }
}
