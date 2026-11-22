// ignore_for_file: deprecated_member_use
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @garden.
  ///
  /// In en, this message translates to:
  /// **'Garden'**
  String get garden;

  /// No description provided for @social.
  ///
  /// In en, this message translates to:
  /// **'Social'**
  String get social;

  /// No description provided for @me.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get me;

  /// No description provided for @recommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get recommended;

  /// No description provided for @following.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get following;

  /// No description provided for @followers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get followers;

  /// No description provided for @mutual.
  ///
  /// In en, this message translates to:
  /// **'Mutual follows'**
  String get mutual;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search users, IDs, gardens or posts'**
  String get searchHint;

  /// No description provided for @publish.
  ///
  /// In en, this message translates to:
  /// **'Create post'**
  String get publish;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get system;

  /// No description provided for @chinese.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get chinese;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete this item?'**
  String get confirmDelete;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @openFull.
  ///
  /// In en, this message translates to:
  /// **'Full garden'**
  String get openFull;

  /// No description provided for @exitFull.
  ///
  /// In en, this message translates to:
  /// **'Exit full garden'**
  String get exitFull;

  /// No description provided for @backHome.
  ///
  /// In en, this message translates to:
  /// **'Back to Garden'**
  String get backHome;

  /// No description provided for @selectPlant.
  ///
  /// In en, this message translates to:
  /// **'Select a plant'**
  String get selectPlant;

  /// No description provided for @switchPlant.
  ///
  /// In en, this message translates to:
  /// **'Switch plant'**
  String get switchPlant;

  /// No description provided for @plants.
  ///
  /// In en, this message translates to:
  /// **'My plants'**
  String get plants;

  /// No description provided for @addPlant.
  ///
  /// In en, this message translates to:
  /// **'Bind a plant'**
  String get addPlant;

  /// No description provided for @plantName.
  ///
  /// In en, this message translates to:
  /// **'Plant nickname'**
  String get plantName;

  /// No description provided for @petName.
  ///
  /// In en, this message translates to:
  /// **'Pet nickname'**
  String get petName;

  /// No description provided for @pothos.
  ///
  /// In en, this message translates to:
  /// **'Pothos'**
  String get pothos;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Demo connected'**
  String get connected;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'No device linked'**
  String get disconnected;

  /// No description provided for @archived.
  ///
  /// In en, this message translates to:
  /// **'Removed plants'**
  String get archived;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Remove plant, keep pet'**
  String get archive;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Rebind plant'**
  String get restore;

  /// No description provided for @archiveNote.
  ///
  /// In en, this message translates to:
  /// **'Removing a plant keeps its pet, level, appearance and history. Rebind it to continue.'**
  String get archiveNote;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Please fill in this field'**
  String get required;

  /// No description provided for @pet.
  ///
  /// In en, this message translates to:
  /// **'My pet'**
  String get pet;

  /// No description provided for @food.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get food;

  /// No description provided for @mood.
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get mood;

  /// No description provided for @energy.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get energy;

  /// No description provided for @clean.
  ///
  /// In en, this message translates to:
  /// **'Clean'**
  String get clean;

  /// No description provided for @xp.
  ///
  /// In en, this message translates to:
  /// **'Growth XP'**
  String get xp;

  /// No description provided for @level.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get level;

  /// No description provided for @initial.
  ///
  /// In en, this message translates to:
  /// **'Initial form'**
  String get initial;

  /// No description provided for @second.
  ///
  /// In en, this message translates to:
  /// **'Second form'**
  String get second;

  /// No description provided for @mature.
  ///
  /// In en, this message translates to:
  /// **'Mature form'**
  String get mature;

  /// No description provided for @trait.
  ///
  /// In en, this message translates to:
  /// **'Initial traits'**
  String get trait;

  /// No description provided for @traitNote.
  ///
  /// In en, this message translates to:
  /// **'A fixed initial appearance assigned by the system. Traits are read-only.'**
  String get traitNote;

  /// No description provided for @feed.
  ///
  /// In en, this message translates to:
  /// **'Feeding'**
  String get feed;

  /// No description provided for @cleanAction.
  ///
  /// In en, this message translates to:
  /// **'Cleaning'**
  String get cleanAction;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Playing'**
  String get play;

  /// No description provided for @explore.
  ///
  /// In en, this message translates to:
  /// **'Exploring'**
  String get explore;

  /// No description provided for @sleep.
  ///
  /// In en, this message translates to:
  /// **'Sleeping'**
  String get sleep;

  /// No description provided for @idle.
  ///
  /// In en, this message translates to:
  /// **'Growing together'**
  String get idle;

  /// No description provided for @auto.
  ///
  /// In en, this message translates to:
  /// **'Autonomous actions'**
  String get auto;

  /// No description provided for @event.
  ///
  /// In en, this message translates to:
  /// **'Latest event'**
  String get event;

  /// No description provided for @noEvent.
  ///
  /// In en, this message translates to:
  /// **'A new story begins today.'**
  String get noEvent;

  /// No description provided for @myCompanions.
  ///
  /// In en, this message translates to:
  /// **'My companions'**
  String get myCompanions;

  /// No description provided for @myGrowth.
  ///
  /// In en, this message translates to:
  /// **'My growth'**
  String get myGrowth;

  /// No description provided for @mySpace.
  ///
  /// In en, this message translates to:
  /// **'My space'**
  String get mySpace;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get profile;

  /// No description provided for @publicProfile.
  ///
  /// In en, this message translates to:
  /// **'Public profile'**
  String get publicProfile;

  /// No description provided for @nickname.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get nickname;

  /// No description provided for @bio.
  ///
  /// In en, this message translates to:
  /// **'About me'**
  String get bio;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account ID'**
  String get account;

  /// No description provided for @avatar.
  ///
  /// In en, this message translates to:
  /// **'Avatar'**
  String get avatar;

  /// No description provided for @chooseAvatar.
  ///
  /// In en, this message translates to:
  /// **'Choose an avatar'**
  String get chooseAvatar;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Garden visiting permissions'**
  String get privacy;

  /// No description provided for @public.
  ///
  /// In en, this message translates to:
  /// **'Completely open'**
  String get public;

  /// No description provided for @request.
  ///
  /// In en, this message translates to:
  /// **'Request approval'**
  String get request;

  /// No description provided for @closed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closed;

  /// No description provided for @allowFollowing.
  ///
  /// In en, this message translates to:
  /// **'People I follow'**
  String get allowFollowing;

  /// No description provided for @allowFollowers.
  ///
  /// In en, this message translates to:
  /// **'My followers'**
  String get allowFollowers;

  /// No description provided for @allowMutual.
  ///
  /// In en, this message translates to:
  /// **'Mutual follows'**
  String get allowMutual;

  /// No description provided for @publicNote.
  ///
  /// In en, this message translates to:
  /// **'Anyone may enter directly.'**
  String get publicNote;

  /// No description provided for @requestNote.
  ///
  /// In en, this message translates to:
  /// **'Visitors may enter after owner approval.'**
  String get requestNote;

  /// No description provided for @closedNote.
  ///
  /// In en, this message translates to:
  /// **'Other users cannot enter.'**
  String get closedNote;

  /// No description provided for @followingNote.
  ///
  /// In en, this message translates to:
  /// **'People you follow may enter directly.'**
  String get followingNote;

  /// No description provided for @followersNote.
  ///
  /// In en, this message translates to:
  /// **'Your followers may enter directly.'**
  String get followersNote;

  /// No description provided for @mutualNote.
  ///
  /// In en, this message translates to:
  /// **'Mutual followers may enter directly.'**
  String get mutualNote;

  /// No description provided for @privacyNote.
  ///
  /// In en, this message translates to:
  /// **'Each garden has its own access rule. Public posts do not change garden access.'**
  String get privacyNote;

  /// No description provided for @visit.
  ///
  /// In en, this message translates to:
  /// **'Visit garden'**
  String get visit;

  /// No description provided for @privateGarden.
  ///
  /// In en, this message translates to:
  /// **'You cannot enter this garden'**
  String get privateGarden;

  /// No description provided for @readOnly.
  ///
  /// In en, this message translates to:
  /// **'Visiting · read only'**
  String get readOnly;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Request a visit'**
  String get apply;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending approval'**
  String get pending;

  /// No description provided for @approved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approved;

  /// No description provided for @rejected.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get rejected;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get reject;

  /// No description provided for @visitRequests.
  ///
  /// In en, this message translates to:
  /// **'Visit requests'**
  String get visitRequests;

  /// No description provided for @incoming.
  ///
  /// In en, this message translates to:
  /// **'Incoming requests'**
  String get incoming;

  /// No description provided for @outgoing.
  ///
  /// In en, this message translates to:
  /// **'Outgoing requests'**
  String get outgoing;

  /// No description provided for @simulateRequest.
  ///
  /// In en, this message translates to:
  /// **'Simulate visitor request'**
  String get simulateRequest;

  /// No description provided for @simulateApprove.
  ///
  /// In en, this message translates to:
  /// **'Simulate owner approval'**
  String get simulateApprove;

  /// No description provided for @simulateReject.
  ///
  /// In en, this message translates to:
  /// **'Simulate owner rejection'**
  String get simulateReject;

  /// No description provided for @approvalDemo.
  ///
  /// In en, this message translates to:
  /// **'Local simulation for exploring the request and approval flow.'**
  String get approvalDemo;

  /// No description provided for @markRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markRead;

  /// No description provided for @noNotices.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotices;

  /// No description provided for @likedNotice.
  ///
  /// In en, this message translates to:
  /// **'liked your post'**
  String get likedNotice;

  /// No description provided for @followNotice.
  ///
  /// In en, this message translates to:
  /// **'followed you'**
  String get followNotice;

  /// No description provided for @commentNotice.
  ///
  /// In en, this message translates to:
  /// **'commented on your post'**
  String get commentNotice;

  /// No description provided for @approvedNotice.
  ///
  /// In en, this message translates to:
  /// **'approved a visit request'**
  String get approvedNotice;

  /// No description provided for @rejectedNotice.
  ///
  /// In en, this message translates to:
  /// **'declined a visit request'**
  String get rejectedNotice;

  /// No description provided for @follow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get follow;

  /// No description provided for @unfollow.
  ///
  /// In en, this message translates to:
  /// **'Unfollow'**
  String get unfollow;

  /// No description provided for @followed.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get followed;

  /// No description provided for @users.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get users;

  /// No description provided for @gardens.
  ///
  /// In en, this message translates to:
  /// **'Gardens'**
  String get gardens;

  /// No description provided for @posts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get posts;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No matching results'**
  String get noResults;

  /// No description provided for @noFollowing.
  ///
  /// In en, this message translates to:
  /// **'No posts from followed users'**
  String get noFollowing;

  /// No description provided for @post.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get post;

  /// No description provided for @like.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get like;

  /// No description provided for @comment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get comment;

  /// No description provided for @reply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// No description provided for @replying.
  ///
  /// In en, this message translates to:
  /// **'Replying to'**
  String get replying;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @commentHint.
  ///
  /// In en, this message translates to:
  /// **'Add a comment'**
  String get commentHint;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved posts'**
  String get saved;

  /// No description provided for @bookmark.
  ///
  /// In en, this message translates to:
  /// **'Save post'**
  String get bookmark;

  /// No description provided for @bookmarked.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get bookmarked;

  /// No description provided for @noSaved.
  ///
  /// In en, this message translates to:
  /// **'No saved posts'**
  String get noSaved;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @shareUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Cross-app sharing is unavailable in this demo.'**
  String get shareUnavailable;

  /// No description provided for @postTitle.
  ///
  /// In en, this message translates to:
  /// **'Title (optional)'**
  String get postTitle;

  /// No description provided for @postBody.
  ///
  /// In en, this message translates to:
  /// **'Caption'**
  String get postBody;

  /// No description provided for @withImage.
  ///
  /// In en, this message translates to:
  /// **'Include garden image'**
  String get withImage;

  /// No description provided for @contentType.
  ///
  /// In en, this message translates to:
  /// **'Content type'**
  String get contentType;

  /// No description provided for @snapshot.
  ///
  /// In en, this message translates to:
  /// **'Garden snapshot'**
  String get snapshot;

  /// No description provided for @petSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Pet snapshot'**
  String get petSnapshot;

  /// No description provided for @exploreSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Exploration memory'**
  String get exploreSnapshot;

  /// No description provided for @textOnly.
  ///
  /// In en, this message translates to:
  /// **'Text only'**
  String get textOnly;

  /// No description provided for @published.
  ///
  /// In en, this message translates to:
  /// **'Post published'**
  String get published;

  /// No description provided for @editPost.
  ///
  /// In en, this message translates to:
  /// **'Edit post'**
  String get editPost;

  /// No description provided for @postRemoved.
  ///
  /// In en, this message translates to:
  /// **'Post deleted'**
  String get postRemoved;

  /// No description provided for @noPosts.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get noPosts;

  /// No description provided for @noComments.
  ///
  /// In en, this message translates to:
  /// **'No comments yet'**
  String get noComments;

  /// No description provided for @evolution.
  ///
  /// In en, this message translates to:
  /// **'Evolution history'**
  String get evolution;

  /// No description provided for @evolutionNote.
  ///
  /// In en, this message translates to:
  /// **'Start at level 1. A fixed evolution at level 5; one of seven random mature forms at level 10. Levels continue after maturity.'**
  String get evolutionNote;

  /// No description provided for @experienced.
  ///
  /// In en, this message translates to:
  /// **'Experienced forms'**
  String get experienced;

  /// No description provided for @diary.
  ///
  /// In en, this message translates to:
  /// **'Growth diary'**
  String get diary;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @actions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actions;

  /// No description provided for @growth.
  ///
  /// In en, this message translates to:
  /// **'Levels & evolution'**
  String get growth;

  /// No description provided for @noRecords.
  ///
  /// In en, this message translates to:
  /// **'No records yet'**
  String get noRecords;

  /// No description provided for @reason.
  ///
  /// In en, this message translates to:
  /// **'Decision basis'**
  String get reason;

  /// No description provided for @changes.
  ///
  /// In en, this message translates to:
  /// **'Changes'**
  String get changes;

  /// No description provided for @shareRecord.
  ///
  /// In en, this message translates to:
  /// **'Share record'**
  String get shareRecord;

  /// No description provided for @monitor.
  ///
  /// In en, this message translates to:
  /// **'Plant monitor'**
  String get monitor;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @sevenDays.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get sevenDays;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @soil.
  ///
  /// In en, this message translates to:
  /// **'Soil moisture'**
  String get soil;

  /// No description provided for @temperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get temperature;

  /// No description provided for @humidity.
  ///
  /// In en, this message translates to:
  /// **'Air humidity'**
  String get humidity;

  /// No description provided for @mockSensors.
  ///
  /// In en, this message translates to:
  /// **'Simulated readings · physical hardware not connected'**
  String get mockSensors;

  /// No description provided for @device.
  ///
  /// In en, this message translates to:
  /// **'My device'**
  String get device;

  /// No description provided for @bindDevice.
  ///
  /// In en, this message translates to:
  /// **'Bind demo device'**
  String get bindDevice;

  /// No description provided for @unbindDevice.
  ///
  /// In en, this message translates to:
  /// **'Unbind device'**
  String get unbindDevice;

  /// No description provided for @sync.
  ///
  /// In en, this message translates to:
  /// **'Sync readings'**
  String get sync;

  /// No description provided for @synced.
  ///
  /// In en, this message translates to:
  /// **'Demo readings synchronized'**
  String get synced;

  /// No description provided for @calibration.
  ///
  /// In en, this message translates to:
  /// **'Calibration'**
  String get calibration;

  /// No description provided for @calibrationNote.
  ///
  /// In en, this message translates to:
  /// **'Physical devices require light, soil moisture and temperature/humidity calibration. Current readings are for the demo.'**
  String get calibrationNote;

  /// No description provided for @editGarden.
  ///
  /// In en, this message translates to:
  /// **'Arrange garden'**
  String get editGarden;

  /// No description provided for @finishEdit.
  ///
  /// In en, this message translates to:
  /// **'Save layout'**
  String get finishEdit;

  /// No description provided for @moveHint.
  ///
  /// In en, this message translates to:
  /// **'Drag decorations to move them; tap to replace or put away.'**
  String get moveHint;

  /// No description provided for @putAway.
  ///
  /// In en, this message translates to:
  /// **'Put away'**
  String get putAway;

  /// No description provided for @replace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replace;

  /// No description provided for @restoreDecor.
  ///
  /// In en, this message translates to:
  /// **'Restore hidden decoration'**
  String get restoreDecor;

  /// No description provided for @noHidden.
  ///
  /// In en, this message translates to:
  /// **'No hidden decorations'**
  String get noHidden;

  /// No description provided for @layoutSaved.
  ///
  /// In en, this message translates to:
  /// **'Garden layout saved'**
  String get layoutSaved;

  /// No description provided for @flower.
  ///
  /// In en, this message translates to:
  /// **'Flowers'**
  String get flower;

  /// No description provided for @mushroom.
  ///
  /// In en, this message translates to:
  /// **'Mushroom'**
  String get mushroom;

  /// No description provided for @stones.
  ///
  /// In en, this message translates to:
  /// **'Stones'**
  String get stones;

  /// No description provided for @bridge.
  ///
  /// In en, this message translates to:
  /// **'Bridge'**
  String get bridge;

  /// No description provided for @fence.
  ///
  /// In en, this message translates to:
  /// **'Fence'**
  String get fence;

  /// No description provided for @ufo.
  ///
  /// In en, this message translates to:
  /// **'UFO'**
  String get ufo;

  /// No description provided for @puppy.
  ///
  /// In en, this message translates to:
  /// **'Puppy decoration'**
  String get puppy;

  /// No description provided for @socialNotifications.
  ///
  /// In en, this message translates to:
  /// **'Social notifications'**
  String get socialNotifications;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About Plant Mate'**
  String get about;

  /// No description provided for @demoNote.
  ///
  /// In en, this message translates to:
  /// **'Plants act autonomously. Watch them grow, arrange your garden and share moments. Devices and community are simulated locally.'**
  String get demoNote;

  /// No description provided for @accountNote.
  ///
  /// In en, this message translates to:
  /// **'This local demo uses a fixed account ID.'**
  String get accountNote;

  /// No description provided for @emptyPlants.
  ///
  /// In en, this message translates to:
  /// **'Bind a plant to begin a new story'**
  String get emptyPlants;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'First hello'**
  String get welcome;

  /// No description provided for @newForm.
  ///
  /// In en, this message translates to:
  /// **'A new appearance'**
  String get newForm;

  /// No description provided for @levelUp.
  ///
  /// In en, this message translates to:
  /// **'Level up'**
  String get levelUp;

  /// No description provided for @record.
  ///
  /// In en, this message translates to:
  /// **'Growth record'**
  String get record;

  /// No description provided for @viewPet.
  ///
  /// In en, this message translates to:
  /// **'View pet'**
  String get viewPet;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @initialPetNote.
  ///
  /// In en, this message translates to:
  /// **'Binding creates a fixed initial pet. Its nickname can be changed.'**
  String get initialPetNote;

  /// No description provided for @plant.
  ///
  /// In en, this message translates to:
  /// **'Plant'**
  String get plant;

  /// No description provided for @petLabel.
  ///
  /// In en, this message translates to:
  /// **'Pet'**
  String get petLabel;

  /// No description provided for @explorationCount.
  ///
  /// In en, this message translates to:
  /// **'Plant explorations'**
  String get explorationCount;

  /// No description provided for @recordSaved.
  ///
  /// In en, this message translates to:
  /// **'Record saved'**
  String get recordSaved;

  /// No description provided for @browseMap.
  ///
  /// In en, this message translates to:
  /// **'Browse map'**
  String get browseMap;

  /// No description provided for @adjustDecorations.
  ///
  /// In en, this message translates to:
  /// **'Arrange items'**
  String get adjustDecorations;

  /// No description provided for @browseHint.
  ///
  /// In en, this message translates to:
  /// **'Pan or zoom the map, then switch to arranging items in that area.'**
  String get browseHint;

  /// No description provided for @gameData.
  ///
  /// In en, this message translates to:
  /// **'Game data'**
  String get gameData;

  /// No description provided for @hardwareData.
  ///
  /// In en, this message translates to:
  /// **'Hardware data'**
  String get hardwareData;

  /// No description provided for @showGameData.
  ///
  /// In en, this message translates to:
  /// **'Show game data'**
  String get showGameData;

  /// No description provided for @showHardwareData.
  ///
  /// In en, this message translates to:
  /// **'Show hardware data'**
  String get showHardwareData;

  /// No description provided for @deviceAddress.
  ///
  /// In en, this message translates to:
  /// **'Device address'**
  String get deviceAddress;

  /// No description provided for @deviceAddressInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a local HTTP address, e.g. http://192.168.4.1'**
  String get deviceAddressInvalid;

  /// No description provided for @deviceConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect / Reconnect'**
  String get deviceConnect;

  /// No description provided for @deviceWifiHelp.
  ///
  /// In en, this message translates to:
  /// **'Join the device’s PlantMate Wi-Fi network and stay connected to read data. For desktop testing, enter the computer’s LAN address and port.'**
  String get deviceWifiHelp;

  /// No description provided for @devicePaused.
  ///
  /// In en, this message translates to:
  /// **'Data reading paused'**
  String get devicePaused;

  /// No description provided for @deviceConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to device…'**
  String get deviceConnecting;

  /// No description provided for @deviceReceiving.
  ///
  /// In en, this message translates to:
  /// **'Receiving data'**
  String get deviceReceiving;

  /// No description provided for @deviceStale.
  ///
  /// In en, this message translates to:
  /// **'Sample sequence unchanged for over 5 seconds; readings are stale'**
  String get deviceStale;

  /// No description provided for @deviceConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed. Check Wi-Fi, the device address and local network permission, then reconnect.'**
  String get deviceConnectionFailed;

  /// No description provided for @deviceProtocolInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid device data; reading stopped'**
  String get deviceProtocolInvalid;

  /// No description provided for @deviceSensorUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sensor data unavailable'**
  String get deviceSensorUnavailable;

  /// No description provided for @deviceSourceHardware.
  ///
  /// In en, this message translates to:
  /// **'Source: hardware device'**
  String get deviceSourceHardware;

  /// No description provided for @deviceSourceSimulation.
  ///
  /// In en, this message translates to:
  /// **'Source: desktop simulation'**
  String get deviceSourceSimulation;

  /// No description provided for @deviceSequence.
  ///
  /// In en, this message translates to:
  /// **'Sample sequence: {sequence}'**
  String deviceSequence(int sequence);

  /// No description provided for @deviceSoilContact.
  ///
  /// In en, this message translates to:
  /// **'Soil contact'**
  String get deviceSoilContact;

  /// No description provided for @deviceSoilHigh.
  ///
  /// In en, this message translates to:
  /// **'Open / HIGH'**
  String get deviceSoilHigh;

  /// No description provided for @deviceSoilLow.
  ///
  /// In en, this message translates to:
  /// **'Closed / LOW'**
  String get deviceSoilLow;

  /// No description provided for @deviceSoilHelp.
  ///
  /// In en, this message translates to:
  /// **'The soil contact is a threshold switch. Its dry/wet meaning requires physical calibration.'**
  String get deviceSoilHelp;

  /// No description provided for @deviceTouch.
  ///
  /// In en, this message translates to:
  /// **'Touch electrodes'**
  String get deviceTouch;

  /// No description provided for @deviceTouchIdle.
  ///
  /// In en, this message translates to:
  /// **'No touch detected'**
  String get deviceTouchIdle;

  /// No description provided for @deviceLatestEvent.
  ///
  /// In en, this message translates to:
  /// **'Latest device event'**
  String get deviceLatestEvent;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
