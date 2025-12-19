import 'dart:typed_data';
import '../models/book.dart';
import '../models/book_progress_bucket.dart';
import '../objectbox.g.dart';
import '../src/rust/api/epub.dart';

/// Service for managing Book persistence with ObjectBox
class BookService {
  final Box<Book> _bookBox;
  final Box<BookProgressBucket> _progressBox;

  BookService(Store store)
      : _bookBox = store.box<Book>(),
        _progressBox = store.box<BookProgressBucket>();

  /// Save an imported EPUB book to the database
  Book saveBook(EpubBook epubBook, String filePath) {
    final book = Book(
      title: epubBook.metadata.title,
      author: epubBook.metadata.creator,
      language: epubBook.metadata.language,
      publisher: epubBook.metadata.publisher,
      description: epubBook.metadata.description,
      coverImage: epubBook.coverImage,
      chapterCount: epubBook.chapters.length,
      filePath: filePath,
      addedAt: DateTime.now(),
      progress: 0,
    );

    book.id = _bookBox.put(book);
    return book;
  }

  /// Get all books sorted by most recently added
  List<Book> getAllBooks() {
    final query = _bookBox.query()
      ..order(Book_.addedAt, flags: Order.descending);
    return query.build().find();
  }

  /// Get a single book by ID
  Book? getBook(int id) {
    return _bookBox.get(id);
  }

  /// Update reading progress
  void updateProgress(int id, int progress) {
    final book = _bookBox.get(id);
    if (book != null) {
      book.progress = progress.clamp(0, 100);
      _bookBox.put(book);
    }
  }

  /// Mark a bucket as listened for a given chapter and paragraph.
  void markBucketProgress({
    required int bookId,
    required int chapterIndex,
    required int paragraphIndex,
    required int totalParagraphs,
    int bucketCount = 64,
  }) {
    if (totalParagraphs <= 0 || bucketCount <= 0) return;

    final ratio = (paragraphIndex + 1) / totalParagraphs;
    final rawBucket = (ratio * bucketCount).ceil() - 1;
    final bucketIndex = rawBucket.clamp(0, bucketCount - 1);

    final query = _progressBox.query(
      BookProgressBucket_.bookId.equals(bookId) &
          BookProgressBucket_.chapterIndex.equals(chapterIndex),
    );
    final bucket = query.build().findFirst();

    final current = bucket ??
        BookProgressBucket(
          bookId: bookId,
          chapterIndex: chapterIndex,
          bucketCount: bucketCount,
          buckets: Uint8List(bucketCount),
        );

    if (current.bucketCount != bucketCount ||
        current.buckets.length != bucketCount) {
      current.bucketCount = bucketCount;
      current.buckets = Uint8List(bucketCount);
    }

    if (current.buckets[bucketIndex] == 1) return;
    current.buckets[bucketIndex] = 1;
    current.updatedAt = DateTime.now();
    _progressBox.put(current);
  }

  /// Get bucket progress for a chapter (0/1 values).
  Uint8List getBucketProgress({
    required int bookId,
    required int chapterIndex,
    int bucketCount = 64,
  }) {
    final query = _progressBox.query(
      BookProgressBucket_.bookId.equals(bookId) &
          BookProgressBucket_.chapterIndex.equals(chapterIndex),
    );
    final bucket = query.build().findFirst();
    if (bucket == null || bucket.buckets.length != bucketCount) {
      return Uint8List(bucketCount);
    }
    return bucket.buckets;
  }

  /// Stream bucket progress for a chapter (0/1 values).
  Stream<Uint8List> watchBucketProgress({
    required int bookId,
    required int chapterIndex,
    int bucketCount = 64,
  }) {
    final query = _progressBox.query(
      BookProgressBucket_.bookId.equals(bookId) &
          BookProgressBucket_.chapterIndex.equals(chapterIndex),
    );
    return query.watch(triggerImmediately: true).map((result) {
      final bucket = result.findFirst();
      if (bucket == null || bucket.buckets.length != bucketCount) {
        return Uint8List(bucketCount);
      }
      return bucket.buckets;
    });
  }

  /// Delete a book
  bool deleteBook(int id) {
    return _bookBox.remove(id);
  }

  /// Stream of all books (for reactive UI)
  Stream<List<Book>> watchAllBooks() {
    final query = _bookBox.query()
      ..order(Book_.addedAt, flags: Order.descending);
    return query.watch(triggerImmediately: true).map((q) => q.find());
  }
}
