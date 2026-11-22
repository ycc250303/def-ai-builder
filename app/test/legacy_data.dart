import 'package:plant/data/mock_data.dart';
import 'package:plant/data/models.dart';

AppData legacyData(DateTime now) {
  final first = newGarden('g1', '窗边绿萝', '团子', now);
  first.pet.xp = 58;
  first.deviceId = 'PM-LEAF-001';
  first.action = PlantAction.play;
  first.actionStartedAt = now.subtract(const Duration(minutes: 2));
  first.actionEndsAt = now.add(const Duration(minutes: 3));
  first.cooldowns = {'play': first.actionStartedAt!};
  first.events.insert(
    0,
    DiaryEvent(
      id: 'g1-play',
      time: first.actionStartedAt!,
      kind: '行为',
      title: '追着落叶去玩耍',
      titleEn: 'Chasing leaves',
      bodyEn: 'Tuantuan and 团子 chased leaves around the garden.',
      reasonEn:
          'Simulated temperature and humidity are suitable. Play score: 66.',
      changesEn: 'Mood +12 · Energy −8 · Clean −4 · XP +4',
      body: '绿萝和团子追着落叶，玩了一个下午。',
      reason: '模拟温度与空气湿度适宜，宠物精力充足，玩耍评分 66。',
      changes: '心情 +12 · 精力 −8 · 清洁度 −4 · 经验 +4',
    ),
  );
  first.events.insert(
    1,
    DiaryEvent(
      id: 'g1-explore',
      time: now.subtract(const Duration(hours: 3)),
      kind: '探索',
      title: '把春天带回花园',
      titleEn: 'A little piece of spring',
      bodyEn: 'Tuantuan brought back flowers.',
      reasonEn: 'Suitable environment; exploration cooldown ended.',
      changesEn: 'Flowers +1 · XP +4 · Plant explorations +1',
      body: '绿萝带回了一朵向阳小雏菊。',
      reason: '综合环境适宜，探索冷却结束。',
      changes: '向阳小雏菊 +1 · 经验 +4 · 植物探索次数 +1',
    ),
  );
  final second = newGarden('g2', '书桌绿萝', '啵啵', now);
  second.deviceId = 'PM-LEAF-002';
  second.pet.xp = 412;
  second.pet.history = [
    ...second.pet.history,
    EvolutionRecord('fixed', 5, now.subtract(const Duration(days: 1))),
  ];
  second.pet.energy = 82;
  second.decorations = ['daisy', 'mushroom', 'lamp'];
  second.events.insert(
    0,
    DiaryEvent(
      id: 'g2-evolve',
      time: now.subtract(const Duration(days: 1)),
      kind: '进化',
      title: '长成了新的模样',
      body: '啵啵在5级完成第一次进化。',
      titleEn: 'A new appearance',
      bodyEn: '啵啵 evolved at level 5.',
      reasonEn: 'Reached level 5.',
      changesEn: 'Initial → second form',
      reason: '达到5级，完成固定形态进化。',
      changes: '初始形态 → 成长形态',
    ),
  );
  first.readings.addAll(
    List.generate(
      169,
      (i) => mockReading(now.subtract(Duration(hours: 168 - i)), 0),
    ),
  );
  second.readings.addAll(
    List.generate(
      169,
      (i) => mockReading(now.subtract(Duration(hours: 168 - i)), 1),
    ),
  );
  final community = initialData(now);
  return AppData(
    gardens: [first, second],
    selectedId: first.id,
    users: community.users,
    posts: community.posts,
    following: {'moss_sun', 'moon_leaf'},
    followers: {'moss_sun', 'tomato_day'},
  );
}
