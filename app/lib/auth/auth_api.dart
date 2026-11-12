import 'package:dio/dio.dart';

/// 后端地址。联调时可用 `--dart-define=API_BASE_URL=http://localhost:8080` 覆盖。
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);

/// 登录后的用户。
class AuthUser {
  /// 创建用户信息。
  const AuthUser({required this.id, required this.username});

  /// 用户编号。
  final int id;

  /// 规范化后的用户名称。
  final String username;

  /// 从接口 JSON 读取用户。
  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['id'] as num).toInt(),
      username: json['username'] as String,
    );
  }
}

/// 登录成功后的令牌和用户。
class LoginResult {
  /// 创建登录结果。
  const LoginResult({required this.token, required this.user});

  /// 当前登录令牌。
  final String token;

  /// 当前用户。
  final AuthUser user;
}

/// 接口返回的可展示失败。
class AuthException implements Exception {
  /// 创建失败说明。
  const AuthException(this.message);

  /// 给页面展示的说明。
  final String message;
}

/// 注册、登录、当前用户和退出。
abstract class AuthApi {
  /// 注册账号。
  Future<AuthUser> register(String username, String password);

  /// 登录并取得令牌。
  Future<LoginResult> login(String username, String password);

  /// 用令牌读取当前用户。
  Future<AuthUser> currentUser(String token);

  /// 退出并使令牌失效。
  Future<void> logout(String token);
}

/// 通过 HTTP 调用后端登录接口。
class DioAuthApi implements AuthApi {
  /// 创建接口客户端。
  DioAuthApi({Dio? dio, this.baseUrl = apiBaseUrl})
    : dio = dio ?? Dio(BaseOptions(baseUrl: baseUrl));

  /// HTTP 客户端。
  final Dio dio;

  /// 后端根地址。
  final String baseUrl;

  @override
  Future<AuthUser> register(String username, String password) async {
    final response = await _send(
      () => dio.post<Map<String, dynamic>>(
        '/users',
        data: {'username': username, 'password': password},
      ),
    );
    return AuthUser.fromJson(response.data!);
  }

  @override
  Future<LoginResult> login(String username, String password) async {
    final response = await _send(
      () => dio.post<Map<String, dynamic>>(
        '/users/login',
        data: {'username': username, 'password': password},
      ),
    );
    final body = response.data!;
    return LoginResult(
      token: body['token'] as String,
      user: AuthUser.fromJson(body['user'] as Map<String, dynamic>),
    );
  }

  @override
  Future<AuthUser> currentUser(String token) async {
    final response = await _send(
      () => dio.get<Map<String, dynamic>>(
        '/users/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      ),
    );
    return AuthUser.fromJson(response.data!);
  }

  @override
  Future<void> logout(String token) {
    return _send(
      () => dio.post<void>(
        '/users/logout',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      ),
    );
  }

  Future<Response<T>> _send<T>(Future<Response<T>> Function() send) async {
    try {
      return await send();
    } on DioException catch (error) {
      throw AuthException(_messageOf(error));
    }
  }

  String _messageOf(DioException error) {
    final data = error.response?.data;
    if (data is Map &&
        data['detail'] is String &&
        (data['detail'] as String).isNotEmpty) {
      return data['detail'] as String;
    }
    return '暂时无法完成请求';
  }
}
