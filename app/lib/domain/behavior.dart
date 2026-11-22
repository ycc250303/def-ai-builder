import 'dart:math' as math;

import '../data/models.dart';

/// 适宜度由数据提供方传入；模拟数据不定义正式的传感器校准阈值。
class EnvironmentFit {
  const EnvironmentFit(
    this.light,
    this.soil,
    this.temperature,
    this.humidity, {
    this.change = 0.3,
    this.darkness = 0,
  });
  final double light, soil, temperature, humidity, change, darkness;
}

class BehaviorScore {
  const BehaviorScore(this.action, this.score);
  final PlantAction action;
  final double score;
}

class BehaviorRules {
  static const cooldownMinutes = {
    PlantAction.feed: 60,
    PlantAction.clean: 90,
    PlantAction.play: 45,
    PlantAction.explore: 120,
  };

  /// 先计算评分与候选资格，再应用间隔和冷却。无候选时返回空列表。
  static List<BehaviorScore> candidates(
    Garden garden,
    EnvironmentFit e,
    DateTime now,
  ) {
    final p = garden.pet;
    if (garden.action == PlantAction.sleep) {
      return [];
    }
    if (garden.actionEndsAt != null && now.isBefore(garden.actionEndsAt!)) {
      return [];
    }
    if (garden.actionStartedAt != null &&
        now.difference(garden.actionStartedAt!).inMinutes < 25) {
      return [];
    }
    final day = now.hour >= 7 && now.hour < 20;
    final d = day ? 1.0 : 0.0, n = day ? 0.0 : 1.0;
    final gap = garden.lastExplore == null
        ? 1.0
        : (now.difference(garden.lastExplore!).inMinutes / 240).clamp(0.0, 1.0);
    final g = (e.light + e.soil + e.temperature + e.humidity) / 4;
    final scores = <PlantAction, double>{
      PlantAction.feed: 20 + 35 * e.light + 35 * (1 - p.satiety / 100) + 10 * d,
      PlantAction.clean:
          15 + 25 * e.soil + 15 * e.humidity + 45 * (1 - p.cleanliness / 100),
      PlantAction.play:
          15 +
          20 * e.temperature +
          20 * e.humidity +
          25 * (1 - p.mood / 100) +
          20 * p.energy / 100,
      PlantAction.explore: 20 + 30 * g + 20 * d + 20 * gap + 10 * e.change,
      PlantAction.sleep:
          10 + 40 * (1 - p.energy / 100) + 35 * n + 15 * e.darkness,
    };
    final allowed = <PlantAction, bool>{
      PlantAction.feed: day && e.light >= .35 && p.satiety < 85,
      PlantAction.clean:
          p.cleanliness <= 80 && math.max(e.soil, e.humidity) >= .35,
      PlantAction.play:
          p.energy >= 25 && math.max(e.temperature, e.humidity) >= .35,
      PlantAction.explore: day && g >= .35,
      PlantAction.sleep:
          (!day && garden.latestReading.light < 50) || p.energy <= 40,
    };
    final result = <BehaviorScore>[];
    for (final action in PlantAction.values) {
      final last = garden.cooldowns[action.name];
      final ready =
          last == null ||
          now.difference(last).inMinutes >= (cooldownMinutes[action] ?? 25);
      if (allowed[action]! && ready && scores[action]! >= 50) {
        result.add(BehaviorScore(action, scores[action]!.clamp(0, 100)));
      }
    }
    result.sort((a, b) => b.score.compareTo(a.score));
    return result;
  }

  static void decay(Garden garden, DateTime now) {
    if (!now.isAfter(garden.updatedAt)) {
      return;
    }
    final hours = now.difference(garden.updatedAt).inSeconds / 3600;
    final p = garden.pet;
    p.satiety = (p.satiety - 2 * hours).clamp(0, 100);
    p.cleanliness = (p.cleanliness - hours).clamp(0, 100);
    if (garden.action == PlantAction.sleep) {
      final until = garden.actionEndsAt!;
      final sleepingHours = math.max(
        0,
        (now.isBefore(until) ? now : until)
                .difference(garden.updatedAt)
                .inSeconds /
            3600,
      );
      p.energy = (p.energy + sleepingHours * 8 - (hours - sleepingHours)).clamp(
        0,
        100,
      );
    } else {
      p.energy = (p.energy - hours).clamp(0, 100);
    }
    garden.updatedAt = now;
    if (garden.actionEndsAt != null && !now.isBefore(garden.actionEndsAt!)) {
      garden.action = null;
    }
  }

