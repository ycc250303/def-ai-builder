import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:plant/data/app_store.dart';
import 'package:plant/data/mock_data.dart';
import 'package:plant/data/models.dart';
import 'package:plant/domain/behavior.dart';

import 'test_storage.dart';
import 'legacy_data.dart';

void main() {
  final now = DateTime(2026, 11, 22, 10);
  Future<AppStore> create() => seededStore(MemoryStorage(), now: now);
  test('六种访问权限按关注方向分别判断', () async {
    final store = await create();
    for (final mode in VisitMode.values) {
      await store.setVisitMode('g1', mode);
      final g = store.garden('g1').snapshot();
      expect(
        store.canVisit('me', g, visitorId: 'moss_sun'),
        mode != VisitMode.closed && mode != VisitMode.request,
      );
      expect(
        store.canVisit('me', g, visitorId: 'moon_leaf'),
        [VisitMode.public, VisitMode.following].contains(mode),
      );
      expect(
        store.canVisit('me', g, visitorId: 'tomato_day'),
        [VisitMode.public, VisitMode.followers].contains(mode),
      );
      expect(
        store.canVisit('me', g, visitorId: 'moss_post'),
        mode == VisitMode.public,
      );
      expect(store.canVisit('me', g), isTrue);
    }
  });
  test('申请去重、审批、拒绝后重新申请及重新加载均保持访问规则', () async {
    final storage = MemoryStorage(),
        store = await seededStore(storage, now: now);
    await store.setVisitMode('g1', VisitMode.request);
    await store.simulateIncomingRequest('g1');
    await store.simulateIncomingRequest('g1');
    expect(store.data.requests, hasLength(1));
    final id = store.data.requests.single.id;
    expect(
      store.canVisit(
        'me',
        store.garden('g1').snapshot(),
        visitorId: 'moss_sun',
      ),
      isFalse,
    );
    await store.decideVisit(id, false);
    await store.simulateIncomingRequest('g1');
    expect(store.data.requests.single.status, RequestStatus.pending);
    await store.decideVisit(id, true);
    final restored = await AppStore.load(storage, now: now);
    expect(
      restored.canVisit(
        'me',
        restored.garden('g1').snapshot(),
        visitorId: 'moss_sun',
      ),
      isTrue,
    );
    expect(
      restored.canVisit(
        'me',
        restored.garden('g1').snapshot(),
        visitorId: 'moon_leaf',
      ),
      isFalse,
    );
    await restored.setVisitMode('g1', VisitMode.closed);
    expect(
      restored.canVisit(
        'me',
        restored.garden('g1').snapshot(),
        visitorId: 'moss_sun',
      ),
      isFalse,
    );
  });
  test('发出的申请只在明确模拟对方批准后允许参观', () async {
    final store = await create(), owner = 'moss_post';
    final g = store.data.user(owner).gardens.single;
    await store.requestVisit(owner, g.id);
    expect(store.canVisit(owner, g), isFalse);
    await store.decideVisit(
      store.data.requests.single.id,
      true,
      simulateOwner: true,
    );
    expect(store.canVisit(owner, g), isTrue);
    expect(store.data.notices.first.kind, 'approved');
  });
  test('无法替其他用户审批且错误不发布状态', () async {
    final store = await create();
    await store.requestVisit('moss_post', 'moss_post-garden');
    await expectLater(
      store.decideVisit(store.data.requests.single.id, true),
      throwsStateError,
    );
    expect(store.data.requests.single.status, RequestStatus.pending);
  });
  test('移除并重新绑定植物保留宠物、等级、进化与成长记录', () async {
    final store = await create(),
        pet = jsonEncode((await create()).garden('g2').pet.toJson());
    final events = jsonEncode(
      store.garden('g2').events.map((e) => e.toJson()).toList(),
    );
    await store.archivePlant('g2');
    expect(store.data.activeGardens, hasLength(1));
    expect(store.garden('g2').archived, isTrue);
    expect(store.garden('g2').deviceId, isNull);
    await store.restorePlant('g2');
    expect(jsonEncode(store.garden('g2').pet.toJson()), pet);
    expect(
      jsonEncode(store.garden('g2').events.map((e) => e.toJson()).toList()),
      events,
    );
  });
  test('场景移动替换收起与恢复保存到对应植物且快照独立', () async {
    final storage = MemoryStorage(),
        store = await seededStore(storage, now: now);
    final item = SceneItem(
      id: 'decor',
      asset: 'decorations/exploration_mushroom.png',
      x: 200,
      y: 300,
      visible: false,
    );
    await store.saveLayout('g1', [item]);
    item.x = 20;
    final reloaded = await AppStore.load(storage, now: now);
    expect(reloaded.garden('g1').items.single.x, 200);
    expect(reloaded.garden('g1').items.single.visible, isFalse);
    expect(reloaded.garden('g2').items, isEmpty);
    final snapshot = reloaded.garden('g1').snapshot();
    snapshot.items.single.x = 50;
    expect(reloaded.garden('g1').items.single.x, 200);
  });
  test('越出固定区域的装饰位置直接失败', () async {
    final store = await create();
    await expectLater(
      store.saveLayout('g1', [
        SceneItem(
          id: 'outside',
          asset: 'decorations/exploration_mushroom.png',
          x: 674,
        ),
      ]),
      throwsArgumentError,
    );
    expect(store.garden('g1').items, isEmpty);
  });
  test('等级4至5固定进化，9至10随机一次，成熟后升级不改变形象', () {
    final g = newGarden('test', '植物', '宠物', now);
    g.pet.xp = 398;
    BehaviorRules.apply(
      g,
      const BehaviorScore(PlantAction.feed, 80),
      now,
      Random(3),
    );
    expect(g.pet.level, 5);
    expect(g.pet.formId, 'fixed');
    expect(g.pet.history.map((e) => e.level), [1, 5]);
    g.pet.xp = 898;
    BehaviorRules.apply(
      g,
      const BehaviorScore(PlantAction.feed, 80),
      now.add(const Duration(hours: 1)),
      Random(4),
    );
    expect(g.pet.level, 10);
    expect(g.pet.formId, startsWith('mature_'));
    expect(g.pet.history, hasLength(3));
    final form = g.pet.formId;
    final restored = Garden.fromJson(g.toJson());
    expect(restored.pet.formId, form);
    restored.pet.xp = 998;
    BehaviorRules.apply(
      restored,
      const BehaviorScore(PlantAction.feed, 80),
      now.add(const Duration(hours: 2)),
      Random(6),
    );
    expect(restored.pet.level, 11);
    expect(restored.pet.formId, form);
    expect(restored.pet.history, hasLength(3));
    expect(restored.events.where((e) => e.kind == '升级'), hasLength(3));
  });
  test('普通升级保留形态且记录等级事件', () {
    final g = newGarden('test', '植物', '宠物', now);
    g.pet.xp = 98;
    BehaviorRules.apply(
      g,
      const BehaviorScore(PlantAction.feed, 80),
      now,
      Random(1),
    );
    expect(g.pet.level, 2);
    expect(g.pet.formId, 'eggie');
    expect(g.pet.history, hasLength(1));
    expect(g.events.first.kind, '升级');
  });
  test('纯文字发布、帖子编辑删除及评论回复删除均保存且不改变宠物', () async {
    final storage = MemoryStorage(),
        store = await seededStore(storage, now: now);
    final pet = jsonEncode(store.garden('g1').pet.toJson());
    await store.publish('g1', '文字', '', '纯文字动态', withImage: false);
    final id = store.data.posts.first.id;
    expect(store.data.posts.first.snapshot, isNull);
    await store.editPost(id, '标题', '修改正文');
    await store.comment(id, '留言');
    final commentId = store.data.posts.first.comments.single.id;
    await store.comment(id, '回复', replyTo: commentId);
    expect(store.data.posts.first.comments.last.replyTo, commentId);
    await store.deleteComment(id, commentId);
    final restored = await AppStore.load(storage, now: now);
    expect(restored.data.posts.first.title, '标题');
    expect(restored.data.posts.first.comments.single.text, '回复');
    expect(jsonEncode(restored.garden('g1').pet.toJson()), pet);
    await restored.deletePost(id);
    expect(restored.data.posts.any((p) => p.id == id), isFalse);
  });
  test('其他用户的帖子与评论不允许删除', () async {
    final store = await create();
    await expectLater(store.deletePost('post-0'), throwsStateError);
    expect(store.data.posts.any((p) => p.id == 'post-0'), isTrue);
    final second = await create();
    await expectLater(
      second.deleteComment('post-0', 'comment-0'),
      throwsStateError,
    );
    expect(second.data.posts.first.comments, hasLength(1));
  });
  test('修改场景不重置养育数值的时间基准', () async {
    final store = await create();
    final before = store.garden('g1').updatedAt;
    await store.saveLayout('g1', [
      SceneItem(id: 'one', asset: 'decorations/exploration_mushroom.png'),
    ]);
    expect(store.garden('g1').updatedAt, before);
  });
  test('移除植物后终止尚未处理的参观申请', () async {
    final store = await create();
    await store.setVisitMode('g1', VisitMode.request);
    await store.simulateIncomingRequest('g1');
    await store.archivePlant('g1');
    expect(store.data.requests.single.status, RequestStatus.rejected);
  });
  test('语言和头像保存后恢复', () async {
    final storage = MemoryStorage(),
        store = await seededStore(storage, now: now);
    await store.language('en');
    await store.profile('名字', '简介', avatar: 'fixed');
    final d = (await AppStore.load(storage, now: now)).data;
    expect(d.language, 'en');
    expect(d.avatar, 'fixed');
    expect(d.nickname, '名字');
  });
  test('已知旧版本数据显式迁移，保留昵称与经验并持久化新版本', () async {
    final j = legacyData(now).toJson();
    j['gardens'][1]['id'] = 'garden-user';
    j['selectedId'] = 'garden-user';
    j['version'] = 1;
    for (final key in [
      'language',
      'avatar',
      'followers',
      'requests',
      'notices',
    ]) {
      j.remove(key);
    }
    void snapshot(Map<String, dynamic> g) {
      g['open'] = g.remove('visitMode') == 'public';
      g.remove('formId');
      g.remove('items');
    }

    for (final g in j['gardens'] as List) {
      g['open'] = g.remove('visitMode') == 'public';
      g.remove('archived');
      g.remove('items');
      g['resources'] = 0;
      g['pet'].remove('history');
      for (final e in g['events'] as List) {
        for (final k in ['titleEn', 'bodyEn', 'reasonEn', 'changesEn']) {
          e.remove(k);
        }
      }
    }
    for (final u in j['users'] as List) {
      u.remove('avatar');
      for (final g in u['gardens'] as List) {
        snapshot(g as Map<String, dynamic>);
      }
    }
    for (final p in j['posts'] as List) {
      snapshot(p['snapshot'] as Map<String, dynamic>);
      p['comments'] = ['旧评论'];
    }
    final storage = MemoryStorage()..value = jsonEncode(j);
    final store = await AppStore.load(storage, now: now);
    expect(store.garden('garden-user').pet.xp, 412);
    expect(store.garden('garden-user').pet.formId, 'fixed');
    expect(store.data.posts.first.comments.single.text, '旧评论');
    expect(jsonDecode(storage.value!)['version'], 3);
  });
  test('未知版本不会覆盖本机数据', () async {
    final storage = MemoryStorage()..value = '{"version":99}';
    await expectLater(AppStore.load(storage, now: now), throwsFormatException);
    expect(storage.value, '{"version":99}');
  });
}
