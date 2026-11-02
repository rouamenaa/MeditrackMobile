/// ============================================================
/// Module — MÉDICAMENTS (Medication)
/// Catalogue personnel de médicaments de l'utilisateur.
///
/// Un médicament est une entrée du catalogue (ex : "Doliprane 500mg").
/// Il peut ensuite être référencé par un Treatment (module d'Oussama).
///
/// Stockage : table `medications` dans meditrack.db (partagé équipe).
/// Même pattern CREATE TABLE IF NOT EXISTS → pas de conflit au merge.
/// ============================================================
library;

/// Forme pharmaceutique du médicament
enum MedicationForm {
  comprime,
  gelule,
  sirop,
  injection,
  pommade,
  patch,
  gouttes,
  autre,
}

/// Labels affichés en français
const Map<MedicationForm, String> medicationFormLabels = {
  MedicationForm.comprime: 'Comprimé',
  MedicationForm.gelule: 'Gélule',
  MedicationForm.sirop: 'Sirop',
  MedicationForm.injection: 'Injection',
  MedicationForm.pommade: 'Pommade',
  MedicationForm.patch: 'Patch',
  MedicationForm.gouttes: 'Gouttes',
  MedicationForm.autre: 'Autre',
};

MedicationForm medicationFormFromString(String s) =>
    MedicationForm.values.firstWhere((e) => e.name == s,
        orElse: () => MedicationForm.autre);

class Medication {
  final int? id;
  final int userId; // FK -> users(id)

  final String name; // ex : "Doliprane"
  final String? dosage; // ex : "500 mg"
  final MedicationForm form; // comprimé, sirop…
  final String? manufacturer; // ex : "Sanofi"
  final String? description; // notes libres
  final int? stockQuantity; // nb d'unités restantes (null = non suivi)
  final int? stockAlertThreshold; // alerte si stock <= seuil (null = pas d'alerte)
  final String? expiryDate; // "AAAA-MM-JJ" (null = non renseigné)
  final String? barcode; // code-barre scanné (optionnel)
  final String createdAt; // ISO 8601

  Medication({
    this.id,
    required this.userId,
    required this.name,
    this.dosage,
    this.form = MedicationForm.comprime,
    this.manufacturer,
    this.description,
    this.stockQuantity,
    this.stockAlertThreshold,
    this.expiryDate,
    this.barcode,
    required this.createdAt,
  });

  // ---------- Propriétés calculées ----------

  /// Libellé complet affiché dans la liste : "Doliprane 500 mg · Comprimé"
  String get fullLabel {
    final parts = [name];
    if (dosage != null && dosage!.isNotEmpty) parts.add(dosage!);
    parts.add('· ${medicationFormLabels[form] ?? 'Autre'}');
    return parts.join(' ');
  }

  /// true si le stock est en dessous du seuil d'alerte
  bool get isLowStock {
    if (stockQuantity == null || stockAlertThreshold == null) return false;
    return stockQuantity! <= stockAlertThreshold!;
  }

  /// true si la date d'expiration est passée ou dans les 30 prochains jours
  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final exp = DateTime.tryParse(expiryDate!);
    if (exp == null) return false;
    final now = DateTime.now();
    return exp.isBefore(now.add(const Duration(days: 30)));
  }

  bool get isExpired {
    if (expiryDate == null) return false;
    final exp = DateTime.tryParse(expiryDate!);
    if (exp == null) return false;
    return exp.isBefore(DateTime.now());
  }

  // ---------- Sérialisation ----------

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'dosage': dosage,
        'form': form.name,
        'manufacturer': manufacturer,
        'description': description,
        'stock_quantity': stockQuantity,
        'stock_alert_threshold': stockAlertThreshold,
        'expiry_date': expiryDate,
        'barcode': barcode,
        'created_at': createdAt,
      };

  factory Medication.fromMap(Map<String, dynamic> m) => Medication(
        id: m['id'] as int?,
        userId: m['user_id'] as int,
        name: m['name'] as String,
        dosage: m['dosage'] as String?,
        form: medicationFormFromString(m['form'] as String? ?? 'comprime'),
        manufacturer: m['manufacturer'] as String?,
        description: m['description'] as String?,
        stockQuantity: m['stock_quantity'] as int?,
        stockAlertThreshold: m['stock_alert_threshold'] as int?,
        expiryDate: m['expiry_date'] as String?,
        barcode: m['barcode'] as String?,
        createdAt: m['created_at'] as String,
      );

  Medication copyWith({
    String? name,
    String? dosage,
    MedicationForm? form,
    String? manufacturer,
    String? description,
    int? stockQuantity,
    int? stockAlertThreshold,
    String? expiryDate,
    String? barcode,
  }) =>
      Medication(
        id: id,
        userId: userId,
        name: name ?? this.name,
        dosage: dosage ?? this.dosage,
        form: form ?? this.form,
        manufacturer: manufacturer ?? this.manufacturer,
        description: description ?? this.description,
        stockQuantity: stockQuantity ?? this.stockQuantity,
        stockAlertThreshold: stockAlertThreshold ?? this.stockAlertThreshold,
        expiryDate: expiryDate ?? this.expiryDate,
        barcode: barcode ?? this.barcode,
        createdAt: createdAt,
      );
}
