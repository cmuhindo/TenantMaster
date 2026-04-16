import 'package:dio/dio.dart';
import 'package:flareline/pages/layout.dart';
import 'package:flareline_uikit/components/card/common_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AddPaymentPage extends LayoutWidget {
  const AddPaymentPage({super.key});

  @override
  Widget contentDesktopWidget(BuildContext context) {
    return const AddPaymentForm();
  }

  @override
  String breakTabTitle(BuildContext context) => 'Add Payment';
}

class AddPaymentForm extends StatefulWidget {
  const AddPaymentForm({super.key});

  @override
  State<AddPaymentForm> createState() => _AddPaymentFormState();
}

class _AddPaymentFormState extends State<AddPaymentForm> {
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> invoices = [];
  bool loadingInvoices = true;
  bool saving = false;

  String? selectedInvoiceId;
  final amountController = TextEditingController();
  final methodController = TextEditingController();
  final referenceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchInvoices();
  }

  Future<void> fetchInvoices() async {
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

      final response = await dio.get('/invoices');
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
        invoices = fetched;
        loadingInvoices = false;
      });
    } catch (_) {
      setState(() => loadingInvoices = false);
    }
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => saving = true);

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

      await dio.post('/payments', data: {
        'invoice_id': selectedInvoiceId,
        'amount': amountController.text.trim(),
        'payment_method': methodController.text.trim(),
        'reference': referenceController.text.trim().isEmpty
            ? null
            : referenceController.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment added successfully')),
      );
      Navigator.of(context).pushReplacementNamed('/payments');
    } on DioException catch (e) {
      String message = 'Failed to add payment';
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
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loadingInvoices) {
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
              DropdownButtonFormField<String>(
                value: selectedInvoiceId,
                decoration: const InputDecoration(labelText: 'Invoice'),
                items: invoices.map((invoice) {
                  return DropdownMenuItem<String>(
                    value: invoice['id'].toString(),
                    child: Text(
                      'Invoice #${invoice['id']} - Balance: ${invoice['balance'] ?? invoice['total_amount'] ?? 0}',
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedInvoiceId = value;
                    final selected = invoices.firstWhere(
                          (e) => e['id'].toString() == value,
                      orElse: () => {},
                    );
                    if (selected.isNotEmpty) {
                      amountController.text =
                          (selected['balance'] ?? selected['total_amount'] ?? '').toString();
                    }
                  });
                },
                validator: (v) => v == null ? 'Select an invoice' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Amount'),
                validator: (v) => v == null || v.isEmpty ? 'Amount is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: methodController,
                decoration: const InputDecoration(labelText: 'Payment Method'),
                validator: (v) =>
                v == null || v.isEmpty ? 'Payment method is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: referenceController,
                decoration: const InputDecoration(labelText: 'Reference'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: saving ? null : submit,
                child: Text(saving ? 'Saving...' : 'Add Payment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}