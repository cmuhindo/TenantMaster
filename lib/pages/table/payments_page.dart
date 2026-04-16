import 'package:dio/dio.dart';
import 'package:flareline/pages/layout.dart';
import 'package:flareline_uikit/components/card/common_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PaymentsPage extends LayoutWidget {
  const PaymentsPage({super.key});

  Future<List<Map<String, dynamic>>> _fetchPayments() async {
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

    final response = await dio.get('/payments');
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
      future: _fetchPayments(),
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
                'Failed to load payments: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final payments = snapshot.data ?? [];
        final totalAmount = payments.fold<double>(0, (sum, item) {
          return sum + (double.tryParse((item['amount'] ?? '0').toString()) ?? 0);
        });

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: _summaryCard('Total Payments', payments.length.toString())),
                const SizedBox(width: 16),
                Expanded(child: _summaryCard('Amount Collected', 'UGX ${totalAmount.toStringAsFixed(0)}')),
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
                    DataColumn(label: Text('Invoice ID')),
                    DataColumn(label: Text('Amount')),
                    DataColumn(label: Text('Payment Date')),
                    DataColumn(label: Text('Method')),
                    DataColumn(label: Text('Reference')),
                  ],
                  rows: payments.map((payment) {
                    return DataRow(
                      cells: [
                        DataCell(Text('${payment['id'] ?? ''}')),
                        DataCell(Text('${payment['invoice_id'] ?? '-'}')),
                        DataCell(Text('UGX ${payment['amount'] ?? 0}')),
                        DataCell(Text('${payment['payment_date'] ?? '-'}')),
                        DataCell(Text('${payment['payment_method'] ?? '-'}')),
                        DataCell(Text('${payment['reference'] ?? '-'}')),
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

  @override
  String breakTabTitle(BuildContext context) => 'Payments';
}