import 'package:dio/dio.dart';
import 'package:flareline/pages/layout.dart';
import 'package:flareline_uikit/components/card/common_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AllTenantsPage extends LayoutWidget {
  const AllTenantsPage({super.key});

  Future<List<Map<String, dynamic>>> _fetchTenants() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'auth_token');

    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://rentcom.net/api',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );

    final response = await dio.get('/tenants');
    final raw = response.data;

    if (raw is Map<String, dynamic> && raw['data'] is List) {
      return (raw['data'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    return [];
  }

  Future<void> _deleteTenant(BuildContext context, int id) async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'auth_token');

    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://rentcom.net/api',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );

    await dio.delete('/tenants/$id');
  }

  Future<void> _showEditDialog(
      BuildContext context,
      Map<String, dynamic> tenant,
      ) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: tenant['name']?.toString() ?? '');
    final phoneController = TextEditingController(text: tenant['phone']?.toString() ?? '');
    final nationalIdController =
    TextEditingController(text: tenant['national_id']?.toString() ?? '');

    final save = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Tenant'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                validator: (v) => v == null || v.isEmpty ? 'Phone is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nationalIdController,
                decoration: const InputDecoration(labelText: 'National ID'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (save != true) return;

    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'auth_token');

    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://rentcom.net/api',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );

    await dio.put('/tenants/${tenant['id']}', data: {
      'name': nameController.text.trim(),
      'phone': phoneController.text.trim(),
      'national_id': nationalIdController.text.trim().isEmpty
          ? null
          : nationalIdController.text.trim(),
    });
  }

  @override
  Widget contentDesktopWidget(BuildContext context) {
    return _AllTenantsBody(
      fetchTenants: _fetchTenants,
      deleteTenant: _deleteTenant,
      showEditDialog: _showEditDialog,
    );
  }

  @override
  String breakTabTitle(BuildContext context) => 'All Tenants';
}

class _AllTenantsBody extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function() fetchTenants;
  final Future<void> Function(BuildContext, int) deleteTenant;
  final Future<void> Function(BuildContext, Map<String, dynamic>) showEditDialog;

  const _AllTenantsBody({
    required this.fetchTenants,
    required this.deleteTenant,
    required this.showEditDialog,
  });

  @override
  State<_AllTenantsBody> createState() => _AllTenantsBodyState();
}

class _AllTenantsBodyState extends State<_AllTenantsBody> {
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = widget.fetchTenants();
  }

  void refresh() {
    setState(() {
      future = widget.fetchTenants();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 400,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return CommonCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Failed to load tenants: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final tenants = snapshot.data ?? [];

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: CommonCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            tenants.length.toString(),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text('Total Tenants'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CommonCard(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 28,
                  columns: const [
                    DataColumn(label: Text('ID')),
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('Phone')),
                    DataColumn(label: Text('National ID')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: tenants.map((tenant) {
                    return DataRow(
                      cells: [
                        DataCell(Text('${tenant['id'] ?? ''}')),
                        DataCell(Text('${tenant['name'] ?? '-'}')),
                        DataCell(Text('${tenant['email'] ?? '-'}')),
                        DataCell(Text('${tenant['phone'] ?? '-'}')),
                        DataCell(Text('${tenant['national_id'] ?? '-'}')),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () async {
                                  await widget.showEditDialog(context, tenant);
                                  refresh();
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Delete Tenant'),
                                      content: const Text(
                                        'Are you sure you want to delete this tenant?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    await widget.deleteTenant(context, tenant['id'] as int);
                                    refresh();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}