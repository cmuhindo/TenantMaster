import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart';

class HmkBookingPage extends StatefulWidget {
  const HmkBookingPage({super.key});

  @override
  State<HmkBookingPage> createState() => _HmkBookingPageState();
}

class _HmkBookingPageState extends State<HmkBookingPage> {
  final WebviewController windowsController = WebviewController();
  WebViewController? mobileController;

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

      if (!kIsWeb && Platform.isWindows) {
        await windowsController.initialize();

        // Important for dropdowns / popups / dashboard menus
        await windowsController.setPopupWindowPolicy(WebviewPopupWindowPolicy.allow);

        await windowsController.loadUrl(url);

        windowsController.loadingState.listen((state) {
          if (state == LoadingState.navigationCompleted && mounted) {
            setState(() => loading = false);
          }
        });

        setState(() => loading = false);
      } else {
        final controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished: (_) {
                if (mounted) setState(() => loading = false);
              },
              onWebResourceError: (err) {
                if (mounted) {
                  setState(() {
                    error = err.description;
                    loading = false;
                  });
                }
              },
            ),
          )
          ..loadRequest(Uri.parse(url));

        setState(() {
          mobileController = controller;
        });
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> _goBack() async {
    if (!kIsWeb && Platform.isWindows) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    if (mobileController != null) {
      final canGoBack = await mobileController!.canGoBack();
      if (canGoBack) {
        await mobileController!.goBack();
      } else if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    if (!kIsWeb && Platform.isWindows) {
      windowsController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: error != null
          ? Center(child: Text('Failed to open HMK Booking:\n$error'))
          : Stack(
        children: [
          Positioned.fill(child: _buildWebView()),

          Positioned(
            top: 20,
            left: 20,
            child: SafeArea(
              child: FloatingActionButton.small(
                heroTag: 'hmk_back_btn',
                onPressed: _goBack,
                child: const Icon(Icons.arrow_back),
              ),
            ),
          ),

          if (loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildWebView() {
    if (!kIsWeb && Platform.isWindows) {
      return Webview(windowsController);
    }

    if (mobileController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return WebViewWidget(controller: mobileController!);
  }
}