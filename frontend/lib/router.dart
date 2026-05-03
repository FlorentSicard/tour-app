import 'package:go_router/go_router.dart';
import 'package:tourapp/screens/login_screen.dart';
import 'package:tourapp/screens/home_screen.dart';
import 'package:tourapp/screens/tour_screen.dart';
import 'package:tourapp/screens/day_screen.dart';

final router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
    GoRoute(
      path: '/tours/:tourId',
      builder: (_, state) => TourScreen(tourId: state.pathParameters['tourId']!),
    ),
    GoRoute(
      path: '/days/:dayId',
      builder: (_, state) => DayScreen(dayId: state.pathParameters['dayId']!),
    ),
  ],
);
