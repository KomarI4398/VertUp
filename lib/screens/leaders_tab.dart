import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:govnolda/providers/quest_controller.dart';
import 'package:govnolda/providers/settings_provider.dart';
import 'package:govnolda/models/user_profile.dart'; // <--- Добавь эту строчку
import 'package:govnolda/screens/home_screen.dart';

class LeadersTab extends StatelessWidget {
  const LeadersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final controller = context.watch<QuestController>();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(settings.translate('🏆 Зал славы', '🏆 Leaderboard'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<UserProfile>>(
              stream: controller.onlineLeaderboard,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text(settings.translate('Лидеров пока нет', 'No leaders yet')));
                }

                final leaders = snapshot.data!;
                return ListView.builder(
                  itemCount: leaders.length,
                  itemBuilder: (context, index) {
                    final leader = leaders[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: AvatarWidget(
                          asset: leader.avatarAsset, 
                          radius: 20, 
                          fontSize: 18,
                        ),
                        title: Text(leader.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(leader.title, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${leader.xp} XP', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                            Text('🔥 ${leader.streak}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}