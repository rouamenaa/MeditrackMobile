/// ============================================================
/// Module – MÉDICAMENTS : formulaire ajout / édition
///
/// Utilisé pour :
///  - Créer un nouveau médicament (medication == null)
///  - Modifier un médicament existant (medication != null)
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/medication.dart';
import '../repositories/medication_repository.dart';

// Réutilisation de la palette de l'écran principal
const _kPrimary = Color(0xFF0B6B5D);
const _kNavy = Color(0xFF0A2540);
const _kBg = Color(0xFFF4F8F7);
const _kMuted = Color(0xFF6B7280);

class MedicationFormScreen extends StatefulWidget {
  final int userId;
  final Medication? medication; // null = création

  const MedicationFormScreen({
    super.key,
    required this.userId,
    this.medication,
  });

  @override
  State<MedicationFormScreen> createState() => _MedicationFormScreenState();
}

class _MedicationFormScreenState extends State<MedicationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = MedicationRepository();

  // Contrôleurs de champs
  final _nameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _manufacturerCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _alertCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();

  MedicationForm _form = MedicationForm.comprime;
  String? _expiryDate; // "AAAA-MM-JJ"
  bool _trackStock = false;
  bool _loading = false;

  bool get _isEditing => widget.medication != null;

  @override
  void initState() {
    super.initState();
    final med = widget.medication;
    if (med != null) {
      _nameCtrl.text = med.name;
      _dosageCtrl.text = med.dosage ?? '';
      _manufacturerCtrl.text = med.manufacturer ?? '';
      _descriptionCtrl.text = med.description ?? '';
      _form = med.form;
      _expiryDate = med.expiryDate;
      if (med.stockQuantity != null) {
        _trackStock = true;
        _stockCtrl.text = med.stockQuantity.toString();
        _alertCtrl.text = med.stockAlertThreshold?.toString() ?? '';
      }
      _barcodeCtrl.text = med.barcode ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    _manufacturerCtrl.dispose();
    _descriptionCtrl.dispose();
    _stockCtrl.dispose();
    _alertCtrl.dispose();
    _barcodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickExpiryDate() async {
    final initial = _expiryDate != null
        ? (DateTime.tryParse(_expiryDate!) ?? DateTime.now())
        : DateTime.now().add(const Duration(days: 365));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2040),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              const ColorScheme.light(primary: _kPrimary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _expiryDate =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final stockQty =
        _trackStock && _stockCtrl.text.isNotEmpty
            ? int.tryParse(_stockCtrl.text)
            : null;
    final alertQty =
        _trackStock && _alertCtrl.text.isNotEmpty
            ? int.tryParse(_alertCtrl.text)
            : null;

    final now = DateTime.now().toIso8601String();

    if (_isEditing) {
      final updated = widget.medication!.copyWith(
        name: _nameCtrl.text.trim(),
        dosage: _dosageCtrl.text.trim().isEmpty
            ? null
            : _dosageCtrl.text.trim(),
        form: _form,
        manufacturer: _manufacturerCtrl.text.trim().isEmpty
            ? null
            : _manufacturerCtrl.text.trim(),
        description: _descriptionCtrl.text.trim().isEmpty
            ? null
            : _descriptionCtrl.text.trim(),
        stockQuantity: stockQty,
        stockAlertThreshold: alertQty,
        expiryDate: _expiryDate,
        barcode: _barcodeCtrl.text.trim().isEmpty
            ? null
            : _barcodeCtrl.text.trim(),
      );
      await _repo.update(updated);
    } else {
      final newMed = Medication(
        userId: widget.userId,
        name: _nameCtrl.text.trim(),
        dosage: _dosageCtrl.text.trim().isEmpty
            ? null
            : _dosageCtrl.text.trim(),
        form: _form,
        manufacturer: _manufacturerCtrl.text.trim().isEmpty
            ? null
            : _manufacturerCtrl.text.trim(),
        description: _descriptionCtrl.text.trim().isEmpty
            ? null
            : _descriptionCtrl.text.trim(),
        stockQuantity: stockQty,
        stockAlertThreshold: alertQty,
        expiryDate: _expiryDate,
        barcode: _barcodeCtrl.text.trim().isEmpty
            ? null
            : _barcodeCtrl.text.trim(),
        createdAt: now,
      );
      await _repo.create(newMed);
    }

    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).pop();
  }

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        foregroundColor: _kNavy,
        title: Text(
          _isEditing ? 'Modifier le médicament' : 'Nouveau médicament',
          style: const TextStyle(
              fontWeight: FontWeight.w800, fontSize: 18, color: _kNavy),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // ---------- Informations principales ----------
            _sectionTitle('Informations principales'),
            const SizedBox(height: 10),
            _fieldCard(children: [
              _textField(
                controller: _nameCtrl,
                label: 'Nom du médicament *',
                icon: Icons.medication_rounded,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nom obligatoire'
                    : null,
              ),
              _divider(),
              _textField(
                controller: _dosageCtrl,
                label: 'Dosage (ex : 500 mg)',
                icon: Icons.straighten_outlined,
              ),
              _divider(),
              _textField(
                controller: _manufacturerCtrl,
                label: 'Fabricant / Marque',
                icon: Icons.business_outlined,
              ),
            ]),

            const SizedBox(height: 20),

            // ---------- Forme pharmaceutique ----------
            _sectionTitle('Forme pharmaceutique'),
            const SizedBox(height: 10),
            _fieldCard(children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                child: DropdownButtonFormField<MedicationForm>(
                  value: _form,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.category_outlined,
                        color: _kMuted),
                    labelText: 'Forme',
                  ),
                  items: MedicationForm.values.map((f) {
                    return DropdownMenuItem(
                      value: f,
                      child: Text(medicationFormLabels[f] ?? f.name),
                    );
                  }).toList(),
                  onChanged: (v) =>
                      setState(() => _form = v ?? MedicationForm.comprime),
                ),
              ),
            ]),

            const SizedBox(height: 20),

            // ---------- Date d'expiration ----------
            _sectionTitle('Date d\'expiration'),
            const SizedBox(height: 10),
            _fieldCard(children: [
              ListTile(
                leading: const Icon(Icons.event_outlined, color: _kMuted),
                title: Text(
                  _expiryDate != null
                      ? _fmtDate(_expiryDate!)
                      : 'Non renseignée',
                  style: TextStyle(
                    color: _expiryDate != null
                        ? _kNavy
                        : Colors.grey.shade400,
                    fontSize: 15,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_expiryDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear, color: _kMuted),
                        onPressed: () =>
                            setState(() => _expiryDate = null),
                        tooltip: 'Effacer',
                      ),
                    TextButton(
                      onPressed: _pickExpiryDate,
                      child: const Text('Choisir',
                          style: TextStyle(color: _kPrimary)),
                    ),
                  ],
                ),
              ),
            ]),

            const SizedBox(height: 20),

            // ---------- Suivi du stock ----------
            _sectionTitle('Suivi du stock'),
            const SizedBox(height: 10),
            _fieldCard(children: [
              SwitchListTile(
                value: _trackStock,
                activeColor: _kPrimary,
                title: const Text('Activer le suivi du stock',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Comptez vos unités restantes',
                    style: TextStyle(fontSize: 12)),
                onChanged: (v) => setState(() => _trackStock = v),
              ),
              if (_trackStock) ...[
                _divider(),
                _textField(
                  controller: _stockCtrl,
                  label: 'Quantité en stock',
                  icon: Icons.inventory_2_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (!_trackStock) return null;
                    if (v == null || v.isEmpty) return 'Quantité obligatoire';
                    if (int.tryParse(v) == null) return 'Nombre invalide';
                    return null;
                  },
                ),
                _divider(),
                _textField(
                  controller: _alertCtrl,
                  label: 'Alerte si stock ≤ (optionnel)',
                  icon: Icons.notifications_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ],
            ]),

            const SizedBox(height: 20),

            // ---------- Notes ----------
            _sectionTitle('Notes'),
            const SizedBox(height: 10),
            _fieldCard(children: [
              _textField(
                controller: _descriptionCtrl,
                label: 'Description / Notes',
                icon: Icons.notes_outlined,
                maxLines: 3,
              ),
            ]),

            const SizedBox(height: 32),

            // ---------- Bouton Enregistrer ----------
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : Text(
                        _isEditing
                            ? 'Enregistrer les modifications'
                            : 'Ajouter le médicament',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------- Widgets helpers ---------

  Widget _sectionTitle(String title) => Text(
        title.toUpperCase(),
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _kMuted,
            letterSpacing: .8),
      );

  Widget _fieldCard({required List<Widget> children}) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(children: children),
      );

  Widget _divider() =>
      const Divider(height: 1, indent: 56, endIndent: 16);

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _kMuted),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
