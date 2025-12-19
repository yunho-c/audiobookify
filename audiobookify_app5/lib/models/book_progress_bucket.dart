import 'dart:typed_data';
import 'package:objectbox/objectbox.dart';

/// Bucketed progress data for minimap-style progress visuals.
@Entity()
class BookProgressBucket {
  @Id()
  int id = 0;

  @Index()
  int bookId;

  @Index()
  int chapterIndex;

  int bucketCount;

  /// Byte array where 1 = listened, 0 = not listened.
  @Property(type: PropertyType.byteVector)
  Uint8List buckets;

  @Property(type: PropertyType.date)
  DateTime updatedAt;

  BookProgressBucket({
    this.id = 0,
    required this.bookId,
    required this.chapterIndex,
    required this.bucketCount,
    required this.buckets,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();
}
