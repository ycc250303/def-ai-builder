import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/behavior.dart';
import 'mock_data.dart';
import 'models.dart';

abstract interface class LocalStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class PreferencesStorage implements LocalStorage {
  PreferencesStorage() : _prefs = SharedPreferencesAsync();
  final SharedPreferencesAsync _prefs;
  static const key = 'plant_mate_demo_v1';
  @override
  Future<String?> read() => _prefs.getString(key);
  @override
  Future<void> write(String value) => _prefs.setString(key, value);
}

class AppStore extends ChangeNotifier {
  AppStore._(this.storage, this.data);
  final LocalStorage storage;
  AppData data;
  Future<void> _pending = Future.value();
  int _sequence = 0;
  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';

  static Future<AppStore> load(LocalStorage storage, {DateTime? now}) async {
    final saved = await storage.read();
    final data = saved == null
        ? mockData(now ?? DateTime.now())
        : AppData.fromJson(jsonDecode(saved) as Map<String, dynamic>);
    final store = AppStore._(storage, data);
    if (saved == null ||
        (jsonDecode(saved) as Map<String, dynamic>)['version'] == 1) {
      await storage.write(jsonEncode(data.toJson()));
    }
    return store;
  }

  /// 串行保存完整快照，保存成功后发布新状态，避免并发操作覆盖及部分更新。
  Future<void> change(void Function(AppData) mutation) {
    _pending = _pending.then((_) async {
      final next = data.copy();
      mutation(next);
      await storage.write(jsonEncode(next.toJson()));
      data = next;
      notifyListeners();
    });
    return _pending;
  }

  Garden garden(String id) => data.gardens.singleWhere((g) => g.id == id);
  Future<void> select(String id) => change((d) {
    d.gardens.singleWhere((g) => g.id == id);
    d.selectedId = id;
  });
  Future<void> addPlant(String name, String petName) => change((d) {
    final g = newGarden(
      _id('garden'),
      name.trim(),
      petName.trim(),
      DateTime.now(),
      d.gardens.length,
    );
    if (g.name.isEmpty || g.pet.name.isEmpty) {
      throw ArgumentError('植物和宠物昵称不能为空');
    }
    d.gardens.add(g);
    d.selectedId = g.id;
  });
  Future<void> renamePet(String id, String name) => change((d) {
    if (name.trim().isEmpty) {
      throw ArgumentError('宠物昵称不能为空');
    }
    d.gardens.singleWhere((g) => g.id == id).pet.name = name.trim();
  });
  Future<void> profile(String name, String bio, {String? avatar}) =>
      change((d) {
        if (name.trim().isEmpty) {
          throw ArgumentError('用户昵称不能为空');
        }
        d.nickname = name.trim();
        d.bio = bio.trim();
        if (avatar != null) d.avatar = avatar;
      });
  Future<void> privacy(String id, bool open) =>
      change((d) => d.gardens.singleWhere((g) => g.id == id).open = open);
  Future<void> follow(String id) => change((d) {
    d.user(id);
    if (id == 'me') {
      throw ArgumentError('不能关注自己');
    }
    d.following = {...d.following};
    if (!d.following.remove(id)) {
      d.following.add(id);
    }
  });
  Future<void> like(String id) => change((d) {
    final p = d.posts.singleWhere((p) => p.id == id);
    p.liked = !p.liked;
    p.likes += p.liked ? 1 : -1;
  });
  Future<void> savePost(String id) => change((d) {
    final p = d.posts.singleWhere((p) => p.id == id);
    p.saved = !p.saved;
  });
  Future<void> comment(String id, String text, {String? replyTo}) =>
      change((d) {
        if (text.trim().isEmpty) {
          throw ArgumentError('评论不能为空');
        }
        final p = d.posts.singleWhere((p) => p.id == id);
        if (replyTo != null) p.comments.singleWhere((c) => c.id == replyTo);
        p.comments = [
          ...p.comments,
          PostComment(
            id: _id('comment'),
            userId: 'me',
            text: text.trim(),
            time: DateTime.now(),
            replyTo: replyTo,
          ),
        ];
      });
  Future<void> publish(
    String gardenId,
    String type,
    String title,
    String body, {
    bool withImage = true,
  }) => change((d) {
    if (body.trim().isEmpty) {
      throw ArgumentError('正文不能为空');
    }
    final garden = d.gardens.singleWhere((g) => g.id == gardenId);
    d.posts.insert(
      0,
      Post(
        id: _id('post'),
        userId: 'me',
        title: title.trim(),
        body: body.trim(),
        type: type,
        snapshot: withImage ? garden.snapshot() : null,
        time: DateTime.now(),
      ),
    );
  });
  Future<void> setDevice(String id, bool bound) => change((d) {
    final garden = d.gardens.singleWhere((g) => g.id == id);
    garden.deviceId = bound ? 'PM-${garden.id}' : null;
  });
  Future<void> sync(String id) => change((d) {
    final g = d.gardens.singleWhere((g) => g.id == id);
    if (g.deviceId == null) {
      throw StateError('请先绑定模拟设备');
    }
    g.readings.add(mockReadings(DateTime.now(), g.pet.trait).last);
  });

