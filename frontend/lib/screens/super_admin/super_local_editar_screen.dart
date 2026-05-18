import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../components/bravo_app_bar.dart';
import '../../core/app_snackbar.dart';
import '../../core/colors_style.dart';
import '../../models/restaurante_model.dart';
import '../../services/http_client.dart';
import '../../services/restaurante_service.dart';
import '../../services/super_admin_service.dart';
import '../shared/restaurante_editor/components/glass_card.dart';
import '../shared/restaurante_editor/components/campo_form.dart';
import '../shared/restaurante_editor/components/selector_hora.dart';

// ─── Constantes locales ───────────────────────────────────────────────────────

// Copiado de admin_editar_plato.dart para mantener independencia entre roles.
const int _kMaxLogoBytes = 5 * 1024 * 1024; // 5 MB
const List<String> _kMimesPermitidos = ['image/jpeg', 'image/png', 'image/webp'];

/// Slugs de métodos de pago y sus etiquetas legibles.
const List<_MetodoPago> _kMetodosPago = [
  _MetodoPago('efectivo', 'Efectivo', Icons.payments_outlined),
  _MetodoPago('tarjeta', 'Tarjeta', Icons.credit_card_outlined),
  _MetodoPago('paypal', 'PayPal', Icons.account_balance_wallet_outlined),
  _MetodoPago('google_pay', 'Google Pay', Icons.phone_android_outlined),
  _MetodoPago('stripe', 'Stripe', Icons.bolt_outlined),
];

/// Días de la semana en el orden que espera el backend.
const List<_DiaSemana> _kDias = [
  _DiaSemana('lunes', 'Lunes'),
  _DiaSemana('martes', 'Martes'),
  _DiaSemana('miercoles', 'Miércoles'),
  _DiaSemana('jueves', 'Jueves'),
  _DiaSemana('viernes', 'Viernes'),
  _DiaSemana('sabado', 'Sábado'),
  _DiaSemana('domingo', 'Domingo'),
];

class _MetodoPago {
  final String slug;
  final String etiqueta;
  final IconData icono;
  const _MetodoPago(this.slug, this.etiqueta, this.icono);
}

class _DiaSemana {
  final String clave;
  final String etiqueta;
  const _DiaSemana(this.clave, this.etiqueta);
}

// ─── Pantalla ─────────────────────────────────────────────────────────────────

/// Pantalla de edición avanzada de una sucursal para el super_admin.
///
/// Cubre: datos básicos, logo, horarios por día, datos fiscales y métodos
/// de pago. Envía al backend únicamente los campos que han cambiado respecto
/// al [restaurante] original.
class SuperLocalEditarScreen extends StatefulWidget {
  final Restaurante restaurante;

  const SuperLocalEditarScreen({super.key, required this.restaurante});

  @override
  State<SuperLocalEditarScreen> createState() => _SuperLocalEditarScreenState();
}

