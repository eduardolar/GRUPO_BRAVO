import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/restaurante_model.dart';
import '../../providers/restaurante_provider.dart';
import '../../providers/usuario_provider.dart';
import 'sucursal_detail_screen.dart';
import '../../core/colors_style.dart';

class SeleccionarRestauranteScreen extends StatefulWidget {
  const SeleccionarRestauranteScreen({super.key});

  @override
  State<SeleccionarRestauranteScreen> createState() =>
      _SeleccionarRestauranteScreenState();
}

class _SeleccionarRestauranteScreenState
    extends State<SeleccionarRestauranteScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RestauranteProvider>().cargar();
      context.read<UsuarioProvider>().cargar();
    });
  }

  static String? _validarHora(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final parts = v.trim().split(':');
    if (parts.length != 2) return 'Usa el formato HH:MM';
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return 'Hora inválida (00:00 – 23:59)';
    }
    return null;
  }

  // ── DIÁLOGO CREAR / EDITAR ────────────────────────────────────────
  Future<void> _mostrarFormulario({Restaurante? restaurante}) async {
    final nombreCtrl = TextEditingController(text: restaurante?.nombre ?? '');
    final direccionCtrl = TextEditingController(
      text: restaurante?.direccion ?? '',
    );
    final aperturaCtrl = TextEditingController(
      text: restaurante?.horarioApertura ?? '',
    );
    final cierreCtrl = TextEditingController(
      text: restaurante?.horarioCierre ?? '',
    );
    final formKey = GlobalKey<FormState>();
    final esEdicion = restaurante != null;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: const RoundedRectangleBorder(),
        title: Text(
          esEdicion ? 'Editar sucursal' : 'Nueva sucursal',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nombreCtrl,
                style: GoogleFonts.manrope(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Nombre',
                  labelStyle: GoogleFonts.manrope(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  prefixIcon: const Icon(
                    Icons.storefront_outlined,
                    color: AppColors.button,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: AppColors.line),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: AppColors.button, width: 1.5),
                  ),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Campo obligatorio' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: direccionCtrl,
                style: GoogleFonts.manrope(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Dirección',
                  labelStyle: GoogleFonts.manrope(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  prefixIcon: const Icon(
                    Icons.location_on_outlined,
                    color: AppColors.button,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: AppColors.line),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: AppColors.button, width: 1.5),
                  ),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Campo obligatorio' : null,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: aperturaCtrl,
                      style: GoogleFonts.manrope(color: AppColors.textPrimary),
                      keyboardType: TextInputType.datetime,
                      decoration: InputDecoration(
                        labelText: 'Apertura (HH:MM)',
                        labelStyle: GoogleFonts.manrope(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        hintText: '09:00',
                        hintStyle: GoogleFonts.manrope(
                          fontSize: 12,
                          color: AppColors.line,
                        ),
                        prefixIcon: const Icon(
                          Icons.schedule_outlined,
                          color: AppColors.button,
                          size: 18,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: AppColors.line),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(
                            color: AppColors.button,
                            width: 1.5,
                          ),
                        ),
                      ),
                      validator: _validarHora,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: cierreCtrl,
                      style: GoogleFonts.manrope(color: AppColors.textPrimary),
                      keyboardType: TextInputType.datetime,
                      decoration: InputDecoration(
                        labelText: 'Cierre (HH:MM)',
                        labelStyle: GoogleFonts.manrope(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        hintText: '23:00',
                        hintStyle: GoogleFonts.manrope(
                          fontSize: 12,
                          color: AppColors.line,
                        ),
                        prefixIcon: const Icon(
                          Icons.schedule_outlined,
                          color: AppColors.button,
                          size: 18,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: AppColors.line),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(
                            color: AppColors.button,
                            width: 1.5,
                          ),
                        ),
                      ),
                      validator: _validarHora,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.manrope(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: Text(
              esEdicion ? 'GUARDAR' : 'CREAR',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                color: AppColors.button,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;

    final nombre = nombreCtrl.text.trim();
    final direccion = direccionCtrl.text.trim();
    final apertura = aperturaCtrl.text.trim();
    final cierre = cierreCtrl.text.trim();
    final provider = context.read<RestauranteProvider>();

    if (esEdicion) {
      final ok = await provider.editar(
        id: restaurante.id,
        nombre: nombre,
        direccion: direccion,
        horarioApertura: apertura,
        horarioCierre: cierre,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok ? 'Sucursal actualizada' : 'Error al actualizar',
              style: GoogleFonts.manrope(),
            ),
            backgroundColor: ok ? AppColors.button : AppColors.error,
          ),
        );
      }
    } else {
      final ok = await provider.crear(nombre: nombre, direccion: direccion);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok ? 'Sucursal creada' : 'Error al crear',
              style: GoogleFonts.manrope(),
            ),
            backgroundColor: ok ? AppColors.button : AppColors.error,
          ),
        );
      }
    }
  }

  // ── CONFIRMAR BORRADO ─────────────────────────────────────────────
  Future<void> _confirmarBorrado(Restaurante restaurante) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: const RoundedRectangleBorder(),
        title: Text(
          '¿Eliminar sucursal?',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Se eliminará "${restaurante.nombre}" permanentemente. Esta acción no se puede deshacer.',
          style: GoogleFonts.manrope(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.manrope(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
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

    if (confirmado != true || !mounted) return;

    final ok = await context.read<RestauranteProvider>().eliminar(
      restaurante.id,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? 'Sucursal eliminada' : 'Error al eliminar',
            style: GoogleFonts.manrope(),
          ),
          backgroundColor: ok ? AppColors.button : AppColors.error,
        ),
      );
    }
  }

  // ── TOGGLE ACTIVO ──────────────────────────────────────────────────
  Future<void> _toggleActivo(Restaurante restaurante, bool nuevoEstado) async {
    final accion = nuevoEstado ? 'activar' : 'suspender';
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: const RoundedRectangleBorder(),
        title: Text(
          nuevoEstado ? 'Activar sucursal' : 'Suspender sucursal',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
        content: Text(
          nuevoEstado
              ? '¿Deseas activar "${restaurante.nombre}"? Volverá a aceptar pedidos.'
              : '¿Deseas suspender "${restaurante.nombre}"? No se aceptarán nuevos pedidos mientras esté suspendida.',
          style: GoogleFonts.manrope(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.manrope(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              nuevoEstado ? 'ACTIVAR' : 'SUSPENDER',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                color: nuevoEstado ? AppColors.button : AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    final ok = await context.read<RestauranteProvider>().toggleActivo(
      restaurante.id,
      nuevoEstado,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Sucursal ${nuevoEstado ? "activada" : "suspendida"}'
                : 'Error al $accion la sucursal',
            style: GoogleFonts.manrope(),
          ),
          backgroundColor: ok
              ? (nuevoEstado ? AppColors.button : AppColors.error)
              : AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _mostrarFormulario();
        },
        backgroundColor: AppColors.button,
        elevation: 4,
        shape: const RoundedRectangleBorder(),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'NUEVA SUCURSAL',
          style: GoogleFonts.manrope(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: Container(
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
                Colors.black.withValues(alpha: 0.55),
                Colors.black.withValues(alpha: 0.88),
              ],
            ),
          ),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: screenHeight * 0.42,
                pinned: true,
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                iconTheme: const IconThemeData(color: Colors.white),
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  background: _HeroHeader(),
                  title: Text(
                    'GRUPO BRAVO',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  centerTitle: true,
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
                  child: Row(
                    children: [
                      Container(width: 3, height: 18, color: AppColors.button),
                      const SizedBox(width: 10),
                      Text(
                        'SUCURSALES',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white70,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Consumer<UsuarioProvider>(
                builder: (context, usuarioProvider, _) {
                  return Consumer<RestauranteProvider>(
                    builder: (context, provider, _) {
                      if (provider.cargando) {
                        return const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding: EdgeInsets.only(top: 48),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppColors.button,
                              ),
                            ),
                          ),
                        );
                      }

                      if (provider.error != null) {
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyState(
                            icon: Icons.wifi_off_outlined,
                            mensaje:
                                'No se pudieron cargar las sucursales.\nComprueba tu conexión e inténtalo de nuevo.',
                          ),
                        );
                      }

                      if (provider.restaurantes.isEmpty) {
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyState(
                            icon: Icons.storefront_outlined,
                            mensaje: 'No hay sucursales registradas todavía.',
                          ),
                        );
                      }

                      final restaurantes = provider.restaurantes;
                      return SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 100),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 640,
                                ),
                                child: _RestauranteCard(
                                  restaurante: restaurantes[index],
                                  numero: index + 1,
                                  personalCount: usuarioProvider.usuarios.where(
                                    (u) {
                                      final idDB = (u.restauranteId ?? '')
                                          .toString()
                                          .trim()
                                          .toLowerCase();
                                      return idDB ==
                                              restaurantes[index].id
                                                  .trim()
                                                  .toLowerCase() &&
                                          u.rolRaw != 'cliente' &&
                                          u.rolRaw != 'superadministrador';
                                    },
                                  ).length,
                                  onEdit: () {
                                    _mostrarFormulario(
                                      restaurante: restaurantes[index],
                                    );
                                  },
                                  onDelete: () {
                                    _confirmarBorrado(restaurantes[index]);
                                  },
                                  onToggleActivo: (v) =>
                                      _toggleActivo(restaurantes[index], v),
                                ),
                              ),
                            ),
                            childCount: restaurantes.length,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── HERO HEADER ────────────────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/Bravo restaurante.jpg',
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.35, 0.70, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.20),
                  Colors.black.withValues(alpha: 0.70),
                  Colors.black.withValues(alpha: 0.95),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white60, width: 1.2),
                  ),
                  child: Text(
                    'EST. 2024',
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'GRUPO BRAVO',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Playfair Display',
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 16)],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Panel de Administración',
                  style: GoogleFonts.manrope(
                    color: Colors.white70,
                    fontSize: 13,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 32, height: 1, color: Colors.white30),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.admin_panel_settings_outlined,
                      color: Colors.white54,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Container(width: 32, height: 1, color: Colors.white30),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── TARJETA DE RESTAURANTE ──────────────────────────────────────────
