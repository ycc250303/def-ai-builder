import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:hello_flutter/auth/auth_api.dart';
import 'package:hello_flutter/auth/login_page.dart';
import 'package:hello_flutter/auth/token_store.dart';
import 'package:hello_flutter/main.dart';

import 'support/fake_plant_api.dart';

void main() {
  testWidgets('登录失败时展示接口说明', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          resetPassword: (_, _) async {},
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
    await tester.pumpWidget(
      PlantApp(session: session, plantApi: FakePlantApi()),
    );
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

  testWidgets('忘记密码按账号重置，成功后返回登录并清空密码', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _FakeAuthApi();
    final session = AuthSession(api: api, store: MemoryTokenStore());
    await tester.pumpWidget(
      PlantApp(session: session, plantApi: FakePlantApi()),
    );
    await session.restore();
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('username')), 'Alice');
    await tester.enterText(find.byKey(const Key('password')), 'password1');
    await tester.tap(find.byKey(const Key('forgot-password')));
    await tester.pumpAndSettle();
    expect(find.text('新密码'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('password')))
          .controller!
          .text,
      isEmpty,
    );
    await tester.enterText(find.byKey(const Key('password')), ' new-password ');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();
    expect(api.resetUsername, 'Alice');
    expect(api.resetNewPassword, ' new-password ');
    expect(find.text('密码已重置，请使用新密码登录'), findsOneWidget);
    expect(session.user, isNull);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('password')))
          .controller!
          .text,
      isEmpty,
    );
    await tester.enterText(find.byKey(const Key('password')), ' new-password ');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();
    expect(session.user!.username, 'alice');
    expect(tester.takeException(), isNull);
  });

  testWidgets('重置失败显示接口说明并保留输入，可以重试和返回登录', (tester) async {
    final api = _FakeAuthApi()..resetFailure = '账号不存在';
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          submit: (_, _, _) async {},
          resetPassword: api.resetPassword,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('forgot-password')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('username')), 'Alice');
    await tester.enterText(find.byKey(const Key('password')), 'password2');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();
    expect(find.text('账号不存在'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('password')))
          .controller!
          .text,
      'password2',
    );
    api.resetFailure = null;
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();
    expect(api.resetNewPassword, 'password2');
    expect(find.text('账号不存在'), findsNothing);
    await tester.tap(find.byKey(const Key('forgot-password')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('switch-mode')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forgot-password')), findsOneWidget);
    expect(find.text('新密码'), findsNothing);
  });
}

class _FakeAuthApi implements AuthApi {
  String? registeredUsername;
  var loggedOut = false;
  String? resetUsername;
  String? resetNewPassword;
  String? resetFailure;

  @override
  Future<void> resetPassword(String username, String newPassword) async {
    if (resetFailure != null) throw AuthException(resetFailure!);
    resetUsername = username;
    resetNewPassword = newPassword;
  }

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
