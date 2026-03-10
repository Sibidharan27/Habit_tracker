import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authStateProvider = StreamProvider((ref) {
  return ref.watch(authServiceProvider).authState;
});