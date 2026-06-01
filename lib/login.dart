import 'package:flutter/material.dart';
import 'services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _auth         = AuthService();
  bool    _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    final err = await _auth.login(_emailCtrl.text, _passwordCtrl.text);
    if (!mounted) return;
    if (err != null) {
      setState(() { _loading = false; _error = err; });
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B2C),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Logo
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.purple.withValues(alpha: 0.15),
                      boxShadow: [BoxShadow(
                          color: Colors.purpleAccent.withValues(alpha: 0.3),
                          blurRadius: 20, spreadRadius: 2)],
                    ),
                    child: const Icon(Icons.nightlight_round,
                        color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 20),
                  const Text('Night Dump',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w300)),
                  const SizedBox(height: 10),
                  const Text(
                    'Lepaskan pikiranmu ke dalam keheningan malam.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 15),
                  ),
                  const SizedBox(height: 40),

                  // Form
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF11163D),
                      borderRadius: BorderRadius.circular(35),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_error != null) ...[
                          _errorBox(_error!),
                          const SizedBox(height: 20),
                        ],
                        _field(
                          ctrl: _emailCtrl,
                          hint: 'Alamat Email',
                          type: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 28),
                        _field(
                          ctrl: _passwordCtrl,
                          hint: 'Kata Sandi',
                          obscure: true,
                          onSubmit: (_) => _loading ? null : _login(),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {},
                            child: const Text('Lupa Kata Sandi?',
                                style:
                                    TextStyle(color: Colors.white54)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _primaryBtn('MASUK', _loading, _login),
                        const SizedBox(height: 32),
                        _orDivider(),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _socialBtn('Google'),
                            _socialBtn('Apple'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Belum punya akun? ',
                          style: TextStyle(color: Colors.white54)),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(
                            context, '/register'),
                        child: const Text('Daftar Sekarang',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorBox(String msg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Colors.redAccent.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline,
                color: Colors.redAccent, size: 16),
            const SizedBox(width: 8),
            Expanded(
                child: Text(msg,
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 13))),
          ],
        ),
      );

  Widget _field({
    required TextEditingController ctrl,
    required String hint,
    TextInputType? type,
    bool obscure = false,
    void Function(String)? onSubmit,
  }) =>
      TextField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: type,
        style: const TextStyle(color: Colors.white),
        onSubmitted: onSubmit,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              TextStyle(color: Colors.white.withValues(alpha: 0.4)),
          enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2))),
          focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFD1B3FF))),
        ),
      );

  Widget _primaryBtn(
          String label, bool loading, VoidCallback onTap) =>
      Container(
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          gradient: const LinearGradient(
              colors: [Color(0xFF6A5CFF), Color(0xFF8B3DFF)]),
          boxShadow: [
            BoxShadow(
                color: Colors.purpleAccent.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8))
          ],
        ),
        child: ElevatedButton(
          onPressed: loading ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(40)),
          ),
          child: loading
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold)),
        ),
      );

  Widget _orDivider() => Row(
        children: [
          Expanded(
              child: Divider(
                  color: Colors.white.withValues(alpha: 0.2))),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child:
                Text('ATAU', style: TextStyle(color: Colors.white38)),
          ),
          Expanded(
              child: Divider(
                  color: Colors.white.withValues(alpha: 0.2))),
        ],
      );

  Widget _socialBtn(String label) => Container(
        width: 130, height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white10),
        ),
        child: Center(
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white, fontSize: 15))),
      );
}
