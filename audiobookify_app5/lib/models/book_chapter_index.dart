import 'package:objectbox/objectbox.dart';

@Entity()
class BookChapterIndex {
  @Id()
  int id = 0;

  @Index()
  int bookId;

  @Index()
  int chapterIndex;

  String title;
  String startHref;
  String? startFragment;
  String? endHref;
  String? endFragment;
  int spineStart;
  int spineEnd;

  BookChapterIndex({
    this.id = 0,
    required this.bookId,
    required this.chapterIndex,
    required this.title,
    required this.startHref,
    this.startFragment,
    this.endHref,
    this.endFragment,
    required this.spineStart,
    required this.spineEnd,
  });
}

class BookChapterSummary {
  final int chapterIndex;
  final String title;
  final String startHref;
  final String? startFragment;
  final String? endHref;
  final String? endFragment;
  final int spineStart;
  final int spineEnd;

  const BookChapterSummary({
    required this.chapterIndex,
    required this.title,
    required this.startHref,
    this.startFragment,
    this.endHref,
    this.endFragment,
    required this.spineStart,
    required this.spineEnd,
  });
}
