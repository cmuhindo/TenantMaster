import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flareline/pages/layout.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart';

class HmkBookingPage extends LayoutWidget {
  const HmkBookingPage({super.key});

  @override
  Widget contentDesktopWidget(BuildContext context) {
    return const HmkBookingFullScreenPage();
  }

  @override
  Widget contentMobileWidget(BuildContext context) {
    return const HmkBookingFullScreenPage();
  }

  @override
  String breakTabTitle(BuildContext context) => 'HMK Booking';
}

class HmkBookingFullScreenPage extends StatefulWidget {
  const HmkBookingFullScreenPage({super.key});

  @override
  State<HmkBookingFullScreenPage> createState() => _HmkBookingFullScreenPageState();
}

class _HmkBookingFullScreenPageState extends State<HmkBookingFullScreenPage> {
  final windowsController = WebviewController();
  WebViewController? androidController;

  bool loading = true;
  String? error;
  String? currentUrl;

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

        await windowsController.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
        await windowsController.loadUrl(url);

        windowsController.url.listen((url) {
          currentUrl = url;
        });

        windowsController.loadingState.listen((state) {
          if (mounted && state == LoadingState.navigationCompleted) {
            setState(() => loading = false);
          }
        });

        if (mounted) {
          setState(() {
            currentUrl = url;
          });
        }
      } else {
        final webController = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (url) {
                currentUrl = url;
                if (mounted) setState(() => loading = true);
              },
              onPageFinished: (url) {
                currentUrl = url;
                if (mounted) setState(() => loading = false);
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

        if (mounted) {
          setState(() {
            androidController = webController;
            currentUrl = url;
          });
        }
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

  Future<void> _goBack() async {
    if (!kIsWeb && Platform.isWindows) {
      try {
        await windowsController.goBack();
      } catch (_) {
        if (mounted) Navigator.of(context).pop();
      }
      return;
    }

    if (androidController != null) {
      final canGoBack = await androidController!.canGoBack();
      if (canGoBack) {
        await androidController!.goBack();
      } else if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _refresh() async {
    if (!kIsWeb && Platform.isWindows) {
      await windowsController.reload();
      return;
    }

    await androidController?.reload();
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
    final fullHeight = MediaQuery.of(context).size.height;

    return SizedBox(
      height: fullHeight,
      width: double.infinity,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('HMK Booking'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBack,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refresh,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        body: error != null
            ? Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Failed to open HMK Booking:\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        )
            : Stack(
          children: [
            Positioned.fill(
              child: _buildWebView(),
            ),
            if (loading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebView() {
    if (!kIsWeb && Platform.isWindows) {
      return Listener(
        onPointerSignal: (event) {
          // Windows WebView should handle mouse wheel internally.
          // This Listener helps prevent parent widgets from stealing scroll focus.
        },
        child: Webview(windowsController),
      );
    }

    if (androidController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return WebViewWidget(
      controller: androidController!,
      gestureRecognizers: {
        Factory<VerticalDragGestureRecognizer>(
              () => VerticalDragGestureRecognizer(),
        ),
        Factory<HorizontalDragGestureRecognizer>(
              () => HorizontalDragGestureRecognizer(),
        ),
        Factory<ScaleGestureRecognizer>(
              () => ScaleGestureRecognizer(),
        ),
      },
    );
  }
}