  Future<void> language(String value) => change((d) {
    if (!['system', 'zh', 'en'].contains(value)) {
      throw ArgumentError('Unsupported language');
    }
    d.language = value;
  });
  Future<void> setAvatar(String value) => change((d) {
    if (![
      'tuantuan',
      'eggie',
      'fixed',
      ...List.generate(7, (i) => 'mature_${i + 1}'),
    ].contains(value)) {
      throw ArgumentError('Unknown avatar');
    }
    d.avatar = value;
  });
  Future<void> setVisitMode(String id, VisitMode mode) => change((d) {
    final g = d.gardens.singleWhere((g) => g.id == id);
    g.visitMode = mode;
    for (final r in d.requests.where(
      (r) => r.gardenId == id && r.ownerId == 'me',
    )) {
      r.status = RequestStatus.rejected;
    }
  });
  Future<void> archivePlant(String id) => change((d) {
    final g = d.gardens.singleWhere((g) => g.id == id);
    g.archived = true;
    for (final r in d.requests.where(
      (r) => r.ownerId == 'me' && r.gardenId == id,
    )) {
      r.status = RequestStatus.rejected;
    }
    g.deviceId = null;
    g.visitMode = VisitMode.closed;
    g.action = null;
    if (d.activeGardens.isNotEmpty) d.selectedId = d.activeGardens.first.id;
  });
  Future<void> restorePlant(String id) => change((d) {
    final g = d.gardens.singleWhere((g) => g.id == id);
    g.archived = false;
    d.selectedId = id;
  });
  Future<void> renamePlant(String id, String value) => change((d) {
    if (value.trim().isEmpty) throw ArgumentError('Empty name');
    d.gardens.singleWhere((g) => g.id == id).name = value.trim();
  });
  Future<void> saveLayout(String id, List<SceneItem> items) => change((d) {
    final g = d.gardens.singleWhere((g) => g.id == id);
    if (items.map((i) => i.id).toSet().length != items.length) {
      throw ArgumentError('Duplicate scene item');
    }
    for (final item in items) {
      if (!item.x.isFinite ||
          !item.y.isFinite ||
          item.x < 0 ||
          item.y < 0 ||
          item.x + item.width > 675 ||
          item.y + item.height > 1292) {
        throw ArgumentError('Scene item outside garden');
      }
    }
    g.items = items.map((i) => SceneItem.fromJson(i.toJson())).toList();
    g.sceneSavedAt = DateTime.now();
  });
  Future<void> editPost(String id, String title, String body) => change((d) {
    final p = d.posts.singleWhere((p) => p.id == id);
    if (p.userId != 'me') throw StateError('Post ownership required');
    if (body.trim().isEmpty) throw ArgumentError('Empty post');
    p.title = title.trim();
    p.body = body.trim();
  });
  Future<void> deletePost(String id) => change((d) {
    final p = d.posts.singleWhere((p) => p.id == id);
    if (p.userId != 'me') throw StateError('Post ownership required');
    d.posts.remove(p);
  });
  Future<void> deleteComment(String postId, String commentId) => change((d) {
    final p = d.posts.singleWhere((p) => p.id == postId);
    final c = p.comments.singleWhere((c) => c.id == commentId);
    if (c.userId != 'me') throw StateError('Comment ownership required');
    p.comments.remove(c);
  });
  bool _follows(AppData d, String from, String to) {
    if (from == 'me') return d.following.contains(to);
    if (to == 'me') return d.followers.contains(from);
    return false;
  }