class _RestauranteCard extends StatelessWidget {
  final Restaurante restaurante;
  final int numero;
  final int personalCount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleActivo;

  const _RestauranteCard({
    required this.restaurante,
    required this.numero,
    required this.personalCount,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActivo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Número de sucursal
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SucursalDetailScreen(
                    restauranteId: restaurante.id,
                    restauranteNombre: restaurante.nombre,
                  ),
                ),
              ),
              child: Container(
                width: 52,
                color: AppColors.button,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  numero.toString().padLeft(2, '0'),
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),

            // Info
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SucursalDetailScreen(
                      restauranteId: restaurante.id,
                      restauranteNombre: restaurante.nombre,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre + badge abierto/cerrado
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              restaurante.nombre,
                              style: GoogleFonts.manrope(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          restaurante.activo
                              ? _BadgeEstado(abierto: restaurante.estaAbierto())
                              : _BadgeSuspendida(),
                        ],
                      ),
                      const SizedBox(height: 5),
                      // Direccion
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              restaurante.direccion,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Horario + Personal
                      Row(
                        children: [
                          if (restaurante.horarioApertura != null &&
                              restaurante.horarioCierre != null) ...[
                            const Icon(
                              Icons.schedule_outlined,
                              size: 13,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${restaurante.horarioApertura!} - ${restaurante.horarioCierre!}',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          const Icon(
                            Icons.badge_outlined,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$personalCount empleados',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'GESTIONAR',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.button,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Acciones editar / borrar / suspender
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: AppColors.button,
                      ),
                      onPressed: onEdit,
                      tooltip: 'Editar',
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: AppColors.error.withValues(alpha: 0.8),
                      ),
                      onPressed: onDelete,
                      tooltip: 'Eliminar',
                    ),
                  ],
                ),
                Tooltip(
                  message: restaurante.activo
                      ? 'Suspender sucursal'
                      : 'Activar sucursal',
                  child: Transform.scale(
                    scale: 0.75,
                    child: Switch.adaptive(
                      value: restaurante.activo,
                      activeThumbColor: AppColors.button,
                      inactiveThumbColor: AppColors.error,
                      onChanged: onToggleActivo,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── ESTADO VACÍO ────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String mensaje;

  const _EmptyState({required this.icon, required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.line),
            const SizedBox(height: 16),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── BADGE ABIERTO / CERRADO ──────────────────────────────────────────
class _BadgeEstado extends StatelessWidget {
  final bool abierto;
  const _BadgeEstado({required this.abierto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: abierto
            ? const Color(0xFF2E7D32).withValues(alpha: 0.10)
            : AppColors.error.withValues(alpha: 0.10),
        border: Border.all(
          color: abierto
              ? const Color(0xFF2E7D32).withValues(alpha: 0.40)
              : AppColors.error.withValues(alpha: 0.40),
        ),
      ),
      child: Text(
        abierto ? 'ABIERTO' : 'CERRADO',
        style: GoogleFonts.manrope(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          color: abierto ? const Color(0xFF2E7D32) : AppColors.error,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// ── BADGE SUSPENDIDA ────────────────────────────────────────────────
class _BadgeSuspendida extends StatelessWidget {
  const _BadgeSuspendida();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.45)),
      ),
      child: Text(
        'SUSPENDIDA',
        style: GoogleFonts.manrope(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          color: AppColors.error,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
