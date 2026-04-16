import 'package:dio/dio.dart';
import 'package:flareline/flutter_gen/app_localizations.dart';
import 'package:flareline/pages/layout.dart';
import 'package:flareline_uikit/components/card/common_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ContactsPage extends LayoutWidget {
  const ContactsPage({super.key});

  Future<List<Map<String, dynamic>>> _fetchUnits() async {
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

    final response = await dio.get('/units');
    final raw = response.data;

    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }

    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    return [];
  }

  @override
  Widget contentDesktopWidget(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchUnits(),
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
                'Failed to load units: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final units = snapshot.data ?? [];

        if (units.isEmpty) {
          return const CommonCard(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text('No units found'),
              ),
            ),
          );
        }

        return Column(
          children: [
            _summaryCards(units),
            const SizedBox(height: 16),
            SizedBox(
              width: double.maxFinite,
              child: _unitsTable(units),
            ),
          ],
        );
      },
    );
  }

  Widget _summaryCards(List<Map<String, dynamic>> units) {
    final totalUnits = units.length;

    final occupiedUnits = units.where((unit) {
      return (unit['status'] ?? '').toString().toLowerCase() == 'occupied';
    }).length;

    final vacantUnits = units.where((unit) {
      return (unit['status'] ?? '').toString().toLowerCase() == 'vacant';
    }).length;

    final maintenanceUnits = units.where((unit) {
      return (unit['status'] ?? '').toString().toLowerCase() == 'maintenance';
    }).length;

    return Row(
      children: [
        Expanded(
          child: _summaryCard('Total Units', totalUnits.toString()),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _summaryCard('Occupied', occupiedUnits.toString()),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _summaryCard('Vacant', vacantUnits.toString()),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _summaryCard('Maintenance', maintenanceUnits.toString()),
        ),
      ],
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

  Widget _unitsTable(List<Map<String, dynamic>> units) {
    return CommonCard(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 28,
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Unit Number')),
            DataColumn(label: Text('Property')),
            DataColumn(label: Text('Rent Amount')),
            DataColumn(label: Text('Status')),
          ],
          rows: units.map((unit) {
            final property = unit['property'] as Map<String, dynamic>?;

            return DataRow(
              cells: [
                DataCell(Text('${unit['id'] ?? ''}')),
                DataCell(Text('${unit['unit_number'] ?? ''}')),
                DataCell(Text('${property?['name'] ?? '-'}')),
                DataCell(Text('UGX ${unit['rent_amount'] ?? 0}')),
                DataCell(
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(
                        (unit['status'] ?? '').toString(),
                      ).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${unit['status'] ?? '-'}',
                      style: TextStyle(
                        color: _statusColor(
                          (unit['status'] ?? '').toString(),
                        ),
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
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'occupied':
        return Colors.green;
      case 'vacant':
        return Colors.orange;
      case 'maintenance':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  String breakTabTitle(BuildContext context) {
    return AppLocalizations.of(context)!.tables;
  }
}