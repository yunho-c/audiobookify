import 'dart:typed_data';
import 'package:objectbox/objectbox.dart';

/// Book entity for ObjectBox persistence
@Entity()
class Book {
  @Id()
  int id = 0;

  String? title;
  String? author;
  String? language;
  String? publisher;
  String? description;

  /// Cover image as bytes
  @Property(type: PropertyType.byteVector)
  Uint8List? coverImage;

  /// Number of chapters in the book
  int chapterCount;

  /// Path to the original EPUB file
  String filePath;

  /// Chapter-index cache version to invalidate persisted section summaries.
  int chapterIndexCacheVersion;

  /// File size used to validate the cached chapter index.
  int chapterIndexFileSizeBytes;

  /// File modified time used to validate the cached chapter index.
  @Property(type: PropertyType.date)
  DateTime? chapterIndexFileModifiedAt;

  /// When the book was added to the library
  @Property(type: PropertyType.date)
  DateTime addedAt;

  /// Reading progress (0-100)
  int progress;

  Book({
    this.id = 0,
    this.title,
    this.author,
    this.language,
    this.publisher,
    this.description,
    this.coverImage,
    this.chapterCount = 0,
    required this.filePath,
    this.chapterIndexCacheVersion = 0,
    this.chapterIndexFileSizeBytes = 0,
    this.chapterIndexFileModifiedAt,
    DateTime? addedAt,
    this.progress = 0,
  }) : addedAt = addedAt ?? DateTime.now();
}
