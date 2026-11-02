/// ============================================================
/// Module – MÉDICAMENTS : écran de détail
/// Affiche toutes les informations d'un médicament + gestion stock.
///
/// Navigation :
///  - Bouton modifier -> MedicationFormScreen
///  - Bouton supprimer (avec confirmation) -> pop
///  - Boutons +/- stock -> mise à jour directe
/// ============================================================
library;

import 'package:flutter/material.dart';
import '../../auth/models/user.dart';
import '../models/medication.dart';
import '../repositories/medication_repository.dart';
import 'medication_form_screen.dart';

const _kPrimary = Color(0xFF0B6B5D);
const _kGreen = Color(0xFF12B76A);
const _kGreenSoft = Color(0xFFDCFCE7);
const _kTealSoft = Color(0xFFE0F2F1);
const _kOrangeSoft = Color(0xFFFFF7ED);
const _kRedSoft = Color(0xFFFFE4E6);
const _kBlueSoft = Color(0xFFDBEAFE);
const _kBg = Color(0xFFF4F8F7);
const _kTextDark = Color(0xFF1F2937);
const _kMuted = Color(0xFF6B7280);
const _kNavy = Color(0xFF0A2540);

class MedicationDetailScreen extends StatefulWidget {
  final User user;
  final Medication medication;
  final VoidCallback onChanged;

  const MedicationDetailScreen({
    super.key,
    required this.user,
    required this.medication,
    required this.onChanged,
  });

  @override
  State<MedicationDetailScreen> createState() =>
      _MedicationDetailScreenState();
}

