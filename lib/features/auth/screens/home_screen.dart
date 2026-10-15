import 'package:flutter/material.dart';
import '../models/user.dart';

class HomeScreen extends StatelessWidget {
  final User user;
  const HomeScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MediTrack')),
      body: Center(
        child: Text('Bonjour ${user.prenom} ${user.nom} 👋',
            style: const TextStyle(fontSize: 22)),
      ),
    );
  }
}