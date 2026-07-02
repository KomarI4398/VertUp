import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:govnolda/models/quest.dart';
import 'package:govnolda/models/user_profile.dart'; // <--- Вот этот импорт критически важен!

class QuestController extends ChangeNotifier {
  static const int xpPerLevel = 100;

  SharedPreferences? _prefs;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  int _xp = 0;
  int _streak = 0;
  String? _lastCompletedDate;
  bool _questRevealed = false;
  bool _questCompleted = false;
  bool _panicUsed = false;
  String? _hardcoreQuestId;
  String? _completedQuestTextRu;
  String? _completedQuestTextEn;

  List<Quest> _customQuests = [];
  List<Quest> _globalQuests = [];

  String _username = 'Игрок';
  String _avatarAsset = '🥷';
  String _profileTitle = 'Разрушитель реальности';

  final List<Quest> normalQuests = const [
    Quest(
      id: 'normal_01',
      titleRu: 'Микро-победа в реальности',
      titleEn: 'Micro-victory in reality',
      descriptionRu: 'Сделай одно дело, которое откладывал больше недели. Маленькое тоже считается.',
      descriptionEn: 'Do one thing you\'ve been putting off for over a week. Small things count too.',
      xpReward: 20,
      isHardcore: false,
    ),
    Quest(
      id: 'normal_02',
      titleRu: 'Пять минут смелости',
      titleEn: 'Five minutes of courage',
      descriptionRu: 'Напиши человеку, с которым давно хотел связаться. Коротко и честно.',
      descriptionEn: 'Write to someone you wanted to contact for a long time. Short and honest.',
      xpReward: 20,
      isHardcore: false,
    ),
    Quest(
      id: 'normal_03',
      titleRu: 'Касание травы',
      titleEn: 'Touch grass',
      descriptionRu: 'Выйди на улицу на 15 минут без телефона. Заметь 3 детали вокруг.',
      descriptionEn: 'Go outside for 15 minutes without your phone. Notice 3 details around you.',
      xpReward: 20,
      isHardcore: false,
    ),
  ];

  final List<Quest> hardcoreQuests = const [
    Quest(
      id: 'hard_01',
      titleRu: 'Социальный босс-файт',
      titleEn: 'Social Boss Fight',
      descriptionRu: 'Сделай искренний комплимент незнакомцу без кринжа.',
      descriptionEn: 'Give a sincere compliment to a stranger without being cringy.',
      xpReward: 40,
      isHardcore: true,
    ),
    Quest(
      id: 'hard_02',
      titleRu: 'Абсурдный режим героя',
      titleEn: 'Absurd Hero Mode',
      descriptionRu: 'Снииви 30-секундное видео о том, почему сегодняшний день не будет NPC-днем.',
      descriptionEn: 'Record a 30-second video about why today will not be an NPC day.',
      xpReward: 40,
      isHardcore: true,
    ),
  ];

  bool get isLoading => _isLoading;
  int get xp => _xp;
  int get level => _xp ~/ xpPerLevel + 1;
  int get xpIntoLevel => _xp % xpPerLevel;
  double get levelProgress => xpIntoLevel / xpPerLevel;
  int get streak => _streak;
  bool get questRevealed => _questRevealed;
  bool get questCompleted => _questCompleted;
  bool get panicUsed => _panicUsed;
  List<Quest> get customQuests => _customQuests;
  List<Quest> get globalQuests => _globalQuests;
  String get username => _username;
  String get avatarAsset => _avatarAsset;
  String get profileTitle => _profileTitle;

  bool get isOnline => _auth.currentUser != null;

