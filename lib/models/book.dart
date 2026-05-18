class Book {
  final int? id;
  final String title;
  final String coverImagePath;
  final DateTime createdAt;

  Book({
    this.id,
    required this.title,
    required this.coverImagePath,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Book copyWith({
    int? id,
    String? title,
    String? coverImagePath,
    DateTime? createdAt,
  }) =>
      Book(
        id: id ?? this.id,
        title: title ?? this.title,
        coverImagePath: coverImagePath ?? this.coverImagePath,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'coverImagePath': coverImagePath,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Book.fromMap(Map<String, dynamic> map) => Book(
        id: map['id'] as int,
        title: map['title'] as String,
        coverImagePath: map['coverImagePath'] as String,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
}
