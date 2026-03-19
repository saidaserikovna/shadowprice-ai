import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
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

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await context.read<AuthService>().updateProfile(name: _nameCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated.')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
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
            const Text('Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ShadowTheme.textPrimary)),
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
                    backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                    child: user?.photoURL == null
                      ? Text(
                          (_profile?['name'] ?? user?.email ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(color: ShadowTheme.accent, fontSize: 28, fontWeight: FontWeight.bold),
                        )
                      : null,
                  ),
                  const SizedBox(height: 12),
                  Text(_profile?['name'] ?? 'User', style: const TextStyle(color: ShadowTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
                  Text(user?.email ?? '', style: const TextStyle(color: ShadowTheme.textMuted, fontSize: 13)),
                  const SizedBox(height: 20),

                  // Name field
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      labelStyle: TextStyle(color: ShadowTheme.textMuted),
                      prefixIcon: Icon(Icons.person_outline, color: ShadowTheme.textMuted, size: 20),
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
                      prefixIcon: Icon(Icons.email_outlined, color: ShadowTheme.textMuted, size: 20),
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
                  const Text('Account', style: TextStyle(fontWeight: FontWeight.w600, color: ShadowTheme.textPrimary)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await auth.signOut();
                      },
                      icon: const Icon(Icons.logout, size: 18, color: ShadowTheme.danger),
                      label: const Text('Sign out', style: TextStyle(color: ShadowTheme.danger)),
                      style: OutlinedButton.styleFrom(side: BorderSide(color: ShadowTheme.danger.withValues(alpha: 0.3))),
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
