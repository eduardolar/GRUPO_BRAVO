import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

class InicioSesionBiometrico {
  final LocalAuthentication auth = LocalAuthentication();
  
  Future<void> authenticarBiometrico() async {
    // Se compruba que el dispositivo soporta la autenticación biométrica
    final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
    final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();

    if (!canAuthenticate) return; // Si el dispositivo no soporta biometría, se cancela

    try {
      final bool didAutenticate = await auth.authenticate(localizedReason: 'Inicia sesión con biometría', biometricOnly: true);

      if (didAutenticate) {
        // Aquí se puede manejar el inicio de sesión exitoso, por ejemplo, navegando a la pantalla principal
        SnackBar(content: Text('Autenticación biométrica exitosa'));
      } 
      
    } catch (e) {
      SnackBar(content: Text('Error al autenticar con biometría: $e'));
    }
  }
}