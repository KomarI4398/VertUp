import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/quest_controller.dart';
import '../providers/settings_provider.dart';
import 'quest_tab.dart';
import 'create_quest_tab.dart';
import 'leaders_tab.dart';
import 'profile_tab.dart';

class AvatarWidget extends StatelessWidget {
  final String asset;
  final double radius;
  final double fontSize;

  const AvatarWidget({
    super.key, 
    required this.asset, 
    this.radius = 50, 
    this.fontSize = 48,
  });

  @override
  Widget build(BuildContext context) {
    final isFile = asset.contains('/') || asset.contains('\\');

    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
      backgroundImage: isFile ? FileImage(File(asset)) : null,
      child: isFile ? null : Text(asset, style: TextStyle(fontSize: fontSize)),
    );
  }
}

class VertUpHome extends StatefulWidget {
  const VertUpHome({super.key});

  @override
  State<VertUpHome> createState() => _VertUpHomeState();
}

class _VertUpHomeState extends State<VertUpHome> {
  int _selectedTab = 0;
  // Добавляем контроллер для управления страницами
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedTab);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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
              : PageView(
                  controller: _pageController,
                  // Отключаем свайп пальцем, чтобы он не конфликтовал с элементами внутри вкладок
                  physics: const NeverScrollableScrollPhysics(), 
                  children: const [
                    QuestTab(),
                    CreateQuestTab(),
                    LeadersTab(),
                    ProfileTab(),
                  ],
                ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        height: 72,
        onDestinationSelected: (index) {
          setState(() => _selectedTab = index);
          // Запускаем плавную анимацию перехода
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutQuart,
          );
        },
        destinations: [
          NavigationDestination(icon: const Icon(Icons.style_outlined), selectedIcon: const Icon(Icons.style), label: settings.translate('Квест', 'Quest')),
          NavigationDestination(icon: const Icon(Icons.build_outlined), selectedIcon: const Icon(Icons.build), label: settings.translate('Крафт', 'Craft')),
          NavigationDestination(icon: const Icon(Icons.leaderboard_outlined), selectedIcon: const Icon(Icons.leaderboard), label: settings.translate('Лидеры', 'Leaders')),
          NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: settings.translate('Профиль', 'Profile')),
        ],
      ),
    );
  }
}