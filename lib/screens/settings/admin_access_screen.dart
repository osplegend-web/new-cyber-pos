import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';

class AdminAccessScreen extends StatefulWidget {
  const AdminAccessScreen({super.key});
  @override
  State<AdminAccessScreen> createState() => _AdminAccessScreenState();
}

class _AdminAccessScreenState extends State<AdminAccessScreen> {
  final _pin = TextEditingController();
  final _newPin = TextEditingController();
  final _confirmPin = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() { _pin.dispose(); _newPin.dispose(); _confirmPin.dispose(); super.dispose(); }

  Future<void> _setup() async {
    final p = _newPin.text.trim();
    if (p.length < 4 || p != _confirmPin.text.trim()) {
      _msg('PIN must be at least 4 digits and both PINs must match.'); return;
    }
    final ok = await context.read<AdminProvider>().setPin(p);
    if (ok && mounted) { _newPin.clear(); _confirmPin.clear(); _msg('Admin PIN created. Admin access is unlocked.'); }
  }

  void _unlock() {
    final ok = context.read<AdminProvider>().unlock(_pin.text.trim());
    if (ok) { _pin.clear(); _msg('Admin access unlocked.'); }
    else { _msg('Incorrect admin PIN.'); }
  }

  Future<void> _changePin() async {
    final old = _pin.text.trim();
    final p = _newPin.text.trim();
    if (p.length < 4 || p != _confirmPin.text.trim()) { _msg('New PINs must match and be at least 4 digits.'); return; }
    final ok = await context.read<AdminProvider>().changePin(old, p);
    if (ok && mounted) { _pin.clear(); _newPin.clear(); _confirmPin.clear(); _msg('Admin PIN changed.'); }
    else { _msg('Current PIN is incorrect.'); }
  }

  void _msg(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  InputDecoration _dec(String label) => InputDecoration(labelText: label, prefixIcon: const Icon(Icons.lock_outline));

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Access')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
            Icon(admin.isAdmin ? Icons.admin_panel_settings : Icons.lock, size: 40, color: admin.isAdmin ? Colors.green : Colors.orange),
            const SizedBox(width: 14), Expanded(child: Text(admin.isAdmin ? 'Admin mode is unlocked' : 'Admin mode is locked', style: Theme.of(context).textTheme.titleMedium)),
            if (admin.isAdmin) FilledButton.tonal(onPressed: admin.lock, child: const Text('Lock')),
          ]))),
          const SizedBox(height: 20),
          if (!admin.hasPin) ...[
            Text('Create Admin PIN', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(controller: _newPin, obscureText: _obscure, keyboardType: TextInputType.number, decoration: _dec('New PIN')),
            const SizedBox(height: 12),
            TextField(controller: _confirmPin, obscureText: _obscure, keyboardType: TextInputType.number, decoration: _dec('Confirm PIN')),
            const SizedBox(height: 12),
            SwitchListTile(title: const Text('Show PIN'), value: !_obscure, onChanged: (v) => setState(() => _obscure = !v)),
            FilledButton.icon(onPressed: _setup, icon: const Icon(Icons.admin_panel_settings), label: const Text('Create Admin PIN')),
          ] else ...[
            Text('Unlock Admin', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(controller: _pin, obscureText: _obscure, keyboardType: TextInputType.number, decoration: _dec('Admin PIN'), onSubmitted: (_) => _unlock()),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: _unlock, icon: const Icon(Icons.lock_open), label: const Text('Unlock Admin')),
            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 18),
            Text('Change Admin PIN', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(controller: _newPin, obscureText: _obscure, keyboardType: TextInputType.number, decoration: _dec('New PIN')),
            const SizedBox(height: 12),
            TextField(controller: _confirmPin, obscureText: _obscure, keyboardType: TextInputType.number, decoration: _dec('Confirm New PIN')),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: _changePin, child: const Text('Change PIN (current PIN above)')),
          ],
          const SizedBox(height: 24),
          const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Admin-only information includes purchasing prices, profit figures, and stock cost/value. Regular users can continue using sales and billing normally.'))),
        ],
      ),
    );
  }
}