  /// 数值由规则执行，探索自动带回装饰。每100经验提升一级，5级与10级记录进化。
  static void apply(
    Garden g,
    BehaviorScore decision,
    DateTime now,
    math.Random random,
  ) {
    final p = g.pet, action = decision.action;
    final beforeLevel = p.level;
    String body, changes;
    switch (action) {
      case PlantAction.feed:
        p.satiety = (p.satiety + 20).clamp(0, 100);
        p.mood = (p.mood + 3).clamp(0, 100);
        body = '绿萝收集光点，给${p.name}准备了${now.hour < 12 ? '汉堡' : '披萨'}。';
        changes = '饱腹 +20 · 心情 +3 · 经验 +4';
      case PlantAction.clean:
        p.cleanliness = (p.cleanliness + 25).clamp(0, 100);
        p.mood = (p.mood + 5).clamp(0, 100);
        body = '绿萝用露珠和泡泡，给${p.name}洗了一个澡。';
        changes = '清洁度 +25 · 心情 +5 · 经验 +4';
      case PlantAction.play:
        p.mood = (p.mood + 12).clamp(0, 100);
        p.energy = (p.energy - 8).clamp(0, 100);
        p.cleanliness = (p.cleanliness - 4).clamp(0, 100);
        body = '绿萝和${p.name}追着落叶玩了起来。';
        changes = '心情 +12 · 精力 −8 · 清洁度 −4 · 经验 +4';
      case PlantAction.explore:
        final item = SceneItem(
          id: 'explore-${g.id}-${now.microsecondsSinceEpoch}',
          asset: 'decorations/exploration_mushroom.png',
          x: 440 + (g.explorationCount % 4) * 42.0,
          y: 700 + (g.explorationCount ~/ 4 % 3) * 60.0,
        );
        g.items = [...g.items, item];
        body = '绿萝独自探索归来，带回了蘑菇装饰。';
        g.lastExplore = now;
        g.explorationCount++;
        changes = '植物探索次数 +1 · 探索奖励 +1 · 经验 +4';
      case PlantAction.sleep:
        p.energy = (p.energy + 18).clamp(0, 100);
        p.mood = (p.mood + 4).clamp(0, 100);
        body = '绿萝陪着${p.name}进入了梦乡。';
        changes = '精力 +18 · 心情 +4 · 经验 +4 · 睡眠恢复 8/小时';
    }
    p.xp += 4;
    if (action != PlantAction.explore) {
      p.counts = {...p.counts, action.name: (p.counts[action.name] ?? 0) + 1};
    }
    g.action = action;
    g.actionStartedAt = now;
    g.actionEndsAt = action == PlantAction.sleep
        ? (now.hour >= 7 && now.hour < 20
              ? now.add(const Duration(minutes: 25))
              : DateTime(
                  now.year,
                  now.month,
                  now.day + (now.hour >= 20 ? 1 : 0),
                  7,
                ))
        : now.add(Duration(minutes: action == PlantAction.explore ? 10 : 5));
    g.cooldowns = {...g.cooldowns, action.name: now};
    g.events.insert(
      0,
      DiaryEvent(
        id: '${g.id}-${now.microsecondsSinceEpoch}',
        time: now,
        kind: action == PlantAction.explore ? '探索' : '行为',
        title: '${action.label}的小故事',
        body: body,
        reason:
            '模拟环境下${action.label}评分 ${decision.score.toStringAsFixed(1)}，满足触发条件及冷却；采用最高合法评分。',
        changes: changes,
      ),
    );
    final actionEn = [
      'Feeding',
      'Cleaning',
      'Playing',
      'Exploring',
      'Sleeping',
    ][action.index];
    final entry = g.events.first;
    g.events[0] = DiaryEvent(
      id: entry.id,
      time: entry.time,
      kind: entry.kind,
      title: entry.title,
      body: entry.body,
      reason: entry.reason,
      changes: entry.changes,
      titleEn: '$actionEn completed',
      bodyEn: '${p.name}: $actionEn completed in the garden.',
      reasonEn:
          'Score ${decision.score.toStringAsFixed(1)}; eligibility and cooldown satisfied.',
      changesEn: [
        'Food +20 · Mood +3 · XP +4',
        'Clean +25 · Mood +5 · XP +4',
        'Mood +12 · Energy −8 · Clean −4 · XP +4',
        'Plant explorations +1 · Decoration +1 · XP +4',
        'Energy +18 · Mood +4 · XP +4',
      ][action.index],
    );
    for (var lv = beforeLevel + 1; lv <= p.level; lv++) {
      g.events.insert(
        0,
        DiaryEvent(
          id: '${g.id}-level-$lv',
          time: now,
          kind: '升级',
          title: '等级提升',
          body: '${p.name}升到了$lv级。',
          reason: '累计成长经验达到${(lv - 1) * 100}。',
          changes: '等级 +1',
          titleEn: 'Level up',
          bodyEn: '${p.name} reached level $lv.',
          reasonEn: 'Total XP reached ${(lv - 1) * 100}.',
          changesEn: 'Level +1',
        ),
      );
    }
    for (final lv in [5, 10]) {
      if (beforeLevel < lv && p.level >= lv) {
        final form = lv == 5 ? 'fixed' : 'mature_${random.nextInt(7) + 1}';
        p.history = [...p.history, EvolutionRecord(form, lv, now)];
        g.events.insert(
          0,
          DiaryEvent(
            id: '${g.id}-evolve-$lv',
            time: now,
            kind: '进化',
            title: '长成新的模样',
            body: '${p.name}在$lv级完成进化。',
            reason: lv == 5 ? '达到5级，进入固定的第二形态。' : '达到10级，随机确定成熟形态。',
            changes: '外形与行为动画更新',
            titleEn: 'A new appearance',
            bodyEn: '${p.name} evolved at level $lv.',
            reasonEn: lv == 5
                ? 'Level 5: fixed second form.'
                : 'Level 10: one of seven mature forms.',
            changesEn: 'Appearance and behavior animations updated',
          ),
        );
      }
    }
  }
}
