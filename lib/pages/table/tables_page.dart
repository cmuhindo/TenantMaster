import 'package:dio/dio.dart';
import 'package:flareline/flutter_gen/app_localizations.dart';
import 'package:flareline/pages/layout.dart';
import 'package:flareline_uikit/components/card/common_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TablesPage extends LayoutWidget {
  const TablesPage({super.key});

  Future<List<Map<String, dynamic>>> _fetchProperties() async {
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

    final response = await dio.get('/properties');
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
      future: _fetchProperties(),
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
                'Failed to load properties: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final properties = snapshot.data ?? [];

        if (properties.isEmpty) {
          return const CommonCard(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text('No properties found'),
              ),
            ),
          );
        }

        return Column(
          children: [
            _summaryCards(properties),
            const SizedBox(height: 16),
            SizedBox(
              width: double.maxFinite,
              child: _propertiesTable(properties),
            ),
          ],
        );
      },
    );
  }

  Widget _summaryCards(List<Map<String, dynamic>> properties) {
    final totalProperties = properties.length;

    final totalUnits = properties.fold<int>(
      0,
          (sum, property) {
        final units = property['units'];
        if (units is List) return sum + units.length;
        return sum;
      },
    );

    final vacantUnits = properties.fold<int>(
      0,
          (sum, property) {
        final units = property['units'];
        if (units is List) {
          return sum +
              units.where((u) {
                if (u is Map<String, dynamic>) {
                  return (u['status'] ?? '').toString().toLowerCase() == 'vacant';
                }
                return false;
              }).length;
        }
        return sum;
      },
    );

    final occupiedUnits = properties.fold<int>(
      0,
          (sum, property) {
        final units = property['units'];
        if (units is List) {
          return sum +
              units.where((u) {
                if (u is Map<String, dynamic>) {
                  return (u['status'] ?? '').toString().toLowerCase() == 'occupied';
                }
                return false;
              }).length;
        }
        return sum;
      },
    );

    return Row(
      children: [
        Expanded(
          child: _summaryCard('Total Properties', totalProperties.toString()),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _summaryCard('Total Units', totalUnits.toString()),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _summaryCard('Occupied Units', occupiedUnits.toString()),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _summaryCard('Vacant Units', vacantUnits.toString()),
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

  Widget _propertiesTable(List<Map<String, dynamic>> properties) {
    return CommonCard(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 28,
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Property Name')),
            DataColumn(label: Text('Location')),
            DataColumn(label: Text('Description')),
            DataColumn(label: Text('Units')),
          ],
          rows: properties.map((property) {
            final units = property['units'];
            final unitsCount = units is List ? units.length : 0;

            return DataRow(
              cells: [
                DataCell(Text('${property['id'] ?? ''}')),
                DataCell(Text('${property['name'] ?? ''}')),
                DataCell(Text('${property['location'] ?? ''}')),
                DataCell(
                  SizedBox(
                    width: 250,
                    child: Text(
                      '${property['description'] ?? '-'}',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ),
                DataCell(Text(unitsCount.toString())),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  String breakTabTitle(BuildContext context) {
    return AppLocalizations.of(context)!.tables;
  }
}