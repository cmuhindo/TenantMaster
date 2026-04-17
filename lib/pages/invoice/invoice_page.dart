import 'package:dio/dio.dart';
import 'package:flareline/pages/layout.dart';
import 'package:flareline_uikit/components/card/common_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

class InvoicePage extends LayoutWidget {
  const InvoicePage({super.key});

  Future<Dio> _dio() async {
    const storage = FlutterSecureStorage();
    final token = kIsWeb ? null : await storage.read(key: 'auth_token');

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

  Future<List<Map<String, dynamic>>> _fetchInvoices() async {
    final dio = await _dio();
    final response = await dio.get('/invoices');
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

  Future<Map<String, dynamic>> _fetchInvoiceDetails(int invoiceId) async {
    final dio = await _dio();
    final response = await dio.get('/invoices/$invoiceId');
    final raw = response.data;

    if (raw is Map<String, dynamic> && raw['data'] is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw['data']);
    }

    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }

    return {};
  }

  Future<void> _sendInvoice(BuildContext context, int invoiceId) async {
    try {
      final dio = await _dio();
      final response = await dio.post('/invoices/$invoiceId/send');

      String message = 'Invoice sent successfully';
      if (response.data is Map<String, dynamic> &&
          response.data['message'] != null) {
        message = response.data['message'].toString();
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on DioException catch (e) {
      String message = 'Failed to send invoice';
      if (e.response?.data is Map<String, dynamic>) {
        final data = e.response!.data as Map<String, dynamic>;
        if (data['message'] != null) {
          message = data['message'].toString();
        }
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _downloadInvoice(BuildContext context, int invoiceId) async {
    try {
      final url = Uri.parse('https://rentcom.net/api/invoices/$invoiceId/download');
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open invoice download')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  Future<void> _showInvoiceDialog(BuildContext context, int invoiceId) async {
    showDialog(
      context: context,
      builder: (_) => FutureBuilder<Map<String, dynamic>>(
        future: _fetchInvoiceDetails(invoiceId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AlertDialog(
              content: SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          if (snapshot.hasError) {
            return AlertDialog(
              title: const Text('Invoice Details'),
              content: Text('Failed to load invoice: ${snapshot.error}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          }

          final invoice = snapshot.data ?? {};
          final lease = invoice['lease'] as Map<String, dynamic>?;
          final tenant = lease?['tenant'] as Map<String, dynamic>?;
          final unit = lease?['unit'] as Map<String, dynamic>?;
          final property = unit?['property'] as Map<String, dynamic>?;

          return AlertDialog(
            title: Text('Invoice #${invoice['id'] ?? invoiceId}'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('Tenant', '${tenant?['name'] ?? '-'}'),
                  _detailRow('Email', '${tenant?['email'] ?? '-'}'),
                  _detailRow('Property', '${property?['name'] ?? '-'}'),
                  _detailRow('Unit', '${unit?['unit_number'] ?? '-'}'),
                  _detailRow('Invoice Date', '${invoice['invoice_date'] ?? '-'}'),
                  _detailRow('Due Date', '${invoice['due_date'] ?? '-'}'),
                  _detailRow('Total Amount', 'UGX ${invoice['total_amount'] ?? 0}'),
                  _detailRow('Amount Paid', 'UGX ${invoice['amount_paid'] ?? 0}'),
                  _detailRow('Balance', 'UGX ${invoice['balance'] ?? 0}'),
                  _detailRow('Status', '${invoice['status'] ?? '-'}'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, String value) {
    return CommonCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'partial':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      case 'pending':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget contentDesktopWidget(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchInvoices(),
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
                'Failed to load invoices: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final invoices = snapshot.data ?? [];

        final pendingCount = invoices.where((i) =>
        (i['status'] ?? '').toString().toLowerCase() == 'pending').length;
        final paidCount = invoices.where((i) =>
        (i['status'] ?? '').toString().toLowerCase() == 'paid').length;
        final overdueCount = invoices.where((i) =>
        (i['status'] ?? '').toString().toLowerCase() == 'overdue').length;

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: _summaryCard('Total Invoices', invoices.length.toString())),
                const SizedBox(width: 16),
                Expanded(child: _summaryCard('Pending', pendingCount.toString())),
                const SizedBox(width: 16),
                Expanded(child: _summaryCard('Paid', paidCount.toString())),
                const SizedBox(width: 16),
                Expanded(child: _summaryCard('Overdue', overdueCount.toString())),
              ],
            ),
            const SizedBox(height: 16),
            CommonCard(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(label: Text('ID')),
                    DataColumn(label: Text('Tenant')),
                    DataColumn(label: Text('Property')),
                    DataColumn(label: Text('Invoice Date')),
                    DataColumn(label: Text('Due Date')),
                    DataColumn(label: Text('Total')),
                    DataColumn(label: Text('Paid')),
                    DataColumn(label: Text('Balance')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: invoices.map((invoice) {
                    final lease = invoice['lease'] as Map<String, dynamic>?;
                    final tenant = lease?['tenant'] as Map<String, dynamic>?;
                    final unit = lease?['unit'] as Map<String, dynamic>?;
                    final property = unit?['property'] as Map<String, dynamic>?;
                    final invoiceId = int.tryParse('${invoice['id']}') ?? 0;
                    final status = '${invoice['status'] ?? '-'}';

                    return DataRow(
                      cells: [
                        DataCell(Text('${invoice['id'] ?? ''}')),
                        DataCell(Text('${tenant?['name'] ?? '-'}')),
                        DataCell(Text('${property?['name'] ?? '-'}')),
                        DataCell(Text('${invoice['invoice_date'] ?? '-'}')),
                        DataCell(Text('${invoice['due_date'] ?? '-'}')),
                        DataCell(Text('UGX ${invoice['total_amount'] ?? 0}')),
                        DataCell(Text('UGX ${invoice['amount_paid'] ?? 0}')),
                        DataCell(Text('UGX ${invoice['balance'] ?? 0}')),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusColor(status).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: _statusColor(status),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Row(
                            children: [
                              TextButton(
                                onPressed: invoiceId == 0
                                    ? null
                                    : () => _showInvoiceDialog(context, invoiceId),
                                child: const Text('Show'),
                              ),
                              TextButton(
                                onPressed: invoiceId == 0
                                    ? null
                                    : () => _downloadInvoice(context, invoiceId),
                                child: const Text('Download'),
                              ),
                              TextButton(
                                onPressed: invoiceId == 0
                                    ? null
                                    : () => _sendInvoice(context, invoiceId),
                                child: const Text('Send'),
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

  @override
  String breakTabTitle(BuildContext context) => 'Invoices';
}