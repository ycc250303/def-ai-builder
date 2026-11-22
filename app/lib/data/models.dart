import 'dart:convert';

enum PlantAction {
  feed('喂食'),
  clean('清洁'),
  play('玩耍'),
  explore('探索'),
  sleep('睡觉');

  const PlantAction(this.label);
  final String label;
}

enum VisitMode { public, request, closed, following, mutual, followers }

enum RequestStatus { pending, approved, rejected }

class EvolutionRecord {
  EvolutionRecord(this.formId, this.level, this.time);
  final String formId;
  final int level;
  final DateTime time;
  Map<String, dynamic> toJson() => {
    'formId': formId,
    'level': level,
    'time': time.toIso8601String(),
  };
  factory EvolutionRecord.fromJson(Map<String, dynamic> j) => EvolutionRecord(
    j['formId'] as String,
    j['level'] as int,
    DateTime.parse(j['time'] as String),
  );
}

class Pet {
  Pet({
    required this.name,
    this.satiety = 45,
    this.cleanliness = 65,
    this.mood = 50,
    this.energy = 73,
    this.xp = 12,
    this.trait = 0,
    this.counts = const {},
    this.history = const [],
  });
  String name;
  double satiety, cleanliness, mood, energy;
  int xp, trait;
  Map<String, int> counts;
  List<EvolutionRecord> history;
  int get level => 1 + xp ~/ 100;
  int get stage => level >= 10
      ? 2
      : level >= 5
      ? 1
      : 0;
  String get form => ['初始形态', '成长形态', '成熟形态'][stage];
  String get formId => history.isEmpty ? 'eggie' : history.last.formId;
  int get nextXp => (xp ~/ 100 + 1) * 100;
  Map<String, dynamic> toJson() => {
    'name': name,
    'satiety': satiety,
    'cleanliness': cleanliness,
    'mood': mood,
    'energy': energy,
    'xp': xp,
    'trait': trait,
    'counts': counts,
    'history': history.map((e) => e.toJson()).toList(),
  };
  factory Pet.fromJson(Map<String, dynamic> j) => Pet(
    name: j['name'] as String,
    satiety: (j['satiety'] as num).toDouble(),
    cleanliness: (j['cleanliness'] as num).toDouble(),
    mood: (j['mood'] as num).toDouble(),
    energy: (j['energy'] as num).toDouble(),
    xp: j['xp'] as int,
    trait: j['trait'] as int,
    counts: (j['counts'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, v as int),
    ),
    history: (j['history'] as List)
        .map((e) => EvolutionRecord.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class SensorReading {
  SensorReading(
    this.time,
    this.light,
    this.soil,
    this.temperature,
    this.humidity,
  );
  final DateTime time;
  final double light, soil, temperature, humidity;
  List<double> get values => [light, soil, temperature, humidity];
  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'values': values,
  };
  factory SensorReading.fromJson(Map<String, dynamic> j) {
    final v = (j['values'] as List).cast<num>();
    return SensorReading(
      DateTime.parse(j['time'] as String),
      v[0].toDouble(),
      v[1].toDouble(),
      v[2].toDouble(),
      v[3].toDouble(),
    );
  }
}

class DiaryEvent {
  DiaryEvent({
    required this.id,
    required this.time,
    required this.kind,
    required this.title,
    required this.body,
    required this.reason,
    required this.changes,
    this.titleEn = '',
    this.bodyEn = '',
    this.reasonEn = '',
    this.changesEn = '',
  });
  final String id,
      kind,
      title,
      body,
      reason,
      changes,
      titleEn,
      bodyEn,
      reasonEn,
      changesEn;
  final DateTime time;
  Map<String, dynamic> toJson() => {
    'id': id,
    'time': time.toIso8601String(),
    'kind': kind,
    'title': title,
    'body': body,
    'reason': reason,
    'changes': changes,
    'titleEn': titleEn,
    'bodyEn': bodyEn,
    'reasonEn': reasonEn,
    'changesEn': changesEn,
  };
  factory DiaryEvent.fromJson(Map<String, dynamic> j) => DiaryEvent(
    id: j['id'] as String,
    time: DateTime.parse(j['time'] as String),
    kind: j['kind'] as String,
    title: j['title'] as String,
    body: j['body'] as String,
    reason: j['reason'] as String,
    changes: j['changes'] as String,
    titleEn: j['titleEn'] as String,
    bodyEn: j['bodyEn'] as String,
    reasonEn: j['reasonEn'] as String,
    changesEn: j['changesEn'] as String,
  );
}

class SceneItem {
  SceneItem({
    required this.id,
    required this.asset,
    this.x = 480,
    this.y = 700,
    this.width = 64,
    this.height = 70,
    this.visible = true,
  });
  final String id;
  String asset;
  double x, y, width, height;
  bool visible;
  Map<String, dynamic> toJson() => {
    'id': id,
    'asset': asset,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'visible': visible,
  };
  factory SceneItem.fromJson(Map<String, dynamic> j) => SceneItem(
    id: j['id'] as String,
    asset: j['asset'] as String,
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    width: (j['width'] as num).toDouble(),
    height: (j['height'] as num).toDouble(),
    visible: j['visible'] as bool,
  );
}

class Garden {
  Garden({
    required this.id,
    required this.name,
    required this.pet,
    required this.createdAt,
    required this.updatedAt,
    required this.lastDecision,
    required this.readings,
    required this.events,
    VisitMode visitMode = VisitMode.closed,
    bool? open,
    this.deviceId,
    this.action,
    this.actionStartedAt,
    this.actionEndsAt,
    this.lastExplore,
    this.cooldowns = const {},
    this.decorations = const ['daisy', 'mushroom'],
    this.items = const [],
    this.explorationCount = 0,
    this.archived = false,
    DateTime? sceneSavedAt,
  }) : sceneSavedAt = sceneSavedAt ?? updatedAt,
       visitMode = open == null
           ? visitMode
           : (open ? VisitMode.public : VisitMode.closed);
  final String id;
  String name;
  final Pet pet;
  final DateTime createdAt;
  DateTime updatedAt, lastDecision, sceneSavedAt;
  DateTime? actionStartedAt, actionEndsAt, lastExplore;
  VisitMode visitMode;
  bool archived;
  String? deviceId;
  PlantAction? action;
  Map<String, DateTime> cooldowns;
  List<String> decorations;
  List<SceneItem> items;
  int explorationCount;
  bool get open => visitMode == VisitMode.public;
  set open(bool v) => visitMode = v ? VisitMode.public : VisitMode.closed;
  final List<SensorReading> readings;
  final List<DiaryEvent> events;
  String get species => '绿萝';
  SensorReading get latestReading => readings.last;
  String get latestEvent => events.isEmpty ? '新的相伴，从今天开始。' : events.first.body;
  PublicGarden snapshot() => PublicGarden(
    id: id,
    name: name,
    plant: species,
    petName: pet.name,
    form: pet.form,
    trait: pet.trait,
    stage: pet.stage,
    decorations: List.of(decorations),
    visitMode: visitMode,
    savedAt: sceneSavedAt.isAfter(updatedAt) ? sceneSavedAt : updatedAt,
    formId: pet.formId,
    items: items.map((x) => SceneItem.fromJson(x.toJson())).toList(),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'pet': pet.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'lastDecision': lastDecision.toIso8601String(),
    'sceneSavedAt': sceneSavedAt.toIso8601String(),
    'visitMode': visitMode.name,
    'archived': archived,
    'deviceId': deviceId,
    'action': action?.name,
    'actionStartedAt': actionStartedAt?.toIso8601String(),
    'actionEndsAt': actionEndsAt?.toIso8601String(),
    'lastExplore': lastExplore?.toIso8601String(),
    'cooldowns': cooldowns.map((k, v) => MapEntry(k, v.toIso8601String())),
    'decorations': decorations,
    'items': items.map((x) => x.toJson()).toList(),
    'explorationCount': explorationCount,
    'readings': readings.map((x) => x.toJson()).toList(),
    'events': events.map((x) => x.toJson()).toList(),
  };
  factory Garden.fromJson(Map<String, dynamic> j) => Garden(
    id: j['id'] as String,
    name: j['name'] as String,
    pet: Pet.fromJson(j['pet'] as Map<String, dynamic>),
    createdAt: DateTime.parse(j['createdAt'] as String),
    updatedAt: DateTime.parse(j['updatedAt'] as String),
    lastDecision: DateTime.parse(j['lastDecision'] as String),
    sceneSavedAt: DateTime.parse(j['sceneSavedAt'] as String),
    visitMode: VisitMode.values.byName(j['visitMode'] as String),
    archived: j['archived'] as bool,
    deviceId: j['deviceId'] as String?,
    action: j['action'] == null
        ? null
        : PlantAction.values.byName(j['action'] as String),
    actionStartedAt: j['actionStartedAt'] == null
        ? null
        : DateTime.parse(j['actionStartedAt'] as String),
    actionEndsAt: j['actionEndsAt'] == null
        ? null
        : DateTime.parse(j['actionEndsAt'] as String),
    lastExplore: j['lastExplore'] == null
        ? null
        : DateTime.parse(j['lastExplore'] as String),
    cooldowns: (j['cooldowns'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, DateTime.parse(v as String)),
    ),
    decorations: (j['decorations'] as List).cast<String>(),
    items: (j['items'] as List)
        .map((x) => SceneItem.fromJson(x as Map<String, dynamic>))
        .toList(),
    explorationCount: j['explorationCount'] as int,
    readings: (j['readings'] as List)
        .map((x) => SensorReading.fromJson(x as Map<String, dynamic>))
        .toList(),
    events: (j['events'] as List)
        .map((x) => DiaryEvent.fromJson(x as Map<String, dynamic>))
        .toList(),
  );
}

/// 公开画面包含角色与布局；设备、传感器和四项养育属性仅在本人页面显示。
class PublicGarden {
  const PublicGarden({
    required this.id,
    required this.name,
    required this.plant,
    required this.petName,
    required this.form,
    required this.trait,
    required this.stage,
    required this.decorations,
    required this.savedAt,
    bool? open,
    VisitMode visitMode = VisitMode.closed,
    this.formId = 'eggie',
    this.items = const [],
  }) : visitMode = open == null
           ? visitMode
           : (open ? VisitMode.public : VisitMode.closed);
  final String id, name, plant, petName, form, formId;
  final int trait, stage;
  final List<String> decorations;
  final DateTime savedAt;
  final VisitMode visitMode;
  final List<SceneItem> items;
  bool get open => visitMode == VisitMode.public;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'plant': plant,
    'petName': petName,
    'form': form,
    'trait': trait,
    'stage': stage,
    'decorations': decorations,
    'savedAt': savedAt.toIso8601String(),
    'visitMode': visitMode.name,
    'formId': formId,
    'items': items.map((x) => x.toJson()).toList(),
  };
  factory PublicGarden.fromJson(Map<String, dynamic> j) => PublicGarden(
    id: j['id'] as String,
    name: j['name'] as String,
    plant: j['plant'] as String,
    petName: j['petName'] as String,
    form: j['form'] as String,
    trait: j['trait'] as int,
    stage: j['stage'] as int,
    decorations: (j['decorations'] as List).cast<String>(),
    savedAt: DateTime.parse(j['savedAt'] as String),
    visitMode: VisitMode.values.byName(j['visitMode'] as String),
    formId: j['formId'] as String,
    items: (j['items'] as List)
        .map((x) => SceneItem.fromJson(x as Map<String, dynamic>))
        .toList(),
  );
}

class CommunityUser {
  const CommunityUser({
    required this.id,
    required this.name,
    required this.bio,
    required this.gardens,
    required this.color,
    this.avatar = 'eggie',
  });
  final String id, name, bio, avatar;
  final int color;
  final List<PublicGarden> gardens;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'bio': bio,
    'color': color,
    'avatar': avatar,
    'gardens': gardens.map((x) => x.toJson()).toList(),
  };
  factory CommunityUser.fromJson(Map<String, dynamic> j) => CommunityUser(
    id: j['id'] as String,
    name: j['name'] as String,
    bio: j['bio'] as String,
    color: j['color'] as int,
    avatar: j['avatar'] as String,
    gardens: (j['gardens'] as List)
        .map((x) => PublicGarden.fromJson(x as Map<String, dynamic>))
        .toList(),
  );
}

