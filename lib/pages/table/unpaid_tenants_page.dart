import 'package:dio/dio.dart';
import 'package:flareline/pages/layout.dart';
import 'package:flareline_uikit/components/card/common_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UnpaidTenantsPage extends LayoutWidget {
  const UnpaidTenantsPage({super.key});

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
      tenants = (raw['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } else if (raw is List) {
      tenants = raw.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    return tenants.where(_isUnpaidTenant).toList();
  }

  bool _isUnpaidTenant(Map<String, dynamic> tenant) {
    final leases = tenant['leases'];
    if (leases is List && leases.isNotEmpty) {
      return leases.any((lease) {
        if (lease is Map<String, dynamic>) {
          final status = (lease['status'] ?? '').toString().toLowerCase();
          final balance = double.tryParse((lease['balance'] ?? '0').toString()) ?? 0;
          return status.contains('unpaid') || balance > 0;
        }
        return false;
      });
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
                'Failed to load unpaid tenants: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final tenants = snapshot.data ?? [];

        if (tenants.isEmpty) {
          return const CommonCard(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('No unpaid tenants found')),
            ),
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: _summaryCard('Unpaid Tenants', tenants.length.toString())),
              ],
            ),
            const SizedBox(height: 16),
            _tenantTable(tenants),
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

  Widget _tenantTable(List<Map<String, dynamic>> tenants) {
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
  }

  @override
  String breakTabTitle(BuildContext context) => 'Unpaid Tenants';
}