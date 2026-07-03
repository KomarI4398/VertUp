import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:govnolda/providers/quest_controller.dart';
import 'package:govnolda/providers/settings_provider.dart';
import 'package:govnolda/screens/home_screen.dart'; // Для AvatarWidget

class LeadersTab extends StatefulWidget {
  const LeadersTab({super.key});

  @override
  State<LeadersTab> createState() => _LeadersTabState();
}

class _LeadersTabState extends State<LeadersTab> {
  final TextEditingController _squadIdController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _squadIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final controller = context.watch<QuestController>();
    
    final String? currentSquadId = controller.currentSquadId;
    final Map<String, dynamic> members = controller.squadMembers;
    final int squadStreak = controller.squadStreak;
    final String squadQuestTitle = controller.squadQuestTitle;
    final String squadQuestDesc = controller.squadQuestDesc;

    // --- ЭКРАН 1: ЕСЛИ ИГРОК ЕЩЕ НЕ В КОМАНДЕ ---
    if (currentSquadId == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              settings.translate('👥 Командный синдикат', '👥 Team Syndicate'), 
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              settings.translate(
                'Объединяйтесь с друзьями, выполняйте квесты вместе и удерживайте общий огонёк стрика!', 
                'Unite with friends, complete quests together and maintain a shared streak fire!'
              ),
              style: const TextStyle(color: Colors.white60, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            // Карточка создания команды
            Card(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Icon(Icons.group_add_outlined, size: 48, color: Colors.greenAccent),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(45),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isProcessing ? null : () async {
                        setState(() => _isProcessing = true);
                        String? newId = await controller.createSquad();
                        setState(() => _isProcessing = false);
                        if (newId != null && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${settings.translate('Команда создана! Код', 'Team created! Code')}: $newId')),
                          );
                        }
                      },
                      child: _isProcessing 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : Text(settings.translate('СОЗДАТЬ СВОЮ КОМАНДУ', 'CREATE OWN TEAM')),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(child: Divider(color: Colors.white24)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(settings.translate('ИЛИ', 'OR'), style: const TextStyle(color: Colors.white38)),
                ),
                const Expanded(child: Divider(color: Colors.white24)),
              ],
            ),
            const SizedBox(height: 20),

            // Карточка подключения
            Card(
              color: Colors.white.withOpacity(0.02),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white12)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      settings.translate('Войти по коду друга:', 'Join via friend\'s code:'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _squadIdController,
                      decoration: InputDecoration(
                        hintText: 'Например: SQ-123456',
                        hintStyle: const TextStyle(color: Colors.white30),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      style: const TextStyle(color: Colors.white),
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white24,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(45),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isProcessing ? null : () async {
                        final code = _squadIdController.text.trim();
                        if (code.isEmpty) return;

                        setState(() => _isProcessing = true);
                        bool joined = await controller.joinSquad(code);
                        setState(() => _isProcessing = false);

                        if (mounted) {
                          if (joined) {
                            _squadIdController.clear();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(settings.translate('Команда не найдена!', 'Team not found!'))),
                            );
                          }
                        }
                      },
                      child: _isProcessing 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(settings.translate('ПОДКЛЮЧИТЬСЯ', 'JOIN TEAM')),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // --- ЭКРАН 2: ЕСЛИ ИГРОК УЖЕ В КОМАНДЕ ---
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                settings.translate('🔥 Командный Контракт', '🔥 Team Contract'), 
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                tooltip: settings.translate('Выйти из команды', 'Leave team'),
                onPressed: () => controller.leaveSquad(),
              ),
            ],
          ),
          
          // Выводим ID команды сверху, чтобы им можно было поделиться
          SelectableText(
            '${settings.translate('КОД ДЛЯ ДРУЗЕЙ', 'CODE FOR FRIENDS')}: $currentSquadId',
            style: const TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          Card(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        '${settings.translate('ОБЩИЙ СТРИК', 'TOTAL STREAK')}: 🔥 $squadStreak',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: Colors.white24),
                  Text(
                    squadQuestTitle.isEmpty ? settings.translate('Загрузка контракта...', 'Loading contract...') : squadQuestTitle,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    squadQuestDesc,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          Text(
            settings.translate('👥 Статус синдикации', '👥 Sync Status'), 
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white60)
          ),
          const SizedBox(height: 12),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.3, 
            ),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final memberId = members.keys.elementAt(index);
              final memberData = members[memberId] as Map<String, dynamic>;
              
              final String name = memberData['name'] ?? 'Agent';
              final bool isReady = memberData['ready'] ?? false;
              final String avatar = memberData['avatar'] ?? '🥷';

              return Container(
                decoration: BoxDecoration(
                  color: isReady ? Colors.green.withOpacity(0.08) : Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isReady ? Colors.greenAccent.withOpacity(0.4) : Colors.white12,
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        AvatarWidget(
                          asset: avatar, 
                          radius: 18, 
                          fontSize: 14,
                        ),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isReady ? Colors.greenAccent : Colors.redAccent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isReady ? Colors.white : Colors.white60,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            isReady ? 'Ready 🔥' : 'In progress...',
                            style: TextStyle(
                              color: isReady ? Colors.greenAccent : Colors.white38, 
                              fontSize: 11
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 30),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              controller.completeSquadQuest();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(settings.translate('Твой огонёк зажжён! Ждём команду.', 'Your fire is lit! Waiting for team.'))),
              );
            },
            icon: const Icon(Icons.check_circle),
            label: Text(settings.translate('Я ВЫПОЛНИЛ КОМАНДНЫЙ КВЕСТ', 'I COMPLETED TEAM QUEST')),
          ),
        ],
      ),
    );
  }
}