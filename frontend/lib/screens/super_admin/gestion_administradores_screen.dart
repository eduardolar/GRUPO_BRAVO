import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/usuario_model.dart';
import '../../services/usuario_service.dart';
import '../../core/colors_style.dart';

class GestionAdministradorScreen extends StatefulWidget {
  final String rolAFiltrar;
  const GestionAdministradorScreen({super.key, required this.rolAFiltrar});

  @override
  State<GestionAdministradorScreen> createState() => _GestionAdministradorScreen();
}

class _GestionAdministradorScreen extends State<GestionAdministradorScreen> {
  final UsuarioService _usuarioService = UsuarioService();

  String get _titulo {
    final r = widget.rolAFiltrar.toLowerCase();
    if (r == 'administrador' || r == 'admin') return 'Administradores';
    return '${widget.rolAFiltrar}es';
  }

  List<Usuario> _filtrar(List<Usuario> todos) {
    return todos.where((u) {
      final rolDelUsuario = u.rol.toString().split('.').last.toLowerCase();
      String filtro = widget.rolAFiltrar.toLowerCase();
      if (filtro == 'admin') { filtro = 'administrador'; }
      else if (filtro == 'superadmin') { filtro = 'superadministrador'; }
      return rolDelUsuario == filtro;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<List<Usuario>>(
        future: _usuarioService.obtenerTodos(),
        builder: (context, snapshot) {
          final lista = snapshot.hasData ? _filtrar(snapshot.data!) : <Usuario>[];

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: AppColors.button,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  _titulo,
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: Colors.white),
                ),
                actions: [
                  if (snapshot.hasData)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Center(
                        child: Text(
                          '${lista.length}',
                          style: GoogleFonts.manrope(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: AppColors.button)),
                )
              else if (snapshot.hasError)
                SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'Error al cargar datos: ${snapshot.error}',
                      style: GoogleFonts.manrope(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else if (lista.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_outline, size: 64, color: AppColors.line),
                        const SizedBox(height: 16),
                        Text(
                          'No hay $_titulo registrados',
                          style: GoogleFonts.manrope(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: Row(
                      children: [
                        Container(width: 3, height: 18, color: AppColors.button),
                        const SizedBox(width: 10),
                        Text(
                          _titulo.toUpperCase(),
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: _AdminTile(
                            usuario: lista[index],
                            onDelete: () => _confirmarBorrado(context, lista[index]),
                          ),
                        ),
                      ),
                      childCount: lista.length,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
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
          '¿Confirmas la eliminación de ${user.nombre}?',
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
              final borrado = await _usuarioService.eliminarUsuario(user.id);
              if (borrado) {
                if (!mounted) return;
                nav.pop();
                setState(() {});
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Usuario eliminado', style: GoogleFonts.manrope()),
                    backgroundColor: AppColors.button,
                  ),
                );
              }
            },
            child: Text(
              'Eliminar',
              style: GoogleFonts.manrope(color: AppColors.error, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  final Usuario usuario;
  final VoidCallback onDelete;

  const _AdminTile({required this.usuario, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final initials = usuario.nombre.isNotEmpty
        ? usuario.nombre.trim().split(' ').map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').take(2).join()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 72,
            color: AppColors.button,
            alignment: Alignment.center,
            child: Text(
              initials,
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  usuario.nombre,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${usuario.email} · ${usuario.rol.name}',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: AppColors.error.withValues(alpha: 0.7), size: 22),
            onPressed: onDelete,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
