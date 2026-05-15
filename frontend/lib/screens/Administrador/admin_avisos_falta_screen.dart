import 'package:flutter/material.dart';
import 'package:frontend/components/bravo_app_bar.dart';
import 'package:frontend/core/app_snackbar.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/services/aviso_falta_service.dart';

class AdminAvisosFaltaScreen extends StatefulWidget {
  const AdminAvisosFaltaScreen({super.key});

  @override
  State<AdminAvisosFaltaScreen> createState() => _AdminAvisosFaltaScreenState();
}

class _AdminAvisosFaltaScreenState extends State<AdminAvisosFaltaScreen> {
  List<Map<String, dynamic>> _avisos = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await AvisoFaltaService.listar(estado: 'pendiente');
      if (!mounted) return;
      setState(() {
        _avisos = lista;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _marcarAtendido(Map<String, dynamic> aviso) async {
    final id = (aviso['id'] ?? aviso['_id'])?.toString();
    if (id == null) return;
    try {
      await AvisoFaltaService.marcarAtendido(id);
      if (!mounted) return;
      setState(() => _avisos.removeWhere(
            (a) => (a['id'] ?? a['_id'])?.toString() == id,
          ));
      showAppSuccess(context, 'Aviso marcado como atendido.');
    } catch (e) {
      if (!mounted) return;
      handleApiError(context, e, prefix: 'No se pudo marcar el aviso');
    }
  }

  String _formatFecha(dynamic valor) {
    if (valor == null) return '';
    try {
      final dt = DateTime.parse(valor.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return valor.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: const BravoAppBar(title: 'AVISOS DE FALTA DE STOCK'),
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
                Colors.black.withValues(alpha: 0.85),
              ],
            ),
          ),
          child: SafeArea(
            child: RefreshIndicator(
              color: AppColors.button,
              backgroundColor: Colors.black87,
              onRefresh: _cargar,
              child: _buildBody(),
            ),
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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _cargar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.button,
                ),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_avisos.isEmpty) {
      return ListView(
        // AlwaysScrollable para que el pull-to-refresh funcione en vacío
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 56,
                  color: Colors.white38,
                ),
                SizedBox(height: 16),
                Text(
                  'Sin avisos pendientes',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'El inventario está bajo control.',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: _avisos.length,
      itemBuilder: (_, i) => _AvisoCard(
        aviso: _avisos[i],
        formatFecha: _formatFecha,
        onAtendido: () => _marcarAtendido(_avisos[i]),
      ),
    );
  }
}

// ── Tarjeta de aviso individual ───────────────────────────────────────────────

class _AvisoCard extends StatelessWidget {
  final Map<String, dynamic> aviso;
  final String Function(dynamic) formatFecha;
  final VoidCallback onAtendido;

  const _AvisoCard({
    required this.aviso,
    required this.formatFecha,
    required this.onAtendido,
  });

  @override
  Widget build(BuildContext context) {
    final nombre =
        (aviso['ingredienteNombre'] ?? aviso['nombre'] ?? '—').toString();
    final fecha = formatFecha(aviso['creadoEn'] ?? aviso['creado_en']);
    final creadoPor =
        (aviso['creadoPor'] ?? aviso['creado_por'] ?? '').toString();
    final notas = (aviso['notas'] ?? '').toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nombre,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (fecha.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                fecha,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
            if (creadoPor.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Por: $creadoPor',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
            if (notas.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  notas,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.disp,
                  side: const BorderSide(color: AppColors.disp),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                onPressed: onAtendido,
                icon: const Icon(Icons.check, size: 16),
                label: const Text(
                  'Marcar atendido',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
