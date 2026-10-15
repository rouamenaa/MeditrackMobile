class User {
  final int? id;
  final String nom;
  final String prenom;
  final String email;
  final String passwordHash;
  final String salt;
  final String? telephone;
  final String? dateNaissance;
  final String? sexe;

  // Préférences de notification
  final bool notifMedicaments;
  final bool notifRdv;
  final bool notifSon;
  final bool notifVibration;
  final int rappelAvantMinutes;

  User({
    this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.passwordHash,
    required this.salt,
    this.telephone,
    this.dateNaissance,
    this.sexe,
    this.notifMedicaments = true,
    this.notifRdv = true,
    this.notifSon = true,
    this.notifVibration = true,
    this.rappelAvantMinutes = 10,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'nom': nom,
    'prenom': prenom,
    'email': email,
    'password_hash': passwordHash,
    'salt': salt,
    'telephone': telephone,
    'date_naissance': dateNaissance,
    'sexe': sexe,
    'notif_medicaments': notifMedicaments ? 1 : 0,
    'notif_rdv': notifRdv ? 1 : 0,
    'notif_son': notifSon ? 1 : 0,
    'notif_vibration': notifVibration ? 1 : 0,
    'rappel_avant_minutes': rappelAvantMinutes,
  };

  factory User.fromMap(Map<String, dynamic> m) => User(
    id: m['id'] as int?,
    nom: m['nom'] as String,
    prenom: m['prenom'] as String,
    email: m['email'] as String,
    passwordHash: m['password_hash'] as String,
    salt: m['salt'] as String,
    telephone: m['telephone'] as String?,
    dateNaissance: m['date_naissance'] as String?,
    sexe: m['sexe'] as String?,
    notifMedicaments: m['notif_medicaments'] == 1,
    notifRdv: m['notif_rdv'] == 1,
    notifSon: m['notif_son'] == 1,
    notifVibration: m['notif_vibration'] == 1,
    rappelAvantMinutes: m['rappel_avant_minutes'] as int,
  );

  User copyWith({
    String? nom,
    String? prenom,
    String? email,
    String? passwordHash,
    String? salt,
    String? telephone,
    String? dateNaissance,
    String? sexe,
    bool? notifMedicaments,
    bool? notifRdv,
    bool? notifSon,
    bool? notifVibration,
    int? rappelAvantMinutes,
  }) =>
      User(
        id: id,
        nom: nom ?? this.nom,
        prenom: prenom ?? this.prenom,
        email: email ?? this.email,
        passwordHash: passwordHash ?? this.passwordHash,
        salt: salt ?? this.salt,
        telephone: telephone ?? this.telephone,
        dateNaissance: dateNaissance ?? this.dateNaissance,
        sexe: sexe ?? this.sexe,
        notifMedicaments: notifMedicaments ?? this.notifMedicaments,
        notifRdv: notifRdv ?? this.notifRdv,
        notifSon: notifSon ?? this.notifSon,
        notifVibration: notifVibration ?? this.notifVibration,
        rappelAvantMinutes: rappelAvantMinutes ?? this.rappelAvantMinutes,
      );
}