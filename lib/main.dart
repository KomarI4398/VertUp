import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Добавили для копирования ссылки в буфер
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => QuestController()..init()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: const VertUpApp(),
    ),
  );
}

// --- PROVIDER НАСТРОЕК (ПЕРЕВОД И ТЕМЫ) ---
class SettingsProvider extends ChangeNotifier {
  String _currentTheme = 'dark_cyber';
  String _currentLanguage = 'ru';
  
  String get currentTheme => _currentTheme;
  String get currentLanguage => _currentLanguage;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _currentTheme = prefs.getString('theme_key') ?? 'dark_cyber';
    _currentLanguage = prefs.getString('lang_key') ?? 'ru';
    notifyListeners();
  }

  Future<void> setTheme(String themeName) async {
    _currentTheme = themeName;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_key', themeName);
  }

  Future<void> setLanguage(String langCode) async {
    _currentLanguage = langCode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang_key', langCode);
  }

  String translate(String keyRu, String keyEn) {
    return _currentLanguage == 'ru' ? keyRu : keyEn;
  }
}

class VertUpApp extends StatelessWidget {
  const VertUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    
    Color seed = const Color(0xFF7CFFB2);
    Color scaffoldBg = const Color(0xFF121212);
    Color cardBg = const Color(0xFF1E1E1E);

    if (settings.currentTheme == 'dark_sunset') {
      seed = const Color(0xFFFF6B9A);
    } else if (settings.currentTheme == 'dark_chocolate') {
      seed = const Color(0xFFD7CCC8);
      scaffoldBg = const Color(0xFF2D221E);
      cardBg = const Color(0xFF3E312C);
    } else if (settings.currentTheme == 'dark_neon') {
      seed = const Color(0xFF00E5FF);
      scaffoldBg = const Color(0xFF0A0E17);
      cardBg = const Color(0xFF141A29);
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VertUp',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: scaffoldBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
          surface: cardBg,
          primary: seed,
          secondary: seed.withValues(alpha: 0.7),
        ),
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1.1),
          headlineMedium: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.8),
          titleLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.4),
          titleMedium: TextStyle(fontWeight: FontWeight.w700),
          bodyMedium: TextStyle(height: 1.35),
        ),
        cardTheme: CardThemeData(
          color: cardBg,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: scaffoldBg.withValues(alpha: 0.5),
          indicatorColor: seed.withValues(alpha: 0.16),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            return const VertUpHome();
          }
          return const AuthScreen();
        },
      ),
    );
  }
}

class Quest {
  final String id;
  final String titleRu;
  final String titleEn;
  final String descriptionRu;
  final String descriptionEn;
  final int xpReward;
  final bool isHardcore;
  final bool isCustom;

  const Quest({
    required this.id,
    required this.titleRu,
    required this.titleEn,
    required this.descriptionRu,
    required this.descriptionEn,
    required this.xpReward,
    required this.isHardcore,
    this.isCustom = false,
  });

  String getTitle(String lang) => lang == 'ru' ? titleRu : titleEn;
  String getDescription(String lang) => lang == 'ru' ? descriptionRu : descriptionEn;
}

class UserProfile {
  final String uid;
  final String username;
  final String avatarAsset;
  final String title;
  final int xp;
  final int streak;

  UserProfile({
    required this.uid,
    required this.username,
    required this.avatarAsset,
    required this.title,
    required this.xp,
    required this.streak,
  });

