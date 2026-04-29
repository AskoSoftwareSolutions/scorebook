import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../services/fcm_service.dart';
import '../../services/network_service.dart';
import '../../services/session_service.dart';
import '../../services/subscription_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// LOGIN PAGE — Firebase Phone Auth + OTP
//
// Flow: Enter phone → Send OTP → Enter 6-digit OTP → Verified →
//       If subscription page pending → go to subscription
//       Else → back to settings
// ═══════════════════════════════════════════════════════════════════════════════

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;

  // Step 1: phone input
  final _phoneCtrl = TextEditingController();
  // Step 2: OTP input — 6 separate fields
  final List<TextEditingController> _otpCtrl =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());

  bool   _otpSent    = false;
  bool   _loading    = false;
  String? _error;
  String? _verificationId;
  int?   _resendToken;
  int    _resendCooldown = 0;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))
      ..forward();
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    for (final c in _otpCtrl) c.dispose();
    for (final f in _otpFocus) f.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Send OTP ──────────────────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    final raw = _phoneCtrl.text.trim().replaceAll(RegExp(r'\s'), '');
    if (raw.length < 10) {
      setState(() => _error = 'Enter a valid 10-digit mobile number');
      return;
    }
    // Block early if offline — Firebase Phone Auth would otherwise hang
    // for ~60s before throwing an opaque "network error".
    if (!await NetworkService().requireOnline(action: 'send the OTP')) {
      setState(() => _error = 'No internet connection. Connect and retry.');
      return;
    }
    final phone = raw.startsWith('+') ? raw : '+91$raw';

    setState(() { _loading = true; _error = null; });

    try {
      await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: _resendToken,
      timeout: const Duration(seconds: 60),
      // ── Auto-retrieved OTP (Android SMS) ────────────────────────────────
      verificationCompleted: (PhoneAuthCredential cred) async {
        await _signIn(cred);
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() {
          _loading = false;
          _error   = e.message ?? 'Verification failed. Try again.';
        });
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _loading        = false;
          _otpSent        = true;
          _verificationId = verificationId;
          _resendToken    = resendToken;
          _error          = null;
        });
        _startResendCooldown();
        // Auto-focus first OTP field
        Future.delayed(const Duration(milliseconds: 200),
                () => _otpFocus[0].requestFocus());
        _fadeCtrl.forward(from: 0);
      },
      codeAutoRetrievalTimeout: (String id) {
        _verificationId = id;
      },
    );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not reach the server. Check your internet and retry.';
      });
    }
  }

  void _startResendCooldown() {
    setState(() => _resendCooldown = 30);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendCooldown--);
      return _resendCooldown > 0;
    });
  }

  // ── Verify OTP ────────────────────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.map((c) => c.text).join();
    if (otp.length < 6) {
      setState(() => _error = 'Enter the 6-digit OTP');
      return;
    }
    if (_verificationId == null) return;
    if (!await NetworkService().requireOnline(action: 'verify the OTP')) {
      setState(() => _error = 'No internet connection. Connect and retry.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    final cred = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: otp,
    );
    await _signIn(cred);
  }

  Future<void> _signIn(PhoneAuthCredential cred) async {
    try {
      await _auth.signInWithCredential(cred);
      await FcmService().initialize();

      // ── Save phone to SessionService for later use ──────────────────────
      final phone = _auth.currentUser?.phoneNumber ??
          ('+91${_phoneCtrl.text.trim().replaceAll(RegExp(r'\s'), '')}');
      await SessionService().saveUserPhone(phone);
      SessionService().loadCachedPhone();
      // Load any existing subscription
      await SubscriptionService().loadSubscription();
      if (!mounted) return;
      // If came from subscription flow, go there; else back
      final pending = Get.parameters['next'];
      if (pending == 'subscription') {
        Get.offNamed('/subscription');
      } else {
        Get.back(result: true);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _loading = false;
        _error   = e.message ?? 'Invalid OTP. Try again.';
      });
      HapticFeedback.heavyImpact();
    } catch (e) {
      // Network or unknown error — surface a friendly message instead
      // of leaving the user staring at a spinner forever.
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error   = 'Sign-in failed. Check your internet and try again.';
      });
      HapticFeedback.heavyImpact();
    }
  }

  // ── OTP field handler ─────────────────────────────────────────────────────
  void _onOtpChanged(int idx, String val) {
    if (val.length == 1 && idx < 5) {
      _otpFocus[idx + 1].requestFocus();
    } else if (val.isEmpty && idx > 0) {
      _otpFocus[idx - 1].requestFocus();
    }
    // Auto-submit when all 6 digits entered
    if (_otpCtrl.every((c) => c.text.isNotEmpty)) {
      _verifyOtp();
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
          title: const Text('Login',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ),
        body: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ─────────────────────────────────────────────────
                  Center(
                    child: Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.phone_android_rounded,
                          color: Colors.white, size: 36),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      _otpSent ? 'Enter OTP' : 'Enter Mobile Number',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      _otpSent
                          ? 'OTP sent to +91 ${_phoneCtrl.text.trim()}'
                          : 'We\'ll send a one-time password to verify',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (!_otpSent) ...[
                    // ── Phone input ───────────────────────────────────────
                    _label('MOBILE NUMBER'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _sendOtp(),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        prefixText: '+91  ',
                        prefixStyle: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 16,
                            fontWeight: FontWeight.w500),
                        hintText: '98765 43210',
                        hintStyle: TextStyle(
                            color: AppTheme.textSecondary.withOpacity(0.3),
                            letterSpacing: 3,
                            fontSize: 18),
                        filled: true,
                        fillColor: AppTheme.bgCard,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                          const BorderSide(color: AppTheme.borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                          const BorderSide(color: AppTheme.borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppTheme.primaryLight, width: 1.5),
                        ),
                      ),
                    ),
                  ] else ...[
                    // ── OTP 6-field input ──────────────────────────────────
                    _label('6-DIGIT OTP'),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (i) => _OtpBox(
                        controller: _otpCtrl[i],
                        focusNode: _otpFocus[i],
                        onChanged: (v) => _onOtpChanged(i, v),
                      )),
                    ),
                    const SizedBox(height: 16),
                    // Resend
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Didn't receive? ",
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12)),
                        _resendCooldown > 0
                            ? Text('Resend in ${_resendCooldown}s',
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12))
                            : GestureDetector(
                          onTap: _sendOtp,
                          child: const Text('Resend OTP',
                              style: TextStyle(
                                color: AppTheme.primaryLight,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              )),
                        ),
                      ],
                    ),
                  ],

                  // ── Error ────────────────────────────────────────────────
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border:
                        Border.all(color: AppTheme.error.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline_rounded,
                            color: AppTheme.error, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: AppTheme.error, fontSize: 12)),
                        ),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // ── CTA Button ───────────────────────────────────────────
                  _GradientButton(
                    label: _otpSent ? 'Verify OTP' : 'Send OTP',
                    loading: _loading,
                    onTap: _otpSent ? _verifyOtp : _sendOtp,
                  ),

                  if (_otpSent) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _otpSent = false;
                          for (final c in _otpCtrl) c.clear();
                          _error = null;
                        }),
                        child: const Text('Change number',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              decoration: TextDecoration.underline,
                            )),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'By continuing, you agree to our Terms of Service',
                      style: TextStyle(
                          color: AppTheme.textSecondary.withOpacity(0.5),
                          fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      color: AppTheme.textSecondary,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
    ),
  );
}

// ── OTP Box ───────────────────────────────────────────────────────────────────
class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  const _OtpBox(
      {required this.controller,
        required this.focusNode,
        required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 52,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        onChanged: onChanged,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: AppTheme.bgCard,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
            const BorderSide(color: AppTheme.primaryLight, width: 2),
          ),
        ),
      ),
    );
  }
}

// ── Gradient Button ───────────────────────────────────────────────────────────
class _GradientButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const _GradientButton(
      {required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: loading
              ? LinearGradient(colors: [
            AppTheme.primary.withOpacity(0.4),
            AppTheme.primaryLight.withOpacity(0.4),
          ])
              : const LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF43A047)]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: loading
              ? []
              : [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 5),
            )
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
                  strokeWidth: 2, color: Colors.white))
              : Text(label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              )),
        ),
      ),
    );
  }
}