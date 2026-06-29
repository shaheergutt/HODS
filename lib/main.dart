import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'core/router/app_router.dart';
import 'core/constants/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Supabase.initialize(
    url: 'https://ivjgacthvovhijwadvxu.supabase.co',
    publishableKey: 'sb_publishable_0tenUrup2Y8oxqN1iRF3Mw_PCa8jIL7',
  );

  runApp(
    const ProviderScope(
      child: HODSApp(),
    ),
  );
}

class HODSApp extends ConsumerWidget {
  const HODSApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'HODS - Hostel Booking',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}