import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quest.dart';

class AIService {
  final Random _random = Random();

  static const Map<String, String> categories = {
    'study': '📚 Учеба / Продуктивность',
    'skill': '🎯 Новый навык / Практика',
    'fitness': '💪 Спорт / Тренировки',
    'outdoor': '📍 Прогулки / На улице',
    'lifestyle': '🧹 Быт / Порядок в доме',
    'mind': '🧘 Менталка / Осознанность',
  };

  // Огромная база киберпанк-шаблонов под разные переменные
  final Map<String, List<Map<String, dynamic>>> _questTemplates = {
    'study': [
      {'title': 'Пакет данных: {subject}', 'description': 'Загрузи в свой нейроинтерфейс новые знания: изучай {subject} в течение {time} минут без перерыва на голограммы.', 'baseXp': 25},
      {'title': 'Цифровой аудит: {subject}', 'description': 'Удали весь цифровой мусор. Разбери {count} старых вкладок, писем или файлов по теме: {subject}.', 'baseXp': 15},
      {'title': 'Синхронизация нейросети', 'description': 'Почитай профильную литературу или документацию по теме {subject} в течение {time} минут.', 'baseXp': 20},
      {'title': 'Прошивка памяти: Конспект', 'description': 'Запиши ключевые тезисы, формулы или правила по теме {subject}. Нужно зафиксировать не менее {count} важных мыслей.', 'baseXp': 30},
      {'title': 'Защита дата-центра', 'description': 'Проведи ревизию своих учебных планов или задач по направлению {subject} и расставь приоритеты на {count} дней вперёд.', 'baseXp': 15}
    ],
    'skill': [
      {'title': 'Декомпиляция: {skill}', 'description': 'Разберись в сложной концепции. Посмотри туториал или прочитай техническую статью про {skill} и законспектируй суть.', 'baseXp': 30},
      {'title': 'Прототипирование: {skill}', 'description': 'Практика в полевых условиях. Потрать {time} минут на создание простейшего проекта или упражнения, используя {skill}.', 'baseXp': 40},
      {'title': 'Тест кибердеки: {skill}', 'description': 'Выполни {count} практических мини-заданий или упражнений для закрепления навыка {skill}.', 'baseXp': 25},
      {'title': 'Интеграция софта: {software}', 'description': 'Изучи интерфейс и горячие клавиши в {software}. Протестируй {count} новых функций, которые ты раньше не использовал.', 'baseXp': 20},
      {'title': 'Спидран-сессия: {skill}', 'description': 'Врубай максимальную концентрацию. В течение {time} минут непрерывно и без отвлечений практикуй {skill}.', 'baseXp': 35}
    ],
    'fitness': [
      {'title': 'Калибровка сервоприводов', 'description': 'Твоему телу нужна био-оптимизация. Сделай {count} приседаний или выпадов для укрепления опорных систем ног.', 'baseXp': 20},
      {'title': 'Разгон процессора: Кардио', 'description': 'Выведи кардиосистему на пиковую мощность: выполни {time}-минутную интенсивную тренировку, берпи или пробежку.', 'baseXp': 35},
      {'title': 'Защитный контур: Планка', 'description': 'Зафиксируй тело в статике. Продержись в планке {time} секунд. Не дай сервоприводам перегреться.', 'baseXp': 25},
      {'title': 'Обновление гидравлики', 'description': 'Выполни комплекс упражнений на растяжку мышц спины и ног в течение {time} минут. Увеличь мобильность корпуса.', 'baseXp': 20},
      {'title': 'Тяжёлый апгрейд корпуса', 'description': 'Выполни {count} отжиманий от пола или подтягиваний. Укрепи верхний плечевой пояс твоего аватара.', 'baseXp': 30}
    ],
    'outdoor': [
      {'title': 'Разведка секторов', 'description': 'Выйди из своего жилого отсека на улицы города. Пройди пешком не менее {count} шагов.', 'baseXp': 25},
      {'title': 'Сбор разведданных', 'description': 'Выйди наружу, найди новое для себя заведение или локацию ({landscape}) в радиусе 1.5 км и зафиксируй её координаты.', 'baseXp': 20},
      {'title': 'Дроп-офф вслепую', 'description': 'Поменяй привычный маршрут. Дойди до точки назначения абсолютно новой дорогой, потратив не менее {time} минут.', 'baseXp': 30},
      {'title': 'Сканирование периметра', 'description': 'Выйди на улицу и проведи на свежем воздухе не менее {time} минут, полностью убрав телефон в карман.', 'baseXp': 25},
      {'title': 'Марш-бросок через Сектор', 'description': 'Выберись в {landscape} и устрой там быструю ходьбу или пробежку в течение {time} минут.', 'baseXp': 35}
    ],
    'lifestyle': [
      {'title': 'Очистка матрицы: {place}', 'description': 'В твоем убежище критический уровень энтропии. Наведи идеальный порядок в зоне ({place}) за {time} минут.', 'baseXp': 15},
      {'title': 'Утилизация отходов', 'description': 'Собери весь скопившийся физический мусор в секторе и вынеси его в центральный утилизатор.', 'baseXp': 10},
      {'title': 'Менеджмент припасов: {place}', 'description': 'Разбери вещи, одежду или провода в зоне ({place}). Избавься или аккуратно спрячь {count} предметов.', 'baseXp': 15},
      {'title': 'Дезинфекция терминала', 'description': 'Протри влажными салфетками свои главные рабочие инструменты: клавиатуру, мышь, монитор и экран смартфона.', 'baseXp': 10},
      {'title': 'Техбрейк: Освежение воздуха', 'description': 'Проветри жилой отсек, выпей стакан чистой H2O и сделай влажную уборку пола в текущей комнате.', 'baseXp': 15}
    ],
    'mind': [
      {'title': 'Перезагрузка ядра (Медитация)', 'description': 'Очисти оперативную память от фонового стресса. Проведи {time} минут в полной тишине, концентрируясь только на дыхании.', 'baseXp': 20},
      {'title': 'Логирование матрицы', 'description': 'Запиши в текстовый лог (дневник) {count} вещи, за которые ты благодарен этой реальности сегодня. Стабилизируй ментальный контур.', 'baseXp': 15},
      {'title': 'Защитный экран ЭМИ', 'description': 'Устрой полный цифровой детокс. Проведи {time} минут без экранов смартфонов, мониторов и любых гаджетов.', 'baseXp': 30},
      {'title': 'Анализ логов ошибок', 'description': 'Сядь в тишине и выпиши на бумагу {count} проблемы, которые тревожили тебя за неделю, и придумай к каждой по одному простому решению.', 'baseXp': 25},
      {'title': 'Оптимизация сна', 'description': 'Подготовка к гибернации. Отложи все гаджеты за {time} минут до сна и проветри комнату для глубокой перезагрузки процессора.', 'baseXp': 20}
    ],
  };

