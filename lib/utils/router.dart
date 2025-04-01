import 'package:amplify_authenticator/amplify_authenticator.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../view/authentication/login_screen.dart';

final GoRouter router = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return AuthenticatedView(child: const LoginScreen());
      },
      routes: <RouteBase>[
// For passing parameters form A screen to B screen
        // GoRoute(
        //   path: 'home',
        //   builder: (context, state) {
        //     final data = state.extra as AuthModel;
        //     return HomeScreen(authModel: data);
        //   },
        // ),
      ],
    ),
  ],
);