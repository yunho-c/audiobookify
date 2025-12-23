class BookResumePosition {
  final int chapterIndex;
  final int paragraphIndex;
  final int sentenceIndex;
  final DateTime updatedAt;

  const BookResumePosition({
    required this.chapterIndex,
    required this.paragraphIndex,
    required this.sentenceIndex,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'chapterIndex': chapterIndex,
      'paragraphIndex': paragraphIndex,
      'sentenceIndex': sentenceIndex,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  static BookResumePosition? fromJson(Object? value) {
    if (value is! Map) return null;
    final chapterIndex = _readInt(value['chapterIndex']);
    final paragraphIndex = _readInt(value['paragraphIndex']);
    final sentenceIndex = _readInt(value['sentenceIndex']);
    final updatedAtRaw = _readInt(value['updatedAt']);
    if (chapterIndex == null ||
        paragraphIndex == null ||
        sentenceIndex == null ||
        updatedAtRaw == null) {
      return null;
    }
    return BookResumePosition(
      chapterIndex: chapterIndex,
      paragraphIndex: paragraphIndex,
      sentenceIndex: sentenceIndex,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtRaw),
    );
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}
