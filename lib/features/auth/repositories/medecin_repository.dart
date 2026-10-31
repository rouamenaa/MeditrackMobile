import '../../../database/database_helper.dart';
import '../models/medecin.dart';

class MedecinRepository {
  final _dbHelper = DatabaseHelper.instance;

  Future<List<Medecin>> getByUser(int userId) async {
    final db = await _dbHelper.database;
    final rows = await db.query('medecins',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'id');
    return rows.map(Medecin.fromMap).toList();
  }

  Future<int> add(Medecin m) async {
    final db = await _dbHelper.database;
    return db.insert('medecins', m.toMap()..remove('id'));
  }

  Future<bool> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('medecins', where: 'id = ?', whereArgs: [id]) > 0;
  }
}