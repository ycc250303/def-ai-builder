import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_flutter/plants/plant_api.dart';

void main() {
  final payload = <String, dynamic>{
    'id': 1,
    'species': '绿萝',
    'nickname': '小绿',
    'plantingDate': null,
    'careStartDate': '2026-11-14',
    'growingLocation': 'INDOOR',
    'cultivationMethod': 'SOIL',
    'description': null,
  };

  test('植物接口携带令牌并按契约读取、创建、更新和删除', () async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: options.method == 'GET' && options.path == '/plants'
                  ? [payload]
                  : options.method == 'DELETE'
                  ? null
                  : payload,
            ),
          );
        },
      ),
    );
    final api = DioPlantApi(token: 'test-token', dio: dio);
    expect((await api.list()).single.nickname, '小绿');
    expect((await api.get(1)).plantingDate, isNull);
    expect((await api.create(const PlantInput(species: '绿萝'))).id, 1);
    await api.update(1, const PlantInput(species: '绿萝'));
    await api.delete(1);
    expect(requests.map((request) => request.method), [
      'GET',
      'GET',
      'POST',
      'PUT',
      'DELETE',
    ]);
    expect(requests.map((request) => request.path), [
      '/plants',
      '/plants/1',
      '/plants',
      '/plants/1',
      '/plants/1',
    ]);
    for (final request in requests) {
      expect(request.headers['Authorization'], 'Bearer test-token');
    }
    final update = requests[3].data as Map<String, dynamic>;
    expect(update.containsKey('plantingDate'), isTrue);
    expect(update['plantingDate'], isNull);
    expect(update['careStartDate'], isNull);
    expect(update['growingLocation'], isNull);
    expect(update['cultivationMethod'], isNull);
    expect(update['description'], isNull);
  });

  test('植物请求失败传递服务端 Problem Details', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response(
                requestOptions: options,
                statusCode: 404,
                data: {'code': 'PLANT_NOT_FOUND', 'detail': '植物不存在'},
              ),
            ),
          );
        },
      ),
    );
    final api = DioPlantApi(token: 'test-token', dio: dio);
    await expectLater(
      api.get(1),
      throwsA(
        isA<PlantException>().having((e) => e.message, 'message', '植物不存在'),
      ),
    );
  });
}
