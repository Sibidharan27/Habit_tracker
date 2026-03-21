import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../dashboard/main_scaffold.dart';
import 'login_screen.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        // Firebase persists auth automatically — if user != null they're still logged in
        if (user != null) {
          return const MainScaffold();
        } else {
          return const LoginScreen();
        }
      },
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF1B5E20),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
      error: (e, _) => const LoginScreen(),
    );
  }
}