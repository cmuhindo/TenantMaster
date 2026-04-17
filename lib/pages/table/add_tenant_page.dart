import 'package:dio/dio.dart';
import 'package:flareline/pages/layout.dart';
import 'package:flareline_uikit/components/card/common_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AddTenantPage extends LayoutWidget {
  const AddTenantPage({super.key});

  @override
  Widget contentDesktopWidget(BuildContext context) {
    return const AddTenantForm();
  }

  @override
  String breakTabTitle(BuildContext context) => 'Add Tenant';
}

class AddTenantForm extends StatefulWidget {
  const AddTenantForm({super.key});

  @override
  State<AddTenantForm> createState() => _AddTenantFormState();
}

class _AddTenantFormState extends State<AddTenantForm> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final nationalIdController = TextEditingController();
  final passwordController = TextEditingController();

  final rentAmountController = TextEditingController();
  final dueDayController = TextEditingController();
  final startDateController = TextEditingController();

  bool loading = false;
  bool loadingProperties = true;
  bool loadingUnits = false;

  List<Map<String, dynamic>> properties = [];
  List<Map<String, dynamic>> units = [];

  String? selectedPropertyId;
  String? selectedUnitId;
  String? selectedBillingCycle = 'monthly';

  Future<Dio> _dio() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'auth_token');

    return Dio(
      BaseOptions(
        baseUrl: 'https://rentcom.net/api',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    startDateController.text = DateTime.now().toIso8601String().split('T').first;
    _loadProperties();
  }

  Future<void> _loadProperties() async {
    setState(() => loadingProperties = true);

    try {
      final dio = await _dio();
      final response = await dio.get('/properties');
      final raw = response.data;

      List<Map<String, dynamic>> fetched = [];

      if (raw is Map<String, dynamic> && raw['data'] is List) {
        fetched = (raw['data'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else if (raw is List) {
        fetched = raw.map((e) => Map<String, dynamic>.from(e)).toList();
      }

      setState(() {
        properties = fetched;
        loadingProperties = false;
      });
    } catch (e) {
      setState(() => loadingProperties = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load properties: $e')),
      );
    }
  }

  Future<void> _loadUnitsForProperty(String propertyId) async {
    setState(() {
      loadingUnits = true;
      units = [];
      selectedUnitId = null;
    });

    try {
      final dio = await _dio();
      final response = await dio.get('/units', queryParameters: {
        'property_id': propertyId,
      });

      final raw = response.data;
      List<Map<String, dynamic>> fetched = [];

      if (raw is Map<String, dynamic> && raw['data'] is List) {
        fetched = (raw['data'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else if (raw is List) {
        fetched = raw.map((e) => Map<String, dynamic>.from(e)).toList();
      }

      setState(() {
        units = fetched;
        loadingUnits = false;
      });
    } catch (e) {
      setState(() => loadingUnits = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load units: $e')),
      );
    }
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedPropertyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please assign a property')),
      );
      return;
    }

    if (selectedUnitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please assign a unit')),
      );
      return;
    }

    if (selectedBillingCycle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a billing cycle')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final dio = await _dio();

      final tenantResponse = await dio.post('/tenants', data: {
        'name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'email': emailController.text.trim(),
        'national_id': nationalIdController.text.trim().isEmpty
            ? null
            : nationalIdController.text.trim(),
        'password': passwordController.text.trim(),
      });

      final tenantData = tenantResponse.data;
      int? tenantId;

      if (tenantData is Map<String, dynamic>) {
        if (tenantData['data'] is Map<String, dynamic>) {
          tenantId = int.tryParse('${tenantData['data']['id']}');
        } else if (tenantData['id'] != null) {
          tenantId = int.tryParse('${tenantData['id']}');
        }
      }

      if (tenantId == null) {
        throw Exception('Tenant created but tenant ID was not returned');
      }

      await dio.post('/leases', data: {
        'tenant_id': tenantId,
        'unit_id': int.parse(selectedUnitId!),
        'start_date': startDateController.text.trim(),
        'rent_amount': rentAmountController.text.trim(),
        'billing_cycle': selectedBillingCycle,
        'due_day': int.parse(dueDayController.text.trim()),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tenant and lease added successfully')),
      );
      Navigator.of(context).pushReplacementNamed('/allTenants');
    } on DioException catch (e) {
      String message = 'Failed to add tenant';

      if (e.response?.data is Map<String, dynamic>) {
        final data = e.response!.data as Map<String, dynamic>;

        if (data['message'] != null) {
          message = data['message'].toString();
        }

        if (data['errors'] is Map<String, dynamic>) {
          final errors = data['errors'] as Map<String, dynamic>;
          if (errors.isNotEmpty) {
            final firstError = errors.values.first;
            if (firstError is List && firstError.isNotEmpty) {
              message = firstError.first.toString();
            }
          }
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    nationalIdController.dispose();
    passwordController.dispose();
    rentAmountController.dispose();
    dueDayController.dispose();
    startDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loadingProperties) {
      return const CommonCard(
        child: SizedBox(
          height: 220,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return CommonCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Tenant Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Tenant Name'),
                validator: (v) =>
                v == null || v.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                validator: (v) =>
                v == null || v.isEmpty ? 'Phone is required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) =>
                v == null || !v.contains('@') ? 'Valid email required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: nationalIdController,
                decoration: const InputDecoration(labelText: 'National ID'),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (v) => v == null || v.length < 8
                    ? 'Password must be at least 8 characters'
                    : null,
              ),

              const SizedBox(height: 28),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Lease Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: selectedPropertyId,
                decoration: const InputDecoration(labelText: 'Assign Property'),
                items: properties.map((property) {
                  return DropdownMenuItem<String>(
                    value: property['id'].toString(),
                    child: Text(property['name']?.toString() ?? 'Unnamed Property'),
                  );
                }).toList(),
                onChanged: (value) async {
                  if (value == null) return;
                  setState(() {
                    selectedPropertyId = value;
                  });
                  await _loadUnitsForProperty(value);
                },
                validator: (v) => v == null ? 'Please select a property' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: selectedUnitId,
                decoration: const InputDecoration(labelText: 'Assign Unit'),
                items: units.map((unit) {
                  return DropdownMenuItem<String>(
                    value: unit['id'].toString(),
                    child: Text(
                      '${unit['unit_number'] ?? 'Unit'} (${unit['status'] ?? 'unknown'})',
                    ),
                  );
                }).toList(),
                onChanged: loadingUnits
                    ? null
                    : (value) {
                  setState(() {
                    selectedUnitId = value;
                  });
                },
                validator: (v) => v == null ? 'Please select a unit' : null,
              ),
              if (loadingUnits) ...[
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Loading units...'),
                ),
              ],
              const SizedBox(height: 16),

              TextFormField(
                controller: startDateController,
                decoration: const InputDecoration(
                  labelText: 'Lease Start Date',
                  hintText: 'YYYY-MM-DD',
                ),
                validator: (v) =>
                v == null || v.isEmpty ? 'Start date is required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: rentAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Rent Amount'),
                validator: (v) =>
                v == null || v.isEmpty ? 'Rent amount is required' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: selectedBillingCycle,
                decoration: const InputDecoration(labelText: 'Billing Cycle'),
                items: const [
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
                  DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedBillingCycle = value;
                  });
                },
                validator: (v) => v == null ? 'Please select billing cycle' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: dueDayController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Recurring Payment Day',
                  hintText: 'Enter a day between 1 and 31',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Recurring payment day is required';
                  }

                  final day = int.tryParse(v);
                  if (day == null || day < 1 || day > 31) {
                    return 'Enter a valid day between 1 and 31';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 8),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Example: 1 means invoicing happens every 1st day of the month.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: loading ? null : submit,
                child: Text(loading ? 'Saving...' : 'Add Tenant'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}