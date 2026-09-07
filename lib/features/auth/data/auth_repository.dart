import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';

enum UserRole { admin, officer }

extension UserRoleLabel on UserRole {
  String get value => this == UserRole.admin ? 'Admin' : 'Petugas';

  static UserRole fromValue(String value) =>
      value == 'Admin' ? UserRole.admin : UserRole.officer;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.role,
    required this.isActive,
  });

  final String id;
  final String name;
  final UserRole role;
  final bool isActive;

  bool get isAdmin => role == UserRole.admin;
}

class AuthRepository {
  AuthRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;
  final _uuid = const Uuid();
  final _algorithm = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 120000,
    bits: 256,
  );

  Future<bool> hasUsers() async {
    final db = await _database.database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS count FROM app_users');
    return ((rows.single['count'] as num?)?.toInt() ?? 0) > 0;
  }

  Future<List<AppUser>> getUsers({bool activeOnly = false}) async {
    final db = await _database.database;
    final rows = await db.query(
      'app_users',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'role ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(_userFromRow).toList();
  }

  Future<AppUser> createUser({
    required String name,
    required String pin,
    required UserRole role,
  }) async {
    _validate(name: name, pin: pin);
    final db = await _database.database;
    final normalizedName = name.trim();
    final duplicate = await db.query(
      'app_users',
      columns: const ['id'],
      where: 'name = ? COLLATE NOCASE',
      whereArgs: [normalizedName],
      limit: 1,
    );
    if (duplicate.isNotEmpty) {
      throw ArgumentError('Nama pengguna sudah digunakan.');
    }
    final now = DateTime.now().toIso8601String();
    final salt = _newSalt();
    final hash = await _hash(pin, salt);
    final user = AppUser(
      id: _uuid.v4(),
      name: normalizedName,
      role: role,
      isActive: true,
    );
    await db.insert('app_users', {
      'id': user.id,
      'name': user.name,
      'role': role.value,
      'pin_salt': salt,
      'pin_hash': hash,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
    return user;
  }

  Future<AppUser?> authenticate({
    required String userId,
    required String pin,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'app_users',
      where: 'id = ? AND is_active = 1',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    final actual = await _hash(pin, row['pin_salt']! as String);
    if (actual != row['pin_hash']) return null;
    return _userFromRow(row);
  }

  Future<void> changePin({required String userId, required String pin}) async {
    _validate(name: 'x', pin: pin);
    final salt = _newSalt();
    final hash = await _hash(pin, salt);
    final db = await _database.database;
    await db.update(
      'app_users',
      {
        'pin_salt': salt,
        'pin_hash': hash,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> setActive({required String userId, required bool active}) async {
    final db = await _database.database;
    await db.update(
      'app_users',
      {
        'is_active': active ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String()
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<String> _hash(String pin, String salt) async {
    final secretKey = await _algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: base64Decode(salt),
    );
    return base64Encode(await secretKey.extractBytes());
  }

  String _newSalt() {
    final random = Random.secure();
    return base64Encode(List<int>.generate(16, (_) => random.nextInt(256)));
  }

  void _validate({required String name, required String pin}) {
    if (name.trim().isEmpty) throw ArgumentError('Nama pengguna wajib diisi.');
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw ArgumentError('PIN harus terdiri dari 6 angka.');
    }
  }

  AppUser _userFromRow(Map<String, Object?> row) => AppUser(
        id: row['id']! as String,
        name: row['name']! as String,
        role: UserRoleLabel.fromValue(row['role']! as String),
        isActive: (row['is_active'] as num?)?.toInt() == 1,
      );
}
