import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:frontend/components/bravo_app_bar.dart';
import '../../models/usuario_model.dart';
import '../../providers/usuario_provider.dart';
import '../../core/colors_style.dart';

class GestionRolesScreen extends StatefulWidget {
  final String? restauranteId;

  const GestionRolesScreen({super.key, this.restauranteId});

  @override
  State<GestionRolesScreen> createState() => _GestionRolesScreenState();
}

class _GestionRolesScreenState extends State<GestionRolesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UsuarioProvider>().cargar();
    });
  }

  static const _rolesOrden = [
    'administrador',
    'cocinero',
    'camarero',
    'mesero',
    'trabajador',
    'cliente',
  ];

  static const _rolesEtiqueta = {
    'administrador': 'Administradores',
    'cocinero': 'Cocineros',
    'camarero': 'Camareros',
    'mesero': 'Meseros',
    'trabajador': 'Trabajadores',
    'cliente': 'Clientes',
  };

  static const _rolesIcono = {
    'administrador': Icons.manage_accounts_outlined,
    'cocinero': Icons.restaurant_outlined,
    'camarero': Icons.room_service_outlined,
    'mesero': Icons.dining_outlined,
    'trabajador': Icons.badge_outlined,
    'cliente': Icons.person_outline,
  };

  static const _opcionesRol = [
    'administrador',
    'cocinero',
    'camarero',
    'mesero',
    'trabajador',
  ];

  List<Usuario> _filtrarPorRestaurante(List<Usuario> todos) {
    final idFiltro = (widget.restauranteId ?? '').trim().toLowerCase();
    return todos.where((u) {
      if (idFiltro.isNotEmpty && (u.restauranteId ?? '').toString().trim().toLowerCase() != idFiltro) return false;
      return u.rolRaw != 'cliente';
    }).toList();
  }

  Map<String, List<Usuario>> _agruparPorRol(List<Usuario> lista) {
    final Map<String, List<Usuario>> grupos = {};
    for (final u in lista) {
      grupos.putIfAbsent(u.rolRaw, () => []).add(u);
    }
    grupos.removeWhere((_, v) => v.isEmpty);
    return grupos;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: const BravoAppBar(title: 'PERMISOS Y ROLES'),
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
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.55),
                Colors.black.withValues(alpha: 0.88),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                Expanded(
                  child: Consumer<UsuarioProvider>(
                    builder: (context, provider, _) {
                      if (provider.cargando) {
                        return const Center(
                          child: CircularProgressIndicator(color: AppColors.button),
                        );
                      }
                      if (provider.error != null) {
                        return Center(
                          child: Text(
                            'Error al cargar datos',
                            style: GoogleFonts.manrope(color: Colors.white54),
                          ),
                        );
                      }

                      final lista = _filtrarPorRestaurante(provider.usuarios);
                      final grupos = _agruparPorRol(lista);

                      if (grupos.isEmpty) {
                        return Center(
                          child: Text(
                            'No hay usuarios en esta sucursal',
                            style: GoogleFonts.manrope(color: Colors.white38),
                          ),
                        );
                      }

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 640),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final rol in [..._rolesOrden, 'otros'])
                                    if (grupos.containsKey(rol)) ...[
                                      _buildSeccionHeader(rol, grupos[rol]!.length),
                                      ...grupos[rol]!.map(
                                        (u) => _RolTile(
                                          usuario: u,
                                          onEdit: () => _mostrarDialogoCambiarRol(context, u),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Permisos y Roles',
            style: TextStyle(
              fontFamily: 'Playfair Display',
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Container(height: 2, width: 40, color: AppColors.button),
          const SizedBox(height: 10),
          Text(
            'Modifica el rol de cualquier usuario de esta sucursal',
            style: GoogleFonts.manrope(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionHeader(String rol, int count) {
    final etiqueta = _rolesEtiqueta[rol] ?? rol;
    final icono = _rolesIcono[rol] ?? Icons.person_outline;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(
        children: [
          Container(width: 3, height: 18, color: AppColors.button),
          const SizedBox(width: 10),
          Icon(icono, color: AppColors.button, size: 16),
          const SizedBox(width: 8),
          Text(
            etiqueta.toUpperCase(),
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white70,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.button.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.button.withValues(alpha: 0.45)),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: Colors.white12)),
        ],
      ),
    );
  }

  void _mostrarDialogoCambiarRol(BuildContext context, Usuario user) {
    String rolActual = user.rolRaw;
    if (!_opcionesRol.contains(rolActual)) rolActual = 'trabajador';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: AppColors.background,
          shape: const RoundedRectangleBorder(),
          title: Text('Cambiar rol', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    color: AppColors.button,
                    alignment: Alignment.center,
                    child: Text(
                      user.nombre.trim().split(' ').map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').take(2).join(),
                      style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.nombre, style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 14)),
                        Text(user.email, style: GoogleFonts.manrope(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: rolActual,
                decoration: InputDecoration(
                  labelText: 'Nuevo rol',
                  labelStyle: GoogleFonts.manrope(fontSize: 13),
                  border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: AppColors.line),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: AppColors.button, width: 1.5),
                  ),
                  prefixIcon: const Icon(Icons.vpn_key_outlined, color: AppColors.button),
                  filled: true,
                  fillColor: Colors.white,
                ),
                style: GoogleFonts.manrope(color: AppColors.textPrimary),
                items: _opcionesRol
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(_rolesEtiqueta[r] ?? r, style: GoogleFonts.manrope()),
                        ))
                    .toList(),
                onChanged: (v) => v != null ? setStateDialog(() => rolActual = v) : null,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: GoogleFonts.manrope(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                final nav = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                final provider = context.read<UsuarioProvider>();
                try {
                  final ok = await provider.cambiarRol(user.id, rolActual);
                  if (ok) {
                    if (!mounted) return;
                    nav.pop();
                    messenger.showSnackBar(SnackBar(
                      content: Text('Rol actualizado a ${_rolesEtiqueta[rolActual] ?? rolActual}', style: GoogleFonts.manrope()),
                      backgroundColor: AppColors.button,
                    ));
                  }
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                  );
                }
              },
              child: Text('Guardar', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: AppColors.button)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── TILE DE ROL (GLASS) ──────────────────────────────────────────────
class _RolTile extends StatelessWidget {
  final Usuario usuario;
  final VoidCallback onEdit;

  const _RolTile({required this.usuario, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final initials = usuario.nombre.isNotEmpty
        ? usuario.nombre.trim().split(' ').map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').take(2).join()
        : '?';

    final rolLabel = _labelRol(usuario.rolRaw);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.button.withValues(alpha: 0.85),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        usuario.nombre,
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.button.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.button.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          rolLabel.toUpperCase(),
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 22),
                  onPressed: onEdit,
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _labelRol(String rol) {
    const labels = {
      'administrador': 'Administrador',
      'cocinero': 'Cocinero',
      'camarero': 'Camarero',
      'mesero': 'Mesero',
      'trabajador': 'Trabajador',
      'cliente': 'Cliente',
      'superadministrador': 'Super Admin',
    };
    return labels[rol] ?? rol;
  }
}
