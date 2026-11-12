import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:hello_flutter/auth/auth_api.dart';
import 'package:hello_flutter/auth/login_page.dart';
import 'package:hello_flutter/auth/token_store.dart';
import 'package:hello_flutter/main.dart';

void main() {
  testWidgets('登录失败时展示接口说明', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          submit: (register, username, password) async {
            throw const AuthException('密码错误');
          },
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('username')), 'alice');
    await tester.enterText(find.byKey(const Key('password')), 'password1');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pump();

    expect(find.text('密码错误'), findsOneWidget);
  });

  testWidgets('注册成功后登录并可以退出', (WidgetTester tester) async {
    final api = _FakeAuthApi();
    final session = AuthSession(api: api, store: MemoryTokenStore());
    await tester.pumpWidget(PlantApp(session: session));
    await session.restore();
    await tester.pump();

    await tester.tap(find.byKey(const Key('switch-mode')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('username')), 'Alice');
    await tester.enterText(find.byKey(const Key('password')), 'password1');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pump();

    expect(find.text('alice'), findsOneWidget);
    expect(api.registeredUsername, 'Alice');

    await tester.tap(find.byKey(const Key('logout')));
    await tester.pump();

    expect(find.text('登录'), findsWidgets);
    expect(api.loggedOut, isTrue);
  });
}

class _FakeAuthApi implements AuthApi {
  String? registeredUsername;
  var loggedOut = false;

  @override
  Future<AuthUser> currentUser(String token) async {
    return const AuthUser(id: 1, username: 'alice');
  }

  @override
  Future<LoginResult> login(String username, String password) async {
    return const LoginResult(
      token: 'token-1',
      user: AuthUser(id: 1, username: 'alice'),
    );
  }

  @override
  Future<void> logout(String token) async {
    loggedOut = true;
  }

  @override
  Future<AuthUser> register(String username, String password) async {
    registeredUsername = username;
    return const AuthUser(id: 1, username: 'alice');
  }
}
