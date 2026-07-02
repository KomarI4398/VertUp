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
      username: data['username'] ?? 'Игрок',
      avatarAsset: data['avatarAsset'] ?? '🥷',
      title: data['title'] ?? 'Новичок',
      xp: data['xp'] ?? 0,
      streak: data['streak'] ?? 0,
    );
  }
}