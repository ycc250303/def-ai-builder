import 'package:material_ui/material_ui.dart';

import 'auth/auth_api.dart';
import 'auth/home_page.dart';
import 'auth/login_page.dart';
import 'auth/token_store.dart';
import 'plants/plant_api.dart';
import 'ai/ai_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = AuthSession(api: DioAuthApi(), store: SecureTokenStore());
  runApp(PlantApp(session: session));
  await session.restore();
}

/// 登录状态。启动时用已保存令牌恢复，被拒绝时清除令牌。
class AuthSession extends ChangeNotifier {
  /// 创建登录状态。
  AuthSession({required this.api, required this.store});

  /// 登录接口。
  final AuthApi api;

  /// 令牌存储。
  final TokenStore store;

  /// 当前用户。为空表示停留在登录页。
  AuthUser? user;

  String? _token;

  /// 当前登录令牌，用于访问受保护的业务接口。
  String? get token => _token;

  /// 是否仍在恢复登录。
  var restoring = true;

  /// 读取已保存令牌并请求当前用户。
  Future<void> restore() async {
    final token = await store.read();
    if (token == null || token.isEmpty) {
      restoring = false;
      notifyListeners();
      return;
    }
    try {
      user = await api.currentUser(token);
      _token = token;
    } on AuthException {
      await store.clear();
      user = null;
      _token = null;
    } finally {
      restoring = false;
      notifyListeners();
    }
  }

  /// 按页面选择注册或登录。
  Future<void> submit(bool register, String username, String password) async {
    if (register) {
      await api.register(username, password);
    }
    final result = await api.login(username, password);
    await store.save(result.token);
    _token = result.token;
    user = result.user;
    notifyListeners();
  }

  /// 通知后端退出并删除本机令牌。
  Future<void> logout() async {
    final token = _token;
    if (token != null) {
      await api.logout(token);
    }
    await store.clear();
    _token = null;
    user = null;
    notifyListeners();
  }
}

/// 应用入口。
class PlantApp extends StatelessWidget {
  /// 创建应用。
  const PlantApp({super.key, required this.session, this.plantApi, this.aiApi});

  /// 登录状态。
  final AuthSession session;

  /// 可注入的植物接口，默认携带当前登录令牌访问后端。
  final PlantApi? plantApi;
  final AiApi? aiApi;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '植物养护',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          if (session.restoring) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final user = session.user;
          if (user == null) {
            return LoginPage(
              submit: session.submit,
              resetPassword: session.api.resetPassword,
            );
          }
          return HomePage(
            key: ValueKey(user.id),
            username: user.username,
            onLogout: session.logout,
            plantApi: plantApi ?? DioPlantApi(token: session.token!),
            aiApi: aiApi ?? DioAiApi(token: session.token!),
          );
        },
      ),
    );
  }
}
