class Medecin {
  final int? id;
  final int userId;
  final String nom;
  final String specialite;

  Medecin({
    this.id,
    required this.userId,
    required this.nom,
    required this.specialite,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'nom': nom,
    'specialite': specialite,
  };

  factory Medecin.fromMap(Map<String, dynamic> m) => Medecin(
    id: m['id'] as int?,
    userId: m['user_id'] as int,
    nom: m['nom'] as String,
    specialite: m['specialite'] as String,
  );
}