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

  // Шторка выбора аватарки
  void _showAvatarPicker(BuildContext context, QuestController controller) {
    final List<String> availableAvatars = [
      '🥷', '👾', '🤖', '🦊', '🐯', '🦸', '🐱', '🐺', 
      '🧙', '🧛', '👹', '👽', '💀', '🤡', '🐼', '🚀'
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Выбери аватар',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                ),
                itemCount: availableAvatars.length,
                itemBuilder: (context, index) {
                  final avatar = availableAvatars[index];
                  final isSelected = controller.avatarAsset == avatar;

                  return GestureDetector(
                    onTap: () {
                      controller.updateProfile(
                        newName: controller.username,
                        newAvatar: avatar,
                        newTitle: controller.profileTitle,
                      );
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2) 
                            : Colors.black12,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected 
                              ? Theme.of(context).colorScheme.primary 
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          avatar,
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final controller = context.watch<QuestController>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Обернули аватар в кликабельную область
          GestureDetector(
            onTap: () => _showAvatarPicker(context, controller),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                AvatarWidget(asset: controller.avatarAsset),
                // Маленькая иконка карандаша поверх авы, намекающая на редактирование
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.edit, size: 14, color: Colors.black),
                ),
              ],
            ),
          ),
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
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: Text(settings.translate('Версия', 'Version')),
            trailing: const Text('2.1.0', style: TextStyle(color: Colors.white30)),
          ),
        ],
      ),
    );
  }
}