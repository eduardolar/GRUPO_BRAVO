import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/colors_style.dart';
import '../../models/usuario_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/usuario_service.dart';

class AdminUsuariosScreen extends StatefulWidget {
  const AdminUsuariosScreen({super.key});

  @override
  State<AdminUsuariosScreen> createState() => _AdminUsuariosScreenState();
}

class _AdminUsuariosScreenState extends State<AdminUsuariosScreen> {
  List<Usuario> _usuarios = [];
  bool _cargando = true; // Empieza en true para mostrar la carga inicial

  final UsuarioService _usuarioService = UsuarioService();

  @override
  void initState() {
    super.initState();
    // Cargamos todos los usuarios automáticamente al abrir la pantalla
    _cargarUsuarios();
  }

  Future<void> _cargarUsuarios() async {
    setState(() {
      _cargando = true;
    });
    // Capturamos antes del await: usar context tras async gap está prohibido.
    final miRestaurante = context
        .read<AuthProvider>()
        .usuarioActual
        ?.restauranteId;
    try {
      final todos = await _usuarioService.obtenerTodos();
      if (!mounted) return;
      // Restringimos al restaurante del administrador actual: nunca debe ver
      // empleados ni clientes de otras sucursales.
      setState(() {
        _usuarios = todos.where((u) {
          if (u.rol == RolUsuario.superadministrador) return false;
          if (miRestaurante == null || miRestaurante.isEmpty) return true;
          // Si el usuario no tiene restaurante asignado lo mostramos (legacy);
          // en otro caso debe coincidir con el del admin.
          final r = u.restauranteId;
          if (r == null || r.isEmpty) return true;
          return r == miRestaurante;
        }).toList();
      });
    } catch (_) {
      _showSnackBar("Error al conectar con la base de datos");
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cambiarRol(Usuario usuario, String nuevoRolRaw) async {
    try {
      final exito = await _usuarioService.cambiarRol(usuario.id, nuevoRolRaw);
      if (exito) {
        setState(() {
          final index = _usuarios.indexWhere((u) => u.id == usuario.id);
          if (index != -1) {
            RolUsuario nuevoRolEnum =
                (nuevoRolRaw == 'administrador' || nuevoRolRaw == 'admin')
                ? RolUsuario.administrador
                : RolUsuario.trabajador;

            _usuarios[index] = usuario.copyWith(
              rolRaw: nuevoRolRaw,
              rol: nuevoRolEnum,
            );
          }
        });
        _showSnackBar(
          "Rol actualizado a ${nuevoRolRaw.toUpperCase()}",
          esExito: true,
        );
      }
    } catch (e) {
      _showSnackBar("Error al actualizar en el servidor");
    }
  }

  Future<void> _eliminarUsuario(Usuario usuario) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          "¿Eliminar registro?",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Se eliminará a ${usuario.nombre} del sistema.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              "CANCELAR",
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "ELIMINAR",
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        final exito = await _usuarioService.eliminarUsuario(usuario.id);
        if (exito) {
          setState(() => _usuarios.removeWhere((u) => u.id == usuario.id));
          _showSnackBar("Usuario eliminado con éxito", esExito: true);
        }
      } catch (e) {
        _showSnackBar("Error al eliminar");
      }
    }
  }

  void _showSnackBar(String msj, {bool esExito = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msj,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: esExito ? AppColors.disp : AppColors.button,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "GESTIÓN DE EQUIPO",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/Bravo restaurante.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.5),
                Colors.black.withValues(alpha: 0.95),
              ],
            ),
          ),
          child: SafeArea(
            child: _buildListadoUsuarios(), // Cargamos directamente la lista
          ),
        ),
      ),
    );
  }

  Widget _buildListadoUsuarios() {
    if (_cargando) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.button),
      );
    }

    final trabajadores = _usuarios
        .where((u) => u.rol != RolUsuario.cliente)
        .toList();
    final clientes = _usuarios
        .where((u) => u.rol == RolUsuario.cliente)
        .toList();

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            indicatorColor: AppColors.button,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1,
            ),
            tabs: [
              Tab(text: "TRABAJADORES (${trabajadores.length})"),
              Tab(text: "CLIENTES (${clientes.length})"),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _seccionLista(trabajadores, esTrabajador: true),
                _seccionLista(clientes, esTrabajador: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _seccionLista(List<Usuario> lista, {required bool esTrabajador}) {
    if (lista.isEmpty) {
      return const Center(
        child: Text(
          "Sin registros disponibles",
          style: TextStyle(color: Colors.white38, fontSize: 16),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: lista.length,
      itemBuilder: (context, index) =>
          _usuarioGlassCard(lista[index], esTrabajador),
    );
  }

  Widget _usuarioGlassCard(Usuario usuario, bool esTrabajador) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.button,
          child: Text(
            usuario.nombre.isNotEmpty ? usuario.nombre[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          usuario.nombre,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              esTrabajador ? usuario.rolRaw.toUpperCase() : "CLIENTE",
              style: const TextStyle(
                color: AppColors.button,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              usuario.email.isNotEmpty ? usuario.email : 'Sin correo',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: esTrabajador
            ? _botonCambiarRol(usuario)
            : IconButton(
                icon: const Icon(Icons.delete_forever, color: AppColors.error),
                onPressed: () => _eliminarUsuario(usuario),
              ),
      ),
    );
  }

  Widget _botonCambiarRol(Usuario usuario) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.manage_accounts, color: Colors.white, size: 28),
      color: const Color(0xFF222222),
      onSelected: (nuevoRolRaw) => _cambiarRol(usuario, nuevoRolRaw),
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'administrador',
          child: Text("Administrador", style: TextStyle(color: Colors.white)),
        ),
        const PopupMenuItem(
          value: 'cocinero',
          child: Text("Cocinero", style: TextStyle(color: Colors.white)),
        ),
        const PopupMenuItem(
          value: 'mesero',
          child: Text("Mesero", style: TextStyle(color: Colors.white)),
        ),
        const PopupMenuItem(
          value: 'camarero',
          child: Text("Camarero", style: TextStyle(color: Colors.white)),
        ),
        const PopupMenuItem(
          value: 'trabajador',
          child: Text(
            "Trabajador Genérico",
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
