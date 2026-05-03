import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/usuario_model.dart';
import '../../providers/usuario_provider.dart';
import '../../core/colors_style.dart';
import 'crear_usuario_screen.dart';

class GestionUsuariosScreen extends StatefulWidget {
  final String restauranteId;
  final String rolAFiltrar;

  const GestionUsuariosScreen({
    super.key,
    required this.restauranteId,
    this.rolAFiltrar = '',
  });

  @override
  State<GestionUsuariosScreen> createState() => _GestionUsuariosScreenState();
}

class _GestionUsuariosScreenState extends State<GestionUsuariosScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UsuarioProvider>().cargar();
    });
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Orden y etiquetas de roles
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

  static const _rolesPersonal = ['administrador', 'cocinero', 'camarero', 'mesero', 'trabajador'];

  List<Usuario> _filtrarPorRestaurante(List<Usuario> todos) {
    final idFiltro = widget.restauranteId.trim().toLowerCase();
    final filtro = widget.rolAFiltrar.toLowerCase();

    return todos.where((u) {
      final idDB = (u.restauranteId ?? '').toString().trim().toLowerCase();
      if (idDB != idFiltro) return false;

      final rol = u.rolRaw;

      if (filtro == 'cliente') return rol == 'cliente';
      if (filtro == 'trabajador') return _rolesPersonal.contains(rol);
      if (filtro.isNotEmpty) return rol == filtro;
      return true;
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

  Future<void> _irACrearUsuario() async {
    final rolFijo = widget.rolAFiltrar.toLowerCase() == 'administrador' ? 'administrador' : null;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CrearUsuarioScreen(
          restauranteId: widget.restauranteId,
          rolFijo: rolFijo,
        ),
      ),
    );
  }

  List<Usuario> _filtrarPorBusqueda(List<Usuario> lista) {
    if (_searchQuery.isEmpty) return lista;
    return lista.where((u) {
      return u.nombre.toLowerCase().contains(_searchQuery) ||
          u.email.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  Widget _buildBuscador() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              border: Border.all(color: Colors.white12),
            ),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.manrope(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o email...',
                hintStyle: GoogleFonts.manrope(color: Colors.white38, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Fondo
          Positioned.fill(
            child: Image.asset('assets/images/Bravo restaurante.jpg', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(color: AppColors.shadow.withValues(alpha: 0.88)),
          ),

          // Contenido
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildBuscador(),
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

                      final lista = _filtrarPorBusqueda(_filtrarPorRestaurante(provider.usuarios));
                      final grupos = _agruparPorRol(lista);

                      if (grupos.isEmpty) {
                        return _buildVacio();
                      }

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
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
                                        (u) => _UsuarioTile(
                                          usuario: u,
                                          onDelete: () => _confirmarBorrado(context, u),
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

          // Botón volver
          Positioned(
            top: 20,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.rolAFiltrar.toLowerCase() == 'cliente' ? 'Clientes' : 'Personal',
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Container(height: 2, width: 40, color: AppColors.button),
                const SizedBox(height: 10),
                Text(
                  widget.rolAFiltrar.toLowerCase() == 'cliente'
                      ? 'Base de datos de clientes registrados'
                      : 'Gestión de personal de esta sucursal',
                  style: GoogleFonts.manrope(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (widget.rolAFiltrar.toLowerCase() != 'cliente') ...[
            const SizedBox(width: 16),
            _NuevoUsuarioButton(onPressed: _irACrearUsuario),
          ],
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
          Icon(icono, color: AppColors.button, size: 16),
          const SizedBox(width: 8),
          Text(
            etiqueta.toUpperCase(),
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.button,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            color: AppColors.button.withValues(alpha: 0.15),
            child: Text(
              '$count',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.button,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: Colors.white12)),
        ],
      ),
    );
  }

  Widget _buildVacio() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            'No hay usuarios en esta sucursal',
            style: GoogleFonts.manrope(color: Colors.white38, fontSize: 14),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _irACrearUsuario,
            icon: const Icon(Icons.person_add_outlined, color: AppColors.button, size: 18),
            label: Text(
              'Agregar el primero',
              style: GoogleFonts.manrope(color: AppColors.button, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmarBorrado(BuildContext context, Usuario user) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: const RoundedRectangleBorder(),
        title: Text('¿Eliminar usuario?', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        content: Text(
          '¿Confirmas la eliminación de ${user.nombre}? Esta acción no se puede deshacer.',
          style: GoogleFonts.manrope(color: AppColors.textSecondary, fontSize: 13),
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
              final borrado = await context.read<UsuarioProvider>().eliminar(user.id);
              if (borrado) {
                if (!mounted) return;
                nav.pop();
                messenger.showSnackBar(SnackBar(
                  content: Text('Usuario eliminado', style: GoogleFonts.manrope()),
                  backgroundColor: AppColors.button,
                ));
              }
            },
            child: Text('Eliminar', style: GoogleFonts.manrope(color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── BOTÓN NUEVO USUARIO ──────────────────────────────────────────────
class _NuevoUsuarioButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _NuevoUsuarioButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.button,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_add_outlined, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                'NUEVO',
                style: GoogleFonts.manrope(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── TILE DE USUARIO ──────────────────────────────────────────────────
class _UsuarioTile extends StatelessWidget {
  final Usuario usuario;
  final VoidCallback onDelete;

  const _UsuarioTile({required this.usuario, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final initials = usuario.nombre.isNotEmpty
        ? usuario.nombre.trim().split(' ').map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').take(2).join()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 64,
            color: AppColors.button.withValues(alpha: 0.8),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  usuario.nombre,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  usuario.email,
                  style: GoogleFonts.manrope(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: AppColors.error.withValues(alpha: 0.8), size: 22),
            onPressed: onDelete,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
