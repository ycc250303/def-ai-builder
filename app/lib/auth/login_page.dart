import 'package:material_ui/material_ui.dart';

import 'auth_api.dart';

/// 注册与登录共用的页面。
class LoginPage extends StatefulWidget {
  /// 创建登录页。
  const LoginPage({super.key, required this.submit});

  /// `register` 为 true 时注册，否则登录。失败时抛出 [AuthException]。
  final Future<void> Function(bool register, String username, String password)
  submit;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  var _registerMode = false;
  var _submitting = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.submit(_registerMode, _username.text, _password.text);
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = _registerMode ? '注册' : '登录';
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(action, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 24),
                TextField(
                  key: const Key('username'),
                  controller: _username,
                  decoration: const InputDecoration(labelText: '用户名称'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('password'),
                  controller: _password,
                  decoration: const InputDecoration(labelText: '密码'),
                  obscureText: true,
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, key: const Key('auth-error')),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('submit'),
                  onPressed: _submitting ? null : _submit,
                  child: Text(action),
                ),
                TextButton(
                  key: const Key('switch-mode'),
                  onPressed: _submitting
                      ? null
                      : () => setState(() {
                          _registerMode = !_registerMode;
                          _error = null;
                        }),
                  child: Text(_registerMode ? '已有账号，去登录' : '没有账号，去注册'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
