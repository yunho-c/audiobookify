# ObjectBox Integration in Flutter

Documentation of integrating ObjectBox database for local persistence in Flutter.

## Overview

ObjectBox is a high-performance NoSQL database for Flutter/Dart with support for:
- Fast object storage and retrieval
- Reactive queries (streams)
- Relations between entities
- Type-safe queries

## Setup Steps

### 1. Add dependencies

```bash
flutter pub add objectbox objectbox_flutter_libs
flutter pub add --dev build_runner objectbox_generator
```

### 2. Create entity model

```dart
// lib/models/book.dart
import 'dart:typed_data';
import 'package:objectbox/objectbox.dart';

@Entity()
class Book {
  @Id()
  int id = 0;

  String? title;
  String? author;
  
  @Property(type: PropertyType.byteVector)
  Uint8List? coverImage;  // Binary data
  
  @Property(type: PropertyType.date)
  DateTime addedAt;
  
  int progress;

  Book({
    this.id = 0,
    this.title,
    required this.addedAt,
    this.progress = 0,
  });
}
```

### 3. Generate ObjectBox bindings

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

Creates:
- `lib/objectbox.g.dart` - Generated store and box code
- `lib/objectbox-model.json` - Database schema

### 4. Initialize store

```dart
// main.dart
import 'package:path_provider/path_provider.dart';
import 'objectbox.g.dart';

late final Store objectboxStore;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final appDir = await getApplicationDocumentsDirectory();
  objectboxStore = await openStore(directory: '${appDir.path}/objectbox');
  
  runApp(const MyApp());
}
```

## CRUD Operations

### Service pattern

```dart
class BookService {
  final Box<Book> _bookBox;

  BookService(Store store) : _bookBox = store.box<Book>();

  // Create
  Book saveBook(Book book) {
    book.id = _bookBox.put(book);
    return book;
  }

  // Read all
  List<Book> getAllBooks() {
    return _bookBox.getAll();
  }

  // Read with query (sorted)
  List<Book> getAllBooksSorted() {
    final query = _bookBox.query()
      ..order(Book_.addedAt, flags: Order.descending);
    return query.build().find();
  }

  // Read one
  Book? getBook(int id) {
    return _bookBox.get(id);
  }

  // Update
  void updateProgress(int id, int progress) {
    final book = _bookBox.get(id);
    if (book != null) {
      book.progress = progress;
      _bookBox.put(book);
    }
  }

  // Delete
  bool deleteBook(int id) {
    return _bookBox.remove(id);
  }

  // Reactive stream
  Stream<List<Book>> watchAllBooks() {
    final query = _bookBox.query()
      ..order(Book_.addedAt, flags: Order.descending);
    return query.watch(triggerImmediately: true).map((q) => q.find());
  }
}
```

## Property Types

| Dart Type | ObjectBox Annotation |
|-----------|---------------------|
| `int`, `String`, `double` | None needed |
| `DateTime` | `@Property(type: PropertyType.date)` |
| `Uint8List` | `@Property(type: PropertyType.byteVector)` |
| `List<String>` | `@Property(type: PropertyType.stringVector)` |
| `bool` | None needed |

## macOS Configuration

**Critical**: ObjectBox requires macOS 11.0+

### Update Podfile

```ruby
# macos/Podfile
platform :osx, '11.0'  # Was 10.15
```

### Update Xcode project

```bash
# Update deployment target in project.pbxproj
sed -i '' 's/MACOSX_DEPLOYMENT_TARGET = 10.15/MACOSX_DEPLOYMENT_TARGET = 11.0/g' \
  macos/Runner.xcodeproj/project.pbxproj
```

### Refresh pods

```bash
cd macos
rm Podfile.lock
pod install --repo-update
```

## Common Issues

| Issue | Solution |
|-------|----------|
| `objectbox.g.dart` not found | Run `flutter pub run build_runner build` |
| CocoaPods can't find ObjectBox | Run `pod install --repo-update` |
| macOS deployment target error | Update Podfile and project.pbxproj to 11.0 |
| Store already open error | Ensure `openStore()` is called only once |

## Best Practices

1. **Global store**: Initialize once in `main()`, access globally
2. **Service layer**: Wrap Box operations in a service class
3. **Nullable fields**: Use `String?` for optional metadata
4. **Binary data**: Use `Uint8List` with `PropertyType.byteVector` for images
5. **Sorting**: Use `order()` on queries, not Dart's `sort()`

## Files to gitignore

ObjectBox data directory is auto-created at runtime, no need to gitignore source files:
- `lib/objectbox.g.dart` - **Commit this** (generated code)
- `lib/objectbox-model.json` - **Commit this** (schema)
