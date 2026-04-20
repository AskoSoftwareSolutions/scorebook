import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../services/session_service.dart';
import '../../repositories/match_repository.dart';
import '../../core/constants/app_constants.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});
  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();

    // Wait for animation + check session
    Future.delayed(const Duration(milliseconds: 2000), _navigate);
  }

  Future<void> _navigate() async {
    if (!mounted) return;

    final session = SessionService();
    final repo = Get.find<MatchRepository>();

    ActiveMatchInfo? active;

    final info = await session.getActiveMatch();
    if (info != null) {
      final match = await repo.getMatch(info.matchId);
      if (match != null &&
          match.status == AppConstants.matchStatusInProgress) {
        active = info;
      } else {
        // Stale — wipe it
        await session.clearActiveMatch();
      }
    }

    if (!mounted) return;

    // Always navigate to home first; home will show the resume banner
    // Pass the active match info via Get.arguments so HomeView can
    // immediately display it without an extra async round-trip.
    Get.offAllNamed(
      AppRoutes.home,
      arguments: active, // null = no resume banner
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D1117), Color(0xFF1B5E20), Color(0xFF0D1117)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _scale,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: AppTheme.greenGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.5),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Image.asset(
                        "assets/logo/logo_round.png",
                        width: 120,
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                FadeTransition(
                  opacity: _fade,
                  child: Column(
                    children: [
                      Text('SCORE',
                          style: TextStyle(
                              color: AppTheme.accent,
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 8)),
                      Text('BOOK',
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 6)),
                      const SizedBox(height: 8),
                      Text('Offline • Free • Complete',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              letterSpacing: 2)),
                    ],
                  ),
                ),
                const SizedBox(height: 60),
                FadeTransition(
                  opacity: _fade,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryLight.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}