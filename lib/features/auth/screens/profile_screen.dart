import 'dart:io';
import 'package:flutter/material.dart';
import '../models/medecin.dart';
import '../models/user.dart';
import '../repositories/medecin_repository.dart';
import '../repositories/user_repository.dart';
import 'login_screen.dart';

const _kCardBg = Color(0xFFEDEFFD);
const _kFieldBg = Color(0xFFEEF0FC);
const _kEmergencyBg = Color(0xFFFFE3E0);
const _kEmergencyText = Color(0xFFB3261E);

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July',
  'August', 'September', 'October', 'November', 'December'
];

class ProfileScreen extends StatefulWidget {
  final User user;
  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _userRepo = UserRepository();
  final _medRepo = MedecinRepository();

  late User _user;
  List<Medecin> _medecins = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _load();
  }

  // Recharge toujours les données fraîches depuis SQLite
  Future<void> _load() async {
    final fresh = await _userRepo.getById(widget.user.id!);
    final meds = await _medRepo.getByUser(widget.user.id!);
    if (!mounted) return;
    setState(() {
      if (fresh != null) _user = fresh;
      _medecins = meds;
      _loading = false;
    });
  }

  void _soon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature : bientôt disponible')),
    );
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  String _formatDate(User u) {
    final d = DateTime.tryParse(u.dateNaissance ?? '');
    if (d == null) return 'Not set';
    return '${_months[d.month - 1]} ${d.day}, ${d.year} (${u.age} yrs)';
  }

  String _initials(User u) {
    final p = u.prenom.isNotEmpty ? u.prenom[0] : '';
    final n = u.nom.isNotEmpty ? u.nom[0] : '';
    return (p + n).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: kNavy,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: kGreen, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Profile',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeader(u),
            const SizedBox(height: 16),
            _buildPersonalDetails(u),
            const SizedBox(height: 16),
            _buildCare(u),
            const SizedBox(height: 20),
            _buildButtons(),
          ],
        ),
      ),
    );
  }

  // ---------------- En-tête : photo, nom, ID, groupe sanguin ----------------
  Widget _buildHeader(User u) {
    final hasPhoto = u.photoPath != null && File(u.photoPath!).existsSync();
    final health = [
      if (u.groupeSanguin != null && u.groupeSanguin!.isNotEmpty)
        u.groupeSanguin!,
      if (u.conditionMedicale != null && u.conditionMedicale!.isNotEmpty)
        u.conditionMedicale!,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
          color: _kCardBg, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 46,
                backgroundColor: const Color(0xFFD5E7E4),
                backgroundImage:
                hasPhoto ? FileImage(File(u.photoPath!)) : null,
                child: hasPhoto
                    ? null
                    : Text(_initials(u),
                    style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: kGreen)),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: () => _soon('Changer la photo'),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                        color: kGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2)),
                    child: const Icon(Icons.photo_camera,
                        size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(u.fullName,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800, color: kNavy)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: const Color(0xFFD9E3F5),
                borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user_outlined,
                    size: 15, color: Color(0xFF3B4A6B)),
                const SizedBox(width: 6),
                Text('MediTrack ID: ${u.meditrackId}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3B4A6B))),
              ],
            ),
          ),
          if (health.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFD9D5),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emergency,
                      size: 15, color: _kEmergencyText),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(health,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _kEmergencyText)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------- Personal Details ----------------
  Widget _buildPersonalDetails(User u) {
    final hasEmergency = (u.contactUrgenceNom ?? '').isNotEmpty;
    final emergencyName = hasEmergency
        ? '${u.contactUrgenceNom}'
        '${(u.contactUrgenceLien ?? '').isNotEmpty ? ' (${u.contactUrgenceLien})' : ''}'
        : 'Not set';

    return _SectionCard(
      title: 'Personal Details',
      icon: Icons.assignment_ind_outlined,
      iconColor: kGreen,
      children: [
        _Field(label: 'Full Name', icon: Icons.person_outline, value: u.fullName),
        _Field(
          label: 'Email Address',
          icon: Icons.mail_outline,
          value: u.email,
          trailing:
          const Icon(Icons.check_circle_outline, color: kGreen, size: 22),
        ),
        _Field(
          label: 'Phone Number',
          icon: Icons.phone_outlined,
          value: (u.telephone ?? '').isEmpty ? 'Not set' : u.telephone!,
        ),
        _Field(
          label: 'Date of Birth',
          icon: Icons.calendar_today_outlined,
          value: _formatDate(u),
        ),
        const Text('Emergency Contact',
            style: TextStyle(
                color: _kEmergencyText,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: _kEmergencyBg, borderRadius: BorderRadius.circular(10)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.contact_phone_outlined,
                  color: _kEmergencyText, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(emergencyName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    if ((u.contactUrgenceTel ?? '').isNotEmpty)
                      Text(u.contactUrgenceTel!,
                          style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------- Care & Coverage ----------------
  Widget _buildCare(User u) {
    final hasInsurance = (u.assuranceNom ?? '').isNotEmpty;

    return _SectionCard(
      title: 'Care & Coverage',
      icon: Icons.health_and_safety,
      iconColor: const Color(0xFF1B4FBF),
      children: [
        _InfoTile(
          icon: Icons.account_balance_outlined,
          iconBg: const Color(0xFFD9E3F5),
          iconColor: const Color(0xFF1B4FBF),
          small: 'Insurance Provider',
          lines: hasInsurance
              ? [
            _Line(u.assuranceNom!, bold: true),
            if ((u.assurancePolice ?? '').isNotEmpty)
              _Line('Policy #${u.assurancePolice}'),
          ]
              : [_Line('Not set', bold: true)],
        ),
        const SizedBox(height: 12),
        _InfoTile(
          icon: Icons.medical_services_outlined,
          iconBg: const Color(0xFFD5E7E4),
          iconColor: kGreen,
          small: 'Primary Care Physicians',
          lines: _medecins.isEmpty
              ? [_Line('Not set', bold: true)]
              : [
            for (final m in _medecins) ...[
              _Line(m.nom, bold: true),
              _Line(m.specialite),
            ]
          ],
        ),
      ],
    );
  }

  // ---------------- Boutons ----------------
  Widget _buildButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => _soon('Edit Profile'),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit Profile',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: kGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => _soon('Export PDF'),
            icon: const Icon(Icons.description_outlined, size: 18),
            label: const Text('Medical Records & Export PDF',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDDE4FA),
              foregroundColor: kNavy,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: _logout,
          icon: Icon(Icons.logout, size: 18, color: Colors.grey.shade700),
          label: Text('Log out',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 16)),
        ),
      ],
    );
  }
}

// ======================= Petits widgets réutilisables =======================

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: kNavy)),
              Icon(icon, color: iconColor),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final Widget? trailing;

  const _Field({
    required this.label,
    required this.icon,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
                color: _kFieldBg, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Icon(icon, size: 22, color: kNavy),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(value, style: const TextStyle(fontSize: 16)),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Line {
  final String text;
  final bool bold;
  _Line(this.text, {this.bold = false});
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String small;
  final List<_Line> lines;

  const _InfoTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.small,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: _kFieldBg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(small,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700)),
                const SizedBox(height: 2),
                for (final l in lines)
                  Text(l.text,
                      style: TextStyle(
                          fontSize: l.bold ? 17 : 14,
                          fontWeight:
                          l.bold ? FontWeight.w700 : FontWeight.w400)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}