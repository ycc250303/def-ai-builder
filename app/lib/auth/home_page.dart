import 'package:material_ui/material_ui.dart';

/// 登录后的首页，展示当前用户并提供退出。
class HomePage extends StatelessWidget {
  /// 创建首页。
  const HomePage({super.key, required this.username, required this.onLogout});

  /// 当前用户名称。
  final String username;

  /// 退出当前登录。
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的植物'),
        actions: [
          TextButton(
            key: const Key('logout'),
            onPressed: onLogout,
            child: const Text('退出'),
          ),
        ],
      ),
      body: Center(child: Text(username, key: const Key('current-user'))),
    );
  }
}