  // Словари подстановок (переменные)
  final List<String> _subjects = ['Программирование', 'Английский язык', 'Математика', 'UI/UX Дизайн', 'Финансы и крипта', 'История', 'Нейросети', 'Маркетинг', 'Физика'];
  final List<String> _skills = ['Dart/Flutter', 'Figma', 'Монтаж видео', 'Рисование', 'Слепая печать', '3D-моделирование', 'Написание текстов', 'Алгоритмы'];
  final List<String> _software = ['VS Code', 'Figma', 'Blender', 'Git/GitHub', 'Photoshop', 'Notion', 'Excel'];
  final List<String> _places = ['рабочий стол', 'кухонный блок', 'гардероб', 'книжная полка', 'прихожая', 'прикроватная тумбочка'];
  final List<String> _landscapes = ['городской парк', 'незнакомый жилой квартал', 'центральная аллея', 'набережная', 'лесная зона'];

  Future<Quest> generateQuest({
    required int userLevel,
    required String userTitle,
    required String selectedCategory,
    required List<String> excludedCategories,
  }) async {
    
    // 1. ПРОВЕРКА ЛИМИТА (2 квеста в день)
    final prefs = await SharedPreferences.getInstance();
    final String todayStr = DateTime.now().toIso8601String().split('T')[0];
    
    final String lastGenerationDate = prefs.getString('last_generation_date') ?? '';
    int questsToday = prefs.getInt('quests_generated_today') ?? 0;

    if (lastGenerationDate == todayStr) {
      if (questsToday >= 2) {
        throw Exception("Лимит исчерпан. В день можно сгенерировать не более 2 квестов! Возвращайся завтра.");
      }
    } else {
      questsToday = 0;
    }

    // Имитируем задержку генерации для визуала
    await Future.delayed(const Duration(milliseconds: 250));

    // 2. Логика выбора категории
    String finalCategory = selectedCategory;
    if (selectedCategory == 'random') {
      final availableCategories = categories.keys
          .where((cat) => !excludedCategories.contains(cat))
          .toList();
      
      if (availableCategories.isEmpty) {
        finalCategory = 'study';
      } else {
        finalCategory = availableCategories[_random.nextInt(availableCategories.length)];
      }
    }

    // 3. Выбор случайного шаблона
    final templates = _questTemplates[finalCategory] ?? _questTemplates['study']!;
    final template = templates[_random.nextInt(templates.length)];

    // 4. Динамические переменные (зависят от уровня)
    final int minutes = (5 + _random.nextInt(5) * 5) + (userLevel * 2); 
    final int repeats = (10 + _random.nextInt(4) * 5) + (userLevel * 3); 
    final int smallCounts = 3 + _random.nextInt(4); // Для вкладок, писем, пунктов (от 3 до 6)

    final String subject = _subjects[_random.nextInt(_subjects.length)];
    final String skill = _skills[_random.nextInt(_skills.length)];
    final String software = _software[_random.nextInt(_software.length)];
    final String place = _places[_random.nextInt(_places.length)];
    final String landscape = _landscapes[_random.nextInt(_landscapes.length)];

    // 5. Сборка строк и замена плейсхолдеров
    String title = template['title'] as String;
    String description = template['description'] as String;

    title = title
        .replaceAll('{subject}', subject)
        .replaceAll('{skill}', skill)
        .replaceAll('{software}', software)
        .replaceAll('{place}', place)
        .replaceAll('{landscape}', landscape);

    description = description
        .replaceAll('{subject}', subject)
        .replaceAll('{skill}', skill)
        .replaceAll('{software}', software)
        .replaceAll('{place}', place)
        .replaceAll('{landscape}', landscape)
        .replaceAll('{time}', minutes.toString())
        .replaceAll('{count}', (template['baseXp']! < 20 ? smallCounts : repeats).toString());

    if (userLevel > 3) {
      title = '[$userTitle] $title';
    }

    // Расчет опыта
    final int baseXp = template['baseXp'] as int;
    final int finalXp = baseXp + (userLevel * 2) + _random.nextInt(8);

    // 6. Сохранение счетчика
    questsToday++;
    await prefs.setString('last_generation_date', todayStr);
    await prefs.setInt('quests_generated_today', questsToday);

    // 7. Возврат готового квеста
    return Quest(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(1000)}',
      titleRu: title,
      titleEn: title,
      descriptionRu: description,
      descriptionEn: description,
      xpReward: finalXp,
      isHardcore: finalXp > 45,
    );
  }
}