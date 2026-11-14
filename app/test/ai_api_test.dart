import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_flutter/ai/ai_api.dart';

void main() {
  test('中文字符逐字节分段，多个事件和心跳均按SSE边界解析', () async {
    const wire =
        ':heartbeat\r\n\r\nevent: accepted\r\ndata: {"turnId":"1"}\r\n\r\n'
        'event: delta\ndata: {"text":"检查土壤🌱"}\n\n'
        'event: done\ndata: {"content":"检查土壤🌱",\n'
        'data: "status":"COMPLETED"}\n\n';
    final events = await decodeAiEvents(
      Stream.fromIterable(utf8.encode(wire).map((byte) => [byte])),
    ).toList();
    expect(events.map((event) => event.name), ['accepted', 'delta', 'done']);
    expect(events[1].data['text'], '检查土壤🌱');
    expect(events.last.data['status'], 'COMPLETED');
  });

  test('缺少完成事件或事件未结束时明确报告断连', () async {
    for (final text in [
      'event: delta\ndata: {"text":"部分回复"}\n\n',
      'event: done\ndata: {"content":"正文"}',
    ]) {
      await expectLater(
        decodeAiEvents(Stream.value(utf8.encode(text))).toList(),
        throwsA(isA<AiException>()),
      );
    }
  });

  test('请求携带登录令牌和去重编号，并接收流式正文', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    late RequestOptions sent;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          sent = request;
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              headers: Headers.fromMap({
                'content-type': ['text/event-stream'],
              }),
              data: ResponseBody.fromString(
                'event: done\ndata: {"content":"回复"}\n\n',
                200,
                headers: {
                  'content-type': ['text/event-stream'],
                },
              ),
            ),
          );
        },
      ),
    );
    final events = await DioAiApi(
      token: 'test-token',
      dio: dio,
    ).send('c1', 'request-1', '你好').events.toList();
    expect(sent.path, '/ai/conversations/c1/messages');
    expect(sent.headers['Authorization'], 'Bearer test-token');
    expect(sent.data, {'requestId': 'request-1', 'content': '你好'});
    expect(events.single.data['content'], '回复');
  });

  test('流式请求建立前的Problem Details能够显示', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          handler.reject(
            DioException(
              requestOptions: request,
              type: DioExceptionType.badResponse,
              response: Response(
                requestOptions: request,
                statusCode: 503,
                data: ResponseBody.fromString('{"detail":"模型服务尚未配置"}', 503),
              ),
            ),
          );
        },
      ),
    );
    await expectLater(
      DioAiApi(
        token: 'test-token',
        dio: dio,
      ).send('c1', 'r1', '你好').events.toList(),
      throwsA(
        isA<AiException>().having(
          (error) => error.message,
          'message',
          '模型服务尚未配置',
        ),
      ),
    );
  });

  test('客户端请求编号为独立UUID', () {
    final first = newAiRequestId();
    expect(
      first,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(first, isNot(newAiRequestId()));
  });
}
