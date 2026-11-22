import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:plant/data/mock_data.dart';
import 'package:plant/data/models.dart';
import 'package:plant/domain/behavior.dart';

void main() {
  final now = DateTime(2026, 11, 22, 12);
  Garden garden() => newGarden('test', '绿萝', '团子', now, 0);
  const e = EnvironmentFit(.8, .7, .6, .5, change: .4);
  test('使用新版公式计算白天行为评分', () {
    final g = garden();
    g.pet.satiety = 50;
    g.pet.cleanliness = 50;
    g.pet.mood = 50;
    g.pet.energy = 50;
    final choices = BehaviorRules.candidates(g, e, now);
    final scores = {for (final s in choices) s.action: s.score};
    expect(scores[PlantAction.feed], 75.5);
    expect(scores[PlantAction.clean], 62.5);
    expect(scores[PlantAction.play], 59.5);
    expect(scores[PlantAction.explore], 83.5);
    expect(scores.containsKey(PlantAction.sleep), isFalse);
  });
  test('行动间隔、基本资格、最低评分和独立冷却都约束候选', () {
    final g = garden();
    g.actionStartedAt = now.subtract(const Duration(minutes: 24));
    expect(BehaviorRules.candidates(g, e, now), isEmpty);
    g.actionStartedAt = null;
    g.cooldowns = {'feed': now.subtract(const Duration(minutes: 59))};
    expect(
      BehaviorRules.candidates(g, e, now).map((s) => s.action),
      isNot(contains(PlantAction.feed)),
    );
    g.cooldowns = {};
    g.pet.satiety = 85;
    expect(
      BehaviorRules.candidates(g, e, now).map((s) => s.action),
      isNot(contains(PlantAction.feed)),
    );
    expect(
      BehaviorRules.candidates(g, const EnvironmentFit(0, 0, 0, 0), now),
      isEmpty,
    );
  });
  test('睡眠期间清洁度和饱腹持续下降，精力按小时恢复', () {
    final g = garden();
    g.action = PlantAction.sleep;
    g.actionEndsAt = now.add(const Duration(hours: 2));
    final cleanliness = g.pet.cleanliness,
        energy = g.pet.energy,
        satiety = g.pet.satiety;
    BehaviorRules.decay(g, now.add(const Duration(hours: 1)));
    expect(g.pet.cleanliness, cleanliness - 1);
    expect(g.pet.energy, energy + 8);
    expect(g.pet.satiety, satiety - 2);
    expect(
      BehaviorRules.candidates(g, e, now.add(const Duration(hours: 1))),
      isEmpty,
    );
  });
  test('睡眠结束只恢复睡眠时段的精力，之后按清醒状态消耗', () {
    final g = garden();
    g.action = PlantAction.sleep;
    g.actionEndsAt = now.add(const Duration(minutes: 30));
    final before = g.pet.energy;
    BehaviorRules.decay(g, now.add(const Duration(hours: 1)));
    expect(g.pet.energy, closeTo(before + 4 - .5, .001));
    expect(g.action, isNull);
  });
  test('探索累计在植物历史，宠物留在花园且状态不变', () {
    final g = garden(), p = g.pet;
    final values = [p.satiety, p.energy, p.cleanliness];
    BehaviorRules.apply(
      g,
      const BehaviorScore(PlantAction.explore, 80),
      now,
      Random(2),
    );
    expect([p.satiety, p.energy, p.cleanliness], values);
    expect(p.xp, 4);
    expect(g.explorationCount, 1);
    expect(p.counts.containsKey('explore'), isFalse);
    expect(g.lastExplore, now);
    expect(g.events.first.kind, '探索');
  });
  test('喂食按规则结算并限制属性上限，经验持续累积', () {
    final g = garden();
    g.pet.satiety = 95;
    g.pet.mood = 99;
    g.pet.xp = 898;
    BehaviorRules.apply(
      g,
      const BehaviorScore(PlantAction.feed, 70),
      now,
      Random(2),
    );
    expect(g.pet.satiety, 100);
    expect(g.pet.mood, 100);
    expect(g.pet.xp, 902);
    expect(g.pet.name, '团子');
    expect(g.events.first.kind, '进化');
  });
}
