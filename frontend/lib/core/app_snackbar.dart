import 'package:flutter/material.dart';
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
  _show(context, message, AppColors.button,
      bottomMargin: bottomMargin, action: action);
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
    ..showSnackBar(SnackBar(
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
    ));
}
