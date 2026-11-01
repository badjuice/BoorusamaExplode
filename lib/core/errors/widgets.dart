// Dart imports:
import 'dart:io';

// Package imports:
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../settings/providers.dart';
import 'error.dart';

bool isNetworkError(Object error) => switch (error) {
  SocketException() || HttpException() => true,
  AppError(type: AppErrorType.cannotReachServer) => true,
  DioException(:final type, :final error) => switch (type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.sendTimeout => true,
    DioExceptionType.unknown => error != null && isNetworkError(error),
    _ => false,
  },
  _ => false,
};

/// A one-line description of [error], fit to show to anyone.
String errorSummary(BuildContext context, Object error) => isNetworkError(error)
    ? context.t.generic.errors.no_connection
    : context.t.generic.errors.unknown;

/// A short error message, followed by the raw error and stack trace when
/// "Show error details" is on.
class ErrorText extends ConsumerWidget {
  const ErrorText({
    required this.error,
    super.key,
    this.stackTrace,
    this.message,
    this.style,
    this.textAlign = TextAlign.center,
  });

  final Object error;
  final StackTrace? stackTrace;

  /// Replaces the generic summary, for example "Failed to load tags".
  final String? message;
  final TextStyle? style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showDetails = ref.watch(
      settingsProvider.select((s) => s.showErrorDetails),
    );
    final summary = isNetworkError(error)
        ? context.t.generic.errors.no_connection
        : message ?? errorSummary(context, error);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(summary, style: style, textAlign: textAlign),
        if (showDetails) ...[
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: SingleChildScrollView(
              child: SelectableText(
                [error.toString(), ?stackTrace?.toString()].join('\n\n'),
                style: Kurumi.themeOf(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
