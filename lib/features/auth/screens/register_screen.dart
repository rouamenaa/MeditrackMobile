import 'package:flutter/material.dart';
import '../repositories/user_repository.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart' show kGreen, kNavy, kBackground;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomCtrl = TextEditingController();
  final _prenomCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _repo = UserRepository();

  String? _sexe;
  bool _hidePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _nomCtrl.dispose();
    _prenomCtrl.dispose();
    _emailCtrl.dispose();
    _telCtrl.dispose();
    _dateCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      final m = picked.month.toString().padLeft(2, '0');
      final d = picked.day.toString().padLeft(2, '0');
      _dateCtrl.text = '${picked.year}-$m-$d';
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final user = await _repo.register(
      nom: _nomCtrl.text,
      prenom: _prenomCtrl.text,
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
      telephone: _telCtrl.text.trim().isEmpty ? null : _telCtrl.text.trim(),
      dateNaissance: _dateCtrl.text.isEmpty ? null : _dateCtrl.text,
      sexe: _sexe,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cet email est déjà utilisé')),
      );
      return;
    }

    // On remplace toutes les pages précédentes par l'accueil
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
          (route) => false,
    );
  }

  InputDecoration _decoration(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey.shade600),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kBackground,
        elevation: 0,
        foregroundColor: kNavy,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Créer un compte',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: kNavy)),
                const SizedBox(height: 6),
                Text('Renseignez vos informations pour commencer.',
                    style: TextStyle(color: Colors.grey.shade700)),
                const SizedBox(height: 22),

                TextFormField(
                  controller: _prenomCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: _decoration('Prénom', Icons.person_outline),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Prénom obligatoire' : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _nomCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: _decoration('Nom', Icons.badge_outlined),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nom obligatoire' : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _decoration('Email', Icons.mail_outline),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return 'Email obligatoire';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                      return 'Email invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _telCtrl,
                  keyboardType: TextInputType.phone,
                  decoration:
                  _decoration('Téléphone (optionnel)', Icons.phone_outlined),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _dateCtrl,
                  readOnly: true,
                  onTap: _pickDate,
                  decoration: _decoration(
                      'Date de naissance (optionnel)', Icons.cake_outlined),
                ),
                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  value: _sexe,
                  decoration: _decoration('Sexe (optionnel)', Icons.wc_outlined),
                  items: const [
                    DropdownMenuItem(value: 'Femme', child: Text('Femme')),
                    DropdownMenuItem(value: 'Homme', child: Text('Homme')),
                    DropdownMenuItem(value: 'Autre', child: Text('Autre')),
                  ],
                  onChanged: (v) => setState(() => _sexe = v),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _hidePassword,
                  decoration: _decoration(
                    'Mot de passe',
                    Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(_hidePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _hidePassword = !_hidePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Mot de passe obligatoire';
                    if (v.length < 6) return 'Minimum 6 caractères';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _hidePassword,
                  decoration:
                  _decoration('Confirmer le mot de passe', Icons.lock_outline),
                  validator: (v) => v != _passwordCtrl.text
                      ? 'Les mots de passe ne correspondent pas'
                      : null,
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _loading
                        ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                        : const Text('Créer mon compte',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}