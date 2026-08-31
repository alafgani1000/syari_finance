import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/backup/backup_file_channel.dart';
import '../data/backup_repository.dart';

class BackupSettingsPage extends StatefulWidget {
  const BackupSettingsPage({super.key});

  @override
  State<BackupSettingsPage> createState() => _BackupSettingsPageState();
}

class _BackupSettingsPageState extends State<BackupSettingsPage> {
  final _repository = BackupRepository();
  bool _busy = false;
  DateTime? _lastBackupAt;

  @override
  void initState() {
    super.initState();
    _loadLastBackup();
  }

  Future<void> _loadLastBackup() async {
    final lastBackupAt = await _repository.lastBackupAt();
    if (mounted) {
      setState(() => _lastBackupAt = lastBackupAt);
    }
  }

  Future<void> _backup() async {
    final password = await _showPasswordDialog(
      title: 'Lindungi cadangan',
      description:
          'Buat kata sandi minimal 8 karakter. Kata sandi ini dibutuhkan saat memulihkan data.',
      confirmPassword: true,
    );
    if (password == null || !mounted) return;

    final destination = await _chooseBackupDestination();
    if (destination == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final export =
          await _repository.createEncryptedBackup(password: password);
      final saved = await BackupFileChannel.saveBackup(
        export.file,
        destination: destination,
      );
      if (!saved) {
        _showMessage('Penyimpanan dibatalkan. Cadangan tidak disimpan.');
      } else {
        await _repository.recordBackup(export.createdAt);
        if (mounted) {
          setState(() => _lastBackupAt = export.createdAt);
        }
        _showMessage(
            'Backup berhasil disimpan. Simpan berkas ini di Google Drive atau tempat yang aman.');
      }
      if (await export.file.exists()) {
        await export.file.delete();
      }
    } on BackupException catch (error) {
      _showMessage(error.message, error: true);
    } catch (_) {
      _showMessage('Backup gagal. Silakan coba lagi.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<BackupDestination?> _chooseBackupDestination() =>
      showModalBottomSheet<BackupDestination>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Simpan backup ke',
                    style: Theme.of(sheetContext).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text('Pilih lokasi penyimpanan cadangan Anda.',
                    style: Theme.of(sheetContext).textTheme.bodySmall),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: const Text('Google Drive'),
                  subtitle: const Text('Direkomendasikan untuk perangkat baru'),
                  onTap: () => Navigator.pop(
                    sheetContext,
                    BackupDestination.googleDrive,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.phone_android_outlined),
                  title: const Text('Penyimpanan perangkat'),
                  subtitle: const Text('Simpan ke folder lokal di ponsel'),
                  onTap: () => Navigator.pop(
                    sheetContext,
                    BackupDestination.device,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.folder_open_outlined),
                  title: const Text('Lokasi lain'),
                  subtitle: const Text('Pilih aplikasi atau penyimpanan lain'),
                  onTap: () => Navigator.pop(
                    sheetContext,
                    BackupDestination.other,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  Future<void> _restore() async {
    final confirmed = await _confirmRestore();
    if (confirmed != true || !mounted) return;

    final backupFile = await BackupFileChannel.pickBackup();
    if (backupFile == null || !mounted) return;

    final password = await _showPasswordDialog(
      title: 'Masukkan kata sandi',
      description: 'Gunakan kata sandi yang dibuat ketika backup disimpan.',
    );
    if (password == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await _repository.restoreEncryptedBackup(
        file: backupFile,
        password: password,
      );
      _showMessage('Data berhasil dipulihkan. Dashboard akan dimuat ulang.');
      if (mounted) context.go('/dashboard');
    } on BackupException catch (error) {
      _showMessage(error.message, error: true);
    } catch (_) {
      _showMessage('Restore gagal. Data saat ini tetap dipertahankan.',
          error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _showPasswordDialog({
    required String title,
    required String description,
    bool confirmPassword = false,
  }) =>
      showDialog<String>(
        context: context,
        builder: (_) => _BackupPasswordDialog(
          title: title,
          description: description,
          confirmPassword: confirmPassword,
        ),
      );
  Future<bool?> _confirmRestore() => showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded),
          title: const Text('Pulihkan seluruh data?'),
          content: const Text(
            'Data yang ada di ponsel ini akan diganti dengan isi backup. Aplikasi membuat salinan pengaman sebelum proses dimulai.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Pulihkan'),
            ),
          ],
        ),
      );

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('d MMMM y, HH:mm', 'id_ID');
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            Text('Data & Backup',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Amankan data sebelum mengganti atau kehilangan perangkat.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, color: scheme.primary),
                    const SizedBox(height: 16),
                    Text('Cadangan terenkripsi',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      'Backup dilindungi kata sandi dan dapat disimpan ke Google Drive atau lokasi pilihan Anda.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _lastBackupAt == null
                          ? 'Belum ada backup tersimpan'
                          : 'Backup terakhir: ' +
                              formatter.format(_lastBackupAt!),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _lastBackupAt == null
                                ? scheme.error
                                : scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _backup,
                        icon: const Icon(Icons.backup_outlined),
                        label: const Text('Backup Sekarang'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.settings_backup_restore_outlined,
                        color: scheme.primary),
                    const SizedBox(height: 16),
                    Text('Pulihkan data',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    const Text(
                      'Gunakan berkas .syaribackup dari perangkat lama atau Google Drive.',
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _restore,
                        icon: const Icon(Icons.restore),
                        label: const Text('Pulihkan dari Backup'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Catatan penting',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            const Text(
              'Jangan membagikan berkas backup maupun kata sandinya. Kata sandi tidak dapat dipulihkan oleh aplikasi.',
            ),
          ],
        ),
        if (_busy)
          const ColoredBox(
            color: Color(0x33000000),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

class _BackupPasswordDialog extends StatefulWidget {
  const _BackupPasswordDialog({
    required this.title,
    required this.description,
    required this.confirmPassword,
  });

  final String title;
  final String description;
  final bool confirmPassword;

  @override
  State<_BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<_BackupPasswordDialog> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit() {
    if (_password.text.trim().length < 8) {
      setState(() => _errorText = 'Kata sandi minimal 8 karakter.');
      return;
    }
    if (widget.confirmPassword && _password.text != _confirmation.text) {
      setState(() => _errorText = 'Konfirmasi kata sandi belum sama.');
      return;
    }
    Navigator.pop(context, _password.text);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(widget.description,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              autofocus: true,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Kata sandi backup',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            if (widget.confirmPassword) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _confirmation,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Ulangi kata sandi',
                  prefixIcon: Icon(Icons.lock_reset_outlined),
                ),
              ),
            ],
            if (_errorText != null) ...[
              const SizedBox(height: 10),
              Text(_errorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: _submit,
            child: const Text('Lanjutkan'),
          ),
        ],
      );
}
