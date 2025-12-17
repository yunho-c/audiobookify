import 'dart:async';
import 'dart:ffi';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'api_service.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('books.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';

    await db.execute('''
      CREATE TABLE books (
        id $idType,
        name $textType,
        chapters $textType
      )
    ''');
  }

  Future<Book> getBook(String name) async {
    final db = await instance.database;
    final result = await db.query('books', where: 'name =?', whereArgs: [name]);
    return result.map((json) => Book.fromJson(json)).toList().first;
    // maybe raise errors if there are multiple of same item
  }

  Future<void> insertBook(
      String name, List<String> chapters, Map<String, String>? metadata) async {
    // NOTE consider making chapter argument optional
    // NOTE actually, let's do EPUB parsing at Dart level.
    //      thereby, there's no need for async anymore;
    //      then, chapter (as well as any necessary foundational metadata)
    //      can be supplied mandatorily — and the code/logic can be kept simple
    final db = await instance.database;

    await db.insert(
      'books',
      {'name': name, 'chapters': jsonEncode(chapters)},
      // {'name': name, 'chapters': jsonEncode(chapters), 'metadata': jsonEncode(metadata)},
    );
  }

  Future<void> updateBook(
      String name, Map<String, Chapter> chapterInfo) async {
    // input chapterInfo is a dict of chapter names : all information that requires update.
    // for example, if the input is {'chapter1': {'status': 67}, 'chapter2': {'status': 33}},
    // then the status attribute of corresponding chapters will be updated.

    final db = await instance.database;

    Book book = await instance.getBook(name);

    for (final chapterName in chapterInfo.keys) {
      final info = chapterInfo[chapterName];
      if (chapterInfo.containsKey('status')) {
        book.chapters[chapterName]!.status = info.status;
      }
      if (chapterInfo.containsKey('status')) {
        book.chapters[chapterName]!.status = info.status;
      }
      if (chapterInfo.containsKey('status')) {
        book.chapters[chapterName]!.status = chapterInfo[chapterName].status;
      }
      if (chapterInfo.containsKey('status')) {
        book.chapters[chapterName]!.status = chapterInfo[chapterName].status;
      }
      book.
    }

    // TODO verify
    await db.update(
      'books',
      {'chapters': jsonEncode(chapters)},
      where: 'name = $name',
    );
  }

  // Future<void> updateBookStatus(String name, Map<String, int> chapterStatus} async {
  //   final db = await instance.database;

  //   // TODO verify
  //   await db.update(
  //     'books',
  //     {'chapters': jsonEncode(chapters)},
  //     where: 'name = $name',
  //   );
  // }

  Future<List<Book>> fetchBooks() async {
    final db = await instance.database;

    final result = await db.query('books');

    return result.map((json) => Book.fromJson(json)).toList();
  }

  Future<void> resetDatabase() async {
    final db = await instance.database;
    await db.execute('DELETE FROM books');
  }
}

class Book {
  final int? id;
  final String name;
  // final List<String> chapters; // ORIG
  final Map<String, Chapter> chapters; // ALT1: chapter class

  Book({this.id, required this.name, required this.chapters});

  factory Book.fromJson(Map<String, dynamic> json) => Book(
        id: json['id'],
        name: json['name'],
        chapters: Map<String, Chapter>.from(jsonDecode(json['chapters'])),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'chapters': jsonEncode(chapters),
      };
}

class Chapter {
  final String name;
  int status;
  // final List<String>? content;

  // Chapter({required this.name, required this.status, this.content});
  Chapter({required this.name, required this.status});

  factory Chapter.fromJson(Map<String, dynamic> json) => Chapter(
        name: json['name'],
        status: json['status'],
        // content: List<String>.from(jsonDecode(json['content'])),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'status': status,
        // 'content': jsonEncode(content),
      };
}
