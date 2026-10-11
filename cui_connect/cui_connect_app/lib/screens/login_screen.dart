import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/config.dart';
import '../providers/app_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscurePassword = true;

  Future<void> _serverDialog() async {
    final c = TextEditingController(text: Config.baseUrl);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Server connection'),
        content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Backend URL', hintText: 'http://192.168.1.10:3000')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) setState(() => Config.baseUrl = c.text.trim().replaceAll(RegExp(r'/+$'), ''));
    c.dispose();
  }

  Future<void> _login() async {
    if (_username.text.trim().isEmpty || _password.text.isEmpty) {
      context.read<AppState>().toast('Enter your username and password', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AppState>().login(_username.text.trim(), _password.text);
    } catch (e) {
      if (mounted) context.read<AppState>().toast('Sign in failed: $e', error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFEAF2FC), Color(0xFFF7F9FC), Color(0xFFE8EEF7)]),
        ),
        child: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 56).clamp(0.0, double.infinity),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Row(children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.hub_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 13),
                      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('CampusPulse', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                        SizedBox(height: 2),
                        Text('COMSATS University Islamabad', style: TextStyle(fontSize: 13, color: Colors.black54)),
                      ])),
                      IconButton(tooltip: 'Server settings', onPressed: _serverDialog, icon: const Icon(Icons.settings_outlined)),
                    ]),
                    const SizedBox(height: 25),
                    Card(
                      elevation: 4,
                      shadowColor: const Color(0x220B4F9E),
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Text('Welcome back', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          const Text('Sign in with your university account to continue.', style: TextStyle(color: Colors.black54, height: 1.4)),
                          const SizedBox(height: 25),
                          TextField(
                            controller: _username,
                            enabled: !_busy,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            decoration: _fieldDecoration('Username', 'Enter your username', Icons.person_outline),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _password,
                            enabled: !_busy,
                            obscureText: _obscurePassword,
                            onSubmitted: (_) => _login(),
                            decoration: _fieldDecoration('Password', 'Enter your password', Icons.lock_outline).copyWith(
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(height: 21),
                          SizedBox(
                            height: 50,
                            child: FilledButton.icon(
                              onPressed: _busy ? null : _login,
                              icon: _busy
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.login_rounded),
                              label: Text(_busy ? 'Signing in…' : 'Sign in', style: const TextStyle(fontWeight: FontWeight.w700)),
                              style: FilledButton.styleFrom(backgroundColor: kBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Row(children: [
                            Icon(Icons.verified_user_outlined, size: 16, color: Colors.black45),
                            SizedBox(width: 7),
                            Expanded(child: Text('University accounts are managed by your institution.', style: TextStyle(fontSize: 12, color: Colors.black54))),
                          ]),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text('Campus communication, announcements and student opportunities.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ]),
                ),
              ),
            ),
          )),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, String hint, IconData icon) => InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFF7F9FC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: Color(0xFFDCE3ED))),
      );
}
