import 'package:flutter/material.dart';
import 'services/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _auth         = AuthService();
  bool    _loading       = false;
  bool    _showPassword  = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() { _loading = true; _error = null; });
    final err = await _auth.register(
        _nameCtrl.text, _emailCtrl.text, _passwordCtrl.text);
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
                          fontSize: 34,
                          fontWeight: FontWeight.w300)),
                  const SizedBox(height: 28),

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
                        const Text('Bergabunglah.',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w300)),
                        const SizedBox(height: 6),
                        const Text(
                          'Ruang aman untuk pikiran malam harimu.',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 14),
                        ),
                        const SizedBox(height: 28),
                        if (_error != null) ...[
                          _errorBox(_error!),
                          const SizedBox(height: 20),
                        ],
                        _field(ctrl: _nameCtrl, hint: 'Nama Lengkap',
                            caps: TextCapitalization.words),
                        const SizedBox(height: 24),
                        _field(
                            ctrl: _emailCtrl,
                            hint: 'Alamat Email',
                            type: TextInputType.emailAddress),
                        const SizedBox(height: 24),
                        _passwordField(),
                        const SizedBox(height: 36),
                        _primaryBtn('BUAT AKUN', _loading, _register),
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
                        const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Sudah punya akun? ',
                                style: TextStyle(color: Colors.white54)),
                            GestureDetector(
                              onTap: () => Navigator.pushReplacementNamed(
                                  context, '/login'),
                              child: const Text('Masuk',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
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
    TextCapitalization caps = TextCapitalization.none,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        textCapitalization: caps,
        style: const TextStyle(color: Colors.white),
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

  Widget _passwordField() => TextField(
        controller: _passwordCtrl,
        obscureText: !_showPassword,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Kata Sandi (min. 6 karakter)',
          hintStyle:
              TextStyle(color: Colors.white.withValues(alpha: 0.4)),
          enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2))),
          focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFD1B3FF))),
          suffixIcon: IconButton(
            icon: Icon(
                _showPassword
                    ? Icons.visibility
                    : Icons.visibility_off,
                color: Colors.white38, size: 20),
            onPressed: () =>
                setState(() => _showPassword = !_showPassword),
          ),
        ),
      );

  Widget _primaryBtn(String label, bool loading, VoidCallback onTap) =>
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
