import 'dart:math' as math;

import 'models.dart';

/// 在同步或行为判定时生成当前模拟采样。
SensorReading mockReading(DateTime now, int variant) {
  final wave = math.sin(now.hour * math.pi / 12);
  final hour = now.millisecondsSinceEpoch ~/ Duration.millisecondsPerHour;
  return SensorReading(
    now,
    now.hour >= 7 && now.hour < 20
        ? math.max(12, 780 + wave * 620 + variant * 40)
        : 12,
    48 + math.sin(hour / 5) * 8 + variant,
    24 + wave * 2,
    62 + math.cos(hour / 7) * 9,
  );
}

Garden newGarden(String id, String name, String petName, DateTime now) =>
    Garden(
      id: id,
      name: name,
      pet: Pet(
        name: petName,
        xp: 0,
        history: [EvolutionRecord('eggie', 1, now)],
      ),
      createdAt: now,
      updatedAt: now,
      lastDecision: now,
      readings: [],
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

AppData initialData(DateTime now) {
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
  return AppData(gardens: [], selectedId: null, users: users, posts: posts);
}
