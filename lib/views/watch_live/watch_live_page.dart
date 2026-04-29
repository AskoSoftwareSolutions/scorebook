import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../core/constants/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../services/firebase_sync_service.dart';
import '../../services/network_service.dart';
import '../../services/session_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// WATCH LIVE PAGE
// User manually enters Match Code → opens LiveViewerPage
// (Password is no longer required — anyone with the code can watch.)
// Route: AppRoutes.watchLive
// ═══════════════════════════════════════════════════════════════════════════════

class WatchLivePage extends StatefulWidget {
  const WatchLivePage({super.key});

  @override
  State<WatchLivePage> createState() => _WatchLivePageState();
}

class _WatchLivePageState extends State<WatchLivePage>
    with SingleTickerProviderStateMixin {
  final _codeCtrl = TextEditingController();
  final _sync     = FirebaseSyncService();

  bool _loading   = false;
  String? _error;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeIn;
  late Animation<Offset>   _slideIn;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeIn  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideIn = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeCtrl.text.trim().toUpperCase();

    // Validate
    if (code.isEmpty) {
      setState(() => _error = 'Please enter match code');
      return;
    }

    // Watch live needs a live websocket — short-circuit when offline
    // instead of letting matchExists hang on the network for ~30s.
    if (!await NetworkService().requireOnline(action: 'join the live match')) {
      setState(() => _error = 'No internet connection. Connect and retry.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      // Check match exists — that's the only gate now. Password requirement
      // was dropped: anyone with the share code can watch the live score.
      final exists = await _sync
          .matchExists(code)
          .timeout(const Duration(seconds: 8));
      if (!exists) {
        setState(() {
          _loading = false;
          _error   = 'Match not found. Check the code and try again.';
        });
        HapticFeedback.heavyImpact();
        return;
      }

      setState(() => _loading = false);
      HapticFeedback.mediumImpact();

      // ── Save session so app resume auto-rejoins ──────────────────────────
      // Password field still exists in SessionService for back-compat; we
      // just persist an empty string.
      await SessionService().saveWatchLive(matchCode: code, password: '');

      // Navigate → LiveViewerPage (already authenticated, skip gate)
      Get.toNamed(
        AppRoutes.liveViewer,
        arguments: {'matchCode': code, 'authenticated': true},
      );
    } catch (e) {
      // Network glitch / Firebase timeout — surface a clean message
      // rather than the raw exception text.
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error   = 'Couldn\'t reach the match. Check your internet and retry.';
      });
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Scaffold(
        backgroundColor: AppTheme.bgDark,
        appBar: AppBar(
          backgroundColor: AppTheme.bgDark,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: AppTheme.textPrimary),
            onPressed: () => Get.back(),
          ),
          title: const Text('Watch Live Score',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              )),
        ),
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideIn,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Top illustration ──────────────────────────────────────
                    _LiveIllustration(),

                    const SizedBox(height: 28),

                    // ── Instructions ──────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.info.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.info.withOpacity(0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Icon(Icons.info_outline_rounded,
                              color: AppTheme.info, size: 16),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Ask the scorer to share the Match Code via WhatsApp. '
                                  'Enter it below to watch the live score — no password needed.',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                height: 1.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Match Code ────────────────────────────────────────────
                    _FieldLabel(
                      icon: Icons.tag_rounded,
                      label: 'MATCH CODE',
                    ),
                    const SizedBox(height: 8),
                    _CodeField(
                      controller: _codeCtrl,
                      hint: 'e.g.  CS-CHMU-4821',
                      onChanged: (_) => setState(() => _error = null),
                      onSubmitted: (_) => _join(),
                    ),

                    // ── Error ─────────────────────────────────────────────────
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      child: _error != null
                          ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                AppTheme.error.withOpacity(0.3)),
                          ),
                          child: Row(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: AppTheme.error, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_error!,
                                    style: const TextStyle(
                                      color: AppTheme.error,
                                      fontSize: 12,
                                      height: 1.4,
                                    )),
                              ),
                            ],
                          ),
                        ),
                      )
                          : const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 28),

                    // ── Join button ───────────────────────────────────────────
                    _JoinButton(loading: _loading, onTap: _join),

                    const SizedBox(height: 20),

                    // ── Footer tip ────────────────────────────────────────────
                    Center(
                      child: Text(
                        'Score updates every ball in real-time',
                        style: TextStyle(
                          color: AppTheme.textSecondary.withOpacity(0.6),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Live Illustration ────────────────────────────────────────────────────────

class _LiveIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1B5E20).withOpacity(0.25),
            const Color(0xFF0D1117).withOpacity(0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppTheme.primaryLight.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          // Antenna icon with rings
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer ring
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppTheme.primaryLight.withOpacity(0.12),
                      width: 1),
                ),
              ),
              // Middle ring
              Container(
                width: 66, height: 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppTheme.primaryLight.withOpacity(0.2),
                      width: 1.5),
                ),
              ),
              // Icon
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primary,
                      AppTheme.primaryLight,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryLight.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.cell_tower_rounded,
                    color: Colors.white, size: 26),
              ),
            ],
          ),

          const SizedBox(height: 16),

          const Text(
            'Watch Live Cricket',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ball-by-ball updates · No refresh needed',
            style: TextStyle(
                color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─── Code Field (auto-uppercase) ─────────────────────────────────────────────

class _CodeField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  const _CodeField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.characters,
      textInputAction: TextInputAction.done,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      inputFormatters: [
        TextInputFormatter.withFunction((old, nw) =>
            nw.copyWith(text: nw.text.toUpperCase())),
      ],
      style: const TextStyle(
        color: AppTheme.primaryLight,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: 3,
        fontFamily: 'monospace',
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: AppTheme.textSecondary.withOpacity(0.35),
          fontSize: 15,
          letterSpacing: 1.5,
          fontWeight: FontWeight.normal,
          fontFamily: 'monospace',
        ),
        filled: true,
        fillColor: AppTheme.bgCard,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: AppTheme.primaryLight, width: 1.5),
        ),
        prefixIcon: const Icon(Icons.tag_rounded,
            color: AppTheme.primaryLight, size: 20),
      ),
    );
  }
}

// ─── Field Label ─────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FieldLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: AppTheme.textSecondary, size: 13),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    ]);
  }
}

// ─── Join Button ─────────────────────────────────────────────────────────────

class _JoinButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _JoinButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: loading
              ? LinearGradient(colors: [
            AppTheme.primary.withOpacity(0.5),
            AppTheme.primaryLight.withOpacity(0.5),
          ])
              : const LinearGradient(
            colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: loading
              ? []
              : [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.45),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: loading ? null : onTap,
          child: loading
              ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white),
          )
              : const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_circle_filled_rounded,
                  color: Colors.white, size: 22),
              SizedBox(width: 10),
              Text(
                'Watch Live Score',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}