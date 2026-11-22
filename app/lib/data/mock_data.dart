import 'dart:math' as math;

import 'models.dart';

/// 模拟历史用于页面演示，保留真实时间戳和四项环境数据。
List<SensorReading> mockReadings(DateTime now, int variant) =>
    List.generate(169, (i) {
      final t = now.subtract(Duration(hours: 168 - i));
      final wave = math.sin(t.hour * math.pi / 12);
      return SensorReading(
        t,
        t.hour >= 7 && t.hour < 20
            ? math.max(12, 780 + wave * 620 + variant * 40)
            : 12,
        48 + math.sin(i / 5) * 8 + variant,
        24 + wave * 2,
        62 + math.cos(i / 7) * 9,
      );
    });

Garden newGarden(
  String id,
  String name,
  String petName,
  DateTime now,
  int variant,
) => Garden(
  id: id,
  name: name,
  pet: Pet(name: petName, xp: 0, history: [EvolutionRecord('eggie', 1, now)]),
  createdAt: now,
  updatedAt: now,
  lastDecision: now,
  readings: mockReadings(now, variant),
  events: [
    DiaryEvent(
      id: '$id-welcome',
      time: now,
      kind: '行为',
      title: '初次见面',
      body: '$name和$petName的故事开始了。',
      reason: '建立植物与宠物的一对一关系。',
      titleEn: 'First hello',
      bodyEn: '$name and $petName begin their story.',
      reasonEn: 'One plant, one companion.',
      changesEn: 'Initial form · XP 0',
      changes: '初始形态 · 成长经验 0',
    ),
  ],
);

AppData mockData(DateTime now) {
  final first = newGarden('g1', '窗边绿萝', '团子', now, 0);
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
  final second = newGarden('g2', '书桌绿萝', '啵啵', now, 1);
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
  final names = ['小绿的日常', '月亮种植员', '苔藓邮差', '一颗小番茄'];
  final ids = ['moss_sun', 'moon_leaf', 'moss_post', 'tomato_day'];
  final users = List.generate(
    4,
    (i) => CommunityUser(
      id: ids[i],
      name: names[i],
      bio: [
        '把寻常的日子，种成小小的花园。',
        '月亮升起的时候，植物也在做梦。',
        '收集每一片叶子带回来的故事。',
        '和小宠物一起，慢慢长大。',
      ][i],
      color: [0xffcdeeb6, 0xffece7fb, 0xffb5e4ea, 0xfff5b5cb][i],
      gardens: [
        PublicGarden(
          id: '${ids[i]}-garden',
          name: '${names[i]}的绿萝',
          plant: '绿萝',
          petName: ['糯米', '月饼', '小苔', '布丁'][i],
          form: i % 2 == 0 ? '成长形态' : '初始形态',
          trait: i % 3,
          stage: i % 2 == 0 ? 2 : 0,
          formId: i % 2 == 0 ? 'mature_${i + 1}' : 'eggie',
          decorations: ['daisy', 'mushroom', if (i.isEven) 'lamp'],
          visitMode: [
            VisitMode.public,
            VisitMode.closed,
            VisitMode.request,
            VisitMode.mutual,
          ][i],
          savedAt: now.subtract(Duration(minutes: 12 + i * 7)),
        ),
      ],
    ),
  );
  final titles = [
    '今天的花园，长出了一点小惊喜',
    '睡着的时候也像一颗软软的云',
    '第一次探索，带回了一朵小雏菊',
    '它悄悄长出了新的小叶子',
    '绿萝准备的下午茶',
    '留一盏灯，等植物回家',
  ];
  final posts = List.generate(
    6,
    (i) => Post(
      id: 'post-$i',
      userId: users[i % 4].id,
      title: titles[i],
      body: '${titles[i]}。\n每天看看它们，就觉得日子慢了下来。记录植物与宠物一起成长的瞬间。',
      type: ['花园', '宠物', '探索', '进化', '宠物', '花园'][i],
      snapshot: users[i % 4].gardens.first,
      time: now.subtract(Duration(hours: i + 1)),
      likes: 23 + i * 13,
      comments: [
        PostComment(
          id: 'comment-$i',
          userId: users[(i + 1) % 4].id,
          text: '这份小小的陪伴真好。',
          time: now,
        ),
      ],
    ),
  );
  return AppData(
    gardens: [first, second],
    selectedId: first.id,
    users: users,
    posts: posts,
    following: {'moss_sun', 'moon_leaf'},
    followers: {'moss_sun', 'tomato_day'},
    notices: [
      SocialNotice(
        id: 'notice-like',
        actorId: 'moss_sun',
        kind: 'like',
        time: now,
      ),
      SocialNotice(
        id: 'notice-follow',
        actorId: 'tomato_day',
        kind: 'follow',
        time: now,
      ),
    ],
  );
}
