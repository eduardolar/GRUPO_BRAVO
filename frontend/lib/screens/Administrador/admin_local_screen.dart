import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../components/bravo_app_bar.dart';
import '../../core/colors_style.dart';
import '../../models/restaurante_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/restaurante_service.dart';

class AdminLocalScreen extends StatefulWidget {
  const AdminLocalScreen({super.key});

  @override
  State<AdminLocalScreen> createState() => _AdminLocalScreenState();
}

class _AdminLocalScreenState extends State<AdminLocalScreen> {
  Restaurante? _restaurante;
  bool _cargando = true;
  String? _error;

  final _service = RestauranteService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final restauranteId =
          context.read<AuthProvider>().usuarioActual?.restauranteId;
      final todos = await _service.obtenerTodos();
      if (!mounted) return;

      Restaurante? encontrado;
      if (restauranteId != null && restauranteId.isNotEmpty) {
        encontrado = todos.cast<Restaurante?>().firstWhere(
          (r) => r?.id == restauranteId,
          orElse: () => null,
        );
      }
      // Fallback: si no hay restauranteId asignado al admin, mostramos el primero
      encontrado ??= todos.isNotEmpty ? todos.first : null;

      setState(() {
        _restaurante = encontrado;
        _cargando = false;
        if (encontrado == null) {
          _error = 'No se encontró información del local.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: const BravoAppBar(title: 'INFORMACIÓN DEL LOCAL'),
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
                Colors.black.withValues(alpha: 0.5),
                Colors.black.withValues(alpha: 0.88),
              ],
            ),
          ),
          child: SafeArea(
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_cargando) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.button),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                color: Colors.white54,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.button,
                  foregroundColor: Colors.white,
                ),
                onPressed: _cargar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final r = _restaurante!;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera con nombre del local
          _buildHeader(r),
          const SizedBox(height: 24),

          // Tarjetas de información
          _buildInfoCard(
            icono: Icons.storefront_outlined,
            titulo: 'Nombre',
            valor: r.nombre,
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            icono: Icons.location_on_outlined,
            titulo: 'Dirección',
            valor: r.direccion.isNotEmpty ? r.direccion : 'No especificada',
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            icono: Icons.qr_code_outlined,
            titulo: 'Código de sucursal',
            valor: r.codigo.isNotEmpty ? r.codigo : 'Sin código',
          ),
          const SizedBox(height: 12),

          // Horario en una fila con dos campos
          _buildHorarioCard(r),
          const SizedBox(height: 12),

          // Estado
          _buildEstadoCard(r),
          const SizedBox(height: 32),

          // Nota informativa
          _buildNotaSutil(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeader(Restaurante r) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
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
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.button.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.button.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.storefront,
                  color: AppColors.button,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.nombre,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      r.activo ? 'Local activo' : 'Local inactivo',
                      style: TextStyle(
                        color: r.activo
                            ? AppColors.disp
                            : AppColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icono,
    required String titulo,
    required String valor,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12, width: 1),
          ),
          child: Row(
            children: [
              Icon(icono, color: AppColors.button, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      valor,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorarioCard(Restaurante r) {
    final apertura = r.horarioApertura ?? '—';
    final cierre = r.horarioCierre ?? '—';

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12, width: 1),
          ),
          child: Row(
            children: [
              const Icon(Icons.schedule_outlined,
                  color: AppColors.button, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'HORARIO',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _horaChip('Apertura', apertura, Colors.green),
                        const SizedBox(width: 12),
                        _horaChip('Cierre', cierre, AppColors.error),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _horaChip(String etiqueta, String hora, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: TextStyle(
            color: color.withValues(alpha: 0.8),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          hora,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEstadoCard(Restaurante r) {
    final abierto = r.estaAbierto();
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12, width: 1),
          ),
          child: Row(
            children: [
              Icon(
                abierto ? Icons.door_front_door_outlined : Icons.no_meals,
                color: abierto ? AppColors.disp : Colors.white38,
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ESTADO ACTUAL',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      abierto ? 'Abierto ahora' : 'Cerrado ahora',
                      style: TextStyle(
                        color: abierto ? AppColors.disp : Colors.white54,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotaSutil() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.white30, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Para modificar estos datos contacta con el administrador general.',
              style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
