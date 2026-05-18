class StoryPage {
  final int? id;
  final int bookId;
  final int pageNumber;
  final String imagePath;
  final String text;

  StoryPage({
    this.id,
    required this.bookId,
    required this.pageNumber,
    required this.imagePath,
    required this.text,
  });

  StoryPage copyWith({
    int? id,
    int? bookId,
    int? pageNumber,
    String? imagePath,
    String? text,
  }) =>
      StoryPage(
        id: id ?? this.id,
        bookId: bookId ?? this.bookId,
        pageNumber: pageNumber ?? this.pageNumber,
        imagePath: imagePath ?? this.imagePath,
        text: text ?? this.text,
      );

  Map<String, dynamic> toMap() => {
        'bookId': bookId,
        'pageNumber': pageNumber,
        'imagePath': imagePath,
        'text': text,
      };

  factory StoryPage.fromMap(Map<String, dynamic> map) => StoryPage(
        id: map['id'] as int,
        bookId: map['bookId'] as int,
        pageNumber: map['pageNumber'] as int,
        imagePath: map['imagePath'] as String,
        text: map['text'] as String,
      );
}
