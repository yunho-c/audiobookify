import 'dart:async';
import 'dart:io';
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

  /// Save an imported EPUB book to the database.
  /// Returns an existing book if the import looks like a duplicate.
  BookSaveResult saveBook(
    EpubBook epubBook,
    String filePath, {
    bool allowLooseMatch = true,
  }) {
    final existing = _findDuplicate(
      epubBook,
      filePath,
      allowLooseMatch: allowLooseMatch,
    );
    if (existing != null) {
      return BookSaveResult(book: existing, isDuplicate: true);
    }

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
    return BookSaveResult(book: book, isDuplicate: false);
  }

  Book? _findDuplicate(
    EpubBook epubBook,
    String filePath, {
    required bool allowLooseMatch,
  }) {
    final normalizedPath = filePath.trim();
    if (normalizedPath.isNotEmpty) {
      final query =
          _bookBox.query(Book_.filePath.equals(normalizedPath));
      final handle = query.build();
      try {
        final match = handle.findFirst();
        if (match != null) return match;
      } finally {
        handle.close();
      }
    }

    if (!allowLooseMatch) return null;

    final title = epubBook.metadata.title?.trim();
    final author = epubBook.metadata.creator?.trim();
    if (title == null || title.isEmpty) return null;

    final normalizedTitle = title.toLowerCase();
    final normalizedAuthor = author?.toLowerCase() ?? '';
    final chapterCount = epubBook.chapters.length;

    final query = _bookBox.query(
      Book_.chapterCount.equals(chapterCount),
    );
    final handle = query.build();
    try {
      final candidates = handle.find();
      for (final candidate in candidates) {
        final candidateTitle = candidate.title?.trim().toLowerCase() ?? '';
        if (candidateTitle != normalizedTitle) continue;
        final candidateAuthor = candidate.author?.trim().toLowerCase() ?? '';
        if (normalizedAuthor.isNotEmpty) {
          if (candidateAuthor == normalizedAuthor) return candidate;
        } else if (candidateAuthor.isEmpty) {
          return candidate;
        }
      }
    } finally {
      handle.close();
    }

    return null;
  }

  /// Get all books sorted by most recently added
  List<Book> getAllBooks() {
    final query = _bookBox.query()
      ..order(Book_.addedAt, flags: Order.descending);
    final handle = query.build();
    try {
      return handle.find();
    } finally {
      handle.close();
    }
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
    final handle = query.build();
    BookProgressBucket? bucket;
    try {
      bucket = handle.findFirst();
    } finally {
      handle.close();
    }

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
    final handle = query.build();
    try {
      final bucket = handle.findFirst();
      if (bucket == null || bucket.buckets.length != bucketCount) {
        return Uint8List(bucketCount);
      }
      return bucket.buckets;
    } finally {
      handle.close();
    }
  }

  /// Stream bucket progress for a chapter (0/1 values).
  Stream<Uint8List> watchBucketProgress({
    required int bookId,
    required int chapterIndex,
    int bucketCount = 64,
  }) {
    final queryBuilder = _progressBox.query(
      BookProgressBucket_.bookId.equals(bookId) &
          BookProgressBucket_.chapterIndex.equals(chapterIndex),
    );
    return _watchQuery(queryBuilder, (query) {
      final bucket = query.findFirst();
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

  /// Delete a book and remove stored assets (file + progress buckets).
  Future<bool> deleteBookAndAssets(int id) async {
    final book = _bookBox.get(id);
    if (book == null) return false;

    final progressQuery = _progressBox.query(
      BookProgressBucket_.bookId.equals(id),
    );
    final progressHandle = progressQuery.build();
    try {
      progressHandle.remove();
    } finally {
      progressHandle.close();
    }

    final removed = _bookBox.remove(id);

    final filePath = book.filePath.trim();
    if (filePath.isNotEmpty) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Ignore file cleanup errors.
      }
    }

    return removed;
  }

  /// Stream of all books (for reactive UI)
  Stream<List<Book>> watchAllBooks() {
    final queryBuilder = _bookBox.query()
      ..order(Book_.addedAt, flags: Order.descending);
    return _watchQuery(queryBuilder, (query) => query.find());
  }

  Stream<R> _watchQuery<T, R>(
    QueryBuilder<T> queryBuilder,
    R Function(Query<T>) mapper,
  ) {
    final controller = StreamController<R>();
    StreamSubscription<Query<T>>? subscription;
    Query<T>? activeQuery;

    void closeQuery() {
      try {
        activeQuery?.close();
      } catch (_) {}
      activeQuery = null;
    }

    controller.onListen = () {
      subscription = queryBuilder.watch(triggerImmediately: true).listen(
        (query) {
          activeQuery = query;
          controller.add(mapper(query));
        },
        onError: controller.addError,
        onDone: () {
          closeQuery();
          if (!controller.isClosed) {
            controller.close();
          }
        },
      );
    };

    controller.onCancel = () async {
      await subscription?.cancel();
      closeQuery();
    };

    return controller.stream;
  }
}

class BookSaveResult {
  final Book book;
  final bool isDuplicate;

  const BookSaveResult({
    required this.book,
    required this.isDuplicate,
  });
}