  factory UserProfile.fromFirestore(Map<String, dynamic> data, String id) {
    return UserProfile(
      uid: id,
      username: data['username'] ?? 'Anonymous NPC',
      avatarAsset: data['avatarAsset'] ?? 'default',
      title: data['title'] ?? 'Новичок',
      xp: data['xp'] ?? 0,
      streak: data['streak'] ?? 0,
    );
  }
}

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

  String _username = 'Игрок';
  String _avatarAsset = 'default';
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
    final pool = _customQuests.isNotEmpty ? _customQuests : normalQuests;
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
    _avatarAsset = _prefs?.getString('avatarAsset') ?? 'default';
    _profileTitle = _prefs?.getString('profileTitle') ?? 'Выживший';

    _loadCustomQuests();

    if (isOnline) {
      await _syncWithCloud();
    }

    final today = _dateKey(DateTime.now());
    if (_lastCompletedDate != today && _lastCompletedDate != _dateKey(DateTime.now().subtract(const Duration(days: 1)))) {
      _streak = 0;
    }

    if (_prefs?.getString('statusDate') == today) {
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

// --- ГЛАВНЫЙ ЭКРАН ---
class VertUpHome extends StatefulWidget {
  const VertUpHome({super.key});

  @override
  State<VertUpHome> createState() => _VertUpHomeState();
}

class _VertUpHomeState extends State<VertUpHome> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<QuestController>();
    final settings = context.watch<SettingsProvider>();

    Color radialColor = const Color(0xFF1E2A24);
    if (settings.currentTheme == 'dark_sunset') radialColor = const Color(0xFF381E24);
    if (settings.currentTheme == 'dark_chocolate') radialColor = const Color(0xFF3E2723);
    if (settings.currentTheme == 'dark_neon') radialColor = const Color(0xFF0D1B2A);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.2,
            colors: [radialColor, Theme.of(context).scaffoldBackgroundColor],
          ),
        ),
        child: SafeArea(
          child: controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildCurrentTab(),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        height: 72,
        onDestinationSelected: (index) => setState(() => _selectedTab = index),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.style_outlined), selectedIcon: const Icon(Icons.style), label: settings.translate('Квест', 'Quest')),
          NavigationDestination(icon: const Icon(Icons.build_outlined), selectedIcon: const Icon(Icons.build), label: settings.translate('Крафт', 'Craft')),
          NavigationDestination(icon: const Icon(Icons.leaderboard_outlined), selectedIcon: const Icon(Icons.leaderboard), label: settings.translate('Лидеры', 'Leaders')),
          NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: settings.translate('Профиль', 'Profile')),
        ],
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_selectedTab) {
      case 0: return const QuestTab();
      case 1: return const CreateQuestTab();
      case 2: return const LeadersTab();
      case 3: return const ProfileTab();
      default: return const QuestTab();
    }
  }
}

// --- ВКЛАДКА КВЕСТОВ ---
class QuestTab extends StatelessWidget {
  const QuestTab({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final controller = context.watch<QuestController>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.casino_rounded, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('VertUp', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -1)),
                    Text('Level up your real life', style: TextStyle(color: Colors.white54)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('🔥 ${settings.translate('Серия: ', 'Streak: ')}${controller.streak}', style: const TextStyle(fontSize: 18, color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('⭐ ${settings.translate('Уровень: ', 'Lvl: ')}${controller.level}', style: const TextStyle(fontSize: 18, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(value: controller.levelProgress, minHeight: 8),
                ),
                const SizedBox(height: 8),
                Text('${controller.xpIntoLevel}/100 XP', style: const TextStyle(color: Colors.white54)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: controller.questRevealed ? const _QuestFace() : const _QuestBack(),
          ),
          const SizedBox(height: 20),
          const _QuestActions(),
          
          // --- НАДПИСЬ О ЧЕСТНОСТИ (НОВОЕ!) ---
          const SizedBox(height: 24),
          Text(
            settings.translate(
              'Приложение верит в вашу честность... 🎭', 
              'The app believes in your honesty... 🎭'
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13, 
              color: Colors.white30, 
              fontStyle: FontStyle.italic,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestBack extends StatelessWidget {
  const _QuestBack();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final controller = context.watch<QuestController>();

    return Container(
      padding: const EdgeInsets.all(24),
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(colors: [Color(0xFF1E2A24), Color(0xFF141A29)]),
      ),
      child: Center(
        child: ElevatedButton(
          onPressed: controller.revealQuest,
          child: Text(settings.translate('Открыть квест', 'Reveal Quest')),
        ),
      ),
    );
  }
}

class _QuestFace extends StatelessWidget {
  const _QuestFace();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final controller = context.watch<QuestController>();
    final quest = controller.currentQuest;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color, 
        borderRadius: BorderRadius.circular(24), 
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quest.isHardcore ? settings.translate('🔥 ХАРДКОР', '🔥 HARDCORE') : settings.translate('🎲 КВЕСТ ДНЯ', '🎲 QUEST OF THE DAY'),
            style: TextStyle(fontWeight: FontWeight.bold, color: quest.isHardcore ? Colors.redAccent : Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 12),
          Text(quest.getTitle(settings.currentLanguage), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(quest.getDescription(settings.currentLanguage), style: const TextStyle(fontSize: 16, color: Colors.white70)),
        ],
      ),
    );
  }
}

class _QuestActions extends StatelessWidget {
  const _QuestActions();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final controller = context.watch<QuestController>();

    if (!controller.questRevealed) return const SizedBox();

    if (controller.questCompleted) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            '🎉 ${settings.translate('Выполнено: ', 'Completed: ')} "${controller.getCompletedText(settings.currentLanguage)}"',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: controller.completeQuest,
          child: Text(settings.translate('Выполнено', 'Complete')),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: controller.panicUsed ? null : controller.usePanicButton,
          child: Text(controller.panicUsed ? settings.translate('Паника активирована', 'Panic Active') : settings.translate('Мне слабо (Паника)', 'I Chicken Out (Panic)')),
        ),
      ],
    );
  }
}

