import 'package:dio/dio.dart';
import 'package:flareline/pages/layout.dart';
import 'package:flareline_uikit/components/card/common_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LeasesPage extends LayoutWidget {
  const LeasesPage({super.key});

  Future<List<Map<String, dynamic>>> _fetchLeases() async {
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

    final response = await dio.get('/leases');
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
      future: _fetchLeases(),
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
                'Failed to load leases: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final leases = snapshot.data ?? [];

        if (leases.isEmpty) {
          return const CommonCard(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('No leases found')),
            ),
          );
        }

        final activeCount = leases.where((lease) {
          return (lease['status'] ?? '').toString().toLowerCase() == 'active';
        }).length;

        final endedCount = leases.where((lease) {
          return (lease['status'] ?? '').toString().toLowerCase() == 'ended';
        }).length;

        final pendingCount = leases.where((lease) {
          return (lease['status'] ?? '').toString().toLowerCase() == 'pending';
        }).length;

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _summaryCard('Total Leases', leases.length.toString()),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _summaryCard('Active', activeCount.toString()),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _summaryCard('Pending', pendingCount.toString()),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _summaryCard('Ended', endedCount.toString()),
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
                    DataColumn(label: Text('Tenant')),
                    DataColumn(label: Text('Property')),
                    DataColumn(label: Text('Unit')),
                    DataColumn(label: Text('Start Date')),
                    DataColumn(label: Text('End Date')),
                    DataColumn(label: Text('Rent Amount')),
                    DataColumn(label: Text('Billing Cycle')),
                    DataColumn(label: Text('Due Day')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: leases.map((lease) {
                    final tenant = lease['tenant'] as Map<String, dynamic>?;
                    final unit = lease['unit'] as Map<String, dynamic>?;
                    final property = unit?['property'] as Map<String, dynamic>?;

                    final status =
                    (lease['status'] ?? '').toString().toLowerCase();

                    return DataRow(
                      cells: [
                        DataCell(Text('${lease['id'] ?? ''}')),
                        DataCell(Text('${tenant?['name'] ?? '-'}')),
                        DataCell(Text('${property?['name'] ?? '-'}')),
                        DataCell(Text('${unit?['unit_number'] ?? '-'}')),
                        DataCell(Text('${lease['start_date'] ?? '-'}')),
                        DataCell(Text('${lease['end_date'] ?? '-'}')),
                        DataCell(Text('UGX ${lease['rent_amount'] ?? 0}')),
                        DataCell(Text('${lease['billing_cycle'] ?? '-'}')),
                        DataCell(Text('${lease['due_day'] ?? '-'}')),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor(status).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status.isEmpty ? '-' : status,
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
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'ended':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  String breakTabTitle(BuildContext context) => 'Leases';
}