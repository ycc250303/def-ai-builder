import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 本机登录令牌。
abstract class TokenStore {
  /// 读取已保存的令牌。
  Future<String?> read();

  /// 保存令牌。
  Future<void> save(String token);

  /// 删除令牌。
  Future<void> clear();
}

/// 使用系统安全存储保存令牌。
class SecureTokenStore implements TokenStore {
  /// 创建安全存储。
  SecureTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'auth_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() {
    return _storage.read(key: _key);
  }

  @override
  Future<void> save(String token) {
    return _storage.write(key: _key, value: token);
  }

  @override
  Future<void> clear() {
    return _storage.delete(key: _key);
  }
}

/// 测试用的内存令牌存储。
class MemoryTokenStore implements TokenStore {
  String? _token;

  @override
  Future<void> clear() async {
    _token = null;
  }

  @override
  Future<String?> read() async {
    return _token;
  }

  @override
  Future<void> save(String token) async {
    _token = token;
  }
}