class PostComment {
  PostComment({
    required this.id,
    required this.userId,
    required this.text,
    required this.time,
    this.replyTo,
  });
  final String id, userId;
  String text;
  final DateTime time;
  final String? replyTo;
  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'text': text,
    'time': time.toIso8601String(),
    'replyTo': replyTo,
  };
  factory PostComment.fromJson(Map<String, dynamic> j) => PostComment(
    id: j['id'] as String,
    userId: j['userId'] as String,
    text: j['text'] as String,
    time: DateTime.parse(j['time'] as String),
    replyTo: j['replyTo'] as String?,
  );
}

class Post {
  Post({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.snapshot,
    required this.time,
    this.likes = 0,
    this.liked = false,
    this.saved = false,
    this.comments = const [],
  });
  final String id, userId;
  String title, body, type;
  PublicGarden? snapshot;
  final DateTime time;
  int likes;
  bool liked, saved;
  List<PostComment> comments;
  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'title': title,
    'body': body,
    'type': type,
    'snapshot': snapshot?.toJson(),
    'time': time.toIso8601String(),
    'likes': likes,
    'liked': liked,
    'saved': saved,
    'comments': comments.map((c) => c.toJson()).toList(),
  };
  factory Post.fromJson(Map<String, dynamic> j) => Post(
    id: j['id'] as String,
    userId: j['userId'] as String,
    title: j['title'] as String,
    body: j['body'] as String,
    type: j['type'] as String,
    snapshot: j['snapshot'] == null
        ? null
        : PublicGarden.fromJson(j['snapshot'] as Map<String, dynamic>),
    time: DateTime.parse(j['time'] as String),
    likes: j['likes'] as int,
    liked: j['liked'] as bool,
    saved: j['saved'] as bool,
    comments: (j['comments'] as List)
        .map((x) => PostComment.fromJson(x as Map<String, dynamic>))
        .toList(),
  );
}