  Stream<List<UserProfile>> get onlineLeaderboard {
    return _firestore
        .collection('users')
        .orderBy('xp', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserProfile.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  String getCompletedText(String lang) {
    if (lang == 'ru') return _completedQuestTextRu ?? currentQuest.titleRu;
    return _completedQuestTextEn ?? currentQuest.titleEn;
  }

  Quest get todayNormalQuest {
    final pool = _customQuests.isNotEmpty 
        ? _customQuests 
        : (_globalQuests.isNotEmpty ? _globalQuests : normalQuests);
    final now = DateTime.now();
    final daySeed = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
    final index = daySeed % pool.length;
    return pool[index];
  }

  Quest get currentQuest {
    if (_hardcoreQuestId != null) {
      return hardcoreQuests.firstWhere(
        (q) => q.id == _hardcoreQuestId,
        orElse: () => hardcoreQuests.first,
      );
    }
    return todayNormalQuest;
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _xp = _prefs?.getInt('xp') ?? 0;
    _streak = _prefs?.getInt('streak') ?? 0;
    _lastCompletedDate = _prefs?.getString('lastCompletedDate');
    _username = _prefs?.getString('username') ?? 'Игрок';
    _avatarAsset = _prefs?.getString('avatarAsset') ?? '🥷';
    _profileTitle = _prefs?.getString('profileTitle') ?? 'Выживший';

    _loadCustomQuests();
    await _loadGlobalQuests();

    if (isOnline) {
      await _syncWithCloud();
    }

    final today = _dateKey(DateTime.now());
    if (_lastCompletedDate != today && _lastCompletedDate != _dateKey(DateTime.now().subtract(const Duration(days: 1)))) {
      _streak = 0;
    }

    if (_lastCompletedDate == today) {
      _questRevealed = true;
      _questCompleted = true;
      _panicUsed = _prefs?.getBool('panicUsed') ?? false;
      _hardcoreQuestId = _prefs?.getString('hardcoreQuestId');
      _completedQuestTextRu = _prefs?.getString('completedQuestTextRu');
      _completedQuestTextEn = _prefs?.getString('completedQuestTextEn');
    } else if (_prefs?.getString('statusDate') == today) {
      _questRevealed = _prefs?.getBool('questRevealed') ?? false;
      _questCompleted = _prefs?.getBool('questCompleted') ?? false;
      _panicUsed = _prefs?.getBool('panicUsed') ?? false;
      _hardcoreQuestId = _prefs?.getString('hardcoreQuestId');
      _completedQuestTextRu = _prefs?.getString('completedQuestTextRu');
      _completedQuestTextEn = _prefs?.getString('completedQuestTextEn');
    } else {
      await _startFreshDay(today);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadGlobalQuests() async {
    try {
      final snapshot = await _firestore.collection('global_quests').get();
      _globalQuests = snapshot.docs.map((doc) {
        final data = doc.data();
        return Quest(
          id: doc.id,
          titleRu: data['titleRu'] ?? '',
          titleEn: data['titleEn'] ?? '',
          descriptionRu: data['descriptionRu'] ?? '',
          descriptionEn: data['descriptionEn'] ?? '',
          xpReward: data['xpReward'] ?? 20,
          isHardcore: data['isHardcore'] ?? false,
        );
      }).toList();
    } catch (e) {
      debugPrint("Ошибка загрузки глобальных квестов: $e");
    }
  }

  Future<void> addGlobalQuest({
    required String titleRu, 
    required String descriptionRu, 
    required int xp,
    bool isHardcore = false,
  }) async {
    try {
      final id = 'global_${DateTime.now().millisecondsSinceEpoch}';
      await _firestore.collection('global_quests').doc(id).set({
        'titleRu': titleRu,
        'titleEn': titleRu,
        'descriptionRu': descriptionRu,
        'descriptionEn': descriptionRu,
        'xpReward': xp,
        'isHardcore': isHardcore,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _loadGlobalQuests();
      notifyListeners();
    } catch (e) {
      debugPrint("Ошибка публикации глобального квеста: $e");
    }
  }

  Future<void> _syncWithCloud() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      _xp = data['xp'] ?? _xp;
      _streak = data['streak'] ?? _streak;
      _username = data['username'] ?? _username;
      _avatarAsset = data['avatarAsset'] ?? _avatarAsset;
      _profileTitle = data['title'] ?? _profileTitle;
      await _saveAll();
    } else {
      await _updateCloudProfile();
    }
  }

  Future<void> updateProfile({required String newName, required String newAvatar, required String newTitle}) async {
    _username = newName;
    _avatarAsset = newAvatar;
    _profileTitle = newTitle;
    notifyListeners();

    await _prefs?.setString('username', _username);
    await _prefs?.setString('avatarAsset', _avatarAsset);
    await _prefs?.setString('profileTitle', _profileTitle);

    if (isOnline) {
      await _updateCloudProfile();
    }
  }

  void _loadCustomQuests() {
    final list = _prefs?.getStringList('custom_quests_keys') ?? [];
    _customQuests = list.map((qStr) {
      final parts = qStr.split('|');
      return Quest(
        id: parts[0],
        titleRu: parts[1],
        titleEn: parts[1],
        descriptionRu: parts[2],
        descriptionEn: parts[2],
        xpReward: int.parse(parts[3]),
        isHardcore: false,
        isCustom: true,
      );
    }).toList();
  }

  Future<void> addCustomQuest(String title, String desc, int xp) async {
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final qStr = '$id|$title|$desc|$xp';
    final list = _prefs?.getStringList('custom_quests_keys') ?? [];
    list.add(qStr);
    await _prefs?.setStringList('custom_quests_keys', list);
    _loadCustomQuests();
    notifyListeners();
  }

  Future<void> deleteCustomQuest(String id) async {
    final list = _prefs?.getStringList('custom_quests_keys') ?? [];
    list.removeWhere((element) => element.startsWith('$id|'));
    await _prefs?.setStringList('custom_quests_keys', list);
    _loadCustomQuests();
    notifyListeners();
  }

  Future<void> revealQuest() async {
    if (_questRevealed) return;
    _questRevealed = true;
    await _prefs?.setBool('questRevealed', true);
    notifyListeners();
  }

  Future<void> usePanicButton() async {
    if (!_questRevealed || _questCompleted || _panicUsed) return;
    final index = DateTime.now().second % hardcoreQuests.length;
    _hardcoreQuestId = hardcoreQuests[index].id;
    _panicUsed = true;
    await _prefs?.setString('hardcoreQuestId', _hardcoreQuestId!);
    await _prefs?.setBool('panicUsed', true);
    notifyListeners();
  }

  Future<void> completeQuest() async {
    if (!_questRevealed || _questCompleted) return;

    final today = _dateKey(DateTime.now());
    final yesterday = _dateKey(DateTime.now().subtract(const Duration(days: 1)));

    _xp += currentQuest.xpReward;
    _questCompleted = true;
    _completedQuestTextRu = currentQuest.titleRu;
    _completedQuestTextEn = currentQuest.titleEn;

    if (_lastCompletedDate == yesterday) {
      _streak += 1;
    } else if (_lastCompletedDate != today) {
      _streak = 1;
    }
    _lastCompletedDate = today;

    await _saveAll();
    if (isOnline) {
      await _updateCloudProfile();
    }
    notifyListeners();
  }

  Future<void> _startFreshDay(String today) async {
    _questRevealed = false;
    _questCompleted = false;
    _panicUsed = false;
    _hardcoreQuestId = null;
    await _prefs?.setString('statusDate', today);
    await _prefs?.setBool('questRevealed', false);
    await _prefs?.setBool('questCompleted', false);
    await _prefs?.setBool('panicUsed', false);
    await _prefs?.remove('hardcoreQuestId');
  }

  Future<void> _saveAll() async {
    await _prefs?.setInt('xp', _xp);
    await _prefs?.setInt('streak', _streak);
    await _prefs?.setString('lastCompletedDate', _lastCompletedDate ?? '');
    await _prefs?.setBool('questCompleted', _questCompleted);
    await _prefs?.setString('completedQuestTextRu', _completedQuestTextRu ?? '');
    await _prefs?.setString('completedQuestTextEn', _completedQuestTextEn ?? '');
    await _prefs?.setString('username', _username);
    await _prefs?.setString('avatarAsset', _avatarAsset);
    await _prefs?.setString('profileTitle', _profileTitle);
  }

  Future<void> _updateCloudProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).set({
      'username': _username,
      'avatarAsset': _avatarAsset,
      'title': _profileTitle,
      'xp': _xp,
      'streak': _streak,
      'lastActive': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _dateKey(DateTime date) => '${date.year}-${date.month}-${date.day}';
}