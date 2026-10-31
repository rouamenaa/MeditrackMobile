import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:meditrackmobile/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';
import '../models/user.dart';

class UserRepository {
  final _dbHelper = DatabaseHelper.instance;

  // ---------- Sécurité du mot de passe ----------
  String _generateSalt() {
    final rnd = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => rnd.nextInt(256)));
  }

  String _hash(String password, String salt) =>
      sha256.convert(utf8.encode(password + salt)).toString();

  // ---------- CREATE : inscription ----------
  /// Retourne l'utilisateur créé, ou null si l'email existe déjà.
  Future<User?> register({
    required String nom,
    required String prenom,
    required String email,
    required String password,
    String? telephone,
    String? dateNaissance,
    String? sexe,
  }) async {
    final db = await _dbHelper.database;
    final salt = _generateSalt();
    final user = User(
      nom: nom.trim(),
      prenom: prenom.trim(),
      email: email.trim().toLowerCase(),
      passwordHash: _hash(password, salt),
      salt: salt,
      telephone: telephone,
      dateNaissance: dateNaissance,
      sexe: sexe,
      dateCreation: DateTime.now().toIso8601String(),   // <- nouvelle ligne

    );
    try {
      final id = await db.insert('users', user.toMap()..remove('id'),
          conflictAlgorithm: ConflictAlgorithm.abort);
      return getById(id);
    } on DatabaseException {
      return null; // email déjà utilisé
    }
  }

  // ---------- READ : connexion ----------
  /// Retourne l'utilisateur si email + mot de passe corrects, sinon null.
  Future<User?> login(String email, String password) async {
    final db = await _dbHelper.database;
    final rows = await db.query('users',
        where: 'email = ?',
        whereArgs: [email.trim().toLowerCase()],
        limit: 1);
    if (rows.isEmpty) return null;
    final user = User.fromMap(rows.first);
    return _hash(password, user.salt) == user.passwordHash ? user : null;
  }

  Future<User?> getById(int id) async {
    final db = await _dbHelper.database;
    final rows =
    await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : User.fromMap(rows.first);
  }

  // ---------- UPDATE : profil + préférences ----------
  Future<bool> update(User user) async {
    final db = await _dbHelper.database;
    final count = await db.update('users', user.toMap()..remove('id'),
        where: 'id = ?', whereArgs: [user.id]);
    return count > 0;
  }

  Future<bool> changePassword(
      int id, String oldPassword, String newPassword) async {
    final user = await getById(id);
    if (user == null || _hash(oldPassword, user.salt) != user.passwordHash) {
      return false;
    }
    final newSalt = _generateSalt();
    return update(user.copyWith(
        salt: newSalt, passwordHash: _hash(newPassword, newSalt)));
  }

  Future<bool> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('users', where: 'id = ?', whereArgs: [id]) > 0;
  }
}