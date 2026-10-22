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

  // Profil santé (ajoutés en version 2 de la base)
  final String? dateCreation;
  final String? photoPath;
  final String? groupeSanguin;      // "O+"
  final String? conditionMedicale;  // "Diabetic Type 2"
  final String? contactUrgenceNom;
  final String? contactUrgenceLien; // "Spouse"
  final String? contactUrgenceTel;
  final String? assuranceNom;
  final String? assurancePolice;

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
    this.dateCreation,
    this.photoPath,
    this.groupeSanguin,
    this.conditionMedicale,
    this.contactUrgenceNom,
    this.contactUrgenceLien,
    this.contactUrgenceTel,
    this.assuranceNom,
    this.assurancePolice,
  });

  // ---------- Valeurs calculées (utiles pour tous les modules) ----------
  String get fullName => '$prenom $nom';
  String get meditrackId => '#MT-${(id ?? 0).toString().padLeft(4, '0')}';

  int? get age {
    final d = DateTime.tryParse(dateNaissance ?? '');
    if (d == null) return null;
    final now = DateTime.now();
    var a = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) a--;
    return a;
  }

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
    'date_creation': dateCreation,
    'photo_path': photoPath,
    'groupe_sanguin': groupeSanguin,
    'condition_medicale': conditionMedicale,
    'contact_urgence_nom': contactUrgenceNom,
    'contact_urgence_lien': contactUrgenceLien,
    'contact_urgence_tel': contactUrgenceTel,
    'assurance_nom': assuranceNom,
    'assurance_police': assurancePolice,
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
    dateCreation: m['date_creation'] as String?,
    photoPath: m['photo_path'] as String?,
    groupeSanguin: m['groupe_sanguin'] as String?,
    conditionMedicale: m['condition_medicale'] as String?,
    contactUrgenceNom: m['contact_urgence_nom'] as String?,
    contactUrgenceLien: m['contact_urgence_lien'] as String?,
    contactUrgenceTel: m['contact_urgence_tel'] as String?,
    assuranceNom: m['assurance_nom'] as String?,
    assurancePolice: m['assurance_police'] as String?,
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
    String? photoPath,
    String? groupeSanguin,
    String? conditionMedicale,
    String? contactUrgenceNom,
    String? contactUrgenceLien,
    String? contactUrgenceTel,
    String? assuranceNom,
    String? assurancePolice,
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
        dateCreation: dateCreation,
        photoPath: photoPath ?? this.photoPath,
        groupeSanguin: groupeSanguin ?? this.groupeSanguin,
        conditionMedicale: conditionMedicale ?? this.conditionMedicale,
        contactUrgenceNom: contactUrgenceNom ?? this.contactUrgenceNom,
        contactUrgenceLien: contactUrgenceLien ?? this.contactUrgenceLien,
        contactUrgenceTel: contactUrgenceTel ?? this.contactUrgenceTel,
        assuranceNom: assuranceNom ?? this.assuranceNom,
        assurancePolice: assurancePolice ?? this.assurancePolice,
      );
}