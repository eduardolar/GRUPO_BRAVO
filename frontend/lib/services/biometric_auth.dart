import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

class InicioSesionBiometrico {
  final LocalAuthentication auth = LocalAuthentication();
  
  BuildContext? get context => null;
  
  Future<AuthProvider?> authenticarBiometrico() async {
    // Se compruba que el dispositivo soporta la autenticación biométrica
    final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
    final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();
    final storage = FlutterSecureStorage();
    const _kToken = 'token_memoria';

    if (!canAuthenticate) return null; // Si el dispositivo no soporta biometría, se cancela



    try {
      String? token = await storage.read(key:_kToken); // lee el alamacenamiento seguro en busca del token de autenticación guardado en memoria

      if (token == null) {
        return null; // Si no hay token guardado, se cancela la autenticación biométrica
      }

      final bool didAutenticate = await auth.authenticate(localizedReason: 'Inicia sesión con biometría', biometricOnly: true); // Se hace la autenticación biométrica solo meidante huella o rostro

      if (didAutenticate) {

        final authProvider = Provider.of<AuthProvider>(context!, listen: false);
        await authProvider.cargarSesion(token);
        SnackBar(content: Text('Autenticación biométrica exitosa'));
        return authProvider;
      } 
      
    } catch (e) {
      SnackBar(content: Text('Error al autenticar con biometría: $e'));
    }
    return null;
  }
}