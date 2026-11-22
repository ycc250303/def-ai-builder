import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import 'common.dart';
import 'garden_scene.dart';

class SocialPage extends StatefulWidget {
  const SocialPage({super.key});
  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> {
  bool following = false;
  @override
  Widget build(BuildContext context) {
    final d = AppScope.of(context).data;
    final posts = d.posts
        .where((p) => !following || d.following.contains(p.userId))
        .toList();
    return Scaffold(
      backgroundColor: paper,
      floatingActionButton: FloatingActionButton(
        tooltip: context.l.publish,
        backgroundColor: leaf,
        foregroundColor: ink,
        onPressed: () => openPage(context, const PublishPage()),
        child: const Icon(Icons.add),
      ),
      body: CustomScrollView(
        key: const PageStorageKey('social-scroll'),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.l.social,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: context.l.notifications,
                        onPressed: () =>
                            openPage(context, const NotificationsPage()),
                        icon: Badge(
                          isLabelVisible:
                              d.notices.any((n) => !n.read) ||
                              d.requests.any(
                                (r) =>
                                    r.ownerId == 'me' &&
                                    r.status == RequestStatus.pending,
                              ),
                          child: const Icon(Icons.notifications_none),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: muted),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        for (final (value, label) in [
                          (false, context.l.recommended),
                          (true, context.l.following),
                        ])
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: following == value
                                    ? leaf
                                    : null,
                                foregroundColor: ink,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                  side: BorderSide(
                                    color: following == value
                                        ? ink
                                        : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              onPressed: () =>
                                  setState(() => following = value),
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    key: const ValueKey('search-users'),
                    onTap: () => openPage(context, const SearchPage()),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xffeff6f2),
                        border: Border.all(color: const Color(0xffccd8ce)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              context.l.searchHint,
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (posts.isEmpty)
            SliverToBoxAdapter(
              child: EmptyMessage(context.l.noFollowing, context.l.demoNote),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
            sliver: SliverList.builder(
              itemCount: posts.length,
              itemBuilder: (c, i) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: PostCard(post: posts[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FollowButton extends StatelessWidget {
  const FollowButton({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    if (id == 'me') return const SizedBox.shrink();
    return TextButton(
      onPressed: () => store.follow(id),
      child: Text(
        store.data.following.contains(id)
            ? context.l.followed
            : context.l.follow,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post, this.detail = false});
  final Post post;
  final bool detail;
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context), u = store.data.user(post.userId);
    final snapshot = post.snapshot;
    return PaperCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => openPage(context, ProfilePage(id: u.id)),
                child: Avatar(u.name, u.color, asset: u.avatar),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: InkWell(
                  onTap: () => openPage(context, ProfilePage(id: u.id)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        dateLabel(post.time),
                        style: const TextStyle(color: muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
              if (u.id == 'me')
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      openPage(context, PublishPage(postId: post.id));
                    } else if (await confirmDelete(context)) {
                      await store.deletePost(post.id);
                      if (context.mounted && detail) Navigator.pop(context);
                    }
                  },
                  itemBuilder: (c) => [
                    PopupMenuItem(value: 'edit', child: Text(c.l.edit)),
                    PopupMenuItem(value: 'delete', child: Text(c.l.delete)),
                  ],
                )
              else
                FollowButton(id: u.id),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: detail
                ? null
                : () => openPage(context, PostPage(id: post.id)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (post.title.isNotEmpty) ...[
                  Text(
                    post.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 5),
                ],
                Text(
                  post.body,
                  maxLines: detail ? null : 3,
                  overflow: detail ? null : TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                if (snapshot != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: SizedBox(
                      height: detail ? 280 : 210,
                      child: post.type == '宠物'
                          ? ColoredBox(
                              color: const Color(0xfffceaf0),
                              child: Center(
                                child: PixelSprite(snapshot.formId, size: 150),
                              ),
                            )
                          : GardenScene(garden: snapshot, animate: false),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => store.like(post.id),
                icon: Icon(
                  post.liked ? Icons.favorite : Icons.favorite_border,
                  color: post.liked ? const Color(0xffd76589) : muted,
                  size: 20,
                ),
                label: Text('${post.likes}'),
              ),
              TextButton.icon(
                onPressed: detail
                    ? null
                    : () => openPage(context, PostPage(id: post.id)),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: Text('${post.comments.length}'),
              ),
              IconButton(
                tooltip: post.saved ? context.l.bookmarked : context.l.bookmark,
                onPressed: () => store.savePost(post.id),
                icon: Icon(post.saved ? Icons.bookmark : Icons.bookmark_border),
              ),
            ],
          ),
          if (detail && snapshot != null)
            OutlinedButton(
              onPressed: () => openPage(
                context,
                GardenVisitPage(ownerId: u.id, gardenId: snapshot.id),
              ),
              child: Text(context.l.visit),
            ),
        ],
      ),
    );
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final query = TextEditingController();
  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = AppScope.of(context).data, q = query.text.trim().toLowerCase();
    final users = [d.user('me'), ...d.users]
        .where(
          (u) => [
            u.name,
            u.id,
            u.bio,
            ...u.gardens.map((g) => g.name),
          ].join(' ').toLowerCase().contains(q),
        )
        .toList();
    final posts = d.posts
        .where((p) => '${p.title} ${p.body}'.toLowerCase().contains(q))
        .toList();
    return PageFrame(
      title: context.l.search,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('search-input'),
            controller: query,
            decoration: InputDecoration(
              hintText: context.l.searchHint,
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
          SectionLabel(context.l.users),
          for (final u in users)
            PaperCard(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Avatar(u.name, u.color, asset: u.avatar),
                    title: Text(u.name),
                    subtitle: Text('@${u.id}'),
                    trailing: FollowButton(id: u.id),
                    onTap: () => openPage(context, ProfilePage(id: u.id)),
                  ),
                  for (final g in u.gardens)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => openPage(
                          context,
                          GardenVisitPage(ownerId: u.id, gardenId: g.id),
                        ),
                        child: Text(context.l.visit),
                      ),
                    ),
                ],
              ),
            ),
          if (users.isEmpty) Text(context.l.noResults),
          SectionLabel(context.l.gardens),
          for (final u in users)
            for (final g in u.gardens)
              ListTile(
                title: Text(g.name),
                subtitle: Text(modeLabel(context, g.visitMode)),
                leading: PixelSprite(g.formId, size: 40),
                onTap: () => openPage(
                  context,
                  GardenVisitPage(ownerId: u.id, gardenId: g.id),
                ),
              ),
          SectionLabel(context.l.posts),
          for (final p in posts)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PostCard(post: p),
            ),
        ],
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) {
    final d = AppScope.of(context).data, u = d.user(id);
    return PageFrame(
      title: context.l.publicProfile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Avatar(u.name, u.color, size: 80, asset: u.avatar)),
          const SizedBox(height: 12),
          Text(
            u.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 24),
          ),
          Text(
            '@${u.id}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 8),
          Text(u.bio, textAlign: TextAlign.center),
          Center(child: FollowButton(id: u.id)),
          SectionLabel(context.l.gardens),
          for (final g in u.gardens)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      g.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${g.petName} · ${formLabel(context, g.stage)}',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    if (AppScope.of(context).canVisit(id, g))
                      SizedBox(
                        height: 230,
                        child: GardenScene(garden: g, animate: false),
                      ),
                    OutlinedButton(
                      onPressed: () => openPage(
                        context,
                        GardenVisitPage(ownerId: id, gardenId: g.id),
                      ),
                      child: Text(context.l.visit),
                    ),
                  ],
                ),
              ),
            ),
          SectionLabel(context.l.posts),
          for (final p in d.posts.where((p) => p.userId == id))
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: PostCard(post: p),
            ),
        ],
      ),
    );
  }
}