class VisitRequest {
  VisitRequest({
    required this.id,
    required this.gardenId,
    required this.ownerId,
    required this.visitorId,
    required this.time,
    this.status = RequestStatus.pending,
  });
  final String id, gardenId, ownerId, visitorId;
  final DateTime time;
  RequestStatus status;
  Map<String, dynamic> toJson() => {
    'id': id,
    'gardenId': gardenId,
    'ownerId': ownerId,
    'visitorId': visitorId,
    'time': time.toIso8601String(),
    'status': status.name,
  };
  factory VisitRequest.fromJson(Map<String, dynamic> j) => VisitRequest(
    id: j['id'] as String,
    gardenId: j['gardenId'] as String,
    ownerId: j['ownerId'] as String,
    visitorId: j['visitorId'] as String,
    time: DateTime.parse(j['time'] as String),
    status: RequestStatus.values.byName(j['status'] as String),
  );
}

class SocialNotice {
  SocialNotice({
    required this.id,
    required this.actorId,
    required this.kind,
    required this.time,
    this.targetId,
    this.read = false,
  });
  final String id, actorId, kind;
  final String? targetId;
  final DateTime time;
  bool read;
  Map<String, dynamic> toJson() => {
    'id': id,
    'actorId': actorId,
    'kind': kind,
    'time': time.toIso8601String(),
    'targetId': targetId,
    'read': read,
  };
  factory SocialNotice.fromJson(Map<String, dynamic> j) => SocialNotice(
    id: j['id'] as String,
    actorId: j['actorId'] as String,
    kind: j['kind'] as String,
    time: DateTime.parse(j['time'] as String),
    targetId: j['targetId'] as String?,
    read: j['read'] as bool,
  );
}

