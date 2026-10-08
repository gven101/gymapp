import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/constants/app_colors.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/member/member_home_screen.dart';
import 'screens/trainer/trainer_home_screen.dart';
import 'screens/admin/admin_home_screen.dart';

Future<void> _seedExercises() async {
  final db  = FirebaseFirestore.instance;
  final col = db.collection('exercises');
  final existing = await col.limit(1).get();
  if (existing.docs.isNotEmpty) return;

  final exercises = [
    {'name': 'Barbell Bench Press', 'muscleGroup': 'Chest',      'category': 'compound',  'metValue': 3.5},
    {'name': 'Pull-Up',             'muscleGroup': 'Back',        'category': 'compound',  'metValue': 4.0},
    {'name': 'Back Squat',          'muscleGroup': 'Quadriceps',  'category': 'compound',  'metValue': 5.0},
    {'name': 'Romanian Deadlift',   'muscleGroup': 'Hamstrings',  'category': 'compound',  'metValue': 4.5},
    {'name': 'Overhead Press',      'muscleGroup': 'Shoulders',   'category': 'compound',  'metValue': 3.5},
    {'name': 'Barbell Row',         'muscleGroup': 'Back',        'category': 'compound',  'metValue': 4.0},
    {'name': 'Incline DB Press',    'muscleGroup': 'Chest',       'category': 'compound',  'metValue': 3.5},
    {'name': 'Leg Press',           'muscleGroup': 'Quadriceps',  'category': 'compound',  'metValue': 4.0},
    {'name': 'Lateral Raise',       'muscleGroup': 'Shoulders',   'category': 'isolation', 'metValue': 3.0},
    {'name': 'Barbell Curl',        'muscleGroup': 'Biceps',      'category': 'isolation', 'metValue': 3.0},
    {'name': 'Tricep Pushdown',     'muscleGroup': 'Triceps',     'category': 'isolation', 'metValue': 3.0},
    {'name': 'Plank',               'muscleGroup': 'Core',        'category': 'strength',  'metValue': 3.5},
    {'name': 'Hip Thrust',          'muscleGroup': 'Glutes',      'category': 'isolation', 'metValue': 4.0},
    {'name': 'Calf Raise',          'muscleGroup': 'Calves',      'category': 'isolation', 'metValue': 3.0},
    {'name': 'Treadmill Run',       'muscleGroup': 'Cardio',      'category': 'cardio',    'metValue': 9.0},
  ];

  final batch = db.batch();
  for (final ex in exercises) {
    batch.set(col.doc(), ex);
  }
  await batch.commit();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _seedExercises();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const GymApp(),
    ),
  );
}

class GymApp extends StatelessWidget {
  const GymApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GymApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.lime,
          surface: AppColors.surface,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.card,
          hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border, width: 0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.lime, width: 1.5),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.lime,
            foregroundColor: AppColors.bg,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
            elevation: 0,
          ),
        ),
      ),
      home: Consumer<AuthProvider>(
        builder: (_, auth, __) {
          switch (auth.status) {
            case AuthStatus.loading:
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: AppColors.lime),
                ),
              );
            case AuthStatus.unauthenticated:
              return const LoginScreen();
            case AuthStatus.authenticated:
              final role = auth.userRole;
              if (role == 'admin')   return const AdminHomeScreen();
              if (role == 'trainer') return const TrainerHomeScreen();
              return const MemberHomeScreen();
          }
        },
      ),
    );
  }
}