import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flareline/pages/layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart';

class HmkBookingPage extends LayoutWidget {
  const HmkBookingPage({super.key});

  @override
  Widget contentDesktopWidget(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height - 140,
      width: double.infinity,
      child: const HmkBookingWebView(),
    );
  }

  @override
  String breakTabTitle(BuildContext context) => 'HMK Booking';
}

class HmkBookingWebView extends StatefulWidget {
  const HmkBookingWebView({super.key});

  @override
  State<HmkBookingWebView> createState() => _HmkBookingWebViewState();
}

class _HmkBookingWebViewState extends State<HmkBookingWebView> {
  final windowsController = WebviewController();
  WebViewController? androidController;

  bool loading = true;
  String? error;

  Future<String> _getAutoLoginUrl() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'auth_token');

    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://smarthotelapp.net/api',
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );

    final response = await dio.get('/hmk/auto-login-url');
    return response.data['url'].toString();
  }

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    try {
      final url = await _getAutoLoginUrl();

      if (Platform.isWindows) {
        await windowsController.initialize();
        await windowsController.loadUrl(url);

        if (mounted) {
          setState(() {
            loading = false;
          });
        }
      } else {
        final webController = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished: (_) {
                if (mounted) {
                  setState(() => loading = false);
                }
              },
              onWebResourceError: (error) {
                if (mounted) {
                  setState(() {
                    this.error = error.description;
                    loading = false;
                  });
                }
              },
            ),
          )
          ..loadRequest(Uri.parse(url));

        setState(() {
          androidController = webController;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    windowsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Center(child: Text('Failed to open HMK Booking: $error'));
    }

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (Platform.isWindows) {
      return Webview(windowsController);
    }

    if (androidController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return WebViewWidget(controller: androidController!);
  }
}