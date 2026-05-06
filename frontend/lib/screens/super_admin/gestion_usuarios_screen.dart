import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/usuario_model.dart';
import '../../models/restaurante_model.dart';
import '../../providers/restaurante_provider.dart';
import '../../providers/usuario_provider.dart';
import '../../core/colors_style.dart';
import 'crear_usuario_screen.dart';

class GestionUsuariosScreen extends StatefulWidget {
  final String? restauranteId;
  final String rolAFiltrar;

  const GestionUsuariosScreen({
    super.key,
    this.restauranteId,
    this.rolAFiltrar = '',
  });

  @override
  State<GestionUsuariosScreen> createState() => _GestionUsuariosScreenState();
}

class _GestionUsuariosScreenState extends State<GestionUsuariosScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // Estado interno para filtrar por sucursal seleccionada. 
  // 'null' significa "Todas" (Todas).
  String? _selectedRestauranteId;

  @override
  void initState() {
    super.initState();
    _selectedRestauranteId = widget.restauranteId;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provUser = context.read<UsuarioProvider>();
      final provRest = context.read<RestauranteProvider>();
      
      if (provUser.usuarios.isEmpty) {
        provUser.cargar();
      }
      if (provRest.restaurantes.isEmpty) {
        provRest.cargar();
      }
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

  // CORRECCIÓN 1: Quitamos 'administrador' de aquí para que no salgan mezclados con los trabajadores
  static const _rolesPersonal = [
    'cocinero',
    'camarero',
    'mesero',
    'trabajador',
  ];

  List<Usuario> _filtrarUsuarios(List<Usuario> todos) {
    final filtro = widget.rolAFiltrar.toLowerCase();
    final idSucursal = _selectedRestauranteId;

    return todos.where((u) {
      final rol = u.rolRaw;
      final idDB = u.restauranteId;

      // 1. Filtrar por rol
      bool matchRol = false;
      if (filtro.isEmpty) {
        matchRol = true;
      } else if (filtro == 'cliente') {
        matchRol = (rol == 'cliente');
      } else if (filtro == 'trabajador') {
        matchRol = _rolesPersonal.contains(rol);
      } else {
        matchRol = (rol == filtro);
      }

      if (!matchRol) return false;

      // 2. Filtrar por sucursal
      if (rol == 'cliente') return true; 
      if (idSucursal == null) return true; 
      
      return idDB == idSucursal;
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
    final rolFijo = widget.rolAFiltrar.toLowerCase() == 'administrador'
        ? 'administrador'
        : null;
        
    final rId = _selectedRestauranteId ?? '';

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CrearUsuarioScreen(
          restauranteId: rId,
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

  String _buildSubtext() {
    final filtro = widget.rolAFiltrar.toLowerCase();
    final esClientes = filtro == 'cliente';

    if (esClientes) return 'Base de datos global de clientes registrados';

    if (_selectedRestauranteId == null) return 'Gestión de personal de todo el grupo Bravo';

    final rProv = context.read<RestauranteProvider>();
    final rMatch = rProv.restaurantes.where((r) => r.id == _selectedRestauranteId).firstOrNull;
    if (rMatch != null) {
      return 'Gestión de personal de Bravo ${rMatch.nombre.replaceAll('Bravo', '').trim()}';
    }
    return 'Gestión de personal de la sucursal';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/Bravo restaurante.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
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
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderEditorial(), 
                _buildBranchFilterBar(),
                _buildBuscador(),
                Expanded(
                  child: Consumer<UsuarioProvider>(
                    builder: (context, provider, _) {
                      if (provider.cargando && provider.usuarios.isEmpty) {
                        return const Center(
                          child: CircularProgressIndicator(color: AppColors.button),
                        );
                      }
                      
                      if (provider.error != null && provider.usuarios.isEmpty) {
                        return Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              'Error al cargar datos:\n${provider.error}',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(color: Colors.white54),
                            ),
                          ),
                        );
                      }

                      final lista = _filtrarPorBusqueda(_filtrarUsuarios(provider.usuarios));
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
                                      _buildSeccionHeader(
                                        rol,
                                        grupos[rol]!.length,
                                      ),
                                      ...grupos[rol]!.map(
                                        (u) => _UsuarioTile(
                                          usuario: u,
                                          onDelete: () => _confirmarBorrado(context, u),
                                          onEdit: () => _abrirEdicion(context, u),
                                          onToggleActivo: () => _toggleActivo(context, u),
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
        ],
      ),
    );
  }

  Widget _buildHeaderEditorial() {
    final filtro = widget.rolAFiltrar.toLowerCase();
    final esClientes = filtro == 'cliente';
    final subtext = _buildSubtext();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                Text(
                  esClientes ? 'Clientes' : 'Personal',
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Center(child: Container(height: 2, width: 40, color: AppColors.button)),
                const SizedBox(height: 10),
                Text(
                  subtext,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!esClientes) ...[
            _NuevoUsuarioButton(onPressed: _irACrearUsuario),
          ],
        ],
      ),
    );
  }

  Widget _buildBranchFilterBar() {
    if (widget.rolAFiltrar.toLowerCase() == 'cliente') return const SizedBox.shrink();

    return SizedBox(
      height: 62,
      child: Stack(
        children: [
          Consumer<RestauranteProvider>(
            builder: (context, rProv, _) {
              if (rProv.cargando && rProv.restaurantes.isEmpty) {
                return const SizedBox.shrink();
              }
              final sucursales = rProv.restaurantes;
              final opciones = [null, ...sucursales];

              return ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                itemCount: opciones.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final dynamic item = opciones[index];
                  final bool isSelected = (item == null && _selectedRestauranteId == null) ||
                                         (item is Restaurante && _selectedRestauranteId == item.id);
                  
                  final String label = (item == null) ? 'TODAS' : item.nombre.toUpperCase();

                  return _BranchCategoryChip(
                    label: label,
                    seleccionado: isSelected,
                    onTap: () => setState(() {
                      _selectedRestauranteId = (item == null) ? null : item.id;
                    }),
                  );
                },
              );
            },
          ),
          Positioned(
            right: 0,
            top: 12,
            bottom: 12,
            width: 40,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // CORRECCIÓN 2: Buscador con barra blanca y texto oscuro
  Widget _buildBuscador() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white, // Fondo blanco sólido
              borderRadius: BorderRadius.circular(8), // Bordes redondeados
            ),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.manrope(color: Colors.black87, fontSize: 14), // Texto oscuro
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o email...',
                hintStyle: GoogleFonts.manrope(
                  color: Colors.black54, // Hint texto oscuro
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.black54, // Icono oscuro
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.black54,
                          size: 18,
                        ),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // CORRECCIÓN 3: Titulos de roles y números en blanco
  Widget _buildSeccionHeader(String rol, int count) {
    final etiqueta = _rolesEtiqueta[rol] ?? rol;
    final icono = _rolesIcono[rol] ?? Icons.person_outline;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(
        children: [
          Icon(icono, color: Colors.white, size: 16), // Icono blanco
          const SizedBox(width: 8),
          Text(
            etiqueta.toUpperCase(),
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white, // Título en blanco
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15), // Fondo de la píldora semitransparente
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white, // Número en blanco
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
    final bool esClientes = widget.rolAFiltrar.toLowerCase() == 'cliente';
    
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            esClientes ? 'No hay clientes registrados' : 'No hay personal que mostrar',
            style: GoogleFonts.manrope(color: Colors.white38, fontSize: 14),
          ),
          const SizedBox(height: 24),
          if (!esClientes)
            TextButton.icon(
              onPressed: _irACrearUsuario,
              icon: const Icon(
                Icons.person_add_outlined,
                color: AppColors.button,
                size: 18,
              ),
              label: Text(
                'Agregar el primero',
                style: GoogleFonts.manrope(
                  color: AppColors.button,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _toggleActivo(BuildContext context, Usuario user) async {
    final messenger = ScaffoldMessenger.of(context);
    final nuevoEstado = !user.activo;
    final ok = await context.read<UsuarioProvider>().toggleActivo(
      user.id,
      nuevoEstado,
    );
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (nuevoEstado ? 'Usuario activado' : 'Usuario suspendido')
              : 'Error al cambiar estado',
          style: GoogleFonts.manrope(),
        ),
        backgroundColor: ok
            ? (nuevoEstado ? AppColors.button : Colors.orange)
            : AppColors.error,
      ),
    );
  }

void _abrirEdicion(BuildContext context, Usuario user) {
    final nombreCtrl = TextEditingController(text: user.nombre);
    final emailCtrl = TextEditingController(text: user.email);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.background, // Si tu fondo es claro, esto va perfecto
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Editar usuario',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            color: Colors.black87, // Título en oscuro
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CampoEdicion(
              controller: nombreCtrl, 
              label: 'Nombre', 
              color: Colors.black87, // ¡Ahora sí lo acepta!
            ),
            const SizedBox(height: 12),
            _CampoEdicion(
              controller: emailCtrl, 
              label: 'Email', 
              color: Colors.black87, // ¡Ahora sí lo acepta!
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: GoogleFonts.manrope(color: Colors.black54, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final nombre = nombreCtrl.text.trim();
              final correo = emailCtrl.text.trim();
              if (nombre.isEmpty || correo.isEmpty) return;
              final ok = await context.read<UsuarioProvider>().editar(
                user.id,
                nombre: nombre,
                correo: correo,
              );
              if (!mounted) return;
              nav.pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    ok ? 'Usuario actualizado' : 'Error al actualizar',
                    style: GoogleFonts.manrope(),
                  ),
                  backgroundColor: ok ? AppColors.button : AppColors.error,
                ),
              );
            },
            child: Text(
              'Guardar',
              style: GoogleFonts.manrope(
                color: AppColors.button,
                fontWeight: FontWeight.w800,
              ),
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
        title: Text(
          '¿Eliminar usuario?',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
        content: Text(
          '¿Confirmas la eliminación de ${user.nombre}? Esta acción no se puede deshacer.',
          style: GoogleFonts.manrope(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: GoogleFonts.manrope(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final borrado = await context.read<UsuarioProvider>().eliminar(
                user.id,
              );
              if (borrado) {
                if (!mounted) return;
                nav.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Usuario eliminado',
                      style: GoogleFonts.manrope(),
                    ),
                    backgroundColor: AppColors.button,
                  ),
                );
              }
            },
            child: Text(
              'Eliminar',
              style: GoogleFonts.manrope(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
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
              const Icon(
                Icons.person_add_outlined,
                color: Colors.white,
                size: 18,
              ),
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
  final VoidCallback onEdit;
  final VoidCallback onToggleActivo;

  const _UsuarioTile({
    required this.usuario,
    required this.onDelete,
    required this.onEdit,
    required this.onToggleActivo,
  });

  @override
  Widget build(BuildContext context) {
    final initials = usuario.nombre.isNotEmpty
        ? usuario.nombre
              .trim()
              .split(' ')
              .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
              .take(2)
              .join()
        : '?';

    final activo = usuario.activo;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        border: Border.all(
          color: activo ? Colors.white12 : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 72,
            color: activo
                ? AppColors.button.withValues(alpha: 0.8)
                : Colors.orange.withValues(alpha: 0.5),
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
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 5),
                _BadgeEstadoCuenta(activo: activo),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              activo ? Icons.pause_circle_outline : Icons.play_circle_outline,
              color: activo
                  ? Colors.orange.withValues(alpha: 0.8)
                  : Colors.greenAccent.withValues(alpha: 0.8),
              size: 22,
            ),
            tooltip: activo ? 'Suspender' : 'Activar',
            onPressed: onToggleActivo,
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, color: Colors.white38, size: 20),
            onPressed: onEdit,
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: AppColors.error.withValues(alpha: 0.8),
              size: 22,
            ),
            onPressed: onDelete,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ── BADGE ESTADO CUENTA ──────────────────────────────────────────────
class _BadgeEstadoCuenta extends StatelessWidget {
  final bool activo;
  const _BadgeEstadoCuenta({required this.activo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: activo
            ? Colors.greenAccent.withValues(alpha: 0.12)
            : Colors.orange.withValues(alpha: 0.12),
        border: Border.all(
          color: activo
              ? Colors.greenAccent.withValues(alpha: 0.4)
              : Colors.orange.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: activo ? Colors.greenAccent : Colors.orange,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            activo ? 'ACTIVO' : 'SUSPENDIDO',
            style: GoogleFonts.manrope(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: activo ? Colors.greenAccent : Colors.orange,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── CAMPO DE EDICIÓN ─────────────────────────────────────────────────
// ── CAMPO DE EDICIÓN ─────────────────────────────────────────────────
class _CampoEdicion extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final Color color; // <-- ¡Aquí le decimos que acepte el color!

  const _CampoEdicion({
    required this.controller, 
    required this.label,
    this.color = Colors.white, // Por defecto es blanco, pero tomará el black87 que le mandas
  });

  @override
  Widget build(BuildContext context) {
    // Si pasamos un color oscuro, oscurecemos los bordes y fondos. Si es blanco, los aclaramos.
    final isDarkText = color != Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: isDarkText ? Colors.black54 : AppColors.textSecondary,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: isDarkText 
                ? Colors.black.withValues(alpha: 0.05) 
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDarkText 
                  ? Colors.black.withValues(alpha: 0.1) 
                  : Colors.white12,
            ),
          ),
          child: TextField(
            controller: controller,
            style: GoogleFonts.manrope(color: color, fontSize: 14), // <-- Usa tu Colors.black87
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── BRANCH CATEGORY CHIP (Estilo Carta) ──────────────────────────────────
class _BranchCategoryChip extends StatelessWidget {
  final String label;
  final bool seleccionado;
  final VoidCallback onTap;

  const _BranchCategoryChip({
    required this.label,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: seleccionado ? AppColors.button : Colors.black45,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: seleccionado ? AppColors.button : Colors.white24,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: seleccionado ? Colors.white : Colors.white70,
              fontSize: 11,
              fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}