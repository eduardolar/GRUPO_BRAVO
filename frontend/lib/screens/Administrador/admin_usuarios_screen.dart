import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../components/admin/admin_max_width.dart';
import '../../components/bravo_app_bar.dart';
import '../../core/colors_style.dart';
import '../../models/usuario_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/usuario_service.dart';

// ─── Constantes de estilo ────────────────────────────────────────────────────
const _kSheetBg = AppColors.bottomSheetBg;
// Negro translúcido (alpha ~55%): sobre la imagen Bravo de fondo el blanco
// translúcido se confundía con el papel claro y dejaba el texto invisible.
const _kFieldFill = Color(0x8C000000);
const _kBorder = Color(0x33FFFFFF);

class AdminUsuariosScreen extends StatefulWidget {
  const AdminUsuariosScreen({super.key});

  @override
  State<AdminUsuariosScreen> createState() => _AdminUsuariosScreenState();
}

class _AdminUsuariosScreenState extends State<AdminUsuariosScreen>
    with SingleTickerProviderStateMixin {
  List<Usuario> _usuarios = [];
  bool _cargando = true;
  String _busqueda = '';
  final _busquedaCtrl = TextEditingController();

  final _usuarioService = UsuarioService();
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _cargarUsuarios();
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarUsuarios() async {
    setState(() => _cargando = true);
    final miRestaurante =
        context.read<AuthProvider>().usuarioActual?.restauranteId;
    try {
      final todos = await _usuarioService.obtenerTodos();
      if (!mounted) return;
      setState(() {
        _usuarios = todos.where((u) {
          if (u.rol == RolUsuario.superadministrador) return false;
          if (miRestaurante == null || miRestaurante.isEmpty) return true;
          final r = u.restauranteId;
          // Si el admin pertenece a una sucursal, oculta usuarios sin sucursal
          // asignada: el backend los rechazará (403) porque no coinciden con
          // el restaurante_id del admin. Solo super_admin puede gestionarlos.
          if (r == null || r.isEmpty) return false;
          return r == miRestaurante;
        }).toList();
      });
    } catch (_) {
      if (mounted) _showSnack('Error al conectar con la base de datos');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ─── Buscador ─────────────────────────────────────────────────────────────

  List<Usuario> _filtrar(List<Usuario> lista) {
    if (_busqueda.isEmpty) return lista;
    final q = _busqueda.toLowerCase();
    return lista.where((u) {
      return u.nombre.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          u.telefono.toLowerCase().contains(q);
    }).toList();
  }

  // ─── Acciones ─────────────────────────────────────────────────────────────

  Future<void> _cambiarRol(Usuario usuario, String nuevoRolRaw) async {
    try {
      final exito = await _usuarioService.cambiarRol(usuario.id, nuevoRolRaw);
      if (exito) {
        setState(() {
          final i = _usuarios.indexWhere((u) => u.id == usuario.id);
          if (i != -1) {
            final nuevoRol = (nuevoRolRaw == 'administrador' ||
                    nuevoRolRaw == 'admin')
                ? RolUsuario.administrador
                : RolUsuario.trabajador;
            _usuarios[i] = usuario.copyWith(rolRaw: nuevoRolRaw, rol: nuevoRol);
          }
        });
        _showSnack(
          'Rol actualizado a ${nuevoRolRaw.toUpperCase()}',
          esExito: true,
        );
      }
    } catch (_) {
      _showSnack('Error al actualizar en el servidor');
    }
  }

  Future<void> _suspenderUsuario(Usuario usuario) async {
    final confirmar = await _confirmarDialog(
      titulo: '¿Suspender empleado?',
      cuerpo:
          'Se suspenderá la cuenta de ${usuario.nombre}. Podrás reactivarla más adelante.',
      accionLabel: 'SUSPENDER',
      accionColor: AppColors.warningLight,
    );
    if (confirmar != true) return;

    try {
      // DELETE /usuarios/{id} — el backend hace soft-delete cuando lo ejecuta el admin
      final exito = await _usuarioService.eliminarUsuario(usuario.id);
      if (exito) {
        setState(() {
          final i = _usuarios.indexWhere((u) => u.id == usuario.id);
          if (i != -1) {
            _usuarios[i] = _usuarios[i].copyWith(activo: false);
          }
        });
        _showSnack('Empleado suspendido', esExito: true);
      }
    } catch (_) {
      _showSnack('Error al suspender el empleado');
    }
  }

  Future<void> _reactivarUsuario(Usuario usuario) async {
    final confirmar = await _confirmarDialog(
      titulo: '¿Reactivar empleado?',
      cuerpo: 'Se reactivará la cuenta de ${usuario.nombre}.',
      accionLabel: 'REACTIVAR',
      accionColor: AppColors.disp,
    );
    if (confirmar != true) return;

    try {
      await _usuarioService.reactivarUsuario(usuario.id);
      if (!mounted) return;
      setState(() {
        final i = _usuarios.indexWhere((u) => u.id == usuario.id);
        if (i != -1) {
          _usuarios[i] = _usuarios[i].copyWith(activo: true);
        }
      });
      _showSnack('Empleado reactivado', esExito: true);
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  Future<void> _borrarDefinitivamente(Usuario usuario) async {
    // 1.ª confirmación — aviso fuerte
    final aviso = await _confirmarDialog(
      titulo: '¿Borrar definitivamente?',
      cuerpo:
          'Esta acción es IRREVERSIBLE. Se eliminará la cuenta de '
          '${usuario.nombre} y todos sus datos del sistema.',
      accionLabel: 'CONTINUAR',
      accionColor: AppColors.error,
    );
    if (aviso != true) return;
    if (!mounted) return;

    // 2.ª confirmación — pedir el nombre del empleado
    final confirmado = await _confirmarConNombre(usuario);
    if (confirmado != true) return;

    try {
      // El backend hard-deletea cuando el target ya está suspendido
      final exito = await _usuarioService.eliminarUsuario(usuario.id);
      if (exito) {
        setState(() => _usuarios.removeWhere((u) => u.id == usuario.id));
        _showSnack('Empleado eliminado definitivamente', esExito: true);
      }
    } catch (_) {
      _showSnack('Error al eliminar el empleado');
    }
  }

  Future<bool?> _confirmarConNombre(Usuario usuario) {
    final ctrl = TextEditingController();
    bool habilitado = false;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: AppColors.bottomSheetBg,
          title: const Text(
            'Confirmación final',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Para confirmar, escribe el nombre del empleado:',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                usuario.nombre,
                style: const TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: usuario.nombre,
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.white10,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: AppColors.error, width: 2),
                  ),
                ),
                onChanged: (v) => setSt(() {
                  habilitado = v.trim() == usuario.nombre.trim();
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCELAR',
                  style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed:
                  habilitado ? () => Navigator.pop(ctx, true) : null,
              child: Text(
                'BORRAR',
                style: TextStyle(
                  color: habilitado ? AppColors.error : Colors.white24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _eliminarCliente(Usuario usuario) async {
    final confirmar = await _confirmarDialog(
      titulo: '¿Eliminar cliente?',
      cuerpo: 'Se eliminará a ${usuario.nombre} del sistema.',
      accionLabel: 'ELIMINAR',
      accionColor: AppColors.error,
    );
    if (confirmar != true) return;

    try {
      final exito = await _usuarioService.eliminarUsuario(usuario.id);
      if (exito) {
        setState(() => _usuarios.removeWhere((u) => u.id == usuario.id));
        _showSnack('Cliente eliminado', esExito: true);
      }
    } catch (_) {
      _showSnack('Error al eliminar');
    }
  }

  Future<bool?> _confirmarDialog({
    required String titulo,
    required String cuerpo,
    required String accionLabel,
    required Color accionColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bottomSheetBg,
        title: Text(
          titulo,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(cuerpo,
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCELAR',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              accionLabel,
              style: TextStyle(
                  color: accionColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msj, {bool esExito = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msj,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: esExito ? AppColors.disp : AppColors.button,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── FAB: crear empleado ──────────────────────────────────────────────────

  void _abrirCrearEmpleado() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CrearEmpleadoSheet(
        onCreado: _cargarUsuarios,
        service: _usuarioService,
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: const BravoAppBar(title: 'GESTIÓN DE EQUIPO'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirCrearEmpleado,
        backgroundColor: AppColors.button,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text(
          'NUEVO EMPLEADO',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
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
            child: _cargando
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.button),
                  )
                : AdminMaxWidth(child: _buildContenido()),
          ),
        ),
      ),
    );
  }

  Widget _buildContenido() {
    final trabajadores =
        _usuarios.where((u) => u.rol != RolUsuario.cliente).toList();
    final clientes =
        _usuarios.where((u) => u.rol == RolUsuario.cliente).toList();

    return Column(
      children: [
        // ─── Buscador (fondo blanco + texto negro) ──────────────────
        // Patrón input "claro" tipo Google: la imagen Bravo de fondo es muy
        // clara y los overlays translúcidos no daban contraste suficiente.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.15),
                ),
              ),
              child: TextField(
                controller: _busquedaCtrl,
                style: const TextStyle(color: Colors.black87),
                onChanged: (v) =>
                    setState(() => _busqueda = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, correo o teléfono…',
                  hintStyle:
                      const TextStyle(color: Colors.black54, fontSize: 14),
                  prefixIcon:
                      const Icon(Icons.search, color: Colors.black54),
                  suffixIcon: _busqueda.isNotEmpty
                      ? IconButton(
                          tooltip: 'Limpiar búsqueda',
                          icon: const Icon(Icons.clear,
                              color: Colors.black54),
                          onPressed: () {
                            _busquedaCtrl.clear();
                            setState(() => _busqueda = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ),

        // ─── Tabs ───────────────────────────────────────────────
        TabBar(
          controller: _tabCtrl,
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
            Tab(text: 'TRABAJADORES (${trabajadores.length})'),
            Tab(text: 'CLIENTES (${clientes.length})'),
          ],
        ),

        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _listaUsuarios(_filtrar(trabajadores), esTrabajador: true),
              _listaUsuarios(_filtrar(clientes), esTrabajador: false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _listaUsuarios(List<Usuario> lista, {required bool esTrabajador}) {
    if (lista.isEmpty) {
      return Center(
        child: Text(
          _busqueda.isNotEmpty
              ? 'Sin resultados para "$_busqueda"'
              : 'Sin registros disponibles',
          style: const TextStyle(color: Colors.white54, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: lista.length,
      itemBuilder: (_, i) => _usuarioCard(lista[i], esTrabajador),
    );
  }

  Widget _usuarioCard(Usuario usuario, bool esTrabajador) {
    final suspendido = !usuario.activo;

    return Opacity(
      opacity: suspendido ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: suspendido
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white10,
          ),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundColor:
                    suspendido ? AppColors.lineStrong : AppColors.button,
                child: Text(
                  usuario.nombre.isNotEmpty
                      ? usuario.nombre[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (suspendido)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: AppColors.lineStrong,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.block,
                        size: 8, color: Colors.white),
                  ),
                ),
            ],
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  usuario.nombre,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              if (suspendido) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.7)),
                  ),
                  child: const Text(
                    'SUSPENDIDO',
                    style: TextStyle(
                      color: AppColors.warningText,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                esTrabajador
                    ? usuario.rolRaw.toUpperCase()
                    : 'CLIENTE',
                style: TextStyle(
                  color:
                      suspendido ? Colors.white30 : AppColors.button,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                usuario.email.isNotEmpty ? usuario.email : 'Sin correo',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
          isThreeLine: true,
          trailing: esTrabajador
              ? _accionesTrabajador(usuario)
              : IconButton(
                  icon: const Icon(Icons.delete_forever,
                      color: AppColors.error),
                  tooltip: 'Eliminar cliente',
                  onPressed: () => _eliminarCliente(usuario),
                ),
        ),
      ),
    );
  }

  Widget _accionesTrabajador(Usuario usuario) {
    if (!usuario.activo) {
      // Suspendido: dos iconos (reactivar + borrar definitivamente) para
      // mantener el ancho/alineación de la columna igual que en activos.
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check_circle,
                color: AppColors.disp, size: 24),
            tooltip: 'Reactivar empleado',
            onPressed: () => _reactivarUsuario(usuario),
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever,
                color: AppColors.error, size: 24),
            tooltip: 'Borrar definitivamente',
            onPressed: () => _borrarDefinitivamente(usuario),
          ),
        ],
      );
    }

    // Menú: cambiar rol + suspender
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Botón suspender
        IconButton(
          icon: const Icon(Icons.block, color: AppColors.warningLight, size: 24),
          tooltip: 'Suspender empleado',
          onPressed: () => _suspenderUsuario(usuario),
        ),
        // Cambiar rol
        PopupMenuButton<String>(
          icon: const Icon(Icons.manage_accounts,
              color: Colors.white, size: 26),
          color: AppColors.backgroundDark,
          tooltip: 'Cambiar rol',
          onSelected: (r) => _cambiarRol(usuario, r),
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'camarero',
              child: Text('Camarero',
                  style: TextStyle(color: Colors.white)),
            ),
            PopupMenuItem(
              value: 'cocinero',
              child: Text('Cocinero',
                  style: TextStyle(color: Colors.white)),
            ),
            PopupMenuItem(
              value: 'mesero',
              child: Text('Mesero',
                  style: TextStyle(color: Colors.white)),
            ),
            PopupMenuItem(
              value: 'trabajador',
              child: Text('Trabajador genérico',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Bottom sheet: crear empleado ────────────────────────────────────────────

class _CrearEmpleadoSheet extends StatefulWidget {
  final VoidCallback onCreado;
  final UsuarioService service;

  const _CrearEmpleadoSheet({
    required this.onCreado,
    required this.service,
  });

  @override
  State<_CrearEmpleadoSheet> createState() => _CrearEmpleadoSheetState();
}

class _CrearEmpleadoSheetState extends State<_CrearEmpleadoSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  String _rolSeleccionado = 'camarero';
  bool _guardando = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    try {
      final result = await widget.service.crearEmpleado(
        nombre: _nombreCtrl.text.trim(),
        correo: _correoCtrl.text.trim(),
        rol: _rolSeleccionado,
        telefono: _telefonoCtrl.text.trim(),
      );

      if (!mounted) return;
      final statusCode = result['statusCode'] as int;

      if (statusCode == 200 || statusCode == 201) {
        Navigator.pop(context);
        widget.onCreado();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Empleado creado. Le hemos enviado un correo para activar su cuenta.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppColors.disp,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (statusCode == 403) {
        _mostrarError('No puedes crear este tipo de usuario.');
      } else if (statusCode == 409) {
        _mostrarError('Ya existe un usuario con ese correo.');
      } else {
        final body = result['body'] as Map<String, dynamic>;
        final detail = body['detail']?.toString() ?? 'Error desconocido';
        _mostrarError(detail);
      }
    } catch (e) {
      if (mounted) _mostrarError(e.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: _kSheetBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle visual
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'NUEVO EMPLEADO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 20),

            // Nombre
            _Campo(
              controlador: _nombreCtrl,
              etiqueta: 'Nombre completo',
              icono: Icons.badge_outlined,
              validador: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
            ),
            const SizedBox(height: 14),

            // Correo
            _Campo(
              controlador: _correoCtrl,
              etiqueta: 'Correo electrónico',
              icono: Icons.email_outlined,
              tipoTeclado: TextInputType.emailAddress,
              validador: (v) {
                if (v == null || v.trim().isEmpty) return 'Campo obligatorio';
                final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                if (!regex.hasMatch(v.trim())) return 'Correo no válido';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Rol — solo Camarero y Cocinero
            DropdownButtonFormField<String>(
              initialValue: _rolSeleccionado,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              dropdownColor: _kSheetBg,
              decoration: InputDecoration(
                labelText: 'Rol',
                labelStyle: const TextStyle(color: Colors.white60),
                prefixIcon: const Icon(
                  Icons.work_outline,
                  color: Colors.white60,
                ),
                filled: true,
                fillColor: _kFieldFill,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.button, width: 2),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'camarero',
                  child: Text('Camarero'),
                ),
                DropdownMenuItem(
                  value: 'cocinero',
                  child: Text('Cocinero'),
                ),
              ],
              onChanged: (v) => setState(() => _rolSeleccionado = v!),
            ),
            const SizedBox(height: 14),

            // Teléfono (opcional)
            _Campo(
              controlador: _telefonoCtrl,
              etiqueta: 'Teléfono (opcional)',
              icono: Icons.phone_outlined,
              tipoTeclado: TextInputType.phone,
            ),
            const SizedBox(height: 24),

            // Botón guardar
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.button,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'CREAR EMPLEADO',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Widget campo de texto reutilizable ──────────────────────────────────────

class _Campo extends StatelessWidget {
  final TextEditingController controlador;
  final String etiqueta;
  final IconData icono;
  final TextInputType tipoTeclado;
  final String? Function(String?)? validador;

  const _Campo({
    required this.controlador,
    required this.etiqueta,
    required this.icono,
    this.tipoTeclado = TextInputType.text,
    this.validador,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controlador,
      keyboardType: tipoTeclado,
      style: const TextStyle(color: Colors.white),
      validator: validador,
      decoration: InputDecoration(
        labelText: etiqueta,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(icono, color: Colors.white60),
        filled: true,
        fillColor: _kFieldFill,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.button, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
