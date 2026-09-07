import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/input/clear_composing_text_input_formatter.dart';
import '../data/auth_controller.dart';
import '../data/auth_repository.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    if (state.phase == AuthPhase.authenticated) return child;

    final page = switch (state.phase) {
      AuthPhase.loading => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      AuthPhase.setupRequired => const _FirstAdminPage(),
      AuthPhase.signedOut => const _SignInPage(),
      AuthPhase.authenticated => child,
    };

    // MaterialApp.builder berada di atas Router. Saat halaman autentikasi
    // menggantikan child Router, sediakan Navigator sendiri agar TextField
    // tetap mempunyai Overlay untuk cursor, selection, dan IME Android.
    return Navigator(
      key: ValueKey('auth-${state.phase.name}'),
      onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => page),
    );
  }
}

class _FirstAdminPage extends ConsumerStatefulWidget {
  const _FirstAdminPage();

  @override
  ConsumerState<_FirstAdminPage> createState() => _FirstAdminPageState();
}

class _FirstAdminPageState extends ConsumerState<_FirstAdminPage> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _pin = '';
  bool _submitting = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final error =
        await ref.read(authControllerProvider.notifier).createFirstAdmin(
              name: _name,
              pin: _pin,
            );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
        title: 'Amankan Arafah Finance',
        subtitle:
            'Buat akun Admin dan PIN enam angka. PIN diminta kembali saat aplikasi dibuka.',
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                key: const ValueKey('first-admin-name'),
                keyboardType: TextInputType.visiblePassword,
                textCapitalization: TextCapitalization.words,
                inputFormatters: const [
                  ClearComposingTextInputFormatter(),
                ],
                autofillHints: const <String>[],
                enableSuggestions: false,
                autocorrect: false,
                enableIMEPersonalizedLearning: false,
                textInputAction: TextInputAction.next,
                onChanged: (value) => _name = value,
                decoration: const InputDecoration(
                  labelText: 'Nama Admin',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Nama wajib diisi'
                    : null,
              ),
              const SizedBox(height: 14),
              _PinField(
                label: 'PIN 6 angka',
                onChanged: (value) => _pin = value,
              ),
              const SizedBox(height: 14),
              _PinField(
                label: 'Ulangi PIN',
                validator: (value) => value != _pin ? 'PIN belum sama' : null,
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: const Icon(Icons.lock_person_outlined),
                  label: Text(_submitting ? 'Menyimpan...' : 'Buat akun Admin'),
                ),
              ),
            ],
          ),
        ),
      );
}

class _SignInPage extends ConsumerStatefulWidget {
  const _SignInPage();

  @override
  ConsumerState<_SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<_SignInPage> {
  final _repository = AuthRepository();
  final _formKey = GlobalKey<FormState>();
  String _pin = '';
  int _pinFieldVersion = 0;
  AppUser? _selected;
  late Future<List<AppUser>> _users;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _users = _repository.getUsers(activeOnly: true);
  }

  void _reloadUsers() {
    setState(() => _users = _repository.getUsers(activeOnly: true));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selected == null) return;
    setState(() => _submitting = true);
    final error = await ref.read(authControllerProvider.notifier).signIn(
          userId: _selected!.id,
          pin: _pin,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (error != null) {
      setState(() {
        _pin = '';
        _pinFieldVersion++;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
        title: 'Masuk ke aplikasi',
        subtitle: 'Pilih petugas lalu masukkan PIN enam angka.',
        child: FutureBuilder<List<AppUser>>(
          future: _users,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              );
            }
            if (snapshot.hasError) {
              return Column(
                children: [
                  const Text('Daftar pengguna belum dapat dibaca.'),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _reloadUsers,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Coba lagi'),
                  ),
                ],
              );
            }
            final users = snapshot.data ?? const <AppUser>[];
            if (users.isEmpty) {
              return const Text('Belum ada pengguna aktif. Hubungi Admin.');
            }
            _selected ??= users.first;
            return Form(
              key: _formKey,
              child: Column(
                children: [
                  DropdownButtonFormField<AppUser>(
                    initialValue: _selected,
                    decoration: const InputDecoration(
                      labelText: 'Petugas',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    items: users
                        .map(
                          (user) => DropdownMenuItem(
                            value: user,
                            child: Text('${user.name} • ${user.role.value}'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _selected = value),
                  ),
                  const SizedBox(height: 14),
                  _PinField(
                    key: ValueKey('login-pin-$_pinFieldVersion'),
                    label: 'PIN',
                    onChanged: (value) => _pin = value,
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: const Icon(Icons.login),
                      label: Text(_submitting ? 'Memeriksa...' : 'Masuk'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
}

class _PinField extends StatelessWidget {
  const _PinField({
    required this.label,
    this.onChanged,
    this.validator,
    super.key,
  });

  final String label;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) => TextFormField(
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          const ClearComposingTextInputFormatter(),
        ],
        obscureText: true,
        maxLength: 6,
        autofillHints: const <String>[],
        enableSuggestions: false,
        autocorrect: false,
        enableIMEPersonalizedLearning: false,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
          prefixIcon: const Icon(Icons.pin_outlined),
        ),
        validator: validator ??
            (value) => value == null || !RegExp(r'^\d{6}$').hasMatch(value)
                ? 'Masukkan enam angka PIN'
                : null,
      );
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD9F5E9),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.shield_outlined),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(subtitle),
                        const SizedBox(height: 24),
                        child,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
