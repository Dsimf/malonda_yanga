import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../widgets/shop_dialogs.dart';
import '../widgets/shop_ui.dart';

/// Staff management for the shop owner: creates employee logins that can
/// only use Sales and Daily Sales (reports limited to that view).
class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key});

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  List<Map<String, dynamic>> _employees = [];
  bool _loading = true;
  String? _errorMessage;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final employees = await ApiClient.employees();
      if (mounted) {
        setState(() {
          _employees = employees;
          _loading = false;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _addEmployee() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _EmployeeDialog(),
    );
    if (result == null || !mounted) return;
    try {
      await ApiClient.createEmployee(
        displayName: result['name']!,
        email: result['email']!,
        password: result['password']!,
      );
      if (mounted) {
        showShopMessage(
          context,
          'Employee created. They now have their own login (Sales & Daily Sales only).',
        );
        _load();
      }
    } on ApiException catch (error) {
      if (mounted) showShopMessage(context, error.message);
    }
  }

  Future<void> _removeEmployee(String id, String name) async {
    try {
      await ApiClient.deleteEmployee(id);
      if (mounted) {
        showShopMessage(context, '$name removed.');
        _load();
      }
    } on ApiException catch (error) {
      if (mounted) showShopMessage(context, error.message);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ApiClient.isEmployee) {
        Navigator.pushNamedAndRemoveUntil(context, '/sales', (route) => false);
      }
    });
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ShopColors.surface,
    body: SafeArea(
      child: Column(
        children: [
          _EmployeesHeader(onBack: () => Navigator.pop(context)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              children: [
                const _AccessInfoCard(),
                const SizedBox(height: 12),
                if (_loading) const LinearProgressIndicator(),
                if (_errorMessage != null)
                  Text(
                    'Could not load employees: $_errorMessage',
                    style: const TextStyle(color: ShopColors.red, fontSize: 12),
                  ),
                for (final employee in _employees)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 19,
                            backgroundColor: ShopColors.paleBlue,
                            child: Text(
                              (employee['display_name'] as String? ?? '?')
                                  .characters
                                  .first
                                  .toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: ShopColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  employee['display_name'] as String? ??
                                      'Employee',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'Access: Sales & Daily Sales',
                                  style: const TextStyle(
                                    color: ShopColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (employee['role'] != 'owner')
                            IconButton(
                              tooltip: 'Remove employee',
                              onPressed: () => _removeEmployee(
                                employee['id'] as String,
                                employee['display_name'] as String? ??
                                    'Employee',
                              ),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: ShopColors.red,
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (!_loading && _employees.isEmpty && _errorMessage == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No employees yet. Add one below.',
                        style: TextStyle(color: ShopColors.muted),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _addEmployee,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text(
                      'Add Employee Login',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: ShopColors.primary,
                      foregroundColor: Colors.white,
                    ),
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

class _AccessInfoCard extends StatelessWidget {
  const _AccessInfoCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFE4F0EC),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.admin_panel_settings_outlined, color: ShopColors.green),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Shop owner: full access (inventory, suppliers, reports, expenses, staff).\n'
            'Employee: Sales and Daily Sales only.',
            style: TextStyle(
              color: ShopColors.green,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

class _EmployeesHeader extends StatelessWidget {
  const _EmployeesHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Container(
    height: 64,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    color: ShopColors.primary,
    child: Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        const SizedBox(width: 6),
        const Expanded(
          child: Text(
            'Staff & Access',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _EmployeeDialog extends StatefulWidget {
  const _EmployeeDialog();

  @override
  State<_EmployeeDialog> createState() => _EmployeeDialogState();
}

class _EmployeeDialogState extends State<_EmployeeDialog> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ShopPopup(
    title: 'Add employee login',
    icon: Icons.person_add_alt_rounded,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _nameController,
          decoration: shopFieldDecoration('Employee name'),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: shopFieldDecoration('Login email'),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: shopFieldDecoration('Password (min 8 characters)'),
        ),
      ],
    ),
    footer: ShopPopupActions(
      confirmLabel: 'Create login',
      onCancel: () => Navigator.pop(context),
      onConfirm: () {
        final name = _nameController.text.trim();
        final email = _emailController.text.trim();
        final password = _passwordController.text;
        if (name.isEmpty || email.isEmpty || password.length < 8) {
          showShopMessage(
            context,
            'Fill in all fields (password at least 8 characters).',
          );
          return;
        }
        Navigator.pop(context, {
          'name': name,
          'email': email,
          'password': password,
        });
      },
    ),
  );
}
