import 'package:dio/dio.dart';
import 'package:flareline/pages/layout.dart';
import 'package:flareline_uikit/components/card/common_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PaidTenantsPage extends LayoutWidget {
  const PaidTenantsPage({super.key});

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

    List<Map<String, dynamic>> tenants = [];
    if (raw is Map<String, dynamic> && raw['data'] is List) {
      tenants = (raw['data'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } else if (raw is List) {
      tenants = raw.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    return tenants.where(_isPaidTenant).toList();
  }

  bool _isPaidTenant(Map<String, dynamic> tenant) {
    final leases = tenant['leases'];
    if (leases is List && leases.isNotEmpty) {
      final hasUnpaid = leases.any((lease) {
        if (lease is Map<String, dynamic>) {
          final status = (lease['status'] ?? '').toString().toLowerCase();
          final balance = double.tryParse((lease['balance'] ?? '0').toString()) ?? 0;
          return status.contains('unpaid') || balance > 0;
        }
        return false;
      });
      return !hasUnpaid;
    }
    return false;
  }

  @override
  Widget contentDesktopWidget(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchTenants(),
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
                'Failed to load paid tenants: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final tenants = snapshot.data ?? [];

        return CommonCard(
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
              ],
              rows: tenants.map((tenant) {
                return DataRow(
                  cells: [
                    DataCell(Text('${tenant['id'] ?? ''}')),
                    DataCell(Text('${tenant['name'] ?? '-'}')),
                    DataCell(Text('${tenant['email'] ?? '-'}')),
                    DataCell(Text('${tenant['phone'] ?? '-'}')),
                    DataCell(Text('${tenant['national_id'] ?? '-'}')),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  @override
  String breakTabTitle(BuildContext context) => 'Paid Tenants';
}