import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../widgets/shop_dialogs.dart';
import '../widgets/shop_ui.dart';

class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key});

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
  late Future<List<Map<String, dynamic>>> _suppliers;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ApiClient.isEmployee) {
        Navigator.pushNamedAndRemoveUntil(context, '/sales', (route) => false);
      }
    });
    _suppliers = ApiClient.suppliers();
  }

  Future<void> _reload() async {
    final future = ApiClient.suppliers();
    setState(() => _suppliers = future);
    await future;
  }

  Future<void> _editSupplier([Map<String, dynamic>? supplier]) async {
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _SupplierDialog(supplier: supplier),
    );
    if (values == null || !mounted) return;
    try {
      if (supplier == null) {
        await ApiClient.createSupplier(values);
      } else {
        await ApiClient.updateSupplier(supplier['id'] as String, values);
      }
      if (mounted) {
        showShopMessage(context, 'Supplier saved.');
        await _reload();
      }
    } on ApiException catch (error) {
      if (mounted) showShopMessage(context, error.message);
    }
  }

  Future<void> _deleteSupplier(Map<String, dynamic> supplier) async {
    final confirmed = await showShopConfirm(
      context: context,
      title: 'Delete supplier?',
      message: 'Remove ${supplier['name']} from this shop?',
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiClient.deleteSupplier(supplier['id'] as String);
      if (mounted) await _reload();
    } on ApiException catch (error) {
      if (mounted) showShopMessage(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ShopColors.surface,
    appBar: AppBar(
      title: const Text('Suppliers'),
      backgroundColor: ShopColors.primary,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          tooltip: 'Add supplier',
          onPressed: _editSupplier,
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _suppliers,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Could not load suppliers: ${snapshot.error}'),
                TextButton(onPressed: _reload, child: const Text('Try again')),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final suppliers = snapshot.data!;
        if (suppliers.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_shipping_outlined, size: 48),
                const SizedBox(height: 8),
                const Text('No suppliers yet'),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _editSupplier,
                  icon: const Icon(Icons.add),
                  label: const Text('Add supplier'),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: suppliers.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final supplier = suppliers[index];
              final details =
                  [
                        supplier['contact_name'],
                        supplier['phone'],
                        supplier['email'],
                      ]
                      .whereType<String>()
                      .where((value) => value.isNotEmpty)
                      .join(' · ');
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.local_shipping_outlined),
                  ),
                  title: Text(supplier['name'] as String? ?? ''),
                  subtitle: Text(
                    [details, supplier['address'], supplier['notes']]
                        .whereType<String>()
                        .where((value) => value.isNotEmpty)
                        .join('\n'),
                  ),
                  isThreeLine: details.isNotEmpty,
                  onTap: () => _editSupplier(supplier),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) {
                      if (action == 'edit') _editSupplier(supplier);
                      if (action == 'delete') _deleteSupplier(supplier);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: _editSupplier,
      child: const Icon(Icons.add),
    ),
  );
}

/// Upgraded add/edit supplier pop-up. Owns its controllers and disposes them
/// in its own State so the disposal happens after the pop animation finishes.
class _SupplierDialog extends StatefulWidget {
  const _SupplierDialog({this.supplier});

  final Map<String, dynamic>? supplier;

  @override
  State<_SupplierDialog> createState() => _SupplierDialogState();
}

class _SupplierDialogState extends State<_SupplierDialog> {
  late final _name = TextEditingController(
    text: widget.supplier?['name'] as String? ?? '',
  );
  late final _contact = TextEditingController(
    text: widget.supplier?['contact_name'] as String? ?? '',
  );
  late final _phone = TextEditingController(
    text: widget.supplier?['phone'] as String? ?? '',
  );
  late final _email = TextEditingController(
    text: widget.supplier?['email'] as String? ?? '',
  );
  late final _address = TextEditingController(
    text: widget.supplier?['address'] as String? ?? '',
  );
  late final _notes = TextEditingController(
    text: widget.supplier?['notes'] as String? ?? '',
  );
  final _formKey = GlobalKey<FormState>();
  bool _popped = false;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _contact,
      _phone,
      _email,
      _address,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _pop(Map<String, String>? result) {
    if (_popped) return;
    _popped = true;
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) => ShopPopup(
    title: widget.supplier == null ? 'Add supplier' : 'Edit supplier',
    icon: Icons.local_shipping_rounded,
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: shopFieldDecoration('Supplier name *',
                icon: Icons.business_rounded),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 9),
          TextFormField(
            controller: _contact,
            textCapitalization: TextCapitalization.words,
            decoration: shopFieldDecoration('Contact person',
                icon: Icons.person_outline_rounded),
          ),
          const SizedBox(height: 9),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: shopFieldDecoration('Phone',
                icon: Icons.phone_outlined),
          ),
          const SizedBox(height: 9),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: shopFieldDecoration('Email',
                icon: Icons.mail_outline_rounded),
          ),
          const SizedBox(height: 9),
          TextFormField(
            controller: _address,
            textCapitalization: TextCapitalization.words,
            decoration: shopFieldDecoration('Address',
                icon: Icons.location_on_outlined),
          ),
          const SizedBox(height: 9),
          TextFormField(
            controller: _notes,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: shopFieldDecoration('Notes',
                icon: Icons.notes_rounded),
          ),
        ],
      ),
    ),
    footer: ShopPopupActions(
      confirmLabel: widget.supplier == null ? 'Add supplier' : 'Save changes',
      onCancel: () => _pop(null),
      onConfirm: () {
        if (!_formKey.currentState!.validate()) return;
        _pop({
          'name': _name.text.trim(),
          'contact_name': _contact.text.trim(),
          'phone': _phone.text.trim(),
          'email': _email.text.trim(),
          'address': _address.text.trim(),
          'notes': _notes.text.trim(),
        });
      },
    ),
  );
}
