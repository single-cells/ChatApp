import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_providers.dart';
import '../screens/chat_screen.dart';
import '../screens/login_screen.dart';
import '../screens/room_hub_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final token = ref.read(accessTokenProvider);
      final onLogin = state.matchedLocation == '/';
      if (token == null && state.matchedLocation != '/') return '/';
      if (token != null && onLogin) return '/hub';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/hub',
        builder: (_, __) => const RoomHubScreen(),
      ),
      GoRoute(
        path: '/chat/:roomId',
        builder: (_, state) => ChatScreen(
          roomId: state.pathParameters['roomId']!,
        ),
      ),
    ],
  );
});
