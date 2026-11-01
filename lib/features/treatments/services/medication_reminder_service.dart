/// ============================================================
/// Module 3.3 — TRAITEMENTS : rappels de dose (notifications)
///
/// 100% LOCAL : pas de serveur (aucun http/Node.js nécessaire).
/// Le téléphone lui-même déclenche la notification à l'heure
/// exacte de la prise grâce à `flutter_local_notifications`.
///
/// Principe :
///  1. `init()` initialise le plugin + le fuseau horaire
///     + demande la permission Android 13+ une seule fois.
///  2. `refresh(userId)` annule puis reprogramme toutes les doses
///     "pending" des 48 prochaines heures (via repository.upcomingDoses).
///  3. L'identifiant de la notification = id du IntakeLog,
///     donc marquer une prise / modifier le traitement puis
///     re-appeler refresh() resynchronise tout naturellement.
///
/// Appelé depuis TreatmentsScreen (initState + après chaque _reload).
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../repositories/treatment_repository.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Nécessaire pour l'initialisation du plugin en arrière-plan sur certains terminaux
  debugPrint('[REMINDERS] Background tap: ${notificationResponse.payload}');
}

class MedicationReminderService {
  // Même pattern "instance" léger que TreatmentRepository
  MedicationReminderService._ctor();
  static final MedicationReminderService instance =
      MedicationReminderService._ctor();
  factory MedicationReminderService() => instance;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  // Un seul canal Android pour tout le module 3.3
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'meditrack_doses', // channelId
      'Rappels de dose', // channelName
      channelDescription: 'Notification à l\'heure exacte de la prise',
      icon: 'ic_stat_meditrack', // petite icône monochrome (barre d'état)
      ticker: 'Rappel de dose',
      category: AndroidNotificationCategory.reminder,
      fullScreenIntent: false,
      autoCancel: true,
      showWhen: true,
      when: null, // utilise l'heure actuelle au moment de l'affichage
      styleInformation: BigTextStyleInformation(''),
      importance: Importance.max,
      priority: Priority.max,
      enableVibration: true,
      playSound: true,
    ),
  );

  /// Fuseau horaire : essaie le nom de la zone, sinon se rabat sur
  /// un décalage Etc/GMT (suffisant sur une fenêtre de 48 h).
  Future<void> _initTimezone() async {
    tzdata.initializeTimeZones();
    final name = DateTime.now().timeZoneName;
    try {
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // timeZoneName n'est pas toujours un identifiant IANA sur Android
      final off = DateTime.now().timeZoneOffset;
      final hours =
          -off.inMinutes ~/ 60; // signe inversé dans la base Etc/GMT
      final fallbackName = 'Etc/GMT${hours.isNegative ? '' : '+'}$hours';
      try {
        tz.setLocalLocation(tz.getLocation(fallbackName));
        debugPrint('[REMINDERS] TZ fallback réussi : $fallbackName');
      } catch (e) {
        tz.setLocalLocation(tz.UTC); // dernier recours
        debugPrint('[REMINDERS] TZ fallback ÉCHEC ($fallbackName), UTC utilisé : $e');
      }
    }
  }

  /// Initialisation (safe à appeler plusieurs fois)
  Future<void> init() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_meditrack'),
      ),
      onDidReceiveNotificationResponse: (details) {
        debugPrint('[REMINDERS] notification cliquée : ${details.payload}');
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    await _initTimezone();
    // Permission Android 13+ (POST_NOTIFICATIONS) + alarmes exactes
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    // CRUCIAL sur Android 8+ : le canal DOIT exister, sinon les
    // notifications sont silencieusement ignorées (aucune erreur !).
    // Appel idempotent : crée le canal la 1re fois, le vérifie ensuite.
    try {
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          'meditrack_doses', // channelId
          'Rappels de dose', // channelName
          description: 'Notification à l\'heure exacte de la prise',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
      debugPrint('[REMINDERS] canal "meditrack_doses" créé/vérifié');
    } catch (e) {
      debugPrint('[REMINDERS] échec création canal : $e');
    }
    try {
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
    } catch (_) {
      // si l'utilisateur refuse : l'app fonctionne, juste sans notifs
    }
    _ready = true;
  }

  /// (Re)programme les rappels des 48 prochaines heures.
  /// Fire-and-forget : on l'appelle depuis initState et après chaque
  /// mutation sans bloquer l'UI.
  Future<void> refresh(int userId) async {
    try {
      await init();
      // On repart de zéro : plus simple que tenir un registre des ids
      await _plugin.cancelAll();
      final doses =
          await TreatmentRepository().upcomingDoses(userId, hours: 48);
      final now = DateTime.now();
      var scheduled = 0;

      for (final d in doses) {
        final log = d.log;
        if (log.id == null) continue;
        final when = log.scheduledAt;
        // Dose déjà passée (ou imminente) : pas de rappel rétroactif.
        if (when.isBefore(now.add(const Duration(seconds: 5)))) continue;

        final zoned = tz.TZDateTime.from(when, tz.local);
        final title = 'Prise de ${d.medicationName}';
        final body =
            '${d.dose}${d.dosage != null ? ' (${d.dosage})' : ''} à '
            '${when.hour.toString().padLeft(2, '0')}:'
            '${when.minute.toString().padLeft(2, '0')}';
        // id = id du IntakeLog -> peut être annulé un par un plus tard
        try {
          await _plugin.zonedSchedule(
            id: log.id!,
            title: title,
            body: body,
            scheduledDate: zoned,
            notificationDetails: _details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: 'intake_${log.id}',
          );
          scheduled++;
        } catch (_) {
          // Fallback : certains téléphones interdisent les alarmes exactes
          try {
            await _plugin.zonedSchedule(
              id: log.id!,
              title: title,
              body: body,
              scheduledDate: zoned,
              notificationDetails: _details,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              payload: 'intake_${log.id}',
            );
            scheduled++;
          } catch (e) {
            debugPrint('[REMINDERS] échec programmation #${log.id} : $e');
          }
        }
      }
      debugPrint('[REMINDERS] $scheduled rappel(s) programmé(s) sur 48 h');
    } catch (e) {
      debugPrint('[REMINDERS] ERREUR refresh : $e');
      // Les notifications ne doivent JAMAIS faire planter l'écran
    }
  }

  /// Annule un rappel précis (ex : prise marquée à l'avance)
  Future<void> cancelIntake(int intakeId) =>
      _plugin.cancel(id: intakeId);
}
