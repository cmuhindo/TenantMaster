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

  bool loading = false;

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    try {
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

      await dio.post('/tenants', data: {
        'name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'email': emailController.text.trim(),
        'national_id': nationalIdController.text.trim().isEmpty
            ? null
            : nationalIdController.text.trim(),
        'password': passwordController.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tenant added successfully')),
      );
      Navigator.of(context).pushReplacementNamed('/allTenants');
    } on DioException catch (e) {
      String message = 'Failed to add tenant';
      if (e.response?.data is Map<String, dynamic>) {
        final data = e.response!.data as Map<String, dynamic>;
        if (data['message'] != null) {
          message = data['message'].toString();
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CommonCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                validator: (v) => v == null || v.isEmpty ? 'Phone is required' : null,
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
                validator: (v) =>
                v == null || v.length < 8 ? 'Password must be at least 8 characters' : null,
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