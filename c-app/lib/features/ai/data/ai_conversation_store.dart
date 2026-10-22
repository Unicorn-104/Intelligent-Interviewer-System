import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AiConversationStore {
  const AiConversationStore({required this.userId});

  final int userId;
  static const _storage = FlutterSecureStorage();
  static final _recent = <int, String>{};
  static Future<void> _pendingWrite = Future<void>.value();

  String get _key => 'ai_last_conversation_$userId';

  Future<String?> read() async {
    final cached = _recent[userId];
    if (cached != null) return cached;
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String id) {
    _recent[userId] = id;
    // Keep rapid conversation switches in order, including across page instances.
    return _pendingWrite = _pendingWrite.then((_) async {
      try {
        await _storage.write(key: _key, value: id);
      } catch (_) {
        // Storage failures must not interrupt chatting; the in-memory ID remains.
      }
    });
  }
}
