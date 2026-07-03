import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:govnolda/models/quest.dart';
import 'package:govnolda/models/user_profile.dart';

class QuestController extends ChangeNotifier {
  static const int xpPerLevel = 100;

  SharedPreferences? _prefs;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  StreamSubscription<DocumentSnapshot>? _squadSubscription;

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

  // --- ДИНАМИЧЕСКИЕ ПЕРЕМЕННЫЕ ДЛЯ КОМАНДНОГО ОГОНЬКА ---
  String? _currentSquadId; // Теперь грузится из памяти или равен null, если соло
  Map<String, dynamic> _squadMembers = {};
  int _squadStreak = 0;
  String _squadQuestTitle = "";
  String _squadQuestDesc = "";

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
      descriptionRu: 'Сними 30-секундное видео о том, почему сегодняшний день не будет NPC-днем.',
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

  // --- ГЕТТЕРЫ ДЛЯ КОМАНДНОГО ИНТЕРФЕЙСА ---
  String? get currentSquadId => _currentSquadId;
  Map<String, dynamic> get squadMembers => _squadMembers;
  int get squadStreak => _squadStreak;
  String get squadQuestTitle => _squadQuestTitle;
  String get squadQuestDesc => _squadQuestDesc;

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
    _currentSquadId = _prefs?.getString('currentSquadId'); // Подгружаем сохраненную комнату

    _loadCustomQuests();
    await _loadGlobalQuests();

    if (isOnline) {
      await _syncWithCloud();
      listenToSquadUpdates(); 
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

  // --- ДИНАМИЧЕСКОЕ СОЗДАНИЕ НОВОГО СКВАДА ---
  Future<String?> createSquad() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    // Генерируем красивый короткий ID: SQ-174829
    final String newSquadId = 'SQ-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    
    await _firestore.collection('squads').doc(newSquadId).set({
      'questTitle': todayNormalQuest.titleRu,
      'questDesc': todayNormalQuest.descriptionRu,
      'streak': 0,
      'lastUpdateDate': '',
      'members': {
        user.uid: {
          'name': _username,
          'avatar': _avatarAsset,
          'ready': false,
        }
      }
    });

    _currentSquadId = newSquadId;
    await _prefs?.setString('currentSquadId', newSquadId);
    listenToSquadUpdates();
    return newSquadId;
  }

  // --- РАБОЧИЙ ВХОД В СУЩЕСТВУЮЩИЙ СКВАД ПО ID КОДУ ---
  Future<bool> joinSquad(String squadId) async {
    final user = _auth.currentUser;
    if (user == null || squadId.trim().isEmpty) return false;

    final docRef = _firestore.collection('squads').doc(squadId.trim());
    
    try {
      bool success = false;
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        Map<String, dynamic> members = Map<String, dynamic>.from(snapshot.data()!['members'] ?? {});
        
        members[user.uid] = {
          'name': _username,
          'avatar': _avatarAsset,
          'ready': false,
        };

        transaction.update(docRef, {'members': members});
        success = true;
      });

      if (success) {
        _currentSquadId = squadId.trim();
        await _prefs?.setString('currentSquadId', _currentSquadId!);
        listenToSquadUpdates();
        return true;
      }
    } catch (e) {
      debugPrint("Ошибка подключения к скваду: $e");
    }
    return false;
  }

  // --- ПОЛНЫЙ ВЫХОД ИЗ ТЕКУЩЕЙ КОМАНДЫ ---
  Future<void> leaveSquad() async {
    final user = _auth.currentUser;
    if (user == null || _currentSquadId == null) return;

    _squadSubscription?.cancel();
    final docRef = _firestore.collection('squads').doc(_currentSquadId);

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        Map<String, dynamic> members = Map<String, dynamic>.from(snapshot.data()!['members'] ?? {});
        members.remove(user.uid);

        if (members.isEmpty) {
          transaction.delete(docRef); // Если никого нет — удаляем комнату
        } else {
          transaction.update(docRef, {'members': members});
        }
      });
    } catch (e) {
      debugPrint("Ошибка при выходе из группы: $e");
    }

    _currentSquadId = null;
    _squadMembers = {};
    _squadStreak = 0;
    _squadQuestTitle = "";
    _squadQuestDesc = "";
    await _prefs?.remove('currentSquadId');
    notifyListeners();
  }

  // --- СИНХРОНИЗАЦИЯ ОБНОВЛЕНИЙ ИЗ FIRESTORE ---
  void listenToSquadUpdates() {
    if (!isOnline || _currentSquadId == null) return;
    _squadSubscription?.cancel();

    _squadSubscription = _firestore
        .collection('squads')
        .doc(_currentSquadId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        _squadStreak = data['streak'] ?? 0;
        _squadQuestTitle = data['questTitle'] ?? "Общий контракт не выбран";
        _squadQuestDesc = data['questDesc'] ?? "Ждем генерации лидером...";
        _squadMembers = data['members'] ?? {};
        notifyListeners(); 
      }
    });
  }

  // --- ОБНОВЛЕНИЕ СТАТУСА ВЫПОЛНЕНИЯ КВЕСТА ---
  Future<void> completeSquadQuest() async {
    final user = _auth.currentUser;
    if (user == null || _currentSquadId == null || _currentSquadId!.isEmpty) return;

    final todayStr = _dateKey(DateTime.now());
    final docRef = _firestore.collection('squads').doc(_currentSquadId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      Map<String, dynamic> currentMembers = Map<String, dynamic>.from(data['members'] ?? {});
      
      if (currentMembers.containsKey(user.uid)) {
        currentMembers[user.uid]['ready'] = true;
        transaction.update(docRef, {'members': currentMembers});
      }

      bool allReady = true;
      currentMembers.forEach((key, value) {
        if (value['ready'] == false) allReady = false;
      });

      final String lastUpdateDate = data['lastUpdateDate'] ?? '';

      if (allReady && lastUpdateDate != todayStr) {
        int currentStreak = data['streak'] ?? 0;
        transaction.update(docRef, {
          'streak': currentStreak + 1,
          'lastUpdateDate': todayStr,
        });
        
        // Сбрасываем флаги готовности на следующий день
        currentMembers.forEach((key, value) {
          currentMembers[key]['ready'] = false;
        });
        transaction.update(docRef, {'members': currentMembers});
      }
    });
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
      // Если обновился профиль, то обновляем данные и в текущем скваде
      if (_currentSquadId != null) {
        final user = _auth.currentUser;
        if (user != null) {
          final docRef = _firestore.collection('squads').doc(_currentSquadId);
          _firestore.runTransaction((transaction) async {
            final snap = await transaction.get(docRef);
            if (snap.exists) {
              Map<String, dynamic> members = Map<String, dynamic>.from(snap.data()!['members'] ?? {});
              if (members.containsKey(user.uid)) {
                members[user.uid]['name'] = _username;
                members[user.uid]['avatar'] = _avatarAsset;
                transaction.update(docRef, {'members': members});
              }
            }
          });
        }
      }
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

  @override
  void dispose() {
    _squadSubscription?.cancel();
    super.dispose();
  }
}