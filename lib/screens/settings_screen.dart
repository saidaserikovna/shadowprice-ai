import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/shadowprice_api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _backendUrlCtrl = TextEditingController();
  bool _loading = false;
  bool _backendSaving = false;
  bool? _backendReachable;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadBackendUrl();
  }

  Future<void> _loadProfile() async {
    final auth = context.read<AuthService>();
    final profile = await auth.getUserProfile();
    if (mounted && profile != null) {
      setState(() {
        _profile = profile;
        _nameCtrl.text = profile['name'] ?? '';
      });
    }
  }

  Future<void> _loadBackendUrl() async {
    final api = context.read<ShadowPriceApiService>();
    final url = await api.getConfiguredApiBaseUrl();
    if (mounted) {
      setState(() {
        _backendUrlCtrl.text = url;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await context
          .read<AuthService>()
          .updateProfile(name: _nameCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profile updated.')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveBackendUrl({bool testConnection = false}) async {
    setState(() => _backendSaving = true);
    final api = context.read<ShadowPriceApiService>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await api.setApiBaseUrl(_backendUrlCtrl.text.trim());
      bool? reachable;
      if (testConnection) {
        reachable = await api.pingBackend(_backendUrlCtrl.text.trim());
      }

      if (!mounted) {
        return;
      }

      setState(() => _backendReachable = reachable);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            reachable == null
                ? 'Backend URL saved.'
                : reachable
                    ? 'Backend connected successfully.'
                    : 'URL saved, but the backend did not respond.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _backendSaving = false);
      }
    }
  }

  Future<void> _resetBackendUrl() async {
    setState(() => _backendSaving = true);
    final api = context.read<ShadowPriceApiService>();
    try {
      await api.resetApiBaseUrl();
      final defaultUrl = await api.getConfiguredApiBaseUrl();
      if (!mounted) {
        return;
      }
      setState(() {
        _backendReachable = null;
        _backendUrlCtrl.text = defaultUrl;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Backend URL reset to the default emulator value.')),
      );
    } finally {
      if (mounted) {
        setState(() => _backendSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _backendUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Settings',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: ShadowTheme.textPrimary)),
            const SizedBox(height: 24),

            // Profile card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ShadowTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ShadowTheme.border),
              ),
              child: Column(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: ShadowTheme.accent.withValues(alpha: 0.2),
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: user?.photoURL == null
                        ? Text(
                            (_profile?['name'] ?? user?.email ?? 'U')[0]
                                .toUpperCase(),
                            style: const TextStyle(
                                color: ShadowTheme.accent,
                                fontSize: 28,
                                fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(_profile?['name'] ?? 'User',
                      style: const TextStyle(
                          color: ShadowTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 16)),
                  Text(user?.email ?? '',
                      style: const TextStyle(
                          color: ShadowTheme.textMuted, fontSize: 13)),
                  const SizedBox(height: 20),

                  // Name field
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      labelStyle: TextStyle(color: ShadowTheme.textMuted),
                      prefixIcon: Icon(Icons.person_outline,
                          color: ShadowTheme.textMuted, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Email (read only)
                  TextField(
                    enabled: false,
                    controller: TextEditingController(text: user?.email ?? ''),
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(color: ShadowTheme.textMuted),
                      prefixIcon: Icon(Icons.email_outlined,
                          color: ShadowTheme.textMuted, size: 20),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _save,
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: Text(_loading ? 'Saving...' : 'Save'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ShadowTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ShadowTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Backend Connection',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: ShadowTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Emulator default: ${context.read<ShadowPriceApiService>().defaultApiBaseUrl}. On a real phone, use your laptop Wi-Fi IP like http://192.168.x.x:8000.',
                    style: const TextStyle(
                      color: ShadowTheme.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _backendUrlCtrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Backend URL',
                      labelStyle: TextStyle(color: ShadowTheme.textMuted),
                      prefixIcon: Icon(
                        Icons.cloud_outlined,
                        color: ShadowTheme.textMuted,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_backendReachable != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: (_backendReachable!
                                ? ShadowTheme.success
                                : ShadowTheme.warning)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (_backendReachable!
                                  ? ShadowTheme.success
                                  : ShadowTheme.warning)
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _backendReachable!
                            ? 'Backend is reachable.'
                            : 'Saved URL did not answer. Check Wi-Fi, backend host, and port 8000.',
                        style: TextStyle(
                          color: _backendReachable!
                              ? ShadowTheme.success
                              : ShadowTheme.warning,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _backendSaving
                              ? null
                              : () => _saveBackendUrl(testConnection: true),
                          icon: const Icon(Icons.wifi_tethering, size: 18),
                          label: Text(
                              _backendSaving ? 'Saving...' : 'Save & Test'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _backendSaving ? null : _resetBackendUrl,
                          icon: const Icon(Icons.restart_alt, size: 18),
                          label: const Text('Reset'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Sign out
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ShadowTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ShadowTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Account',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: ShadowTheme.textPrimary)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await auth.signOut();
                      },
                      icon: const Icon(Icons.logout,
                          size: 18, color: ShadowTheme.danger),
                      label: const Text('Sign out',
                          style: TextStyle(color: ShadowTheme.danger)),
                      style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color:
                                  ShadowTheme.danger.withValues(alpha: 0.3))),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