class AppData {
  AppData({
    required this.gardens,
    required this.selectedId,
    required this.users,
    required this.posts,
    this.nickname = '小叶同学',
    this.bio = '养一片绿意，等一个小小的惊喜。',
    this.following = const {},
    this.followers = const {},
    this.notifications = true,
    this.language = 'system',
    this.avatar = 'eggie',
    this.requests = const [],
    this.notices = const [],
  });
  final List<Garden> gardens;
  final List<CommunityUser> users;
  final List<Post> posts;
  String selectedId, nickname, bio, language, avatar;
  Set<String> following, followers;
  bool notifications;
  List<VisitRequest> requests;
  List<SocialNotice> notices;
  List<Garden> get activeGardens => gardens.where((g) => !g.archived).toList();
  Garden get selected => gardens.singleWhere((x) => x.id == selectedId);
  CommunityUser user(String id) => id == 'me'
      ? CommunityUser(
          id: 'me',
          name: nickname,
          bio: bio,
          gardens: activeGardens.map((x) => x.snapshot()).toList(),
          color: 0xffcdeeb6,
          avatar: avatar,
        )
      : users.singleWhere((x) => x.id == id);
  Map<String, dynamic> toJson() => {
    'version': 2,
    'gardens': gardens.map((x) => x.toJson()).toList(),
    'selectedId': selectedId,
    'users': users.map((x) => x.toJson()).toList(),
    'posts': posts.map((x) => x.toJson()).toList(),
    'nickname': nickname,
    'bio': bio,
    'following': following.toList(),
    'followers': followers.toList(),
    'notifications': notifications,
    'language': language,
    'avatar': avatar,
    'requests': requests.map((x) => x.toJson()).toList(),
    'notices': notices.map((x) => x.toJson()).toList(),
  };
  factory AppData.fromJson(Map<String, dynamic> source) {
    final j = source['version'] == 1 ? _migrateV1(source) : source;
    if (j['version'] != 2) {
      throw const FormatException('Unsupported local data version');
    }
    final d = AppData(
      gardens: (j['gardens'] as List)
          .map((x) => Garden.fromJson(x as Map<String, dynamic>))
          .toList(),
      selectedId: j['selectedId'] as String,
      users: (j['users'] as List)
          .map((x) => CommunityUser.fromJson(x as Map<String, dynamic>))
          .toList(),
      posts: (j['posts'] as List)
          .map((x) => Post.fromJson(x as Map<String, dynamic>))
          .toList(),
      nickname: j['nickname'] as String,
      bio: j['bio'] as String,
      following: (j['following'] as List).cast<String>().toSet(),
      followers: (j['followers'] as List).cast<String>().toSet(),
      notifications: j['notifications'] as bool,
      language: j['language'] as String,
      avatar: j['avatar'] as String,
      requests: (j['requests'] as List)
          .map((x) => VisitRequest.fromJson(x as Map<String, dynamic>))
          .toList(),
      notices: (j['notices'] as List)
          .map((x) => SocialNotice.fromJson(x as Map<String, dynamic>))
          .toList(),
    );
    d.selected;
    if (d.gardens.map((g) => g.id).toSet().length != d.gardens.length) {
      throw const FormatException('Duplicate garden ID');
    }
    if (!['system', 'zh', 'en'].contains(d.language)) {
      throw const FormatException('Unsupported language');
    }
    return d;
  }
  AppData copy() => AppData.fromJson(
    jsonDecode(jsonEncode(toJson())) as Map<String, dynamic>,
  );
}

