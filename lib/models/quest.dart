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