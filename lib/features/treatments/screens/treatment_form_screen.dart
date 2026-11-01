/// ============================================================
/// Module 3.3 — TRAITEMENTS : formulaire Ajout / Modification
///
/// Recette du cours (Ch4 - Forms & Navigation) :
///   `Form` + `GlobalKey<FormState>` + `TextFormField(validator)`
///   -> validate() puis save() avant d'envoyer.
/// Saisie confortable (widgets Material fournis avec Flutter) :
///   - showDatePicker / showTimePicker          -> dates + horaires
///   - showModalBottomSheet + ChoiceChip/stepper -> forme, dosage, dose
/// Champs du PDF (§3.2/3.3) : médicament (nom + forme + dosage),
/// dose par prise, fréquence (horaires), début / fin (chronique si vide).
/// ============================================================
library;

import 'package:flutter/material.dart';

import '../models/treatment.dart';
import '../repositories/treatment_repository.dart';

/// Formes du médicament (énum `MedicationForm` du doc §5)
const List<(String, IconData)> _kForms = [
  ('Comprimé', Icons.medication_rounded),
  ('Gélule', Icons.healing_rounded),
  ('Sirop', Icons.local_drink_rounded),
  ('Injection', Icons.vaccines_rounded),
  ('Gouttes', Icons.water_drop_rounded),
  ('Crème', Icons.format_paint_rounded),
  ('Autre', Icons.category_rounded),
];

/// Unités de dosage proposées (mg / g / ml / UI comme dans le PDF)
const List<String> _kDosageUnits = ['mg', 'g', 'ml', 'UI'];

const List<String> _kDoseUnits = [
  'comprimé(s)',
  'gélule(s)',
  'cuillère(s)',
  'ml',
  'goutte(s)',
  'dose(s)',
  'application(s)',
];

class TreatmentFormScreen extends StatefulWidget {
  final int userId;
  final Treatment? treatment; // null = AJOUT, sinon = MODIFICATION
  const TreatmentFormScreen({super.key, required this.userId, this.treatment});

  @override
  State<TreatmentFormScreen> createState() => _TreatmentFormState();
}

class _TreatmentFormState extends State<TreatmentFormScreen> {
  final _key = GlobalKey<FormState>();

  // ---------- champs texte (validate() + save(), comme en cours)
  String _medName = '';

  // ---------- forme / dosage / dose (choisis via bottom-sheets)
  String? _selectedForm; // ex : "Comprimé"
  String? _dosage; // ex : "500 mg"
  String _dose = ''; // ex : "2 comprimés"
  // valeurs temporaires des feuilles modales
  double _dosageNum = 500;
  String _dosageUnit = 'mg';
  int _doseQty = 1;
  String _doseUnit = 'comprimé(s)';

  // ---------- horaires choisis à l'horloge
  List<String> _times = [];

  // ---------- dates choisies au calendrier
  DateTime? _start;
  DateTime? _end;
  final _startCtl = TextEditingController();
  final _endCtl = TextEditingController();

