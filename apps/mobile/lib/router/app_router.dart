import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../providers/app_providers.dart';

import '../screens/chat_screen.dart';

import '../screens/login_screen.dart';

import '../screens/main_shell_screen.dart';



final routerProvider = Provider<GoRouter>((ref) {

  final authReady = ref.watch(authReadyProvider);

  final token = ref.watch(accessTokenProvider);

  final needsNickname = ref.watch(needsNicknameProvider);



  return GoRouter(

    initialLocation: '/',

    redirect: (context, state) {

      if (!authReady) return null;



      final onLogin = state.matchedLocation == '/';

      if ((token == null || needsNickname) && state.matchedLocation != '/') {

        return '/';

      }

      if (token != null && !needsNickname && onLogin) return '/hub';

      return null;

    },

    routes: [

      GoRoute(

        path: '/',

        builder: (_, __) => const LoginScreen(),

      ),

      GoRoute(

        path: '/hub',

        builder: (_, __) => const MainShellScreen(),

      ),

      GoRoute(

        path: '/chat/:roomId',

        builder: (_, state) {

          final title = state.uri.queryParameters['title'] ?? '';

          return ChatScreen(

            roomId: state.pathParameters['roomId']!,

            initialTitle: title,

          );

        },

      ),

    ],

  );

});

