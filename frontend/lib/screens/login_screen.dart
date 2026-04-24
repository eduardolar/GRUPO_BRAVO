import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // <-- IMPORTANTE: Para leer la sesión
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/screens/Administrador/admin_home_screen.dart'; // Pantalla del Admin
import 'package:frontend/screens/super_admin/seleccionar_restaurante_screen.dart';
import 'package:frontend/screens/cliente/forgotten_password.dart';
import 'package:frontend/screens/cliente/menu_screen.dart'; // Pantalla del Cliente
import 'package:frontend/screens/cliente/register_screen.dart';
import 'package:frontend/components/Cliente/entrada_texto.dart';
import 'package:frontend/providers/auth_provider.dart'; // <-- IMPORTANTE
import 'package:frontend/models/usuario_model.dart'; // <-- IMPORTANTE: Para los roles

class loginScreen extends StatefulWidget {
  const loginScreen({super.key});

  @override
  State<loginScreen> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<loginScreen> {

  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  bool _cargando = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBarLogin(),
      body: bodyLogin(),
    );
  }

  Padding bodyLogin() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 90),
            child: Text(
              "Iniciar sesión",
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
                child: EntradaTexto(
                  etiqueta: "Correo electrónico", 
                  icono: Icons.mail,
                )
              ),
              Padding(
                padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
                child: EntradaTexto(
                  etiqueta: 'Contraseña', 
                  icono: Icons.visibility_off, 
                  esContrasena: true, 
                  mostrarTexto: true,
                )
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ForgottenPassword()));
                },
                child: Text(
                  "¿Has olvidado la contraseña?",
                  style: TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
           Container(
                  height: 55,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.button,
                      foregroundColor: AppColors.background, 
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    // TODO: Conectar esta función al botón de login
                    onPressed: _cargando ? null : () async {
                      setState(() => _cargando = true);

                      // 1. Aquí iría tu llamada real al backend (ej: await authProvider.login(email, pass))
                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      
                      // 2. Miramos quién es el usuario que acaba de entrar
                      final usuario = authProvider.usuarioActual;

                      setState(() => _cargando = false);

                      if (usuario != null) {
                        Widget pantallaDestino;
                        
                        // 3. El semáforo: redirige según el rol
                        switch (usuario.rol) {
                          case RolUsuario.administrador:
                          pantallaDestino = const MenuAdministrador(); 
                            break;
                          case RolUsuario.superadministrador:
                            pantallaDestino = const SeleccionarRestauranteScreen();
                            break;
                          case RolUsuario.trabajador:
                            // Cámbialo por la pantalla real de tus trabajadores
                            pantallaDestino = const MenuScreen(); 
                            break;
                          case RolUsuario.cliente:
                          default:
                            pantallaDestino = const MenuScreen();
                            break;
                        }

                        // Usamos pushReplacement para que no puedan volver al Login dándole atrás
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => pantallaDestino),
                        );
                      } else {
                        // Fallback temporal si no detecta usuario
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const MenuScreen()),
                        );
                      }
                    },
                    child: _cargando 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : const Text(
                      "INICIAR SESIÓN",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  
                ),
          Spacer(),
          Row(
            children: [
              Spacer(),
              Text("¿No tienes cuenta?"),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => RegisterScreen()),  // Direccionar a la pantalla de registro
                  );
                },
                child: Text("Regístrate"),
              ),
              Spacer(),
            ],
          ),
          Spacer(),
          
        ],
      ),
    );
  }

  AppBar appBarLogin() {
    return AppBar(
      backgroundColor: AppColors.panel,
      elevation: 0,
      title: Text("NombreRestaurante", style: TextStyle(color: Colors.black)),
      centerTitle: true,
    );
  }
}