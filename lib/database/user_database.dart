import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class UserDatabase {
  static final _databaseName = "users.db";
  static final _databaseVersion = 2;

  static final table = "users";
  static final columnId = "id";
  static final columnName = "name";
  static final columnEmail = "email";
  static final columnEmbedding = "embedding";

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<bool> emailExists(String email) async {
    final db = await database;
    final result = await db.query(
      table,
      where: '$columnEmail = ?',
      whereArgs: [email],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS $table');
      await _onCreate(db, newVersion);
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $table (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnName TEXT NOT NULL,
        $columnEmail TEXT NOT NULL UNIQUE,
        $columnEmbedding BLOB NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX idx_email ON $table($columnEmail)
    ''');
  }

  Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    return await db.insert(
      table,
      {
        columnName: user[columnName],
        columnEmail: user[columnEmail],
        columnEmbedding: _floatListToBytes(user[columnEmbedding] as List<double>),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Uint8List _floatListToBytes(List<double> embedding) {
    final byteData = ByteData(embedding.length * 4);
    for (int i = 0; i < embedding.length; i++) {
      byteData.setFloat32(i * 4, embedding[i], Endian.little);
    }
    return byteData.buffer.asUint8List();
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    final db = await database;
    final results = await db.query(table);
    return results.map(_parseUserRow).toList();
  }

  Map<String, dynamic> _parseUserRow(Map<String, dynamic> row) {
    return {
      columnId: row[columnId],
      columnName: row[columnName],
      columnEmail: row[columnEmail],
      columnEmbedding: _bytesToFloatList(row[columnEmbedding] as Uint8List),
    };
  }

  List<double> _bytesToFloatList(Uint8List bytes) {
    final byteData = ByteData.sublistView(bytes);
    return List.generate(
      bytes.length ~/ 4,
          (i) => byteData.getFloat32(i * 4, Endian.little),
    );
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}