  // contrôleurs des champs "picker" (forme / dosage / dose)
  final _formCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _doseCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final t = widget.treatment;
    if (t != null) {
      _start = t.startDate;
      _startCtl.text = _fmtDate(t.startDate);
      if (t.endDate != null) {
        _end = t.endDate;
        _endCtl.text = _fmtDate(t.endDate!);
      }
      _times = List<String>.from(t.reminderTimes);
      _prefillMedication(t);
    } else {
      _start = _dayStart(DateTime.now());
      _startCtl.text = _fmtDate(_start!);
      _times = ['08:00'];
      _selectedForm = _kForms.first.$1;
      _dosage = null;
      _dose = '';
    }
    _formCtrl.text = _selectedForm ?? '';
    _dosageCtrl.text = _dosage ?? '';
    _doseCtrl.text = _dose.isEmpty ? '$_doseQty $_doseUnit' : _dose;
    if (_dose.isEmpty) {
      _dose = '$_doseQty $_doseUnit';
    }
  }

  /// Pré-remplit forme + dosage + dose à partir des chaînes stockées
  void _prefillMedication(Treatment t) {
    // dosage "500 mg" ?
    final mDosage =
        RegExp(r'^\s*(\d+(?:[.,]\d+)?)\s*([a-zA-Zé]+)\s*$').firstMatch(t.medicationDosage ?? '');
    if (mDosage != null) {
      _dosage = t.medicationDosage;
      _dosageNum = double.tryParse(mDosage.group(1)!.replaceAll(',', '.')) ?? 500;
      final u = mDosage.group(2)!.toLowerCase();
      _dosageUnit = _kDosageUnits.contains(u) ? u : 'mg';
    } else if ((t.medicationDosage ?? '').trim().isEmpty) {
      _selectedForm = null;
    }
    // dose "2 comprimés" ?
    final mDose = RegExp(r'^\s*(\d+)\s+(.+)$').firstMatch(t.dose);
    if (mDose != null) {
      _dose = t.dose;
      _doseQty = int.tryParse(mDose.group(1)!) ?? 1;
      final u = mDose.group(2)!.toLowerCase();
      _doseUnit = _kDoseUnits.firstWhere((e) => e.contains(u),
          orElse: () => 'dose(s)');
    } else {
      _dose = t.dose; // ex : "1" -> qty=1, unité par défaut
      _doseQty = 1;
      _doseUnit = 'dose(s)';
    }
    _selectedForm ??= _kForms.first.$1;
  }

  @override
  void dispose() {
    _startCtl.dispose();
    _endCtl.dispose();
    _formCtrl.dispose();
    _dosageCtrl.dispose();
    _doseCtrl.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.treatment != null;

  // ---------- petits utilitaires ----------

  static DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _fmtTimeOfDay(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _fmtNum(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  // ---------- validateurs ----------

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Champ requis' : null;

  String? _validateStart(String? v) => _start == null ? 'Choisissez une date' : null;

  // ---------- sélecteur : dates et horaires ----------

  Future<void> _pickDate(bool isStart) async {
    final now = _dayStart(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _start ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      helpText: isStart ? 'Date de début' : 'Date de fin',
      cancelText: 'Annuler',
      confirmText: 'Valider',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _start = _dayStart(picked);
        _startCtl.text = _fmtDate(_start!);
        if (_end != null && _end!.isBefore(_start!)) {
          _end = _dayStart(_start!);
          _endCtl.text = _fmtDate(_end!);
        }
      } else {
        _end = _dayStart(picked);
        _endCtl.text = _fmtDate(_end!);
      }
    });
  }

  Future<void> _addTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'Horaire de prise',
      cancelText: 'Annuler',
      confirmText: 'Valider',
    );
    if (t == null || !mounted) return;
    setState(() {
      _times.add(_fmtTimeOfDay(t));
      _times.sort(); // "HH:mm" se trie lexicographiquement
    });
  }

  // ---------- sélecteur : FORME (bottom-sheet avec icônes) ----------

  void _pickForm() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Forme du médicament',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              for (final (label, icon) in _kForms)
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _selectedForm == label
                          ? const Color(0xFFE0F2F1)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon,
                        size: 22,
                        color: _selectedForm == label
                            ? const Color(0xFF0B6B5D)
                            : const Color(0xFF6B7280)),
                  ),
                  title: Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: _selectedForm == label
                      ? const Icon(Icons.check_rounded, color: Color(0xFF12B76A))
                      : null,
                  onTap: () => Navigator.pop(c, label),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ).then((label) {
      if (label is String && mounted) {
        setState(() {
          _selectedForm = label;
          // unité de dose par défaut selon la forme choisie
          _doseUnit = switch (label) {
            'Comprimé' => 'comprimé(s)',
            'Gélule' => 'gélule(s)',
            'Sirop' => 'cuillère(s)',
            'Gouttes' => 'goutte(s)',
            'Injection' => 'dose(s)',
            'Crème' => 'application(s)',
            _ => 'dose(s)',
          };
          _formCtrl.text = label;
        });
      }
    });
  }

  // ---------- sélecteur : DOSAGE (bottom-sheet valeur + unité) ----------

  void _pickDosage() {
    final textCtl = TextEditingController(text: _fmtNum(_dosageNum));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (c) => Padding(
        padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(c).viewInsets.bottom + 16,
            top: 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dosage du médicament',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('Ex : 500 mg — appuyez sur une valeur rapide ou tapez-la.',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
              const SizedBox(height: 12),
              // valeurs rapides
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final v in const [100, 250, 500, 875, 1000])
                    ChoiceChip(
                      label: Text('$v mg'),
                      selected: _dosageNum == v && _dosageUnit == 'mg',
                      selectedColor: const Color(0xFFCFE9E4),
                      onSelected: (_) {
                        setState(() {
                          _dosageNum = v.toDouble();
                          _dosageUnit = 'mg';
                        });
                        textCtl.text = '$v';
                      },
                    ),
                  for (final q in const ['5 ml', '10 ml', '1 g'])
                    ChoiceChip(
                      label: Text(q),
                      selected: _dosage == q,
                      selectedColor: const Color(0xFFCFE9E4),
                      onSelected: (_) {
                        final parts = q.split(' ');
                        setState(() {
                          _dosage = q;
                          _dosageNum = double.tryParse(parts[0]) ?? 1;
                          _dosageUnit = parts[1];
                        });
                        textCtl.text = parts[0];
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // valeur + unité
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: textCtl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Quantité',
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final u in _kDosageUnits)
                          ChoiceChip(
                            label: Text(u),
                            selected: _dosageUnit == u,
                            selectedColor: const Color(0xFFCFE9E4),
                            onSelected: (_) =>
                                setState(() => _dosageUnit = u),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0B6B5D),
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () {
                  final v = double.tryParse(textCtl.text.replaceAll(',', '.'));
                  if (v == null || v <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Entrez une valeur valide (ex : 500)')));
                    return;
                  }
                  Navigator.pop(context);
                  setState(() {
                    _dosageNum = v;
                    _dosage = '${_fmtNum(v)} $_dosageUnit';
                    _dosageCtrl.text = _dosage!;
                  });
                },
                child: const Text('Valider',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- sélecteur : DOSE PAR PRISE (stepper + unité) ----------

  void _pickDose() {
    var qty = _doseQty;
    var unit = _doseUnit;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (c) => StatefulBuilder(
        builder: (c, setSheetState) => Padding(
          padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              // micro marge avant le clavier si jamais il s'ouvre
              bottom: MediaQuery.of(c).viewInsets.bottom + 16),
          // SingleChildScrollView : la feuille ne doit JAMAIS overflow
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dose par prise',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  _dosage == null
                      ? 'Combien à chaque prise ?'
                      : 'Dosage $_dosage — combien à chaque prise ?',
                  style:
                      const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                ),
                const SizedBox(height: 12),
                // stepper [-  2  +]
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: qty <= 1 ? null : () => setSheetState(() => qty--),
                      style:
                          IconButton.styleFrom(backgroundColor: const Color(0xFFE0F2F1)),
                      icon: const Icon(Icons.remove_rounded, color: Color(0xFF0B6B5D)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Text('$qty',
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w800)),
                    ),
                    IconButton(
                      onPressed: () => setSheetState(() => qty++),
                      style:
                          IconButton.styleFrom(backgroundColor: const Color(0xFFE0F2F1)),
                      icon: const Icon(Icons.add_rounded, color: Color(0xFF0B6B5D)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // unité de la dose
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final u in _kDoseUnits)
                      ChoiceChip(
                        label: Text(u),
                        selected: unit == u,
                        selectedColor: const Color(0xFFCFE9E4),
                        onSelected: (_) => setSheetState(() => unit = u),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0B6B5D),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () {
                    setState(() {
                      _doseQty = qty;
                      _doseUnit = unit;
                      _dose = '$qty $unit';
                      _doseCtrl.text = _dose;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Valider',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- résumé du plan (live) ----------

  String get _planSummary {
    final nPerDay = _times.length;
    if (nPerDay == 0) return 'Ajoutez au moins un horaire.';
    if (_start == null) return 'Choisissez une date de début.';
    final end = _end;
    if (end == null) {
      final total = 60 * nPerDay;
      return 'Traitement chronique : prises générées pour '
          'les 60 prochains jours (~$total prises).';
    }
    final days = end.difference(_dayStart(_start!)).inDays + 1;
    if (days <= 0) return 'La date de fin doit être après le début.';
    return '≈ ${days * nPerDay} prises réparties sur $days jour(s).';
  }

  // ---------- sauvegarde ----------

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    _key.currentState!.save();

    if (_start == null) {
      _snack('Choisissez une date de début.');
      return;
    }
    if (_end != null && _end!.isBefore(_start!)) {
      _snack('La date de fin doit être après la date de début.');
      return;
    }
    if (_times.isEmpty) {
      _snack('Ajoutez au moins un horaire de prise.');
      return;
    }

    final t = Treatment(
      id: widget.treatment?.id,
      userId: widget.userId,
      medicationName: _medName.trim(),
      medicationDosage: _dosage,
      dose: _dose.trim().isEmpty ? '$_doseQty $_doseUnit' : _dose,
      reminderTimes: _times,
      startDate: _start!,
      endDate: _end,
      status: widget.treatment?.status ?? TreatmentStatus.active,
    );

    try {
      final repo = TreatmentRepository();
      if (_isEdit) {
        await repo.update(t); // where + whereArgs (piège du cours !)
      } else {
        await repo.create(t);
      }
    } catch (e) {
      if (mounted) _snack('Erreur : $e');
      return;
    }
    if (mounted) Navigator.pop(context); // liste rechargée par _reload()
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));

  // ================= BUILD =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text(
          _isEdit ? 'Modifier le traitement' : 'Nouveau traitement',
          style: const TextStyle(
              fontWeight: FontWeight.w800, color: Color(0xFF1F2937)),
        ),
      ),
      body: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('MÉDICAMENT'),
            _field(
              label: 'Nom du médicament *',
              hint: 'Ex : Amoxicilline',
              initialValue: widget.treatment?.medicationName,
              icon: Icons.medication_rounded,
              validator: _required,
              onSaved: (v) => _medName = v!,
            ),
            _pickerField(
              label: 'Forme',
              value: _selectedForm == null ? null : (_selectedForm!),
              hint: 'Ex : Comprimé',
              icon: _iconOf(_selectedForm),
              onTap: _pickForm,
              controller: _formCtrl,
            ),
            _pickerField(
              label: 'Dosage',
              value: _dosage,
              hint: 'Ex : 500 mg',
              icon: Icons.scale_rounded,
              onTap: _pickDosage,
              controller: _dosageCtrl,
            ),
            _pickerField(
              label: 'Dose par prise *',
              value: _dose,
              hint: 'Ex : 2 comprimés',
              icon: Icons.water_drop_rounded,
              onTap: _pickDose,
              controller: _doseCtrl,
            ),

            _section('HORAIRES DES PRISES'),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final time in _times)
                    InputChip(
                      avatar: const Icon(Icons.access_time_rounded,
                          size: 18, color: Color(0xFF0B6B5D)),
                      label: Text(time,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      backgroundColor: const Color(0xFFE0F2F1),
                      onDeleted: () => setState(() => _times.remove(time)),
                      deleteIconColor: const Color(0xFF6B7280),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add_alarm_rounded, size: 18),
                    label: const Text('Ajouter un horaire'),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF0B6B5D)),
                    onPressed: _addTime,
                  ),
                ],
              ),
            ),
            _infoCard(
              icon: Icons.query_stats_rounded,
              title: 'Fréquence : ${_times.length} prise(s) par jour',
              subtitle: 'Les prises sont planifiées automatiquement chaque '
                  'jour à ces horaires (modifiables après).',
            ),

            _section('PÉRIODE DU TRAITEMENT'),
            _dateField(
              controller: _startCtl,
              labelText: 'Date de début *',
              icon: Icons.event_available_rounded,
              validator: _validateStart,
              onTap: () => _pickDate(true),
            ),
            _dateField(
              controller: _endCtl,
              labelText: 'Date de fin (vide = chronique)',
              icon: Icons.event_busy_rounded,
              onTap: () => _pickDate(false),
              suffix: _end == null
                  ? IconButton(
                      tooltip: 'Choisir une date de fin',
                      icon: const Icon(Icons.calendar_today_rounded, size: 20),
                      onPressed: () => _pickDate(false),
                    )
                  : IconButton(
                      tooltip: 'Retirer (traitement chronique)',
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => setState(() {
                        _end = null;
                        _endCtl.clear();
                      }),
                    ),
            ),
            _infoCard(
              icon: Icons.summarize_rounded,
              title: 'Résumé du plan',
              subtitle: _planSummary,
            ),

            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0B6B5D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Enregistrer',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Historique des prises déjà passées : jamais modifié.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- helpers UI ----------

  IconData _iconOf(String? form) =>
      _kForms.firstWhere((f) => f.$1 == form, orElse: () => ('', Icons.medication_rounded)).$2;

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(title,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: .6,
                color: Color(0xFF6B7280))),
      );

  Widget _infoCard({
    required IconData icon,
    required String title,
    String? subtitle,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFE6F4F1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF0B6B5D)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0B6B5D))),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Color(0xFF6B7280), fontSize: 12)),
                  ],
                ],
              ),
            ),
          ],
        ),
      );

  InputDecoration _decoration({
    String? labelText,
    IconData? icon,
    Widget? suffix,
    String? hint,
  }) =>
      InputDecoration(
        labelText: labelText,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        prefixIcon: icon == null ? null : Icon(icon, size: 20),
        suffixIcon: suffix,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF0B6B5D), width: 1.5)),
      );

  /// Champ texte libre (nom du médicament)
  Widget _field({
    required String label,
    required String hint,
    String? initialValue,
    IconData? icon,
    String? Function(String?)? validator,
    void Function(String?)? onSaved,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: TextFormField(
          initialValue: initialValue,
          validator: validator,
          onSaved: onSaved,
          decoration: _decoration(labelText: label, icon: icon, hint: hint),
        ),
      );

  /// Champ "ne se tape pas" : readOnly + onTap -> picker
  Widget _pickerField({
    required String label,
    required String? value,
    required String? hint,
    required IconData icon,
    required VoidCallback onTap,
    required TextEditingController controller,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: TextFormField(
          readOnly: true,
          onTap: onTap,
          controller: controller,
          decoration: _decoration(
            labelText: label,
            icon: icon,
            hint: hint,
            suffix: const Icon(Icons.expand_more_rounded, size: 20, color: Color(0xFF6B7280)),
          ),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );

  /// Champ date (calendar via showDatePicker)
  Widget _dateField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    required VoidCallback onTap,
    String? Function(String?)? validator,
    Widget? suffix,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: TextFormField(
          controller: controller,
          readOnly: true,
          onTap: onTap,
          validator: validator,
          decoration: _decoration(labelText: labelText, icon: icon, suffix: suffix),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
}