// --- ВКЛАДКА КРАФТА ---
class CreateQuestTab extends StatefulWidget {
  const CreateQuestTab({super.key});

  @override
  State<CreateQuestTab> createState() => _CreateQuestTabState();
}

class _CreateQuestTabState extends State<CreateQuestTab> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  int _selectedXp = 20;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final controller = context.watch<QuestController>();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          settings.translate('Крафт Квестов', 'Quest Crafting'),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: settings.translate('Название квеста', 'Quest Title'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: settings.translate('Что нужно сделать?', 'Description'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(settings.translate('Награда:', 'Reward:'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<int>(
                      value: _selectedXp,
                      items: [20, 30, 40, 50].map((xp) => DropdownMenuItem(value: xp, child: Text('$xp XP'))).toList(),
                      onChanged: (val) => setState(() => _selectedXp = val ?? 20),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    if (_titleController.text.isNotEmpty && _descController.text.isNotEmpty) {
                      controller.addCustomQuest(_titleController.text, _descController.text, _selectedXp);
                      _titleController.clear();
                      _descController.clear();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(settings.translate('Квест добавлен!', 'Quest added!'))));
                    }
                  },
                  child: Text(settings.translate('Создать квест', 'Create Quest')),
                )
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          settings.translate('Твои кастомные квесты:', 'Your Custom Quests:'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (controller.customQuests.isEmpty)
          Text(settings.translate('Пул пуст.', 'Pool is empty.')),
        ...controller.customQuests.map((q) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(q.titleRu),
            subtitle: Text('${q.descriptionRu} (${q.xpReward} XP)'),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () => controller.deleteCustomQuest(q.id),
            ),
          ),
        )),
      ],
    );
  }
}

// --- ВКЛАДКА ЛИДЕРОВ ---
class LeadersTab extends StatelessWidget {
  const LeadersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<QuestController>();
    final settings = context.watch<SettingsProvider>();

    if (!controller.isOnline) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            settings.translate('Войдите в аккаунт, чтобы увидеть таблицу лидеров.', 'Sign in to view the leaderboard.'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return StreamBuilder<List<UserProfile>>(
      stream: controller.onlineLeaderboard,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Ошибка: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final board = snapshot.data ?? [];
        if (board.isEmpty) return Center(child: Text(settings.translate('Таблица лидеров пуста', 'Leaderboard is empty')));

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: board.length,
          itemBuilder: (context, index) {
            final player = board[index];
            final bool isCurrentUser = player.uid == FirebaseAuth.instance.currentUser?.uid;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              color: isCurrentUser ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : null,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isCurrentUser ? Theme.of(context).colorScheme.primary : null,
                  child: Text('${index + 1}', style: TextStyle(color: isCurrentUser ? Colors.black : null)),
                ),
                title: Text(player.username, style: TextStyle(fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal)),
                subtitle: Text('🔥 Серия: ${player.streak} | ${player.title}'),
                trailing: Text('${player.xp} XP', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            );
          },
        );
      },
    );
  }
}

