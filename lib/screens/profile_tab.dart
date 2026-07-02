import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/quest_controller.dart';
import '../providers/settings_provider.dart';
import 'home_screen.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  // Функция для открытия ссылки в браузере
  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Не удалось открыть ссылку $urlString');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final controller = context.watch<QuestController>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          AvatarWidget(asset: controller.avatarAsset),
          const SizedBox(height: 16),
          Text(controller.username, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(controller.profileTitle, style: const TextStyle(color: Colors.white54)),
          const Divider(height: 40),
          
          // НАСТРОЙКИ ИНТЕРФЕЙСА
          ListTile(
            leading: const Icon(Icons.translate),
            title: Text(settings.translate('Язык / Language', 'Language / Язык')),
            trailing: Text(settings.currentLanguage.toUpperCase()),
            onTap: () {
              final nextLang = settings.currentLanguage == 'ru' ? 'en' : 'ru';
              settings.setLanguage(nextLang);
            },
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(settings.translate('Тема оформления', 'App Theme')),
            trailing: Text(settings.currentTheme),
            onTap: () {
              final themes = ['dark_cyber', 'dark_sunset', 'dark_chocolate', 'dark_neon'];
              final currentIndex = themes.indexOf(settings.currentTheme);
              final nextIndex = (currentIndex + 1) % themes.length;
              settings.setTheme(themes[nextIndex]);
            },
          ),
          
          const Divider(height: 40),
          
          // БЛОК "О ПРИЛОЖЕНИИ"
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                settings.translate('О приложении', 'About App'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                settings.translate(
                  'VertUp — это интерактивный трекер для геймификации реальной жизни. Выполняйте ежедневные квесты, прокачивайте уровень и соревнуйтесь в общем зачете.',
                  'VertUp is an interactive tracker for gamifying real life. Complete daily quests, level up, and compete in the global leaderboard.',
                ),
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.code_rounded),
            title: Text(settings.translate('Разработчик', 'Developer')),
            subtitle: const Text('KomarI4398'),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () => _launchURL('https://github.com/KomarI4398'),
          ),
         // ... (остальные импорты)
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: Text(settings.translate('Версия', 'Version')),
            trailing: const Text('2.0.0', style: TextStyle(color: Colors.white30)),
          ),
// ...
        ],
      ),
    );
  }
}