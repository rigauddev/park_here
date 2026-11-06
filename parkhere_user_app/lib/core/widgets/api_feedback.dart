import 'package:flutter/material.dart';
import '../i18n/app_localizations.dart';

/// Center-screen feedback for actionable API responses.
class ApiFeedback {
  ApiFeedback._();

  static final navigatorKey = GlobalKey<NavigatorState>();

  static Future<void> show(
    BuildContext context,
    String message, {
    bool isError = true,
    String? title,
  }) async {
    if (!context.mounted || message.trim().isEmpty) return;
    final en = context.strings.isEnglish;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          isError ? Icons.error_outline_rounded : Icons.check_circle_outline,
          color: isError
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primary,
          size: 34,
        ),
        title: title == null ? null : Text(title, textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(en ? 'Got it' : 'Entendi'),
          ),
        ],
      ),
    );
  }

  static Future<void> showSessionExpired() async {
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    await show(
      context,
      context.strings.isEnglish
          ? 'Your session expired. Sign in again to continue.'
          : 'Sua sessão expirou. Entre novamente para continuar.',
      title: context.strings.isEnglish ? 'Session expired' : 'Sessão encerrada',
    );
  }
}
