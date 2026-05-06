import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/models/ingrediente_model.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/ingredientes_service.dart';
import 'package:provider/provider.dart';

class AdminDuplicadosScreen extends StatefulWidget {
  const AdminDuplicadosScreen({super.key});

  @override
  State<AdminDuplicadosScreen> createState() => _AdminDuplicadosScreenState();
}

class _AdminDuplicadosScreenState extends State<AdminDuplicadosScreen> {
  List<_GrupoDuplicado> _grupos = [];
  bool _cargando = true;
  String? _errorCarga;
  String? _restauranteId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _restauranteId = context
          .read<AuthProvider>()
          .usuarioActual
          ?.restauranteId;
      _cargar();
    });
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final raw = await IngredienteService.obtenerDuplicados(
        restauranteId: _restauranteId,
      );
      if (!mounted) return;
      setState(() {
        _grupos = raw.map(_GrupoDuplicado.fromJson).toList();
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorCarga = e.toString();
      });
    }
  }

  Future<void> _fusionar(_GrupoDuplicado grupo) async {
    final absorberIds = grupo.candidatos
        .where((c) => c.id != grupo.principalSeleccionado)
        .map((c) => c.id)
        .toList();

    if (absorberIds.isEmpty) return;

    try {
      final result = await IngredienteService.fusionarIngredientes(
        principalId: grupo.principalSeleccionado,
        absorberIds: absorberIds,
      );
      if (!mounted) return;
      final fusionados = result['fusionados'] ?? absorberIds.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$fusionados fusionados'),
          backgroundColor: AppColors.disp,
        ),
      );
      _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al fusionar: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'DUPLICADOS DE INGREDIENTES',
          style: TextStyle(
            color: AppColors.textAppBar,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Recargar',
            onPressed: _cargando ? null : _cargar,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
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
                      Colors.black.withValues(alpha: 0.9),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: _cargando
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.button),
                  )
                : _errorCarga != null
                ? _buildError()
                : _grupos.isEmpty
                ? _buildVacio()
                : RefreshIndicator(
                    color: AppColors.button,
                    onRefresh: _cargar,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      itemCount: _grupos.length,
                      itemBuilder: (_, i) => _GrupoCard(
                        grupo: _grupos[i],
                        onPrincipalChanged: (id) {
                          setState(() => _grupos[i].principalSeleccionado = id);
                        },
                        onFusionar: () => _fusionar(_grupos[i]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildVacio() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.check_circle_outline, size: 64, color: AppColors.disp),
          SizedBox(height: 16),
          Text(
            'Tu inventario está limpio',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'No se encontraron ingredientes duplicados',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 52, color: AppColors.error),
            const SizedBox(height: 12),
            const Text(
              'No se pudo cargar los duplicados',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              _errorCarga ?? '',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.button,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Modelo local de grupo ────────────────────────────────────────────────────

class _GrupoDuplicado {
  final String nombre;
  final List<Ingrediente> candidatos;
  String principalSeleccionado;

  _GrupoDuplicado({
    required this.nombre,
    required this.candidatos,
    required this.principalSeleccionado,
  });

  factory _GrupoDuplicado.fromJson(Map<String, dynamic> json) {
    final candidatos = (json['ingredientes'] as List? ?? [])
        .map((e) => Ingrediente.fromJson(e as Map<String, dynamic>))
        .toList();
    // El backend sugiere el principal (mayor stock). Si no lo proporciona,
    // se usa el primero de la lista.
    final principalId = (json['principal'] as Map<String, dynamic>?)?['id'] ??
        (json['principal'] as Map<String, dynamic>?)?['_id'] ??
        (candidatos.isNotEmpty ? candidatos.first.id : '');
    return _GrupoDuplicado(
      nombre: json['nombre'] as String? ?? '',
      candidatos: candidatos,
      principalSeleccionado: principalId as String,
    );
  }
}

// ─── Card de grupo ────────────────────────────────────────────────────────────

class _GrupoCard extends StatelessWidget {
  final _GrupoDuplicado grupo;
  final ValueChanged<String> onPrincipalChanged;
  final VoidCallback onFusionar;

  const _GrupoCard({
    required this.grupo,
    required this.onPrincipalChanged,
    required this.onFusionar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cabecera del grupo
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  decoration: BoxDecoration(
                    color: AppColors.button.withValues(alpha: 0.2),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.button,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          grupo.nombre,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.button.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${grupo.candidatos.length} duplicados',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // RadioGroup gestiona el valor seleccionado y accesibilidad
                // de teclado sin necesidad de pasar groupValue a cada Radio.
                RadioGroup<String>(
                  groupValue: grupo.principalSeleccionado,
                  onChanged: (id) {
                    if (id != null) onPrincipalChanged(id);
                  },
                  child: Column(
                    children: grupo.candidatos.map(
                      (ing) => _CandidatoTile(
                        ingrediente: ing,
                        esPrincipal: ing.id == grupo.principalSeleccionado,
                      ),
                    ).toList(),
                  ),
                ),
                // Botón de fusión
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: onFusionar,
                      icon: const Icon(Icons.merge_type, size: 18),
                      label: const Text(
                        'FUSIONAR',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.button,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Fila de candidato ────────────────────────────────────────────────────────

class _CandidatoTile extends StatelessWidget {
  final Ingrediente ingrediente;
  final bool esPrincipal;

  const _CandidatoTile({
    required this.ingrediente,
    required this.esPrincipal,
  });

  @override
  Widget build(BuildContext context) {
    final ing = ingrediente;
    // El RadioGroup ancestro gestiona groupValue y onChanged; Radio solo
    // necesita value para que el grupo lo identifique correctamente.
    return InkWell(
      onTap: () => RadioGroup.maybeOf<String>(context)?.onChanged(ing.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Radio<String>(
              value: ing.id,
              activeColor: AppColors.button,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        ing.nombre,
                        style: TextStyle(
                          color: esPrincipal ? Colors.white : Colors.white70,
                          fontWeight: esPrincipal
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      if (esPrincipal) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.disp.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'PRINCIPAL',
                            style: TextStyle(
                              color: AppColors.disp,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '${ing.categoria} · ${_fmt(ing.cantidadActual)} ${ing.unidad}',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (!esPrincipal)
              const Icon(
                Icons.arrow_forward,
                size: 14,
                color: Colors.white24,
              ),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
}
