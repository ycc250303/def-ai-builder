import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_flutter/auth/auth_api.dart';

void main() {
  test('重置密码匿名提交账号和新密码，保留密码原文', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    late RequestOptions request;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          request = options;
          handler.resolve(
            Response<void>(requestOptions: options, statusCode: 200),
          );
        },
      ),
    );
    await DioAuthApi(dio: dio).resetPassword('Alice', ' new-password ');
    expect(request.method, 'POST');
    expect(request.path, '/users/reset-password');
    expect(request.data, {
      'username': 'Alice',
      'newPassword': ' new-password ',
    });
    expect(request.headers.containsKey('Authorization'), isFalse);
  });

  test('重置密码失败传递服务端 Problem Details', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: options,
              statusCode: 401,
              data: {'code': 'ACCOUNT_NOT_FOUND', 'detail': '账号不存在'},
            ),
          ),
        ),
      ),
    );
    await expectLater(
      DioAuthApi(dio: dio).resetPassword('Alice', 'password2'),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          '账号不存在',
        ),
      ),
    );
  });
}
