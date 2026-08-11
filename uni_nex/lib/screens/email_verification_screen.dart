import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/theme_manager.dart';
import '../utils/app_router.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with TickerProviderStateMixin {
  Timer? _pollingTimer;
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;
  static const int _cooldownDuration = 60;

  bool _isSending = false;
  bool _isVerified = false;
  bool _isCheckingManually = false;

  late AnimationController _iconBounceController;
  late AnimationController _pulseController;
  late AnimationController _successController;
  late AnimationController _bgController;

  late Animation<double> _iconBounce;
  late Animation<double> _pulse;
  late Animation<double> _successScale;
  late Animation<double> _bgAnim;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _initAnims();
    _sendInitial();
    _startPolling();
  }

  void _initAnims() {
    _iconBounceController = AnimationController(
      duration: const Duration(milliseconds: 2000), vsync: this,
    )..repeat(reverse: true);
    _iconBounce = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _iconBounceController, curve: Curves.easeInOut),
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500), vsync: this,
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _successController = AnimationController(
      duration: const Duration(milliseconds: 800), vsync: this,
    );
    _successScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );
    _bgController = AnimationController(
      duration: const Duration(milliseconds: 6000), vsync: this,
    )..repeat();
    _bgAnim = Tween<double>(begin: 0, end: 2 * math.pi).animate(_bgController);
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _cooldownTimer?.cancel();
    _iconBounceController.dispose();
    _pulseController.dispose();
    _successController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _sendInitial() async {
    final u = _user;
    if (u == null) return;
    await u.reload();
    final r = FirebaseAuth.instance.currentUser;
    if (r != null && r.emailVerified) { _onSuccess(); return; }
    try { await u.sendEmailVerification(); _startCooldown(); } catch (_) {}
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_isVerified) return;
      try {
        await FirebaseAuth.instance.currentUser?.reload();
        final r = FirebaseAuth.instance.currentUser;
        if (r != null && r.emailVerified) _onSuccess();
      } catch (_) {}
    });
  }

  Future<void> _checkManually() async {
    setState(() => _isCheckingManually = true);
    try {
      await FirebaseAuth.instance.currentUser?.reload();
      final r = FirebaseAuth.instance.currentUser;
      if (r != null && r.emailVerified) {
        _onSuccess();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Email not verified yet. Check your inbox.', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Could not check status. Try again.', style: TextStyle(color: Colors.white)),
          backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating,
        ));
      }
    } finally { if (mounted) setState(() => _isCheckingManually = false); }
  }

  void _onSuccess() {
    if (_isVerified) return;
    _pollingTimer?.cancel();
    _cooldownTimer?.cancel();
    setState(() => _isVerified = true);
    _iconBounceController.stop();
    _pulseController.stop();
    _successController.forward();
    _syncFirestore();
    Future.delayed(const Duration(seconds: 2), () async {
      if (!mounted) return;
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(AppRouter.login, (_) => false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Email verified! Please sign in.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF2E7D32), behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
      ));
    });
  }

  Future<void> _syncFirestore() async {
    try {
      final u = _user;
      if (u != null) {
        await FirebaseFirestore.instance.collection('users').doc(u.uid).update({
          'emailVerified': true, 'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }

  Future<void> _resend() async {
    if (_cooldownSeconds > 0 || _isSending) return;
    final u = _user;
    if (u == null) return;
    setState(() => _isSending = true);
    try {
      await u.sendEmailVerification();
      _startCooldown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Verification email sent to ${u.email}', style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF2E7D32), behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Failed to send. Try again later.', style: TextStyle(color: Colors.white)),
          backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating,
        ));
      }
    } finally { if (mounted) setState(() => _isSending = false); }
  }

  void _startCooldown() {
    _cooldownSeconds = _cooldownDuration;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() { _cooldownSeconds--; if (_cooldownSeconds <= 0) t.cancel(); });
    });
  }

  Future<void> _backToLogin() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRouter.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final email = _user?.email ?? 'your email';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async { if (!didPop) await _backToLogin(); },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [const Color(0xFFE3F2FD), const Color(0xFFF8F9FA), Colors.white],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: Stack(children: [
            Positioned.fill(child: AnimatedBuilder(animation: _bgAnim, builder: (c, _) => CustomPaint(painter: _WavePainter(v: _bgAnim.value)))),
            SafeArea(child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingXl),
              child: Column(children: [
                const SizedBox(height: 40),
                _stepIndicator(),
                const SizedBox(height: 40),
                _mainCard(email),
                const SizedBox(height: AppDimensions.spacingXl),
                TextButton.icon(
                  onPressed: _backToLogin,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Use a different account', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
                ),
                const SizedBox(height: AppDimensions.spacingXl),
              ]),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _stepIndicator() {
    return Row(children: [
      _step(1, 'Email Sent', true, true),
      _connector(_isVerified),
      _step(2, 'Verify', !_isVerified, _isVerified),
      _connector(_isVerified),
      _step(3, 'Done', false, _isVerified),
    ]);
  }

  Widget _step(int n, String label, bool active, bool done) {
    return Expanded(child: Column(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: done ? const LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF43A047)])
              : active ? LinearGradient(colors: [AppColors.primary, AppColors.secondary]) : null,
          color: (!done && !active) ? Colors.grey[300] : null,
          boxShadow: (done || active) ? [BoxShadow(
            color: (done ? const Color(0xFF2E7D32) : AppColors.primary).withValues(alpha: 0.3),
            blurRadius: 8, offset: const Offset(0, 2),
          )] : null,
        ),
        child: Center(child: done
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
            : Text('$n', style: TextStyle(color: active ? Colors.white : Colors.grey[500], fontWeight: FontWeight.w700, fontSize: 14))),
      ),
      const SizedBox(height: 6),
      Text(label, style: TextStyle(fontSize: 11, fontWeight: (active || done) ? FontWeight.w600 : FontWeight.w400,
          color: done ? const Color(0xFF2E7D32) : active ? AppColors.primary : Colors.grey[500])),
    ]));
  }

  Widget _connector(bool done) {
    return Container(height: 2, width: 40, margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(1), color: done ? const Color(0xFF2E7D32) : Colors.grey[300]));
  }

  Widget _mainCard(String email) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingXl),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Colors.white.withValues(alpha: 0.95), Colors.white.withValues(alpha: 0.9)]),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 30, spreadRadius: 5, offset: const Offset(0, 10)),
          BoxShadow(color: Colors.white.withValues(alpha: 0.8), blurRadius: 20, spreadRadius: -5, offset: const Offset(0, 2)),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _isVerified ? _successIcon() : _mailIcon(),
        const SizedBox(height: AppDimensions.spacingLg),
        Text(_isVerified ? 'Email Verified!' : 'Verify Your Email',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                color: _isVerified ? const Color(0xFF2E7D32) : Colors.grey[800], letterSpacing: 0.5),
            textAlign: TextAlign.center),
        const SizedBox(height: AppDimensions.spacingMd),
        if (_isVerified)
          Text('Your email has been verified.\nRedirecting to login...', style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5), textAlign: TextAlign.center)
        else ...[
          RichText(textAlign: TextAlign.center, text: TextSpan(style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5), children: [
            const TextSpan(text: 'We\'ve sent a verification link to\n'),
            TextSpan(text: email, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
            const TextSpan(text: '\n\nCheck your inbox and spam folder.'),
          ])),
          const SizedBox(height: AppDimensions.spacingLg),
          _statusIndicator(),
          const SizedBox(height: AppDimensions.spacingXl),
          _resendBtn(),
          const SizedBox(height: AppDimensions.spacingMd),
          _checkBtn(),
        ],
      ]),
    );
  }

  Widget _mailIcon() {
    return AnimatedBuilder(animation: _iconBounce, builder: (c, _) => Transform.translate(
      offset: Offset(0, -_iconBounce.value),
      child: Container(width: 100, height: 100,
        decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.1), AppColors.secondary.withValues(alpha: 0.1)]),
          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 20, spreadRadius: 5)],
        ),
        child: const Icon(Icons.mark_email_unread_rounded, size: 50, color: AppColors.primary)),
    ));
  }

  Widget _successIcon() {
    return AnimatedBuilder(animation: _successScale, builder: (c, _) => Transform.scale(
      scale: _successScale.value,
      child: Container(width: 100, height: 100,
        decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF43A047)]),
          boxShadow: [BoxShadow(color: const Color(0xFF2E7D32).withValues(alpha: 0.3), blurRadius: 25, spreadRadius: 5)],
        ),
        child: const Icon(Icons.check_rounded, size: 55, color: Colors.white)),
    ));
  }

  Widget _statusIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingLg, vertical: AppDimensions.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
        AnimatedBuilder(animation: _pulse, builder: (c, _) => Container(
          width: 10, height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: _pulse.value),
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: _pulse.value * 0.5), blurRadius: 6, spreadRadius: 1)],
          ),
        )),
        const SizedBox(width: 10),
        Text('Waiting for verification...', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
      ]),
    );
  }

  Widget _resendBtn() {
    final ok = _cooldownSeconds <= 0 && !_isSending;
    return SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(
      onPressed: ok ? _resend : null,
      icon: _isSending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.refresh_rounded, size: 20),
      label: Text(_isSending ? 'Sending...' : _cooldownSeconds > 0 ? 'Resend in ${_cooldownSeconds}s' : 'Resend Verification Email',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey[300], disabledForegroundColor: Colors.grey[500],
        elevation: ok ? 3 : 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd))),
    ));
  }

  Widget _checkBtn() {
    return SizedBox(width: double.infinity, height: 50, child: OutlinedButton.icon(
      onPressed: _isCheckingManually ? null : _checkManually,
      icon: _isCheckingManually
          ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
          : Icon(Icons.verified_outlined, size: 20, color: AppColors.primary),
      label: Text(_isCheckingManually ? 'Checking...' : 'I\'ve Verified My Email',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.primary)),
      style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.primary, width: 1.5),
        foregroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd))),
    ));
  }
}

class _WavePainter extends CustomPainter {
  final double v;
  _WavePainter({required this.v});

  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()..color = AppColors.primary.withValues(alpha: 0.03)..style = PaintingStyle.fill;
    final path1 = Path()..moveTo(0, size.height * 0.75);
    for (double x = 0; x <= size.width; x += 2) {
      path1.lineTo(x, size.height * 0.75 + math.sin((x / size.width * 4 * math.pi) + v) * 20 + math.sin((x / size.width * 2 * math.pi) + v * 0.7) * 12);
    }
    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    path1.close();
    canvas.drawPath(path1, p1);

    final p2 = Paint()..color = AppColors.secondary.withValues(alpha: 0.02)..style = PaintingStyle.fill;
    final path2 = Path()..moveTo(0, size.height * 0.8);
    for (double x = 0; x <= size.width; x += 2) {
      path2.lineTo(x, size.height * 0.8 + math.sin((x / size.width * 3 * math.pi) + v * 1.3) * 15);
    }
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, p2);
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.v != v;
}
