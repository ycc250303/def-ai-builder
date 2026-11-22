import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:plant/data/app_store.dart';
import 'package:plant/data/mock_data.dart';
import 'package:plant/data/models.dart';

import 'legacy_data.dart';
import 'test_storage.dart';

void main() {
  final now = DateTime(2026, 11, 22, 10);

  Future<AppStore> create({int xp = 0}) async {
    final store = await AppStore.load(MemoryStorage(), now: now);
    await store.addPlant('绿萝', '团团');
    await store.change((d) {
      final g = d.selected;
      g.updatedAt = now;
      g.lastDecision = now;
      g.deviceId = 'PM-TEST';
      g.pet.xp = xp;
      if (xp >= 400) {
        g.pet.history = [...g.pet.history, EvolutionRecord('fixed', 5, now)];
      }
    });
    return store;
  }

  test('版本2迁移清除预置植物及申请，保留用户植物、个人设置与发布内容', () async {
    final data = legacyData(now);
    final own = newGarden('garden-user', '阳台', '团团', now);
    own.pet.xp = 398;
    data.gardens.add(own);
    data.nickname = '用户昵称';
    data.bio = '用户简介';
    data.language = 'en';
    data.avatar = 'fixed';
    data.requests = [
      VisitRequest(
        id: 'seed-request',
        gardenId: 'g1',
        ownerId: 'me',
        visitorId: 'moss_sun',
        time: now,
      ),
      VisitRequest(
        id: 'own-request',
        gardenId: own.id,
        ownerId: 'me',
        visitorId: 'moss_sun',
        time: now,
      ),
    ];
    data.notices = [
      SocialNotice(
        id: 'notice-like',
        actorId: 'moss_sun',
        kind: 'like',
        time: now,
      ),
      SocialNotice(
        id: 'seed-notice',
        actorId: 'moss_sun',
        kind: 'request',
        targetId: 'seed-request',
        time: now,
      ),
      SocialNotice(
        id: 'own-notice',
        actorId: 'moss_sun',
        kind: 'request',
        targetId: 'own-request',
        time: now,
      ),
    ];
    data.posts.add(
      Post(
        id: 'own-post',
        userId: 'me',
        title: '记录',
        body: '正文',
        type: '花园',
        snapshot: own.snapshot(),
        time: now,
      ),
    );
    final ownJson = jsonEncode(own.toJson());
    final json = data.toJson()..['version'] = 2;
    final storage = MemoryStorage()..value = jsonEncode(json);
    final store = await AppStore.load(storage);
    expect(store.data.gardens.map((g) => g.id), ['garden-user']);
    expect(store.data.selectedId, 'garden-user');
    expect(jsonEncode(store.data.selected.toJson()), ownJson);
    expect(store.data.nickname, '用户昵称');
    expect(store.data.bio, '用户简介');
    expect(store.data.language, 'en');
    expect(store.data.avatar, 'fixed');
    expect(store.data.requests.single.id, 'own-request');
    expect(store.data.notices.single.id, 'own-notice');
    expect(store.data.posts.last.body, '正文');
    expect(store.data.following, data.following);
    expect(jsonDecode(storage.value!)['version'], 3);
    expect((await AppStore.load(storage)).data.gardens, hasLength(1));
  });

  test('仅有预置植物的旧账号迁移为空状态，重新加载不生成植物', () async {
    final json = legacyData(now).toJson()..['version'] = 2;
    json['bio'] = '养一片绿意，等一个小小的惊喜。';
    final storage = MemoryStorage()..value = jsonEncode(json);
    final store = await AppStore.load(storage);
    expect(store.data.gardens, isEmpty);
    expect(store.data.selectedId, isNull);
    expect(store.data.bio, isEmpty);
    expect((await AppStore.load(storage)).data.gardens, isEmpty);
  });

  test('迁移保存失败立即暴露且保留原始快照', () async {
    final json = legacyData(now).toJson()..['version'] = 2;
    final original = jsonEncode(json);
    final storage = MemoryStorage()
      ..value = original
      ..failWrites = true;
    await expectLater(AppStore.load(storage), throwsStateError);
    expect(storage.value, original);
  });

  test('无效的旧选择和重复编号立即暴露且不覆盖快照', () async {
    for (final duplicate in [false, true]) {
      final json = legacyData(now).toJson()..['version'] = 2;
      if (duplicate) {
        (json['gardens'] as List).add(json['gardens'][0]);
      } else {
        json['selectedId'] = 'missing';
      }
      final original = jsonEncode(json);
      final storage = MemoryStorage()..value = original;
      await expectLater(AppStore.load(storage), throwsFormatException);
      expect(storage.value, original);
    }
  });

  test('移除非当前植物保留选择，移除全部植物后保存空选择并支持恢复', () async {
    final store = await create();
    final first = store.data.selectedId!;
    await store.addPlant('第二株', '第二只');
    final second = store.data.selectedId!;
    await store.archivePlant(first);
    expect(store.data.selectedId, second);
    await store.archivePlant(second);
    expect(store.data.selectedGarden, isNull);
    final restored = await AppStore.load(store.storage);
    expect(restored.data.selectedId, isNull);
    expect(restored.data.gardens, hasLength(2));
    await restored.restorePlant(first);
    expect(restored.data.selected.pet.name, '团团');
    expect(restored.data.selected.deviceId, isNull);
    expect(restored.data.selected.actionStartedAt, isNull);
  });

  test('自主判定在十分钟触发，主要行动间隔与探索冷却分别生效', () async {
    final store = await create();
    await store.advance(now.add(const Duration(minutes: 9)));
    expect(store.data.selected.pet.xp, 0);
    expect(store.data.selected.readings, isEmpty);
    await store.advance(now.add(const Duration(minutes: 10)));
    expect(store.data.selected.action, PlantAction.explore);
    expect(store.data.selected.pet.xp, 4);
    expect(store.data.selected.explorationCount, 1);
    expect(store.data.selected.items, hasLength(1));
    await store.advance(now.add(const Duration(minutes: 20)));
    await store.advance(now.add(const Duration(minutes: 30)));
    expect(store.data.selected.pet.xp, 4);
    await store.advance(now.add(const Duration(minutes: 40)));
    expect(store.data.selected.action, PlantAction.feed);
    expect(store.data.selected.pet.xp, 8);
    expect(store.data.selected.explorationCount, 1);
  });

  test('长期离线恢复只结算当前一次行为，重新加载保留奖励与行动', () async {
    final store = await create();
    await store.advance(now.add(const Duration(days: 3)));
    expect(store.data.selected.pet.xp, 4);
    expect(
      store.data.selected.events.where(
        (e) => e.id != '${store.data.selectedId}-welcome',
      ),
      hasLength(1),
    );
    final action = store.data.selected.action;
    final restored = await AppStore.load(store.storage);
    await restored.advance(now.add(const Duration(days: 3)));
    expect(restored.data.selected.pet.xp, 4);
    expect(restored.data.selected.action, action);
    expect(
      restored.data.selected.events.where(
        (e) => e.id != '${restored.data.selectedId}-welcome',
      ),
      hasLength(1),
    );
  });

  test('夜间入睡仅结算一次经验，白天唤醒后恢复活动', () async {
    final store = await create();
    final night = DateTime(2026, 11, 22, 22);
    await store.advance(night);
    expect(store.data.selected.action, PlantAction.sleep);
    expect(store.data.selected.pet.xp, 4);
    final energy = store.data.selected.pet.energy;
    await store.advance(night.add(const Duration(hours: 1)));
    expect(store.data.selected.pet.energy, closeTo(energy + 8, .001));
    expect(store.data.selected.pet.xp, 4);
    await store.advance(DateTime(2026, 11, 23, 7));
    expect(store.data.selected.action, isNot(PlantAction.sleep));
    expect(store.data.selected.pet.counts['sleep'], 1);
  });

  test('自主行为跨越五级和十级时保存进化，重复加载保持成熟形态', () async {
    for (final xp in [398, 898]) {
      final store = await create(xp: xp);
      await store.advance(now.add(const Duration(minutes: 10)));
      final pet = store.data.selected.pet;
      expect(pet.level, xp == 398 ? 5 : 10);
      expect(pet.formId, xp == 398 ? 'fixed' : matches(r'^mature_[1-7]$'));
      expect(
        store.data.selected.events.where((e) => e.kind == '进化'),
        hasLength(1),
      );
      final form = pet.formId;
      final restored = await AppStore.load(store.storage);
      await restored.advance(now.add(const Duration(minutes: 40)));
      expect(restored.data.selected.pet.formId, form);
      expect(restored.data.selected.pet.history, hasLength(xp == 398 ? 2 : 3));
    }
  });

  test('切换植物不改变独立状态，未绑定设备时没有自主行为奖励', () async {
    final store = await create();
    final first = store.data.selectedId!;
    await store.addPlant('第二株', '第二只');
    final second = store.data.selectedId!;
    final before = jsonEncode(store.garden(first).toJson());
    await store.select(first);
    await store.select(second);
    expect(jsonEncode(store.garden(first).toJson()), before);
    await store.advance(now.add(const Duration(days: 3)));
    expect(store.garden(first).pet.xp, 4);
    expect(store.garden(second).pet.xp, 0);
    expect(store.garden(second).readings, isEmpty);
    expect(store.data.selectedId, second);
    expect((await AppStore.load(store.storage)).data.selectedId, second);
  });
}
