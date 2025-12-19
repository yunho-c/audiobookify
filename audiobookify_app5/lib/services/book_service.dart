import '../models/book.dart';
import '../objectbox.g.dart';
import '../src/rust/api/epub.dart';

/// Service for managing Book persistence with ObjectBox
class BookService {
  final Box<Book> _bookBox;

  BookService(Store store) : _bookBox = store.box<Book>();

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
