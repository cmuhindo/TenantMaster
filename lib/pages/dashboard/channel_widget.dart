import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:responsive_builder/responsive_builder.dart';

class ChannelWidget extends StatelessWidget {
  const ChannelWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return _channels();
  }

  Widget _channels() {
    return ScreenTypeLayout.builder(
      desktop: _channelsWeb,
      mobile: _channelMobile,
      tablet: _channelMobile,
    );
  }

  Widget _channelsWeb(BuildContext context) {
    return const SizedBox(
      height: 450,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TenantListCard(),
          ),
          SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: TenantSummaryCard(),
          ),
        ],
      ),
    );
  }

  Widget _channelMobile(BuildContext context) {
    return const Column(
      children: [
        SizedBox(
          height: 380,
          child: TenantListCard(),
        ),
        SizedBox(height: 16),
        SizedBox(
          height: 260,
          child: TenantSummaryCard(),
        ),
      ],
    );
  }
}

class TenantListCard extends StatelessWidget {
  const TenantListCard({super.key});

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
    final list = (response.data['data'] ?? []) as List<dynamic>;
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchTenants(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Failed to load tenants: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            final tenants = snapshot.data ?? [];

            if (tenants.isEmpty) {
              return const Center(
                child: Text('No tenants found'),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tenant Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: tenants.length,
                    separatorBuilder: (_, __) => const Divider(height: 16),
                    itemBuilder: (context, index) {
                      final tenant = tenants[index];

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade50,
                          child: Text(
                            (tenant['name'] ?? 'T')
                                .toString()
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        title: Text(
                          tenant['name']?.toString() ?? 'No Name',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('Email: ${tenant['email'] ?? '-'}'),
                            Text('Phone: ${tenant['phone'] ?? '-'}'),
                            Text('National ID: ${tenant['national_id'] ?? '-'}'),
                          ],
                        ),
                        isThreeLine: true,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class TenantSummaryCard extends StatelessWidget {
  const TenantSummaryCard({super.key});

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
    final list = (response.data['data'] ?? []) as List<dynamic>;
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchTenants(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(
                child: Text('Unable to load summary'),
              );
            }

            final tenants = snapshot.data ?? [];
            final totalTenants = tenants.length;
            final withEmail = tenants.where((t) =>
            (t['email'] ?? '').toString().trim().isNotEmpty).length;
            final withPhone = tenants.where((t) =>
            (t['phone'] ?? '').toString().trim().isNotEmpty).length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tenant Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _summaryItem('Total Tenants', totalTenants.toString()),
                const SizedBox(height: 16),
                _summaryItem('With Email', withEmail.toString()),
                const SizedBox(height: 16),
                _summaryItem('With Phone', withPhone.toString()),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}