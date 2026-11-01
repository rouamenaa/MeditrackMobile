import 'package:flutter/material.dart';
import '../../treatments/screens/treatments_screen.dart';
import '../models/medecin.dart';
import '../models/user.dart';
import '../repositories/medecin_repository.dart';
import '../repositories/user_repository.dart';
import 'profile_screen.dart';

class HomeScreen extends StatelessWidget {
  final User user;
  const HomeScreen({super.key, required this.user});

  // TEMPORAIRE : remplit des données de test pour voir le profil complet
  Future<void> _fillTestData(BuildContext context) async {
    await UserRepository().update(user.copyWith(
      telephone: '+1 (555) 234-8901',
      dateNaissance: '1987-04-14',
      groupeSanguin: 'O+ Positive',
      conditionMedicale: 'Diabetic Type 2',
      contactUrgenceNom: 'Karim Ben Ali',
      contactUrgenceLien: 'Spouse',
      contactUrgenceTel: '+1 (555) 987-6543',
      assuranceNom: 'BlueCross Health Premier',
      assurancePolice: 'BC-449102',
    ));

    final medRepo = MedecinRepository();
    final existing = await medRepo.getByUser(user.id!);
    if (existing.isEmpty) {
      await medRepo.add(Medecin(
          userId: user.id!, nom: 'Dr. Ahmed', specialite: 'Cardiology'));
      await medRepo.add(Medecin(
          userId: user.id!, nom: 'Dr. Vance', specialite: 'General Practice'));
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Données de test ajoutées')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MediTrack')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Bonjour ${user.prenom} ${user.nom} 👋',
                style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ProfileScreen(user: user)),
              ),
              child: const Text('Mon profil'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _fillTestData(context),
              child: const Text('Remplir des données de test'),
            ),
            const SizedBox(height: 8),
            // MODULE 3.3 TRAITEMENTS (nouveau fichier, aucune autre modif)
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => TreatmentsScreen(user: user)),
              ),
              child: const Text('Mes traitements'),
            ),
          ],
        ),
      ),
    );
  }
}