import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/quest_controller.dart';
import '../providers/settings_provider.dart';
import '../services/ai_service.dart';
import '../models/quest.dart';

class CreateQuestTab extends StatefulWidget {
  const CreateQuestTab({super.key});

  @override
  State<CreateQuestTab> createState() => _CreateQuestTabState();
}

class _CreateQuestTabState extends State<CreateQuestTab> {
  final AIService _aiService = AIService();
  
  String _selectedCategory = 'random'; 
  List<String> _excludedCategories = []; 
  
  bool _isGenerating = false;
  Quest? _generatedQuest;

  void _startGeneration() async {
    final controller = context.read<QuestController>();
    setState(() {
      _isGenerating = true;
      _generatedQuest = null;
    });

    try {
      final quest = await _aiService.generateQuest(
        userLevel: controller.level, 
        userTitle: controller.profileTitle,
        selectedCategory: _selectedCategory,
        excludedCategories: _excludedCategories,
      );
      setState(() => _generatedQuest = quest);
    } catch (e) {
      // Красиво вырезаем "Exception: " из начала ошибки, если она прилетела от лимита
      final cleanErrorMessage = e.toString().replaceAll('Exception: ', '');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cleanErrorMessage),
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final controller = context.read<QuestController>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            settings.translate('ГЕНЕРАЦИЯ КВЕСТОВ', 'QUEST CRAFTING'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.5),
          ),
          const SizedBox(height: 20),

          Card(
            color: Colors.white.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Выбери вектор прокачки:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ChoiceChip(
                    label: const Text('🎲 Полный Рандом'),
                    selected: _selectedCategory == 'random',
                    onSelected: (val) => setState(() => _selectedCategory = 'random'),
                  ),
                  const SizedBox(height: 10),
                  const Divider(),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AIService.categories.entries.map((entry) {
                      return ChoiceChip(
                        label: Text(entry.value),
                        selected: _selectedCategory == entry.key,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = selected ? entry.key : 'random';
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 15),

          if (_selectedCategory == 'random')
            Card(
              color: Colors.red.withOpacity(0.02),
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.red.withOpacity(0.2)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("🚫 Исключить из рандома (если не можешь выполнить):", 
                      style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: AIService.categories.entries.map((entry) {
                        final isExcluded = _excludedCategories.contains(entry.key);
                        return FilterChip(
                          label: Text(entry.value, style: TextStyle(fontSize: 12, color: isExcluded ? Colors.red : Colors.white70)),
                          selected: isExcluded,
                          selectedColor: Colors.red.withOpacity(0.15),
                          checkmarkColor: Colors.red,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _excludedCategories.add(entry.key);
                              } else {
                                _excludedCategories.remove(entry.key);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 25),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isGenerating ? null : _startGeneration,
              icon: _isGenerating 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Icon(Icons.bolt), // Поменял иконку на молнию (быстрый запуск)
              label: Text(_isGenerating ? 'Сборка матрицы...' : 'СГЕНЕРИРОВАТЬ КВЕСТ (До 2 в день)'),
            ),
          ),

          const SizedBox(height: 30),

          if (_generatedQuest != null) ...[
            const Text("✨ СГЕНЕРИРОВАННЫЙ КВЕСТ:", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Card(
              color: Colors.green.withOpacity(0.05),
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.greenAccent.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                title: Text(_generatedQuest!.titleRu, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(_generatedQuest!.descriptionRu, style: const TextStyle(color: Colors.white70)),
                ),
                trailing: Chip(
                  label: Text('+${_generatedQuest!.xpReward} XP', style: const TextStyle(fontWeight: FontWeight.bold)),
                  backgroundColor: Colors.greenAccent.withOpacity(0.2),
                ),
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  try {
                    (controller as dynamic).addQuest(_generatedQuest!); 
                  } catch (_) {
                    try {
                      (controller as dynamic).addNewQuest(_generatedQuest!);
                    } catch (_) {
                      try {
                        (controller as dynamic).quests.add(_generatedQuest!);
                        controller.notifyListeners();
                      } catch (e) {
                        print("Не удалось добавить квест: $e");
                      }
                    }
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Квест успешно добавлен в твой лог!')),
                  );
                  setState(() => _generatedQuest = null);
                },
                icon: const Icon(Icons.add_task),
                label: const Text("ПРИНЯТЬ КОНТРАКТ"), // Более киберпанковый вариант
              ),
            ),
          ],
        ],
      ),
    );
  }
}