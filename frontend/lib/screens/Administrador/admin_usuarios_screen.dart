import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/models/usuario_model.dart';
import 'package:frontend/services/usuario_service.dart';

class AdminUsuariosScreen extends StatefulWidget {
  const AdminUsuariosScreen({super.key});

  @override
  State<AdminUsuariosScreen> createState() => _AdminUsuariosScreenState();
}

class _AdminUsuariosScreenState extends State<AdminUsuariosScreen> {
  String? _sucursalSeleccionada;
  List<Usuario> _usuarios = [];
  bool _cargando = false;

  final UsuarioService _usuarioService = UsuarioService();

  final Map<String, String> _idsSucursales = {
    'MADRID': '69de6289c4e3ea3a8c771e6d',
    'ZARAGOZA': '69de62a5c4e3ea3a8c771e6f',
  };

  Future<void> _cargarUsuarios(String idRestauranteMongo) async {
    setState(() {
      _cargando = true;
      _usuarios = [];
    });
    try {
      final todos = await _usuarioService.obtenerTodos();
      setState(() {
        _usuarios = todos.where((u) => 
          u.restauranteId == idRestauranteMongo && 
          u.rol != RolUsuario.superadministrador
        ).toList();
      });
    } catch (e) {
      _showSnackBar("Error al conectar con la base de datos");
    } finally {
      setState(() => _cargando = false);
    }
  }

  // AHORA RECIBE EL STRING EXACTO (ej: 'cocinero', 'mesero')
  Future<void> _cambiarRol(Usuario usuario, String nuevoRolRaw) async {
    try {
      final exito = await _usuarioService.cambiarRol(usuario.id, nuevoRolRaw);
      if (exito) {
        setState(() {
          // Buscamos al usuario en la lista
          final index = _usuarios.indexWhere((u) => u.id == usuario.id);
          if (index != -1) {
            // Asignamos el Enum general correcto para que no desaparezca de las pestañas
            RolUsuario nuevoRolEnum = (nuevoRolRaw == 'administrador' || nuevoRolRaw == 'admin') 
                ? RolUsuario.administrador 
                : RolUsuario.trabajador;
            
            // MAGIA: Usamos el copyWith de tu modelo para reemplazarlo sin romper el "final"
            _usuarios[index] = usuario.copyWith(
              rolRaw: nuevoRolRaw,
              rol: nuevoRolEnum,
            );
          }
        });
        _showSnackBar("Rol actualizado a ${nuevoRolRaw.toUpperCase()}", esExito: true);
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
        title: const Text("¿Eliminar registro?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text("Se eliminará a ${usuario.nombre} del sistema.", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCELAR", style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("ELIMINAR", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
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
        content: Text(msj, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: esExito ? Colors.green.shade800 : AppColors.button,
        behavior: SnackBarBehavior.floating,
      )
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
        title: Text(
          _sucursalSeleccionada == null ? "GESTIÓN DE EQUIPO" : "EQUIPO $_sucursalSeleccionada",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(image: AssetImage('assets/images/Bravo restaurante.jpg'), fit: BoxFit.cover),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.5), Colors.black.withOpacity(0.95)],
            ),
          ),
          child: SafeArea(
            child: _sucursalSeleccionada == null 
                ? _buildSeleccionSucursal() 
                : _buildListadoUsuarios(),
          ),
        ),
      ),
    );
  }

  Widget _buildSeleccionSucursal() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("SELECCIONA SUCURSAL", 
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 3)),
          const SizedBox(height: 40),
          _sucursalCard("MADRID", Icons.location_city),
          const SizedBox(height: 20),
          _sucursalCard("ZARAGOZA", Icons.account_balance),
        ],
      ),
    );
  }

  Widget _sucursalCard(String nombre, IconData icono) {
    return GestureDetector(
      onTap: () {
        setState(() => _sucursalSeleccionada = nombre);
        _cargarUsuarios(_idsSucursales[nombre]!);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 280,
            padding: const EdgeInsets.symmetric(vertical: 30),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              border: Border.all(color: Colors.white24, width: 1.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(icono, color: AppColors.button, size: 50),
                const SizedBox(height: 15),
                Text(nombre, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 4)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListadoUsuarios() {
    if (_cargando) return const Center(child: CircularProgressIndicator(color: AppColors.button));

    final trabajadores = _usuarios.where((u) => u.rol != RolUsuario.cliente).toList();
    final clientes = _usuarios.where((u) => u.rol == RolUsuario.cliente).toList();

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            indicatorColor: AppColors.button,
            indicatorWeight: 3,
            labelColor: Colors.white, 
            unselectedLabelColor: Colors.white38,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: TextButton.icon(
              onPressed: () => setState(() => _sucursalSeleccionada = null),
              icon: const Icon(Icons.swap_horiz, color: Colors.white),
              label: const Text("CAMBIAR SUCURSAL", 
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
              style: TextButton.styleFrom(backgroundColor: Colors.white10),
            ),
          )
        ],
      ),
    );
  }

  Widget _seccionLista(List<Usuario> lista, {required bool esTrabajador}) {
    if (lista.isEmpty) {
      return const Center(
        child: Text("Sin registros en esta zona", style: TextStyle(color: Colors.white38, fontSize: 16))
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: lista.length,
      itemBuilder: (context, index) => _usuarioGlassCard(lista[index], esTrabajador),
    );
  }

  Widget _usuarioGlassCard(Usuario usuario, bool esTrabajador) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6), 
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.button,
          child: Text(usuario.nombre.isNotEmpty ? usuario.nombre[0].toUpperCase() : '?', 
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
        title: Text(usuario.nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        // AHORA SE MUESTRA EL PUESTO EXACTO (COCINERO, MESERO...)
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              esTrabajador ? usuario.rolRaw.toUpperCase() : "CLIENTE", 
              style: const TextStyle(color: AppColors.button, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)
            ),
            const SizedBox(height: 2),
            Text(usuario.email.isNotEmpty ? usuario.email : 'Sin correo', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        isThreeLine: true, // Deja espacio extra para las 3 líneas
        trailing: esTrabajador 
            ? _botonCambiarRol(usuario)
            : IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                onPressed: () => _eliminarUsuario(usuario),
              ),
      ),
    );
  }

  // LOS 5 ROLES DEFINIDOS
  Widget _botonCambiarRol(Usuario usuario) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.manage_accounts, color: Color.fromARGB(255, 255, 255, 255), size: 28),
      color: const Color(0xFF222222),
      onSelected: (nuevoRolRaw) => _cambiarRol(usuario, nuevoRolRaw),
      itemBuilder: (ctx) => [
        const PopupMenuItem(value: 'administrador', child: Text("Administrador", style: TextStyle(color: Colors.white))),
        const PopupMenuItem(value: 'cocinero', child: Text("Cocinero", style: TextStyle(color: Colors.white))),
        const PopupMenuItem(value: 'mesero', child: Text("Mesero", style: TextStyle(color: Colors.white))),
        const PopupMenuItem(value: 'camarero', child: Text("Camarero", style: TextStyle(color: Colors.white))),
        const PopupMenuItem(value: 'trabajador', child: Text("Trabajadores", style: TextStyle(color: Colors.white))),
      ],
    );
  }
}