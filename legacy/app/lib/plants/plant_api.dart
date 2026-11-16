import 'package:dio/dio.dart';

import '../auth/auth_api.dart';

/// 植物档案可编辑字段。日期采用 yyyy-MM-dd 格式。
class PlantInput {
  /// 创建完整档案输入。
  const PlantInput({
    required this.species,
    this.nickname,
    this.plantingDate,
    this.careStartDate,
    this.growingLocation,
    this.cultivationMethod,
    this.description,
  });

  final String species;
  final String? nickname;
  final String? plantingDate;
  final String? careStartDate;

  /// INDOOR 为室内，OUTDOOR 为室外，null 表示未填写。
  final String? growingLocation;

  /// SOIL 为土培，WATER 为水培，null 表示未填写。
  final String? cultivationMethod;
  final String? description;

  /// 所有可编辑字段，包含需要清空的 null 值。
  Map<String, dynamic> toJson() => {
    'nickname': nickname,
    'species': species,
    'plantingDate': plantingDate,
    'careStartDate': careStartDate,
    'growingLocation': growingLocation,
    'cultivationMethod': cultivationMethod,
    'description': description,
  };
}

/// 后端保存的植物档案。
class PlantProfile extends PlantInput {
  const PlantProfile({
    required this.id,
    required super.species,
    required String super.nickname,
    required String super.careStartDate,
    super.plantingDate,
    super.growingLocation,
    super.cultivationMethod,
    super.description,
  });

  final int id;

  factory PlantProfile.fromJson(Map<String, dynamic> json) => PlantProfile(
    id: (json['id'] as num).toInt(),
    nickname: json['nickname'] as String,
    species: json['species'] as String,
    plantingDate: json['plantingDate'] as String?,
    careStartDate: json['careStartDate'] as String,
    growingLocation: json['growingLocation'] as String?,
    cultivationMethod: json['cultivationMethod'] as String?,
    description: json['description'] as String?,
  );
}

/// 可向用户展示的请求失败。
class PlantException implements Exception {
  const PlantException(this.message);

  final String message;
}

/// 当前用户的植物列表和档案。
abstract class PlantApi {
  Future<List<PlantProfile>> list();
  Future<PlantProfile> get(int id);
  Future<PlantProfile> create(PlantInput input);
  Future<PlantProfile> update(int id, PlantInput input);
  Future<void> delete(int id);
}

/// 携带当前登录令牌访问植物接口。
class DioPlantApi implements PlantApi {
  DioPlantApi({required this.token, Dio? dio})
    : dio = dio ?? Dio(BaseOptions(baseUrl: apiBaseUrl));

  final String token;
  final Dio dio;

  Options get _options => Options(headers: {'Authorization': 'Bearer $token'});

  @override
  Future<List<PlantProfile>> list() async {
    final response = await _send(
      () => dio.get<List<dynamic>>('/plants', options: _options),
    );
    return response.data!
        .map((item) => PlantProfile.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<PlantProfile> get(int id) async {
    final response = await _send(
      () => dio.get<Map<String, dynamic>>('/plants/$id', options: _options),
    );
    return PlantProfile.fromJson(response.data!);
  }

  @override
  Future<PlantProfile> create(PlantInput input) async {
    final response = await _send(
      () => dio.post<Map<String, dynamic>>(
        '/plants',
        data: input.toJson(),
        options: _options,
      ),
    );
    return PlantProfile.fromJson(response.data!);
  }

  @override
  Future<PlantProfile> update(int id, PlantInput input) async {
    final response = await _send(
      () => dio.put<Map<String, dynamic>>(
        '/plants/$id',
        data: input.toJson(),
        options: _options,
      ),
    );
    return PlantProfile.fromJson(response.data!);
  }

  @override
  Future<void> delete(int id) =>
      _send(() => dio.delete<void>('/plants/$id', options: _options));

  Future<Response<T>> _send<T>(Future<Response<T>> Function() send) async {
    try {
      return await send();
    } on DioException catch (error) {
      final data = error.response?.data;
      if (data is Map && data['detail'] is String) {
        throw PlantException(data['detail'] as String);
      }
      throw const PlantException('暂时无法完成植物档案请求，请检查网络后重试');
    }
  }
}