class _SuperLocalEditarScreenState extends State<SuperLocalEditarScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Datos básicos ─────────────────────────────────────────────────────────
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _direccionCtrl;
  late final TextEditingController _codigoCtrl;

  // ── Logo ──────────────────────────────────────────────────────────────────
  String? _logoUrl;
  // Bytes de logo elegido en esta sesión (aún no subido).
  Uint8List? _logoBytes;
  String? _logoNombre;
  String? _logoMime;
  bool _subiendoLogo = false;

  // ── Horarios por día ──────────────────────────────────────────────────────
  /// Mapa editable de horarios. Clave = clave del día ("lunes"…).
  late Map<String, HorarioDia> _horariosDia;

  // ── Datos fiscales ────────────────────────────────────────────────────────
  late final TextEditingController _cifCtrl;
  late final TextEditingController _razonSocialCtrl;
  late final TextEditingController _dirFiscalCtrl;
  late final TextEditingController _cpCtrl;
  late final TextEditingController _ciudadCtrl;
  late final TextEditingController _provinciaCtrl;
  late final TextEditingController _paisCtrl;

  // ── Métodos de pago ───────────────────────────────────────────────────────
  late Set<String> _metodosPago;

  bool _guardando = false;
  bool _eliminandoSucursal = false;

  @override
  void initState() {
    super.initState();
    final r = widget.restaurante;

    _nombreCtrl = TextEditingController(text: r.nombre);
    _direccionCtrl = TextEditingController(text: r.direccion);
    _codigoCtrl = TextEditingController(text: r.codigo);

    _logoUrl = r.logoUrl;

    // Inicializar horarios: si el restaurante ya tiene horarios por día los
    // usamos; si no, creamos la estructura con todos los días cerrados y
    // horario por defecto 09:00–23:00.
    _horariosDia = {};
    for (final dia in _kDias) {
      _horariosDia[dia.clave] =
          r.horariosDia?[dia.clave] ?? const HorarioDia();
    }

    _cifCtrl = TextEditingController(text: r.cif ?? '');
    _razonSocialCtrl = TextEditingController(text: r.razonSocial ?? '');
    _dirFiscalCtrl = TextEditingController(text: r.direccionFiscal ?? '');
    _cpCtrl = TextEditingController(text: r.codigoPostal ?? '');
    _ciudadCtrl = TextEditingController(text: r.ciudad ?? '');
    _provinciaCtrl = TextEditingController(text: r.provincia ?? '');
    _paisCtrl = TextEditingController(
      text: r.pais?.isNotEmpty == true ? r.pais! : 'España',
    );

    _metodosPago = Set<String>.from(r.metodosPago);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _direccionCtrl.dispose();
    _codigoCtrl.dispose();
    _cifCtrl.dispose();
    _razonSocialCtrl.dispose();
    _dirFiscalCtrl.dispose();
    _cpCtrl.dispose();
    _ciudadCtrl.dispose();
    _provinciaCtrl.dispose();
    _paisCtrl.dispose();
    super.dispose();
  }

  // ── Logo ──────────────────────────────────────────────────────────────────

  Future<void> _elegirLogo() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final mime = picked.mimeType ?? _inferirMime(picked.name);

      if (!_kMimesPermitidos.contains(mime)) {
        if (mounted) showAppError(context, 'Solo se admiten JPG, PNG o WebP');
        return;
      }
      if (bytes.length > _kMaxLogoBytes) {
        if (mounted) showAppError(context, 'El logo supera los 5 MB');
        return;
      }

      setState(() {
        _logoBytes = bytes;
        _logoNombre = picked.name;
        _logoMime = mime;
      });
    } on MissingPluginException {
      if (mounted) {
        showAppError(
          context,
          'Selector de imágenes no disponible en esta plataforma',
        );
      }
    } catch (_) {
      if (mounted) showAppError(context, 'Error al seleccionar el logo');
    }
  }

  Future<void> _subirLogo() async {
    final bytes = _logoBytes;
    if (bytes == null) return;
    setState(() => _subiendoLogo = true);
    try {
      final res = await RestauranteService.subirLogo(
        id: widget.restaurante.id,
        bytes: bytes,
        nombreArchivo: _logoNombre ?? 'logo.jpg',
        contentType: _logoMime ?? 'image/jpeg',
      );
      setState(() {
        _logoUrl = res['logo_url'] as String?;
        _logoBytes = null;
        _logoNombre = null;
        _logoMime = null;
      });
      if (mounted) showAppSuccess(context, 'Logo actualizado');
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 503) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Subida no disponible. Configura Cloudinary.'),
            backgroundColor: AppColors.warningText,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        showAppError(context, e.message);
      }
    } catch (_) {
      if (mounted) showAppError(context, 'Error al subir el logo');
    } finally {
      if (mounted) setState(() => _subiendoLogo = false);
    }
  }

  Future<void> _eliminarLogo() async {
    setState(() => _subiendoLogo = true);
    try {
      await RestauranteService.eliminarLogo(widget.restaurante.id);
      setState(() {
        _logoUrl = null;
        _logoBytes = null;
      });
      if (mounted) showAppSuccess(context, 'Logo eliminado');
    } on ApiException catch (e) {
      if (mounted) showAppError(context, e.message);
    } catch (_) {
      if (mounted) showAppError(context, 'Error al eliminar el logo');
    } finally {
      if (mounted) setState(() => _subiendoLogo = false);
    }
  }

  String _inferirMime(String nombre) {
    final ext = nombre.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'application/octet-stream',
    };
  }

  // ── Selector de hora ──────────────────────────────────────────────────────

  Future<String?> _elegirHora(BuildContext context, String horaActual) async {
    final partes = horaActual.split(':');
    final h = int.tryParse(partes.isNotEmpty ? partes[0] : '9') ?? 9;
    final m = int.tryParse(partes.length > 1 ? partes[1] : '0') ?? 0;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: h, minute: m),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.primaryOnDark,
            onPrimary: Colors.white,
            surface: AppColors.bottomSheetBg,
            onSurface: Colors.white,
          ),
        ),
        child: MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      ),
    );
    if (picked == null) return null;
    return '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
  }

  // ── Aplicar mismo horario a todos los días ────────────────────────────────

  void _aplicarHorarioATodos(HorarioDia modelo) {
    setState(() {
      for (final dia in _kDias) {
        _horariosDia[dia.clave] = modelo;
      }
    });
    showAppSuccess(context, 'Mismo horario aplicado a todos los días');
  }

  // ── Guardar cambios ───────────────────────────────────────────────────────

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    // Si hay bytes de logo nuevos, subir primero.
    if (_logoBytes != null) {
      await _subirLogo();
      if (!mounted) return;
      // Si la subida falló (logoBytes sigue siendo no nulo), abortar.
      if (_logoBytes != null) return;
    }

    setState(() => _guardando = true);

    try {
      final r = widget.restaurante;

      // Solo enviamos campos que han cambiado respecto al original.
      final datos = <String, dynamic>{};

      final nombre = _nombreCtrl.text.trim();
      if (nombre != r.nombre) datos['nombre'] = nombre;

      final direccion = _direccionCtrl.text.trim();
      if (direccion != r.direccion) datos['direccion'] = direccion;

      final codigo = _codigoCtrl.text.trim();
      if (codigo != r.codigo) datos['codigo'] = codigo;

      // Horarios por día — siempre los enviamos si alguno cambió.
      final horariosJson = _horariosDia.map(
        (k, v) => MapEntry(k, v.toJson()),
      );
      // Comparación simple: serializar ambos y comparar strings.
      final horariosOriginalJson = (r.horariosDia ?? {}).map(
        (k, v) => MapEntry(k, v.toJson()),
      );
      if (horariosJson.toString() != horariosOriginalJson.toString()) {
        datos['horarios_dia'] = horariosJson;
      }

      // Datos fiscales
      _agregarSiCambio(datos, 'cif', _cifCtrl.text.trim().toUpperCase(), r.cif ?? '');
      _agregarSiCambio(datos, 'razon_social', _razonSocialCtrl.text.trim(), r.razonSocial ?? '');
      _agregarSiCambio(datos, 'direccion_fiscal', _dirFiscalCtrl.text.trim(), r.direccionFiscal ?? '');
      _agregarSiCambio(datos, 'codigo_postal', _cpCtrl.text.trim(), r.codigoPostal ?? '');
      _agregarSiCambio(datos, 'ciudad', _ciudadCtrl.text.trim(), r.ciudad ?? '');
      _agregarSiCambio(datos, 'provincia', _provinciaCtrl.text.trim(), r.provincia ?? '');
      _agregarSiCambio(datos, 'pais', _paisCtrl.text.trim(), r.pais ?? '');

      // Métodos de pago
      final metodosOrdenados = _metodosPago.toList()..sort();
      final originalesOrdenados = List<String>.from(r.metodosPago)..sort();
      if (metodosOrdenados.join(',') != originalesOrdenados.join(',')) {
        datos['metodos_pago'] = metodosOrdenados;
      }

      if (datos.isEmpty) {
        showAppInfo(context, 'No hay cambios que guardar');
        return;
      }

      await RestauranteService.actualizarRestaurante(
        widget.restaurante.id,
        datos,
      );

      if (mounted) {
        showAppSuccess(context, 'Sucursal actualizada correctamente');
        Navigator.pop(context, true); // devuelve true para refrescar el listado
      }
    } on ApiException catch (e) {
      if (mounted) showAppError(context, e.message);
    } catch (_) {
      if (mounted) showAppError(context, 'Error al guardar los cambios');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _agregarSiCambio(
    Map<String, dynamic> datos,
    String clave,
    String nuevo,
    String original,
  ) {
    if (nuevo != original) datos[clave] = nuevo.isEmpty ? null : nuevo;
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: BravoAppBar(
        title: 'EDITAR ${widget.restaurante.nombre.toUpperCase()}',
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
                Colors.black.withValues(alpha: 0.55),
                Colors.black.withValues(alpha: 0.92),
              ],
            ),
          ),
          child: SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                children: [
                  _buildSeccion('DATOS BÁSICOS', Icons.storefront_outlined),
                  _buildDatosBasicos(),
                  const SizedBox(height: 24),

                  _buildSeccion('LOGO DE LA SUCURSAL', Icons.image_outlined),
                  _buildLogo(),
                  const SizedBox(height: 24),

                  _buildSeccion('HORARIOS POR DÍA', Icons.schedule_outlined),
                  _buildHorarios(),
                  const SizedBox(height: 24),

                  _buildSeccion('DATOS FISCALES', Icons.receipt_long_outlined),
                  _buildDatosFiscales(),
                  const SizedBox(height: 24),

                  _buildSeccion(
                    'MÉTODOS DE PAGO',
                    Icons.payment_outlined,
                  ),
                  _buildMetodosPago(),
                  const SizedBox(height: 32),

                  _buildBotonGuardar(),
                  const SizedBox(height: 24),
                  // Zona destructiva: separada visualmente del guardar para
                  // que no se confunda con la acción principal.
                  Divider(color: Colors.white.withValues(alpha: 0.10)),
                  const SizedBox(height: 12),
                  _buildBotonEliminar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Cabecera de sección ────────────────────────────────────────────────────

  Widget _buildSeccion(String titulo, IconData icono) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(width: 3, height: 18, color: AppColors.detailOnDark),
          const SizedBox(width: 10),
          Icon(icono, color: AppColors.detailOnDark, size: 16),
          const SizedBox(width: 8),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white70,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  // ── Datos básicos ─────────────────────────────────────────────────────────

  Widget _buildDatosBasicos() {
    return GlassCard(
      child: Column(
        children: [
          CampoForm(
            ctrl: _nombreCtrl,
            label: 'Nombre',
            icono: Icons.storefront_outlined,
            validador: (v) =>
                v == null || v.trim().isEmpty ? 'Campo obligatorio' : null,
          ),
          const SizedBox(height: 14),
          CampoForm(
            ctrl: _direccionCtrl,
            label: 'Dirección',
            icono: Icons.location_on_outlined,
            validador: (v) =>
                v == null || v.trim().isEmpty ? 'Campo obligatorio' : null,
          ),
          const SizedBox(height: 14),
          CampoForm(
            ctrl: _codigoCtrl,
            label: 'Código de sucursal',
            icono: Icons.tag_outlined,
          ),
        ],
      ),
    );
  }

  // ── Logo ──────────────────────────────────────────────────────────────────

  Widget _buildLogo() {
    final tieneLogoServidor = _logoUrl != null && _logoUrl!.isNotEmpty;
    final tieneLogoNuevo = _logoBytes != null;

    return GlassCard(
      child: Column(
        children: [
          // Preview
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: tieneLogoNuevo
                  ? Image.memory(
                      _logoBytes!,
                      width: 120,
                      height: 90,
                      fit: BoxFit.cover,
                    )
                  : tieneLogoServidor
                  ? CachedNetworkImage(
                      imageUrl: _logoUrl!,
                      width: 120,
                      height: 90,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => _logoPlaceholder(),
                    )
                  : _logoPlaceholder(),
            ),
          ),
          const SizedBox(height: 14),

          // Botón cambiar
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _subiendoLogo ? null : _elegirLogo,
              icon: const Icon(
                Icons.add_photo_alternate_outlined,
                color: AppColors.detailOnDark,
              ),
              label: Text(
                tieneLogoServidor || tieneLogoNuevo
                    ? 'CAMBIAR LOGO'
                    : 'SUBIR LOGO',
                style: const TextStyle(color: AppColors.linkOnDark, letterSpacing: 1),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.detailOnDark),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),

          // Botón subir logo nuevo (si hay bytes pendientes)
          if (tieneLogoNuevo) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _subiendoLogo ? null : _subirLogo,
                icon: _subiendoLogo
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: const Text('GUARDAR LOGO'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],

          // Botón eliminar logo existente
          if (tieneLogoServidor && !tieneLogoNuevo) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _subiendoLogo ? null : _eliminarLogo,
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                label: const Text(
                  'ELIMINAR LOGO',
                  style: TextStyle(color: AppColors.error, letterSpacing: 1),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _logoPlaceholder() {
    return Container(
      width: 120,
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: const Icon(
        Icons.storefront_outlined,
        color: Colors.white38,
        size: 36,
      ),
    );
  }

  // ── Horarios por día ──────────────────────────────────────────────────────

  Widget _buildHorarios() {
    // Tomamos el horario del lunes como modelo para "aplicar a todos".
    final modeloLunes = _horariosDia['lunes'] ?? const HorarioDia();

    return GlassCard(
      child: Column(
        children: [
          // Filas de días
          for (final dia in _kDias) _buildFilaDia(dia),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),

          // Botón "aplicar mismo horario a todos"
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                // Usamos el horario del primer día abierto como plantilla,
                // o el lunes si ninguno está abierto.
                final primerAbierto = _horariosDia.values
                    .where((h) => h.abierto)
                    .firstOrNull;
                final modelo = primerAbierto ?? modeloLunes;
                _aplicarHorarioATodos(modelo);
              },
              icon: const Icon(
                Icons.copy_all_outlined,
                color: Colors.white70,
                size: 18,
              ),
              label: const Text(
                'Aplicar mismo horario a todos los días',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilaDia(_DiaSemana dia) {
    final horario = _horariosDia[dia.clave] ?? const HorarioDia();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Nombre del día
          SizedBox(
            width: 80,
            child: Text(
              dia.etiqueta,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),

          // Switch abierto/cerrado
          Semantics(
            label: '${dia.etiqueta} abierto',
            child: Switch.adaptive(
              value: horario.abierto,
              activeThumbColor: AppColors.primaryOnDark,
              activeTrackColor: AppColors.primaryOnDark.withValues(alpha: 0.5),
              onChanged: (v) {
                setState(() {
                  _horariosDia[dia.clave] = horario.copyWith(abierto: v);
                });
              },
            ),
          ),

          // Selectores de hora (solo cuando está abierto)
          if (horario.abierto) ...[
            const SizedBox(width: 8),
            SelectorHora(
              hora: horario.apertura,
              tooltip: 'Hora de apertura del ${dia.etiqueta}',
              onTap: () async {
                final nueva = await _elegirHora(context, horario.apertura);
                if (nueva != null) {
                  setState(() {
                    _horariosDia[dia.clave] = horario.copyWith(apertura: nueva);
                  });
                }
              },
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('–', style: TextStyle(color: Colors.white54)),
            ),
            SelectorHora(
              hora: horario.cierre,
              tooltip: 'Hora de cierre del ${dia.etiqueta}',
              onTap: () async {
                final nueva = await _elegirHora(context, horario.cierre);
                if (nueva != null) {
                  setState(() {
                    _horariosDia[dia.clave] = horario.copyWith(cierre: nueva);
                  });
                }
              },
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Text(
                'Cerrado',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  // ── Datos fiscales ────────────────────────────────────────────────────────

  Widget _buildDatosFiscales() {
    return GlassCard(
      child: Column(
        children: [
          CampoForm(
            ctrl: _cifCtrl,
            label: 'CIF',
            icono: Icons.fingerprint_outlined,
            mayusculas: true,
            hint: 'B12345678',
            validador: (v) {
              if (v == null || v.trim().isEmpty) return null; // opcional
              if (v.trim().length < 8 || v.trim().length > 12) {
                return 'El CIF debe tener entre 8 y 12 caracteres';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          CampoForm(
            ctrl: _razonSocialCtrl,
            label: 'Razón social',
            icono: Icons.business_outlined,
          ),
          const SizedBox(height: 14),
          CampoForm(
            ctrl: _dirFiscalCtrl,
            label: 'Dirección fiscal',
            icono: Icons.location_city_outlined,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: CampoForm(
                  ctrl: _cpCtrl,
                  label: 'Código postal',
                  icono: Icons.markunread_mailbox_outlined,
                  teclado: TextInputType.number,
                  formatos: [FilteringTextInputFormatter.digitsOnly],
                  hint: '28001',
                  validador: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (v.trim().contains(RegExp(r'[^0-9]'))) {
                      return 'Solo dígitos';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: CampoForm(
                  ctrl: _ciudadCtrl,
                  label: 'Ciudad',
                  icono: Icons.location_on_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: CampoForm(
                  ctrl: _provinciaCtrl,
                  label: 'Provincia',
                  icono: Icons.map_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CampoForm(
                  ctrl: _paisCtrl,
                  label: 'País',
                  icono: Icons.public_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Métodos de pago ───────────────────────────────────────────────────────

  Widget _buildMetodosPago() {
    return GlassCard(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _kMetodosPago.map((m) {
          final activo = _metodosPago.contains(m.slug);
          return Semantics(
            label: '${m.etiqueta} ${activo ? "activado" : "desactivado"}',
            button: true,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (activo) {
                    _metodosPago.remove(m.slug);
                  } else {
                    _metodosPago.add(m.slug);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: activo
                      ? AppColors.detailOnDark.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: activo
                        ? AppColors.detailOnDark
                        : Colors.white.withValues(alpha: 0.2),
                    width: activo ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      m.icono,
                      size: 16,
                      color: activo ? AppColors.detailOnDark : Colors.white54,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      m.etiqueta,
                      style: TextStyle(
                        color: activo ? Colors.white : Colors.white54,
                        fontSize: 13,
                        fontWeight: activo
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    if (activo) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: AppColors.detailOnDark,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Botón guardar ─────────────────────────────────────────────────────────

  Widget _buildBotonGuardar() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryAccent,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          elevation: 0,
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
                'GUARDAR CAMBIOS',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
      ),
    );
  }

  // ── Eliminar sucursal (doble confirmación + nombre exacto) ─────────────────
  // Movido aquí desde home_screen_super_admin para que esta acción destructiva
  // viva dentro del contexto de "estoy editando ESTA sucursal" en lugar de
  // estar suelta en la lista global.

  Widget _buildBotonEliminar() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _eliminandoSucursal ? null : _eliminarSucursal,
        icon: _eliminandoSucursal
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: AppColors.error,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.delete_forever_outlined, size: 18),
        label: const Text(
          'ELIMINAR SUCURSAL',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
    );
  }

  Future<void> _eliminarSucursal() async {
    final r = widget.restaurante;

    // Primera confirmación
    final primera = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: const RoundedRectangleBorder(),
        title: const Text(
          'Eliminar permanentemente',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.error,
          ),
        ),
        content: Text(
          '¿Eliminar permanentemente "${r.nombre}"?\n\n'
          'Esta acción no se puede deshacer y borra todos los datos asociados.',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'CONTINUAR',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
    if (primera != true || !mounted) return;

    // Segunda confirmación: escribir el nombre exacto
    final confirmCtrl = TextEditingController();
    final segunda = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.background,
          shape: const RoundedRectangleBorder(),
          title: const Text(
            'Confirmar eliminación',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.error,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Esta acción no se puede deshacer. Escribe el nombre de la '
                'sucursal para confirmar:',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                r.nombre,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.error,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Escribe el nombre exacto...',
                  hintStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: const Color(0x8C000000),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: AppColors.line),
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: AppColors.line),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide:
                        BorderSide(color: AppColors.error, width: 1.5),
                  ),
                ),
                onChanged: (_) => setS(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: confirmCtrl.text.trim() == r.nombre
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: Text(
                'ELIMINAR DEFINITIVAMENTE',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: confirmCtrl.text.trim() == r.nombre
                      ? AppColors.error
                      : Colors.white24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (segunda != true || !mounted) return;

    setState(() => _eliminandoSucursal = true);
    try {
      await SuperAdminService.eliminarRestaurante(r.id);
      if (!mounted) return;
      // Volvemos al listado de sucursales del super_admin con un flag para
      // que recargue la lista al recibirnos.
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _eliminandoSucursal = false);
      showAppError(context, 'Error al eliminar: $e');
    }
  }
}

// Widgets auxiliares extraídos a:
//   lib/screens/shared/restaurante_editor/components/glass_card.dart   → GlassCard
//   lib/screens/shared/restaurante_editor/components/campo_form.dart    → CampoForm
//   lib/screens/shared/restaurante_editor/components/selector_hora.dart → SelectorHora
