import 'package:dio/dio.dart';
import 'package:flareline_uikit/core/mvvm/base_viewmodel.dart';
import 'package:flareline_uikit/utils/snackbar_util.dart';
import 'package:flutter/material.dart';

class SignInProvider extends BaseViewModel {
  late TextEditingController emailController;
  late TextEditingController passwordController;

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://rentcom.net/api',
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  SignInProvider(BuildContext ctx) : super(ctx) {
    emailController = TextEditingController();
    passwordController = TextEditingController();
  }

  Future<void> signInWithGoogle(BuildContext context) async {
    SnackBarUtil.showSnack(context, 'Sign In With Google');
  }

  Future<void> signInWithGithub(BuildContext context) async {
    SnackBarUtil.showSnack(context, 'Sign In With Github');
  }

  Future<void> signIn(BuildContext context) async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      SnackBarUtil.showSnack(context, 'Please enter a valid email address');
      return;
    }

    if (password.isEmpty || password.length < 6) {
      SnackBarUtil.showSnack(context, 'Please enter a valid password');
      return;
    }

    try {
      final response = await _dio.post(
        '/login',
        data: {
          'email': email,
          'password': password,
          'device_name': 'flutter_app',
        },
      );

      final statusCode = response.statusCode ?? 0;
      final data = response.data;

      if (statusCode == 200 && data is Map<String, dynamic>) {
        final token = data['token'];
        final user = data['user'];

        if (token == null || user == null) {
          SnackBarUtil.showSnack(context, 'Invalid server response');
          return;
        }

        SnackBarUtil.showSnack(context, 'Login successful');

        final role = (user['role'] as Map<String, dynamic>?)?['name']
            ?.toString()
            .toLowerCase() ??
            '';

        if (role == 'admin') {
          Navigator.of(context).pushReplacementNamed('/');
        } else if (role == 'tenant') {
          Navigator.of(context).pushReplacementNamed('/tenant-dashboard');
        } else {
          Navigator.of(context).pushReplacementNamed('/');
        }

        return;
      }

      if (statusCode == 422 && data is Map<String, dynamic>) {
        String message = 'Invalid credentials';

        if (data['errors'] is Map<String, dynamic>) {
          final errors = data['errors'] as Map<String, dynamic>;
          if (errors.isNotEmpty) {
            final firstError = errors.values.first;
            if (firstError is List && firstError.isNotEmpty) {
              message = firstError.first.toString();
            }
          }
        } else if (data['message'] != null) {
          message = data['message'].toString();
        }

        SnackBarUtil.showSnack(context, message);
        return;
      }

      if (statusCode == 401) {
        SnackBarUtil.showSnack(context, 'Unauthorized. Please login again.');
        return;
      }

      if (statusCode == 302) {
        SnackBarUtil.showSnack(
          context,
          'Unexpected redirect from server. Check API configuration.',
        );
        return;
      }

      SnackBarUtil.showSnack(
        context,
        'Login failed. Please try again.',
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        SnackBarUtil.showSnack(
          context,
          'Connection timed out. Please try again.',
        );
        return;
      }

      SnackBarUtil.showSnack(
        context,
        'Network error. Please check your internet connection.',
      );
    } catch (e) {
      SnackBarUtil.showSnack(
        context,
        'Unexpected error: $e',
      );
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}