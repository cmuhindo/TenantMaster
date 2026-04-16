import 'package:dio/dio.dart';
import 'package:flareline/pages/layout.dart';
import 'package:flareline_uikit/components/card/common_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class InvoicePaymentsPage extends LayoutWidget {
  const InvoicePaymentsPage({super.key});

  Future<List<Map<String, dynamic>>> _fetchInvoices() async {
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
                'Failed to load invoice payments: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final invoices = snapshot.data ?? [];

        return CommonCard(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 28,
              columns: const [
                DataColumn(label: Text('Invoice ID')),
                DataColumn(label: Text('Lease ID')),
                DataColumn(label: Text('Total Amount')),
                DataColumn(label: Text('Amount Paid')),
                DataColumn(label: Text('Balance')),
                DataColumn(label: Text('Status')),
              ],
              rows: invoices.map((invoice) {
                final status = (invoice['status'] ?? '').toString();

                return DataRow(
                  cells: [
                    DataCell(Text('${invoice['id'] ?? ''}')),
                    DataCell(Text('${invoice['lease_id'] ?? '-'}')),
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
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
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
      default:
        return Colors.grey;
    }
  }

  @override
  String breakTabTitle(BuildContext context) => 'Invoice Payments';
}