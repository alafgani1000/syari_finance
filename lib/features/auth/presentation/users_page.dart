import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/input/clear_composing_text_input_formatter.dart';
import '../data/auth_controller.dart';
import '../data/auth_repository.dart';

class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  final _repository = AuthRepository();
  late Future<List<AppUser>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(authControllerProvider).isAdmin
        ? _repository.getUsers()
        : Future.value(const []);
  }

  void _reload() => setState(() => _future = _repository.getUsers());

  Future<void> _createUser() async {
    if (!ref.read(authControllerProvider).isAdmin) return;
    final result = await showModalBottomSheet<_NewUser>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _UserSheet(),
    );
    if (result == null) return;
    try {
      await _repository.createUser(
        name: result.name,
        pin: result.pin,
        role: result.role,
      );
      _reload();
      _message('Pengguna berhasil ditambahkan.');
    } catch (error) {
      _message(error.toString().replaceFirst('Invalid argument(s): ', ''),
          error: true);
    }
  }

  Future<void> _toggle(AppUser user) async {
    if (!ref.read(authControllerProvider).isAdmin) return;
    if (user.isAdmin && user.isActive) {
      final users = await _repository.getUsers(activeOnly: true);
      if (users.where((item) => item.isAdmin).length < 2) {
        _message('Minimal satu Admin aktif harus dipertahankan.', error: true);
        return;
      }
    }
    await _repository.setActive(userId: user.id, active: !user.isActive);
    _reload();
  }

  Future<void> _changePin(AppUser user) async {
    if (!ref.read(authControllerProvider).isAdmin) return;
    final pin = await _showPinDialog(user.name);
    if (pin == null) return;
    await _repository.changePin(userId: user.id, pin: pin);
    _message('PIN ${user.name} berhasil diubah.');
  }

  Future<String?> _showPinDialog(String name) => showDialog<String>(
        context: context,
        builder: (_) => _ChangePinDialog(name: name),
      );
  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(text),
          backgroundColor: error ? Theme.of(context).colorScheme.error : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(authControllerProvider).isAdmin) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Halaman ini hanya dapat dibuka oleh Admin.'),
        ),
      );
    }
    return FutureBuilder<List<AppUser>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: FilledButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          );
        }
        final users = snapshot.data ?? const <AppUser>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            Text('Pengguna & PIN',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            const Text(
                'Admin mengelola backup, laporan, dan akun. Petugas dapat mencatat operasional harian.'),
            const SizedBox(height: 20),
            ...users.map(
              (user) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: user.isActive
                        ? const Color(0xFFD9F5E9)
                        : const Color(0xFFE4E7E5),
                    child: Icon(user.isAdmin
                        ? Icons.admin_panel_settings_outlined
                        : Icons.badge_outlined),
                  ),
                  title: Text(user.name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(user.role.value +
                      (user.isActive ? ' • Aktif' : ' • Nonaktif')),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) {
                      if (action == 'pin') _changePin(user);
                      if (action == 'active') _toggle(user);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'pin', child: Text('Ubah PIN')),
                      PopupMenuItem(
                        value: 'active',
                        child: Text(user.isActive ? 'Nonaktifkan' : 'Aktifkan'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _createUser,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Tambah pengguna'),
            ),
          ],
        );
      },
    );
  }
}

class _ChangePinDialog extends StatefulWidget {
  const _ChangePinDialog({required this.name});

  final String name;

  @override
  State<_ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends State<_ChangePinDialog> {
  String _pin = '';
  String _confirmation = '';
  String? _error;

  void _submit() {
    if (!RegExp(r'^\d{6}$').hasMatch(_pin)) {
      setState(() => _error = 'PIN harus terdiri dari enam angka.');
      return;
    }
    if (_pin != _confirmation) {
      setState(() => _error = 'PIN dan konfirmasi belum sama.');
      return;
    }
    Navigator.pop(context, _pin);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Ubah PIN'),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(alignment: Alignment.centerLeft, child: Text(widget.name)),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('change-pin'),
              maxLength: 6,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                const ClearComposingTextInputFormatter(),
              ],
              autofillHints: const <String>[],
              enableSuggestions: false,
              autocorrect: false,
              enableIMEPersonalizedLearning: false,
              onChanged: (value) => _pin = value,
              decoration: const InputDecoration(
                labelText: 'PIN baru',
                counterText: '',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('confirm-change-pin'),
              maxLength: 6,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                const ClearComposingTextInputFormatter(),
              ],
              autofillHints: const <String>[],
              enableSuggestions: false,
              autocorrect: false,
              enableIMEPersonalizedLearning: false,
              onChanged: (value) => _confirmation = value,
              decoration: const InputDecoration(
                labelText: 'Ulangi PIN',
                counterText: '',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          FilledButton(onPressed: _submit, child: const Text('Simpan PIN')),
        ],
      );
}

class _UserSheet extends StatefulWidget {
  const _UserSheet();

  @override
  State<_UserSheet> createState() => _UserSheetState();
}

class _UserSheetState extends State<_UserSheet> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _pin = '';
  UserRole _role = UserRole.officer;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Tambah pengguna',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 18),
                  TextFormField(
                    key: const ValueKey('new-user-name'),
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
                        labelText: 'Nama pengguna',
                        prefixIcon: Icon(Icons.person_outline)),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Nama wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<UserRole>(
                    initialValue: _role,
                    decoration: const InputDecoration(
                        labelText: 'Peran',
                        prefixIcon: Icon(Icons.badge_outlined)),
                    items: UserRole.values
                        .map((role) => DropdownMenuItem(
                            value: role, child: Text(role.value)))
                        .toList(),
                    onChanged: (value) => setState(() => _role = value!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    maxLength: 6,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      const ClearComposingTextInputFormatter(),
                    ],
                    autofillHints: const <String>[],
                    enableSuggestions: false,
                    autocorrect: false,
                    enableIMEPersonalizedLearning: false,
                    onChanged: (value) => _pin = value,
                    decoration: const InputDecoration(
                        labelText: 'PIN 6 angka',
                        counterText: '',
                        prefixIcon: Icon(Icons.pin_outlined)),
                    validator: (value) =>
                        value == null || !RegExp(r'^\d{6}$').hasMatch(value)
                            ? 'PIN harus enam angka'
                            : null,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          Navigator.pop(
                              context, _NewUser(_name.trim(), _pin, _role));
                        }
                      },
                      child: const Text('Simpan pengguna'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _NewUser {
  const _NewUser(this.name, this.pin, this.role);

  final String name;
  final String pin;
  final UserRole role;
}