  bool canVisit(String ownerId, PublicGarden g, {String visitorId = 'me'}) {
    data.user(ownerId);
    data.user(visitorId);
    if (ownerId == visitorId) return true;
    return switch (g.visitMode) {
      VisitMode.public => true,
      VisitMode.closed => false,
      VisitMode.following => _follows(data, ownerId, visitorId),
      VisitMode.followers => _follows(data, visitorId, ownerId),
      VisitMode.mutual =>
        _follows(data, ownerId, visitorId) &&
            _follows(data, visitorId, ownerId),
      VisitMode.request => data.requests.any(
        (r) =>
            r.ownerId == ownerId &&
            r.gardenId == g.id &&
            r.visitorId == visitorId &&
            r.status == RequestStatus.approved,
      ),
    };
  }

  Future<void> requestVisit(
    String ownerId,
    String gardenId, {
    String visitorId = 'me',
  }) => change((d) {
    final u = d.user(ownerId);
    d.user(visitorId);
    final g = u.gardens.singleWhere((g) => g.id == gardenId);
    if (g.visitMode != VisitMode.request || ownerId == visitorId) {
      throw StateError('Garden does not accept requests');
    }
    final existing = d.requests
        .where(
          (r) =>
              r.ownerId == ownerId &&
              r.gardenId == gardenId &&
              r.visitorId == visitorId,
        )
        .toList();
    if (existing.isNotEmpty) {
      if (existing.single.status == RequestStatus.rejected) {
        existing.single.status = RequestStatus.pending;
      }
      return;
    }
    d.requests = [
      ...d.requests,
      VisitRequest(
        id: _id('visit'),
        gardenId: gardenId,
        ownerId: ownerId,
        visitorId: visitorId,
        time: DateTime.now(),
      ),
    ];
  });
  Future<void> decideVisit(
    String id,
    bool approved, {
    bool simulateOwner = false,
  }) => change((d) {
    final r = d.requests.singleWhere((r) => r.id == id);
    if (r.ownerId != 'me' && !simulateOwner) {
      throw StateError('Garden ownership required');
    }
    if (r.ownerId == 'me' && simulateOwner) {
      throw StateError('Use owner approval');
    }
    if (r.status != RequestStatus.pending) {
      throw StateError('Request already decided');
    }
    final g = d.user(r.ownerId).gardens.singleWhere((g) => g.id == r.gardenId);
    if (g.visitMode != VisitMode.request) {
      throw StateError('Garden no longer accepts requests');
    }
    r.status = approved ? RequestStatus.approved : RequestStatus.rejected;
    d.notices = [
      SocialNotice(
        id: _id('notice'),
        actorId: r.ownerId,
        kind: approved ? 'approved' : 'rejected',
        targetId: r.id,
        time: DateTime.now(),
      ),
      ...d.notices,
    ];
  });
  Future<void> markNoticesRead() => change((d) {
    for (final n in d.notices) {
      n.read = true;
    }
  });

  /// 使用预置访客生成申请，审批与权限判断仍执行相同规则。
  Future<void> simulateIncomingRequest(String gardenId) =>
      requestVisit('me', gardenId, visitorId: data.users.first.id);

  /// 每十分钟检查模拟环境；恢复 App 时只处理当前判定，不补发离线奖励。
  Future<void> advance(DateTime now) {
    if (!data.gardens.any((g) => now.difference(g.updatedAt).inMinutes >= 1)) {
      return Future.value();
    }
    return change((d) {
      for (final g in d.activeGardens) {
        BehaviorRules.decay(g, now);
        if (g.deviceId == null ||
            now.difference(g.lastDecision).inMinutes < 10) {
          continue;
        }
        g.lastDecision = now;
        g.readings.add(mockReadings(now, g.pet.trait).last);
        final day = now.hour >= 7 && now.hour < 20;
        // 明确的模拟适宜度；正式硬件接入后由校准后的数据提供方替换。
        final e = EnvironmentFit(
          day ? .76 : .1,
          .65,
          .82,
          .74,
          darkness: day ? .1 : .95,
        );
        if (!day) {
          final last = g.readings.removeLast();
          g.readings.add(
            SensorReading(
              last.time,
              12,
              last.soil,
              last.temperature,
              last.humidity,
            ),
          );
        }
        final choices = BehaviorRules.candidates(g, e, now);
        if (choices.isNotEmpty) {
          BehaviorRules.apply(g, choices.first, now, Random());
        }
        g.readings.removeWhere((r) => now.difference(r.time).inDays > 7);
      }
    });
  }
}
