import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/quest_controller.dart';
import '../providers/settings_provider.dart';

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
            duration: const Duration(milliseconds: 500),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (Widget child, Animation<double> animation) {
              return ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: controller.questRevealed 
                ? const _QuestFace(key: ValueKey('Face')) 
                : const _QuestBack(key: ValueKey('Back')),
          ),
          
          const SizedBox(height: 20),
          const _QuestActions(),
          
          const SizedBox(height: 24),
          Text(
            settings.translate('Приложение верит в вашу честность... 🎭', 'The app believes in your honesty... 🎭'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.white30, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

class _QuestBack extends StatelessWidget {
  const _QuestBack({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final controller = context.watch<QuestController>();

    return Container(
      padding: const EdgeInsets.all(24),
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E2A24), Color(0xFF141A29)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_open_rounded, size: 48, color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: controller.revealQuest,
              child: Text(settings.translate('Открыть квест', 'Reveal Quest')),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestFace extends StatelessWidget {
  const _QuestFace({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final controller = context.watch<QuestController>();
    final quest = controller.currentQuest;

    return Container(
      padding: const EdgeInsets.all(24),
      constraints: const BoxConstraints(minHeight: 240),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color, 
        borderRadius: BorderRadius.circular(24), 
        border: Border.all(
          color: quest.isHardcore ? Colors.redAccent.withOpacity(0.3) : Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(quest.isHardcore ? Icons.bolt_rounded : Icons.star_rounded, color: quest.isHardcore ? Colors.redAccent : Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                quest.isHardcore ? settings.translate('🔥 ХАРДКОР', '🔥 HARDCORE') : settings.translate('🎲 КВЕСТ ДНЯ', '🎲 QUEST OF THE DAY'),
                style: TextStyle(fontWeight: FontWeight.bold, color: quest.isHardcore ? Colors.redAccent : Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(quest.getTitle(settings.currentLanguage), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
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
          child: Text(controller.panicUsed 
              ? settings.translate('Паника активирована', 'Panic Active') 
              : settings.translate('Мне слабо (Паника)', 'I Chicken Out (Panic)')),
        ),
      ],
    );
  }
}