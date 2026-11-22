import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:plant/data/app_store.dart';

import 'test_storage.dart';

void main() {
  final now = DateTime(2026, 11, 22, 10);
  test('保存后重新加载恢复多植物、独立权限、宠物昵称和社区操作', () async {
    final storage = MemoryStorage(),
        store = await AppStore.load(storage, now: now);
    await store.privacy('g1', true);
    await store.renamePet('g1', '小汤圆');
    await store.select('g2');
    await store.follow('moss_post');
    await store.publish('g2', '花园', '新的一天', '保存今天的花园');
    final postId = store.data.posts.first.id;
    await store.like(postId);
    await store.savePost(postId);
    await store.comment(postId, '真可爱');
    final restored = await AppStore.load(storage, now: now);
    expect(restored.data.selectedId, 'g2');
    expect(restored.garden('g1').pet.name, '小汤圆');
    expect(restored.garden('g1').open, isTrue);
    expect(restored.garden('g2').open, isFalse);
    expect(restored.data.following, contains('moss_post'));
    final post = restored.data.posts.first;
    expect(post.title, '新的一天');
    expect(post.liked, isTrue);
    expect(post.saved, isTrue);
    expect(post.comments.single.text, contains('真可爱'));
    expect(post.snapshot!.petName, '啵啵');
  });
  test('添加植物同时建立唯一宠物及独立花园，不修改现有植物', () async {
    final store = await AppStore.load(MemoryStorage(), now: now);
    final original = jsonEncode(store.garden('g1').toJson());
    await store.addPlant('阳台绿萝', '布布');
    expect(store.data.gardens, hasLength(3));
    expect(store.data.selected.name, '阳台绿萝');
    expect(store.data.selected.pet.name, '布布');
    expect(store.data.selected.open, isFalse);
    expect(store.data.selected.deviceId, isNull);
    expect(jsonEncode(store.garden('g1').toJson()), original);
  });
  test('连续并发保存按顺序执行，不丢失其他操作', () async {
    final store = await AppStore.load(MemoryStorage(), now: now);
    await Future.wait([
      store.renamePet('g1', '团团'),
      store.privacy('g2', true),
      store.follow('moss_post'),
      store.select('g2'),
    ]);
    expect(store.garden('g1').pet.name, '团团');
    expect(store.garden('g2').open, isTrue);
    expect(store.data.selectedId, 'g2');
    expect(store.data.following, contains('moss_post'));
  });
  test('保存失败立即暴露错误且不发布未保存状态', () async {
    final storage = MemoryStorage(),
        store = await AppStore.load(storage, now: now);
    storage.failWrites = true;
    await expectLater(store.renamePet('g1', '未保存昵称'), throwsStateError);
    expect(store.garden('g1').pet.name, '团子');
  });
  test('损坏的本机数据不会被预设数据覆盖', () async {
    final storage = MemoryStorage()..value = 'invalid';
    await expectLater(AppStore.load(storage, now: now), throwsFormatException);
    expect(storage.value, 'invalid');
  });
  test('社交操作不改变养育数值，发布不打开花园，公开画面不泄漏私有信息', () async {
    final store = await AppStore.load(MemoryStorage(), now: now);
    final pet = jsonEncode(store.garden('g1').pet.toJson());
    await store.follow('moss_post');
    await store.like('post-0');
    await store.comment('post-0', '喜欢');
    await store.publish('g1', '宠物', '团子的一天', '阳光和树叶');
    expect(jsonEncode(store.garden('g1').pet.toJson()), pet);
    expect(store.garden('g1').open, isFalse);
    final snapshot = store.data.posts.first.snapshot!.toJson();
    for (final key in [
      'deviceId',
      'readings',
      'satiety',
      'energy',
      'mood',
      'cleanliness',
      'xp',
    ]) {
      expect(snapshot.containsKey(key), isFalse);
    }
  });
  test('解除设备后保留历史和宠物，并停止同步', () async {
    final store = await AppStore.load(MemoryStorage(), now: now);
    final history = store.garden('g1').readings.length;
    await store.setDevice('g1', false);
    expect(store.garden('g1').readings, hasLength(history));
    expect(store.garden('g1').pet.name, '团子');
    await expectLater(store.sync('g1'), throwsStateError);
  });
}
