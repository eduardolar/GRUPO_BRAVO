import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/http_client.dart';
import 'colors_style.dart';

// Duración estándar para mensajes de error/éxito
const _kDuration = Duration(seconds: 4);

void showAppError(
  BuildContext context,
  String message, {
  double bottomMargin = 16,
}) {
  _show(context, message, AppColors.error, bottomMargin: bottomMargin);
}

void showAppSuccess(
  BuildContext context,
  String message, {
  double bottomMargin = 16,
}) {
  _show(context, message, AppColors.disp, bottomMargin: bottomMargin);
}

void showAppInfo(
  BuildContext context,
  String message, {
  double bottomMargin = 16,
  SnackBarAction? action,
}) {
  _show(
    context,
    message,
    AppColors.button,
    bottomMargin: bottomMargin,
    action: action,
  );
}

/// Convierte cualquier excepción en un mensaje legible para el usuario y la
/// muestra como SnackBar. En modo debug deja un `debugPrint` con el detalle
/// técnico para diagnóstico.
///
/// Sustituye al patrón anti-UX `try { ... } catch (e) { debugPrint(...) }`
/// que dejaba al usuario sin feedback de qué había pasado.
void handleApiError(BuildContext context, Object error, {String? prefix}) {
  final mensaje = _mensajeUsuario(error);
  final completo = prefix != null && prefix.isNotEmpty
      ? '$prefix: $mensaje'
      : mensaje;
  if (kDebugMode) debugPrint('handleApiError: $error');
  if (context.mounted) showAppError(context, completo);
}

String _mensajeUsuario(Object error) {
  if (error is ApiException) return error.message;
  // Excepciones de red habituales:
  final raw = error.toString();
  if (raw.contains('SocketException')) return 'Sin conexión a internet';
  if (raw.contains('TimeoutException')) return 'El servidor tardó demasiado';
  if (raw.contains('FormatException')) return 'Respuesta del servidor inválida';
  return 'Ocurrió un error inesperado';
}

void _show(
  BuildContext context,
  String message,
  Color backgroundColor, {
  double bottomMargin = 16,
  SnackBarAction? action,
}) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.fromLTRB(16, 0, 16, bottomMargin),
        duration: _kDuration,
        action: action,
      ),
    );
}