/// 仅转换已知版本；保留旧昵称、记录与数值，新增字段使用明确定义的迁移值。
Map<String, dynamic> _migrateV1(Map<String, dynamic> source) {
  final j = jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
  void snapshot(Map<String, dynamic> s) {
    s['visitMode'] = (s.remove('open') as bool) ? 'public' : 'closed';
    s['formId'] = 'eggie';
    s['items'] = [];
  }

  for (final value in j['gardens'] as List) {
    final g = value as Map<String, dynamic>;
    g['visitMode'] = (g.remove('open') as bool) ? 'public' : 'closed';
    g['archived'] = false;
    g['sceneSavedAt'] = g['updatedAt'];
    g['items'] = [];
    g.remove('resources');
    final p = g['pet'] as Map<String, dynamic>;
    final xp = p['xp'] as int;
    p['history'] = [
      {'formId': 'eggie', 'level': 1, 'time': g['createdAt']},
      if (xp >= 400) {'formId': 'fixed', 'level': 5, 'time': g['updatedAt']},
      if (xp >= 900)
        {
          'formId': 'mature_${1 + (p['trait'] as int) % 7}',
          'level': 10,
          'time': g['updatedAt'],
        },
    ];
    for (final e in g['events'] as List) {
      e['titleEn'] = 'Growth record';
      e['bodyEn'] = e['body'];
      e['reasonEn'] = 'Saved record';
      e['changesEn'] = '';
    }
  }
  for (final u in j['users'] as List) {
    u['avatar'] = 'eggie';
    for (final g in u['gardens'] as List) {
      snapshot(g as Map<String, dynamic>);
    }
  }
  for (final p in j['posts'] as List) {
    snapshot(p['snapshot'] as Map<String, dynamic>);
    p['comments'] = [
      for (final (i, c) in (p['comments'] as List).indexed)
        {
          'id': 'legacy-${p['id']}-$i',
          'userId': 'me',
          'text': c,
          'time': p['time'],
          'replyTo': null,
        },
    ];
  }
  j.addAll({
    'version': 2,
    'language': 'system',
    'avatar': 'eggie',
    'followers': <String>[],
    'requests': <dynamic>[],
    'notices': <dynamic>[],
  });
  return j;
}
