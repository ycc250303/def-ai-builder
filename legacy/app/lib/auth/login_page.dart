import 'package:material_ui/material_ui.dart';

import 'auth_api.dart';

enum _AuthMode { login, register, resetPassword }

/// 注册、登录与密码重置共用的页面。
class LoginPage extends StatefulWidget {
  /// 创建登录页。
  const LoginPage({
    super.key,
    required this.submit,
    required this.resetPassword,
  });

  /// `register` 为 true 时注册，否则登录。失败时抛出 [AuthException]。
  final Future<void> Function(bool register, String username, String password)
  submit;

  /// 按账号名称和新密码重置，失败时抛出 [AuthException]。
  final Future<void> Function(String username, String newPassword)
  resetPassword;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  var _mode = _AuthMode.login;
  var _submitting = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
      _notice = null;
    });
    try {
      if (_mode == _AuthMode.resetPassword) {
        await widget.resetPassword(_username.text, _password.text);
        if (!mounted) return;
        setState(() {
          _mode = _AuthMode.login;
          _password.clear();
          _notice = '密码已重置，请使用新密码登录';
        });
      } else {
        await widget.submit(
          _mode == _AuthMode.register,
          _username.text,
          _password.text,
        );
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = switch (_mode) {
      _AuthMode.login => '登录',
      _AuthMode.register => '注册',
      _AuthMode.resetPassword => '重置密码',
    };
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: SingleChildScrollView(
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
                  enabled: !_submitting,
                  decoration: const InputDecoration(labelText: '用户名称'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('password'),
                  controller: _password,
                  enabled: !_submitting,
                  decoration: InputDecoration(
                    labelText: _mode == _AuthMode.resetPassword ? '新密码' : '密码',
                  ),
                  obscureText: true,
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, key: const Key('auth-error')),
                ],
                if (_notice != null) ...[
                  const SizedBox(height: 12),
                  Text(_notice!, key: const Key('auth-notice')),
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
                          _mode = _mode == _AuthMode.login
                              ? _AuthMode.register
                              : _AuthMode.login;
                          _error = null;
                          _notice = null;
                          _password.clear();
                        }),
                  child: Text(switch (_mode) {
                    _AuthMode.login => '没有账号，去注册',
                    _AuthMode.register => '已有账号，去登录',
                    _AuthMode.resetPassword => '返回登录',
                  }),
                ),
                if (_mode == _AuthMode.login)
                  TextButton(
                    key: const Key('forgot-password'),
                    onPressed: _submitting
                        ? null
                        : () => setState(() {
                            _mode = _AuthMode.resetPassword;
                            _password.clear();
                            _error = null;
                            _notice = null;
                          }),
                    child: const Text('忘记密码'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
