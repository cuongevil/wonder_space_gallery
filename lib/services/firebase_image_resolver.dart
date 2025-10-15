import 'package:firebase_storage/firebase_storage.dart';

/// ✅ Resolve ảnh từ Firebase (hoặc URL trực tiếp)
Future<String> resolveImage(String path) async {
  if (path.startsWith('http')) return path;
  return FirebaseStorage.instance.ref(path).getDownloadURL();
}
