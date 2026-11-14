import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';

import '../auth/auth_api.dart';

class AiException implements Exception {
  const AiException(this.message);
  final String message;
}

class AiConversation {
  const AiConversation({required this.id, required this.title, this.plantId});
  final String id;
  final String title;
  final int? plantId;
  factory AiConversation.fromJson(Map<String, dynamic> json) => AiConversation(
    id: json['id'] as String,
    title: json['title'] as String,
    plantId: (json['plantId'] as num?)?.toInt(),
  );
}

class AiMessage {
  const AiMessage({
    required this.id,
    required this.turnId,
    required this.sequence,
    required this.role,
    required this.content,
    required this.status,
    this.errorCode,
  });
  final String id;
  final String turnId;
  final int sequence;
  final String role;
  final String content;
  final String status;
  final String? errorCode;
  bool get active => status == 'ACCEPTED' || status == 'STREAMING';
  factory AiMessage.fromJson(Map<String, dynamic> json) => AiMessage(
    id: json['id'] as String,
    turnId: json['turnId'] as String,
    sequence: (json['sequence'] as num).toInt(),
    role: json['role'] as String,
    content: json['content'] as String,
    status: json['status'] as String,
    errorCode: json['errorCode'] as String?,
  );
}

class AiEvent {
  const AiEvent(this.name, this.data);
  final String name;
  final Map<String, dynamic> data;
  bool get terminal => name == 'done' || name == 'error' || name == 'snapshot';
}

/// 一次流式请求及其网络取消句柄。
class AiCall {
  const AiCall(this.events, this.cancel);
  final Stream<AiEvent> events;
  final void Function() cancel;
}

abstract class AiApi {
  Future<List<AiConversation>> list({int offset = 0});
  Future<AiConversation> create({int? plantId});
  Future<List<AiMessage>> messages(String id, {int? before});
  AiCall send(String id, String requestId, String content);
  Future<void> cancel(String id, String turnId);
  Future<void> delete(String id);
}

/// 使用安全随机数生成客户端去重 UUID。
String newAiRequestId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// 增量解析 UTF-8 与 SSE 帧，保留跨数据块的字符和事件边界。
Stream<AiEvent> decodeAiEvents(Stream<List<int>> bytes) async* {
  String name = 'message';
  final data = <String>[];
  var size = 0;
  var terminal = false;
  await for (final line
      in bytes
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
    if (line.isEmpty) {
      if (data.isNotEmpty) {
        if (terminal) throw const FormatException('结束事件后收到额外数据');
        final event = AiEvent(
          name,
          jsonDecode(data.join('\n')) as Map<String, dynamic>,
        );
        if (!const {
          'accepted',
          'delta',
          'done',
          'error',
          'snapshot',
        }.contains(name)) {
          throw const FormatException('未知问答事件');
        }
        terminal = event.terminal;
        yield event;
      }
      name = 'message';
      data.clear();
      size = 0;
    } else if (!line.startsWith(':')) {
      size += line.length;
      if (size > 1000000) throw const FormatException('问答事件超过允许大小');
      final colon = line.indexOf(':');
      final field = colon < 0 ? line : line.substring(0, colon);
      var value = colon < 0 ? '' : line.substring(colon + 1);
      if (value.startsWith(' ')) value = value.substring(1);
      if (field == 'event') name = value;
      if (field == 'data') data.add(value);
    }
  }
  if (!terminal || data.isNotEmpty) {
    throw const AiException('连接已中断，请刷新查看已保存的回复');
  }
}

class DioAiApi implements AiApi {
  DioAiApi({required this.token, Dio? dio})
    : dio = dio ?? Dio(BaseOptions(baseUrl: apiBaseUrl));
  final String token;
  final Dio dio;
  Options get _options => Options(headers: {'Authorization': 'Bearer $token'});

  @override
  Future<List<AiConversation>> list({int offset = 0}) async {
    final response = await _request(
      () => dio.get<List<dynamic>>(
        '/ai/conversations',
        queryParameters: {'offset': offset, 'limit': 20},
        options: _options,
      ),
    );
    return response.data!
        .map((item) => AiConversation.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<AiConversation> create({int? plantId}) async {
    final response = await _request(
      () => dio.post<Map<String, dynamic>>(
        '/ai/conversations',
        data: {'plantId': plantId},
        options: _options,
      ),
    );
    return AiConversation.fromJson(response.data!);
  }

  @override
  Future<List<AiMessage>> messages(String id, {int? before}) async {
    final response = await _request(
      () => dio.get<List<dynamic>>(
        '/ai/conversations/$id/messages',
        queryParameters: {'limit': 20, 'before': ?before},
        options: _options,
      ),
    );
    return response.data!
        .map((item) => AiMessage.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  AiCall send(String id, String requestId, String content) {
    final cancellation = CancelToken();
    return AiCall(
      _stream(id, requestId, content, cancellation),
      () => cancellation.cancel(),
    );
  }

  Stream<AiEvent> _stream(
    String id,
    String requestId,
    String content,
    CancelToken cancellation,
  ) async* {
    try {
      final response = await dio.post<ResponseBody>(
        '/ai/conversations/$id/messages',
        data: {'requestId': requestId, 'content': content},
        cancelToken: cancellation,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'text/event-stream, application/problem+json',
          },
        ),
      );
      if (!(response.headers.value('content-type') ?? '').startsWith(
        'text/event-stream',
      )) {
        throw const AiException('问答服务返回了无效的响应类型');
      }
      yield* decodeAiEvents(response.data!.stream);
    } on DioException catch (error) {
      final raw = error.response?.data;
      Object? data = raw;
      if (raw is ResponseBody) {
        data = jsonDecode(
          await raw.stream.cast<List<int>>().transform(utf8.decoder).join(),
        );
      }
      throw AiException(_detail(data));
    } on FormatException {
      throw const AiException('无法解析问答服务的响应，请刷新查看已保存的回复');
    }
  }

  @override
  Future<void> cancel(String id, String turnId) => _request(
    () => dio.post<void>(
      '/ai/conversations/$id/turns/$turnId/cancel',
      options: _options,
    ),
  );

  @override
  Future<void> delete(String id) => _request(
    () => dio.delete<void>('/ai/conversations/$id', options: _options),
  );

  Future<Response<T>> _request<T>(
    Future<Response<T>> Function() operation,
  ) async {
    try {
      return await operation();
    } on DioException catch (error) {
      throw AiException(_detail(error.response?.data));
    }
  }

  String _detail(Object? data) => data is Map && data['detail'] is String
      ? data['detail'] as String
      : '暂时无法完成问答请求';
}
