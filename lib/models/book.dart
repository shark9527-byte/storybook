class Book {
  final int? id;
  final String title;
  final String coverImagePath;
  final DateTime createdAt;
  final int lastPageNumber;

  Book({
    this.id,
    required this.title,
    required this.coverImagePath,
    DateTime? createdAt,
    this.lastPageNumber = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  Book copyWith({
    int? id,
    String? title,
    String? coverImagePath,
    DateTime? createdAt,
    int? lastPageNumber,
  }) =>
      Book(
        id: id ?? this.id,
        title: title ?? this.title,
        coverImagePath: coverImagePath ?? this.coverImagePath,
        createdAt: createdAt ?? this.createdAt,
        lastPageNumber: lastPageNumber ?? this.lastPageNumber,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'coverImagePath': coverImagePath,
        'createdAt': createdAt.toIso8601String(),
        'lastPageNumber': lastPageNumber,
      };

  factory Book.fromMap(Map<String, dynamic> map) => Book(
        id: map['id'] as int,
        title: map['title'] as String,
        coverImagePath: map['coverImagePath'] as String,
        createdAt: DateTime.parse(map['createdAt'] as String),
        lastPageNumber: (map['lastPageNumber'] as int?) ?? 0,
      );
}
