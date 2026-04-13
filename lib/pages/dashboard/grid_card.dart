import 'package:dio/dio.dart';
import 'package:flareline/core/theme/global_colors.dart';
import 'package:flutter/material.dart';
import 'package:flareline_uikit/components/card/common_card.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:responsive_builder/responsive_builder.dart';

class GridCard extends StatelessWidget {
  const GridCard({super.key});

  Future<Map<String, dynamic>> _fetchDashboardData() async {
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

    final response = await dio.get('/reports/dashboard');
    return Map<String, dynamic>.from(response.data);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchDashboardData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ScreenTypeLayout.builder(
            desktop: (_) => _loadingDesktopWidget(),
            mobile: (_) => _loadingMobileWidget(),
            tablet: (_) => _loadingMobileWidget(),
          );
        }

        if (snapshot.hasError) {
          return CommonCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Failed to load dashboard data: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final data = snapshot.data ?? {};
        final totalTenants = (data['total_tenants'] ?? 0).toString();
        final totalRevenue = _formatCurrency(data['total_revenue']);
        final overdueInvoices = (data['overdue_invoices'] ?? 0).toString();
        final outstandingBalance = _formatCurrency(data['outstanding_balance']);

        return ScreenTypeLayout.builder(
          desktop: (_) => contentDesktopWidget(
            context,
            totalTenants: totalTenants,
            totalRevenue: totalRevenue,
            overdueInvoices: overdueInvoices,
            outstandingBalance: outstandingBalance,
          ),
          mobile: (_) => contentMobileWidget(
            context,
            totalTenants: totalTenants,
            totalRevenue: totalRevenue,
            overdueInvoices: overdueInvoices,
            outstandingBalance: outstandingBalance,
          ),
          tablet: (_) => contentMobileWidget(
            context,
            totalTenants: totalTenants,
            totalRevenue: totalRevenue,
            overdueInvoices: overdueInvoices,
            outstandingBalance: outstandingBalance,
          ),
        );
      },
    );
  }

  Widget contentDesktopWidget(
      BuildContext context, {
        required String totalTenants,
        required String totalRevenue,
        required String overdueInvoices,
        required String outstandingBalance,
      }) {
    return Row(
      children: [
        Expanded(
          child: _itemCardWidget(
            context,
            Icons.people,
            totalTenants,
            'Total Tenants',
            '',
            true,
            showTrend: false,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _itemCardWidget(
            context,
            Icons.attach_money,
            totalRevenue,
            'Total Revenue',
            '',
            true,
            showTrend: false,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _itemCardWidget(
            context,
            Icons.warning_amber_rounded,
            overdueInvoices,
            'Overdue Invoices',
            '',
            false,
            showTrend: false,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _itemCardWidget(
            context,
            Icons.account_balance_wallet_outlined,
            outstandingBalance,
            'Outstanding Balance',
            '',
            false,
            showTrend: false,
          ),
        ),
      ],
    );
  }

  Widget contentMobileWidget(
      BuildContext context, {
        required String totalTenants,
        required String totalRevenue,
        required String overdueInvoices,
        required String outstandingBalance,
      }) {
    return Column(
      children: [
        _itemCardWidget(
          context,
          Icons.people,
          totalTenants,
          'Total Tenants',
          '',
          true,
          showTrend: false,
        ),
        const SizedBox(height: 16),
        _itemCardWidget(
          context,
          Icons.attach_money,
          totalRevenue,
          'Total Revenue',
          '',
          true,
          showTrend: false,
        ),
        const SizedBox(height: 16),
        _itemCardWidget(
          context,
          Icons.warning_amber_rounded,
          overdueInvoices,
          'Overdue Invoices',
          '',
          false,
          showTrend: false,
        ),
        const SizedBox(height: 16),
        _itemCardWidget(
          context,
          Icons.account_balance_wallet_outlined,
          outstandingBalance,
          'Outstanding Balance',
          '',
          false,
          showTrend: false,
        ),
      ],
    );
  }

  Widget _loadingDesktopWidget() {
    return Row(
      children: List.generate(
        4,
            (index) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 3 ? 0 : 16),
            child: const CommonCard(
              height: 166,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loadingMobileWidget() {
    return Column(
      children: List.generate(
        4,
            (index) => const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: CommonCard(
            height: 166,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }

  Widget _itemCardWidget(
      BuildContext context,
      IconData icons,
      String text,
      String subTitle,
      String percentText,
      bool isGrow, {
        bool showTrend = true,
      }) {
    return CommonCard(
      height: 166,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipOval(
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                color: Colors.grey.shade200,
                child: Icon(
                  icons,
                  color: GlobalColors.sideBar,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              text,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    subTitle,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
                if (showTrend) ...[
                  Text(
                    percentText,
                    style: TextStyle(
                      fontSize: 10,
                      color: isGrow ? Colors.green : Colors.lightBlue,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    isGrow ? Icons.arrow_upward : Icons.arrow_downward,
                    color: isGrow ? Colors.green : Colors.lightBlue,
                    size: 12,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(dynamic value) {
    final number = double.tryParse(value.toString()) ?? 0;
    return 'UGX ${number.toStringAsFixed(0)}';
  }
}