class _MedicationDetailScreenState extends State<MedicationDetailScreen> {
  final _repo = MedicationRepository();
  late Medication _med;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _med = widget.medication;
  }

  Future<void> _refresh() async {
    final fresh =
        await _repo.byIdForUser(_med.id!, widget.user.id!);
    if (fresh != null && mounted) {
      setState(() => _med = fresh);
    }
  }

  Future<void> _decrementStock() async {
    setState(() => _loading = true);
    final ok =
        await _repo.decrementStock(_med.id!, widget.user.id!);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) {
      _snack('Stock déjà à 0 ou non suivi');
    } else {
      widget.onChanged();
      await _refresh();
      if (_med.isLowStock) {
        _snack(
            '⚠️ Stock bas : ${_med.stockQuantity} unité(s) restante(s)');
      }
    }
  }

  Future<void> _incrementStock(int amount) async {
    setState(() => _loading = true);
    await _repo.incrementStock(_med.id!, widget.user.id!, amount);
    if (!mounted) return;
    setState(() => _loading = false);
    widget.onChanged();
    await _refresh();
    _snack('✅ +$amount unité(s) ajoutée(s)');
  }

  Future<void> _openForm() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MedicationFormScreen(
        userId: widget.user.id!,
        medication: _med,
      ),
    ));
    widget.onChanged();
    await _refresh();
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le médicament'),
        content: Text(
            'Voulez-vous vraiment supprimer "${_med.name}" ? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Annuler', style: TextStyle(color: _kMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _repo.delete(_med.id!, widget.user.id!);
    if (!mounted) return;
    widget.onChanged();
    Navigator.of(context).pop();
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg), behavior: SnackBarBehavior.floating));

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    final hasExpired = _med.isExpired;
    final isExpiringSoon = _med.isExpiringSoon && !hasExpired;
    final hasLowStock = _med.isLowStock;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        foregroundColor: _kNavy,
        title: Text(
          _med.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontWeight: FontWeight.w800, fontSize: 18, color: _kNavy),
        ),
        actions: [
          IconButton(
            tooltip: 'Modifier',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _openForm,
          ),
          IconButton(
            tooltip: 'Supprimer',
            icon: const Icon(Icons.delete_outline,
                color: Color(0xFFDC2626)),
            onPressed: _delete,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: _kPrimary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            // ---- En-tête : icône + nom + badges ----
            _headerCard(hasExpired, isExpiringSoon, hasLowStock),
            const SizedBox(height: 16),

            // ---- Alertes actives ----
            if (hasExpired) ...[
              _alertBanner(
                icon: Icons.warning_rounded,
                bg: _kRedSoft,
                color: const Color(0xFFDC2626),
                message:
                    'Ce médicament est expiré depuis le ${_fmtDate(_med.expiryDate!)}.',
              ),
              const SizedBox(height: 12),
            ] else if (isExpiringSoon) ...[
              _alertBanner(
                icon: Icons.event_outlined,
                bg: _kOrangeSoft,
                color: const Color(0xFFD97706),
                message:
                    'Expire le ${_fmtDate(_med.expiryDate!)} (dans moins de 30 jours).',
              ),
              const SizedBox(height: 12),
            ],
            if (hasLowStock) ...[
              _alertBanner(
                icon: Icons.inventory_2_outlined,
                bg: _kOrangeSoft,
                color: const Color(0xFFD97706),
                message:
                    'Stock bas : ${_med.stockQuantity} unité(s) restante(s).',
              ),
              const SizedBox(height: 12),
            ],

            // ---- Détails ----
            _sectionCard(
              title: 'Informations',
              icon: Icons.info_outline,
              children: [
                _infoRow('Nom', _med.name),
                if (_med.dosage != null && _med.dosage!.isNotEmpty)
                  _infoRow('Dosage', _med.dosage!),
                _infoRow(
                    'Forme',
                    medicationFormLabels[_med.form] ??
                        _med.form.name),
                if (_med.manufacturer != null &&
                    _med.manufacturer!.isNotEmpty)
                  _infoRow('Fabricant', _med.manufacturer!),
                if (_med.expiryDate != null)
                  _infoRow('Expiration', _fmtDate(_med.expiryDate!),
                      valueColor: hasExpired
                          ? const Color(0xFFDC2626)
                          : isExpiringSoon
                              ? const Color(0xFFD97706)
                              : null),
                if (_med.description != null &&
                    _med.description!.isNotEmpty)
                  _infoRow('Notes', _med.description!),
              ],
            ),

            const SizedBox(height: 16),

            // ---- Gestion du stock ----
            if (_med.stockQuantity != null) ...[
              _stockCard(),
              const SizedBox(height: 16),
            ],

            // ---- Date d'ajout ----
            _sectionCard(
              title: 'Ajouté le',
              icon: Icons.calendar_today_outlined,
              children: [
                _infoRow('Date', _fmtDate(_med.createdAt.substring(0, 10))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --------- Widgets helpers ---------

  Widget _headerCard(
      bool hasExpired, bool isExpiringSoon, bool hasLowStock) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _kTealSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.medication_rounded,
                color: _kPrimary, size: 34),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _med.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: _kTextDark),
                ),
                const SizedBox(height: 4),
                Text(
                  _med.fullLabel,
                  style:
                      const TextStyle(color: _kMuted, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    if (hasExpired)
                      _badge('Expiré', _kRedSoft,
                          const Color(0xFFDC2626))
                    else if (isExpiringSoon)
                      _badge('Expire bientôt', _kOrangeSoft,
                          const Color(0xFFD97706)),
                    if (hasLowStock)
                      _badge('Stock bas', _kOrangeSoft,
                          const Color(0xFFD97706))
                    else if (_med.stockQuantity != null)
                      _badge(
                          '${_med.stockQuantity} en stock',
                          _kGreenSoft,
                          _kGreen),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _alertBanner({
    required IconData icon,
    required Color bg,
    required Color color,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _kPrimary, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: _kTextDark),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _stockCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined,
                  color: _kPrimary, size: 18),
              const SizedBox(width: 8),
              const Text('Gestion du stock',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: _kTextDark)),
              const Spacer(),
              if (_med.stockAlertThreshold != null)
                Text(
                  'Alerte : ≤ ${_med.stockAlertThreshold}',
                  style: const TextStyle(
                      color: _kMuted, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Bouton décrémenter
              _stockBtn(
                icon: Icons.remove,
                color: const Color(0xFFDC2626),
                bg: _kRedSoft,
                onTap: _loading ? null : _decrementStock,
                tooltip: 'Prendre 1',
              ),
              const SizedBox(width: 24),
              // Valeur
              Column(
                children: [
                  Text(
                    '${_med.stockQuantity}',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: _med.isLowStock
                          ? const Color(0xFFD97706)
                          : _kPrimary,
                    ),
                  ),
                  const Text('unités',
                      style:
                          TextStyle(color: _kMuted, fontSize: 13)),
                ],
              ),
              const SizedBox(width: 24),
              // Bouton incrémenter
              _stockBtn(
                icon: Icons.add,
                color: _kPrimary,
                bg: _kTealSoft,
                onTap: _loading ? null : () => _showAddStockDialog(),
                tooltip: 'Ajouter du stock',
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _quickAddBtn('+5'),
              _quickAddBtn('+10'),
              _quickAddBtn('+20'),
              _quickAddBtn('+30'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stockBtn({
    required IconData icon,
    required Color color,
    required Color bg,
    required VoidCallback? onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
              color: bg, shape: BoxShape.circle),
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _kPrimary),
                )
              : Icon(icon, color: color, size: 26),
        ),
      ),
    );
  }

  Widget _quickAddBtn(String label) {
    final amount = int.parse(label.replaceAll('+', ''));
    return TextButton(
      onPressed: _loading ? null : () => _incrementStock(amount),
      style: TextButton.styleFrom(
        foregroundColor: _kPrimary,
        backgroundColor: _kTealSoft,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      child: Text(label,
          style: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }

  Future<void> _showAddStockDialog() async {
    final ctrl = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter du stock'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Quantité à ajouter',
            prefixIcon: Icon(Icons.add),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler',
                style: TextStyle(color: _kMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text);
              Navigator.pop(ctx, v);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (result != null && result > 0) {
      await _incrementStock(result);
    }
  }

  Widget _infoRow(String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                  color: _kMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? _kTextDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color bg, Color fg) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999)),
        child: Text(label,
            style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      );

  String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
