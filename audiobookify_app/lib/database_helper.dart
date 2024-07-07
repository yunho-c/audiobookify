import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('items.db');
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
      CREATE TABLE items (
        id $idType,
        name $textType
      )
    ''');
  }

  Future<void> insertItem(String name) async {
    final db = await instance.database;

    await db.insert(
      'items',
      {'name': name},
    );
  }

  Future<List<Item>> fetchItems() async {
    final db = await instance.database;

    final result = await db.query('items');

    return result.map((json) => Item.fromJson(json)).toList();
  }
}

class Item {
  final int? id;
  final String name;

  Item({this.id, required this.name});

  factory Item.fromJson(Map<String, dynamic> json) => Item(
        id: json['id'],
        name: json['name'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
      };
}