class GardenVisitPage extends StatelessWidget {
  const GardenVisitPage({
    super.key,
    required this.ownerId,
    required this.gardenId,
  });
  final String ownerId, gardenId;
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context), owner = store.data.user(ownerId);
    final matches = owner.gardens.where((g) => g.id == gardenId).toList();
    if (matches.isEmpty) {
      return PageFrame(
        title: context.l.visit,
        child: EmptyMessage(context.l.privateGarden, context.l.closedNote),
      );
    }
    final g = matches.single;
    final allowed = store.canVisit(ownerId, g);
    final requests = store.data.requests
        .where(
          (r) =>
              r.ownerId == ownerId &&
              r.gardenId == gardenId &&
              r.visitorId == 'me',
        )
        .toList();
    final pending = requests.any((r) => r.status == RequestStatus.pending);
    return Scaffold(
      appBar: AppBar(
        title: Text(g.name),
        actions: [
          IconButton(
            tooltip: context.l.publicProfile,
            onPressed: () => openPage(context, ProfilePage(id: ownerId)),
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: allowed
            ? Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      '${owner.name} · ${context.l.readOnly}',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: GardenScene(
                      garden: g,
                      interactive: true,
                      animate: false,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      '${context.l.plant}: Tuantuan · ${context.l.petLabel}: ${g.petName}',
                    ),
                  ),
                ],
              )
            : Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.lock_outline, size: 44),
                      const SizedBox(height: 16),
                      Text(
                        context.l.privateGarden,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        modeDescription(context, g.visitMode),
                        textAlign: TextAlign.center,
                      ),
                      if (g.visitMode == VisitMode.request) ...[
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: pending
                              ? null
                              : () => store.requestVisit(ownerId, gardenId),
                          child: Text(
                            pending ? context.l.pending : context.l.apply,
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              openPage(context, const NotificationsPage()),
                          child: Text(context.l.notifications),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class PostPage extends StatefulWidget {
  const PostPage({super.key, required this.id});
  final String id;
  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  final comment = TextEditingController();
  String? replyTo;
  bool sending = false;
  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context),
        found = store.data.posts.where((p) => p.id == widget.id).toList();
    if (found.isEmpty) {
      return PageFrame(
        title: context.l.post,
        child: Text(context.l.postRemoved),
      );
    }
    final p = found.single;
    return PageFrame(
      title: context.l.post,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PostCard(post: p, detail: true),
          SectionLabel(context.l.comment),
          if (p.comments.isEmpty) Text(context.l.noComments),
          for (final c in p.comments)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Avatar(
                store.data.user(c.userId).name,
                0xfffce5ed,
                asset: store.data.user(c.userId).avatar,
              ),
              title: Text(store.data.user(c.userId).name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (c.replyTo != null)
                    Text(
                      '↳ ${context.l.reply}',
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                  Text(c.text),
                  Wrap(
                    children: [
                      TextButton(
                        onPressed: () => setState(() => replyTo = c.id),
                        child: Text(context.l.reply),
                      ),
                      if (c.userId == 'me')
                        TextButton(
                          onPressed: () async {
                            if (await confirmDelete(context)) {
                              await store.deleteComment(p.id, c.id);
                              if (mounted && replyTo == c.id) {
                                setState(() => replyTo = null);
                              }
                            }
                          },
                          child: Text(context.l.delete),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          if (replyTo != null)
            Row(
              children: [
                Expanded(child: Text(context.l.replying)),
                IconButton(
                  onPressed: () => setState(() => replyTo = null),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          TextField(
            key: const ValueKey('comment-input'),
            controller: comment,
            maxLength: 220,
            decoration: InputDecoration(hintText: context.l.commentHint),
          ),
          FilledButton(
            onPressed: sending
                ? null
                : () async {
                    if (comment.text.trim().isEmpty) return;
                    setState(() => sending = true);
                    await store.comment(p.id, comment.text, replyTo: replyTo);
                    if (mounted) {
                      setState(() {
                        comment.clear();
                        replyTo = null;
                        sending = false;
                      });
                    }
                  },
            child: Text(context.l.send),
          ),
        ],
      ),
    );
  }
}

class PublishPage extends StatefulWidget {
  const PublishPage({
    super.key,
    this.postId,
    this.initialBody,
    this.initialType,
  });
  final String? postId, initialBody, initialType;
  @override
  State<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends State<PublishPage> {
  final title = TextEditingController(), body = TextEditingController();
  final form = GlobalKey<FormState>();
  bool ready = false, busy = false, withImage = true;
  String? gardenId;
  String type = '花园';
  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context), d = store.data;
    if (!ready) {
      ready = true;
      gardenId = d.selectedId;
      body.text = widget.initialBody ?? '';
      type = widget.initialType ?? '花园';
      if (widget.postId != null) {
        final p = d.posts.singleWhere((p) => p.id == widget.postId);
        title.text = p.title;
        body.text = p.body;
        type = p.type;
        withImage = p.snapshot != null;
      }
    }
    return PageFrame(
      title: widget.postId == null ? context.l.publish : context.l.editPost,
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.postId == null) ...[
              DropdownButtonFormField<String>(
                initialValue: gardenId,
                isExpanded: true,
                decoration: InputDecoration(labelText: context.l.garden),
                items: d.gardens
                    .map(
                      (g) => DropdownMenuItem(value: g.id, child: Text(g.name)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => gardenId = v),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l.withImage),
                value: withImage,
                onChanged: (v) => setState(() => withImage = v),
              ),
              if (withImage) ...[
                DropdownButtonFormField<String>(
                  initialValue: type,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: context.l.contentType),
                  items:
                      [
                            ('花园', context.l.snapshot),
                            ('宠物', context.l.petSnapshot),
                            ('探索', context.l.exploreSnapshot),
                          ]
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.$1,
                              child: Text(e.$2),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => type = v!),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 210,
                  child: type == '宠物'
                      ? Center(
                          child: PixelSprite(
                            store.garden(gardenId!).pet.formId,
                            size: 160,
                          ),
                        )
                      : GardenScene(
                          garden: store.garden(gardenId!).snapshot(),
                          animate: false,
                        ),
                ),
              ],
            ],
            const SizedBox(height: 18),
            TextFormField(
              controller: title,
              maxLength: 80,
              decoration: InputDecoration(labelText: context.l.postTitle),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: body,
              maxLength: 1000,
              minLines: 4,
              maxLines: 8,
              decoration: InputDecoration(labelText: context.l.postBody),
              validator: (s) =>
                  s == null || s.trim().isEmpty ? context.l.required : null,
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      setState(() => busy = true);
                      if (widget.postId == null) {
                        await store.publish(
                          gardenId!,
                          withImage ? type : '文字',
                          title.text,
                          body.text,
                          withImage: withImage,
                        );
                      } else {
                        await store.editPost(
                          widget.postId!,
                          title.text,
                          body.text,
                        );
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
              child: Text(
                widget.postId == null ? context.l.publish : context.l.save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SavedPostsPage extends StatelessWidget {
  const SavedPostsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final posts = AppScope.of(context).data.posts
        .where((p) => p.saved)
        .toList();
    return PageFrame(
      title: context.l.saved,
      child: Column(
        children: [
          if (posts.isEmpty)
            EmptyMessage(context.l.noSaved, context.l.bookmark),
          for (final p in posts)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: PostCard(post: p),
            ),
        ],
      ),
    );
  }
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context), d = store.data;
    Widget requestCard(VisitRequest r) {
      final incoming = r.ownerId == 'me';
      final person = d.user(incoming ? r.visitorId : r.ownerId);
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: PaperCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${person.name} · ${incoming ? context.l.incoming : context.l.outgoing}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                [
                  context.l.pending,
                  context.l.approved,
                  context.l.rejected,
                ][r.status.index],
              ),
              if (r.status == RequestStatus.pending)
                Wrap(
                  spacing: 10,
                  children: [
                    FilledButton(
                      onPressed: () => store.decideVisit(
                        r.id,
                        true,
                        simulateOwner: !incoming,
                      ),
                      child: Text(
                        incoming
                            ? context.l.approve
                            : context.l.simulateApprove,
                      ),
                    ),
                    TextButton(
                      onPressed: () => store.decideVisit(
                        r.id,
                        false,
                        simulateOwner: !incoming,
                      ),
                      child: Text(
                        incoming ? context.l.reject : context.l.simulateReject,
                      ),
                    ),
                  ],
                ),
              if (!incoming && r.status == RequestStatus.approved)
                TextButton(
                  onPressed: () => openPage(
                    context,
                    GardenVisitPage(ownerId: r.ownerId, gardenId: r.gardenId),
                  ),
                  child: Text(context.l.visit),
                ),
            ],
          ),
        ),
      );
    }

    return PageFrame(
      title: context.l.notifications,
      actions: [
        TextButton(
          onPressed: () => store.markNoticesRead(),
          child: Text(context.l.markRead),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (d.requests.isNotEmpty) ...[
            Text(
              context.l.approvalDemo,
              style: const TextStyle(color: muted, fontSize: 12),
            ),
            SectionLabel(context.l.visitRequests),
            for (final r in d.requests.reversed) requestCard(r),
          ],
          for (final n in d.notices)
            ListTile(
              leading: Avatar(
                d.user(n.actorId).name,
                0xffe9f2e4,
                asset: d.user(n.actorId).avatar,
              ),
              title: Text(
                '${d.user(n.actorId).name} ${switch (n.kind) {
                  'like' => context.l.likedNotice,
                  'follow' => context.l.followNotice,
                  'approved' => context.l.approvedNotice,
                  'rejected' => context.l.rejectedNotice,
                  _ => context.l.commentNotice,
                }}',
              ),
              subtitle: Text(dateLabel(n.time)),
              trailing: n.read
                  ? null
                  : const Icon(Icons.circle, size: 8, color: Colors.pink),
            ),
          if (d.requests.isEmpty && d.notices.isEmpty)
            EmptyMessage(context.l.noNotices, context.l.socialNotifications),
        ],
      ),
    );
  }
}