// --- ВКЛАДКА ПРОФИЛЯ ---
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final controller = context.watch<QuestController>();
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          settings.translate('Твой Профиль', 'Your Profile'),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1),
        ),
        const SizedBox(height: 16),
        Card(
          color: colorScheme.primary.withValues(alpha: 0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: colorScheme.primary,
                      child: const Icon(Icons.person, size: 40, color: Colors.black),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(controller.username, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          Text(controller.profileTitle, style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _showEditProfileDialog(context, controller, settings),
                      icon: const Icon(Icons.edit_note_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMiniStat('Level', controller.level.toString(), Icons.star_border_rounded),
                    _buildMiniStat('XP', controller.xp.toString(), Icons.bolt_rounded),
                    _buildMiniStat('Streak', controller.streak.toString(), Icons.local_fire_department_rounded),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(settings.translate('Настройки', 'App Settings'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.language_rounded),
                title: Text(settings.translate('Язык приложения', 'Language')),
                trailing: Text(settings.currentLanguage == 'ru' ? 'РУ' : 'EN'),
                onTap: () => settings.setLanguage(settings.currentLanguage == 'ru' ? 'en' : 'ru'),
              ),
              const Divider(height: 1, indent: 60),
              ListTile(leading: const Icon(Icons.palette_rounded), title: Text(settings.translate('Тема интерфейса', 'UI Theme'))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ThemeButton(label: 'Cyber', color: const Color(0xFF7CFFB2), isSelected: settings.currentTheme == 'dark_cyber', onTap: () => settings.setTheme('dark_cyber')),
                    _ThemeButton(label: 'Sunset', color: const Color(0xFFFF6B9A), isSelected: settings.currentTheme == 'dark_sunset', onTap: () => settings.setTheme('dark_sunset')),
                    _ThemeButton(label: 'Neon', color: const Color(0xFF00E5FF), isSelected: settings.currentTheme == 'dark_neon', onTap: () => settings.setTheme('dark_neon')),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // --- БЛОК «О ПРИЛОЖЕНИИ» С ТВОИМ GITHUB (НОВОЕ!) ---
        const SizedBox(height: 24),
        Text(settings.translate('О приложении', 'About App'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: Text(settings.translate('Версия', 'Version')),
                trailing: const Text('1.0.0', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white60)),
              ),
              const Divider(height: 1, indent: 60),
              ListTile(
                leading: const Icon(Icons.code_rounded, color: Colors.purpleAccent),
                title: Text(settings.translate('Разработчик (GitHub)', 'Developer (GitHub)')),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () => _showGitHubDialog(context, settings),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: Text(settings.translate('Выйти из аккаунта', 'Logout'), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onTap: () async => await FirebaseAuth.instance.signOut(),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.white54),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white54)),
      ],
    );
  }

  void _showEditProfileDialog(BuildContext context, QuestController controller, SettingsProvider settings) {
    final nameController = TextEditingController(text: controller.username);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(settings.translate('Изменить имя', 'Edit Name')),
        content: TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Никнейм')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                controller.updateProfile(newName: nameController.text, newAvatar: 'default', newTitle: controller.profileTitle);
                Navigator.pop(context);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  // Окно для GitHub ссылки
  void _showGitHubDialog(BuildContext context, SettingsProvider settings) {
    const String url = 'https://github.com/korami4398-ctrl';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.terminal_rounded, color: Colors.purpleAccent),
            const SizedBox(width: 10),
            Text(settings.translate('Профиль автора', 'Author\'s Profile')),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ссылка на проект и автора:', style: TextStyle(color: Colors.white70)),
            SizedBox(height: 10),
            SelectableText(
              url,
              style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(settings.translate('Ссылка скопирована!', 'Link copied!'))),
              );
              Navigator.pop(context);
            },
            child: Text(settings.translate('Скопировать', 'Copy Link')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeButton({required this.label, required this.color, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : Colors.white.withValues(alpha: 0.08), width: 2),
        ),
        child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? color : Colors.white70)),
      ),
    );
  }
}

// --- ЭКРАН АВТОРИЗАЦИИ ---
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isSignUp = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();

    if (email.isEmpty || password.isEmpty || (_isSignUp && username.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заполните все поля')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isSignUp) {
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
        if (userCredential.user != null) {
          await context.read<QuestController>().updateProfile(newName: username, newAvatar: 'default', newTitle: 'Новичок');
        }
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
        await context.read<QuestController>().init();
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Произошла ошибка';
      if (e.code == 'user-not-found') message = 'Пользователь не найден';
      if (e.code == 'wrong-password') message = 'Неверный пароль';
      if (e.code == 'email-already-in-use') message = 'Этот Email уже занят';
      if (e.code == 'weak-password') message = 'Слишком слабый пароль (мин. 6 символов)';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('VertUp', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1), textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  Text(_isSignUp ? 'Регистрация профиля' : 'Вход в систему', style: const TextStyle(fontSize: 18, color: Colors.white54), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  if (_isSignUp) ...[
                    TextField(controller: _usernameController, decoration: InputDecoration(labelText: 'Игровой никнейм', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                    const SizedBox(height: 12),
                  ],
                  TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'Email', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  const SizedBox(height: 12),
                  TextField(controller: _passwordController, obscureText: true, decoration: InputDecoration(labelText: 'Пароль', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  const SizedBox(height: 20),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : FilledButton(onPressed: _submit, child: Text(_isSignUp ? 'Создать аккаунт' : 'Войти')),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() => _isSignUp = !_isSignUp),
                    child: Text(_isSignUp ? 'Уже есть аккаунт? Войти' : 'Нет аккаунта? Зарегистрироваться'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}