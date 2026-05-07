import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../components/bravo_app_bar.dart';
import '../../core/app_snackbar.dart';
import '../../core/colors_style.dart';
import '../../models/restaurante_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/http_client.dart';
import '../../services/restaurante_service.dart';
import '../shared/restaurante_editor/components/glass_card.dart';
import '../shared/restaurante_editor/components/campo_form.dart';
import '../shared/restaurante_editor/components/selector_hora.dart';

// ─── Constantes locales ───────────────────────────────────────────────────────

const int _kMaxLogoBytes = 5 * 1024 * 1024; // 5 MB
const List<String> _kMimesPermitidos = ['image/jpeg', 'image/png', 'image/webp'];

const List<_MetodoPago> _kMetodosPago = [
  _MetodoPago('efectivo', 'Efectivo', Icons.payments_outlined),
  _MetodoPago('tarjeta', 'Tarjeta', Icons.credit_card_outlined),
  _MetodoPago('paypal', 'PayPal', Icons.account_balance_wallet_outlined),
  _MetodoPago('google_pay', 'Google Pay', Icons.phone_android_outlined),
  _MetodoPago('stripe', 'Stripe', Icons.bolt_outlined),
];

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

/// Pantalla de edición del local para el rol [admin].
///
/// No recibe sucursal por parámetro: obtiene el [restauranteId] del usuario
/// logueado via [AuthProvider] y realiza el GET inicial para precargar el
/// formulario. Llama a [PUT /restaurantes/{id}] y [POST /restaurantes/{id}/logo].
class AdminLocalEditarScreen extends StatefulWidget {
  const AdminLocalEditarScreen({super.key});

  @override
  State<AdminLocalEditarScreen> createState() => _AdminLocalEditarScreenState();
}

class _AdminLocalEditarScreenState extends State<AdminLocalEditarScreen> {
  // ── Estado de carga inicial ───────────────────────────────────────────────
  bool _cargando = true;
  String? _errorCarga;
  Restaurante? _restauranteOriginal;

  // ── Formulario ────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();

  // Datos básicos
  late TextEditingController _nombreCtrl;
  late TextEditingController _direccionCtrl;
  late TextEditingController _codigoCtrl;

  // Logo
  String? _logoUrl;
  Uint8List? _logoBytes;
  String? _logoNombre;
  String? _logoMime;
  bool _subiendoLogo = false;

  // Horarios por día
  late Map<String, HorarioDia> _horariosDia;

  // Datos fiscales
  late TextEditingController _cifCtrl;
  late TextEditingController _razonSocialCtrl;
  late TextEditingController _dirFiscalCtrl;
  late TextEditingController _cpCtrl;
  late TextEditingController _ciudadCtrl;
  late TextEditingController _provinciaCtrl;
  late TextEditingController _paisCtrl;

  // Métodos de pago
  late Set<String> _metodosPago;

  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    // Inicializar controllers vacíos; se rellenarán tras la carga.
    _nombreCtrl = TextEditingController();
    _direccionCtrl = TextEditingController();
    _codigoCtrl = TextEditingController();
    _cifCtrl = TextEditingController();
    _razonSocialCtrl = TextEditingController();
    _dirFiscalCtrl = TextEditingController();
    _cpCtrl = TextEditingController();
    _ciudadCtrl = TextEditingController();
    _provinciaCtrl = TextEditingController();
    _paisCtrl = TextEditingController();
    _horariosDia = {};
    _metodosPago = {};

    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarRestaurante());
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

  // ── Carga inicial ─────────────────────────────────────────────────────────

  Future<void> _cargarRestaurante() async {
    if (!mounted) return;
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });

    try {
      final restauranteId =
          context.read<AuthProvider>().usuarioActual?.restauranteId;

      if (restauranteId == null || restauranteId.isEmpty) {
        setState(() {
          _cargando = false;
          _errorCarga = 'No tienes un local asignado.';
        });
        return;
      }

      final todos = await RestauranteService().obtenerTodos();
      if (!mounted) return;

      final encontrado = todos.cast<Restaurante?>().firstWhere(
        (r) => r?.id == restauranteId,
        orElse: () => null,
      );

      if (encontrado == null) {
        setState(() {
          _cargando = false;
          _errorCarga = 'No se encontró el local con id $restauranteId.';
        });
        return;
      }

      _poblarFormulario(encontrado);
      setState(() {
        _restauranteOriginal = encontrado;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorCarga = 'Error al cargar el local: $e';
      });
    }
  }

  void _poblarFormulario(Restaurante r) {
    _nombreCtrl.text = r.nombre;
    _direccionCtrl.text = r.direccion;
    _codigoCtrl.text = r.codigo;

    _logoUrl = r.logoUrl;
    _logoBytes = null;
    _logoNombre = null;
    _logoMime = null;

    _horariosDia = {};
    for (final dia in _kDias) {
      _horariosDia[dia.clave] =
          r.horariosDia?[dia.clave] ?? const HorarioDia();
    }

    _cifCtrl.text = r.cif ?? '';
    _razonSocialCtrl.text = r.razonSocial ?? '';
    _dirFiscalCtrl.text = r.direccionFiscal ?? '';
    _cpCtrl.text = r.codigoPostal ?? '';
    _ciudadCtrl.text = r.ciudad ?? '';
    _provinciaCtrl.text = r.provincia ?? '';
    _paisCtrl.text = r.pais?.isNotEmpty == true ? r.pais! : 'España';

    _metodosPago = Set<String>.from(r.metodosPago);
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
    if (bytes == null || _restauranteOriginal == null) return;
    setState(() => _subiendoLogo = true);
    try {
      final res = await RestauranteService.subirLogo(
        id: _restauranteOriginal!.id,
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
            backgroundColor: Colors.amber.shade700,
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
    if (_restauranteOriginal == null) return;
    setState(() => _subiendoLogo = true);
    try {
      await RestauranteService.eliminarLogo(_restauranteOriginal!.id);
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
            primary: AppColors.button,
            onPrimary: Colors.white,
            surface: const Color(0xFF1A1A1A),
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
    final r = _restauranteOriginal;
    if (r == null) return;

    if (_logoBytes != null) {
      await _subirLogo();
      if (!mounted) return;
      if (_logoBytes != null) return;
    }

    setState(() => _guardando = true);

    try {
      final datos = <String, dynamic>{};

      final nombre = _nombreCtrl.text.trim();
      if (nombre != r.nombre) datos['nombre'] = nombre;

      final direccion = _direccionCtrl.text.trim();
      if (direccion != r.direccion) datos['direccion'] = direccion;

      final codigo = _codigoCtrl.text.trim();
      if (codigo != r.codigo) datos['codigo'] = codigo;

      final horariosJson = _horariosDia.map((k, v) => MapEntry(k, v.toJson()));
      final horariosOriginalJson =
          (r.horariosDia ?? {}).map((k, v) => MapEntry(k, v.toJson()));
      if (horariosJson.toString() != horariosOriginalJson.toString()) {
        datos['horarios_dia'] = horariosJson;
      }

      _agregarSiCambio(
        datos, 'cif', _cifCtrl.text.trim().toUpperCase(), r.cif ?? '');
      _agregarSiCambio(
        datos, 'razon_social', _razonSocialCtrl.text.trim(), r.razonSocial ?? '');
      _agregarSiCambio(
        datos, 'direccion_fiscal', _dirFiscalCtrl.text.trim(), r.direccionFiscal ?? '');
      _agregarSiCambio(
        datos, 'codigo_postal', _cpCtrl.text.trim(), r.codigoPostal ?? '');
      _agregarSiCambio(
        datos, 'ciudad', _ciudadCtrl.text.trim(), r.ciudad ?? '');
      _agregarSiCambio(
        datos, 'provincia', _provinciaCtrl.text.trim(), r.provincia ?? '');
      _agregarSiCambio(
        datos, 'pais', _paisCtrl.text.trim(), r.pais ?? '');

      final metodosOrdenados = _metodosPago.toList()..sort();
      final originalesOrdenados = List<String>.from(r.metodosPago)..sort();
      if (metodosOrdenados.join(',') != originalesOrdenados.join(',')) {
        datos['metodos_pago'] = metodosOrdenados;
      }

      if (datos.isEmpty) {
        showAppInfo(context, 'No hay cambios que guardar');
        return;
      }

      await RestauranteService.actualizarRestaurante(r.id, datos);

      if (mounted) {
        showAppSuccess(context, 'Local actualizado correctamente');
        Navigator.pop(context, true);
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
      appBar: const BravoAppBar(title: 'EDITAR MI LOCAL'),
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
          child: SafeArea(child: _buildBody()),
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

    if (_errorCarga != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  color: Colors.white54, size: 64),
              const SizedBox(height: 16),
              Text(
                _errorCarga!,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.button,
                  foregroundColor: Colors.white,
                ),
                onPressed: _cargarRestaurante,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    // Estado success: formulario completo.
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: [
          _buildSeccion('DATOS BÁSICOS', Icons.storefront_outlined),
          _buildDatosBasicos(),
          const SizedBox(height: 24),

          _buildSeccion('LOGO DEL LOCAL', Icons.image_outlined),
          _buildLogo(),
          const SizedBox(height: 24),

          _buildSeccion('HORARIOS POR DÍA', Icons.schedule_outlined),
          _buildHorarios(),
          const SizedBox(height: 24),

          _buildSeccion('DATOS FISCALES', Icons.receipt_long_outlined),
          _buildDatosFiscales(),
          const SizedBox(height: 24),

          _buildSeccion('MÉTODOS DE PAGO', Icons.payment_outlined),
          _buildMetodosPago(),
          const SizedBox(height: 32),

          _buildBotonGuardar(),
        ],
      ),
    );
  }

  // ── Cabecera de sección ───────────────────────────────────────────────────

  Widget _buildSeccion(String titulo, IconData icono) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(width: 3, height: 18, color: AppColors.button),
          const SizedBox(width: 10),
          Icon(icono, color: AppColors.button, size: 16),
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

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _subiendoLogo ? null : _elegirLogo,
              icon: const Icon(
                Icons.add_photo_alternate_outlined,
                color: AppColors.button,
              ),
              label: Text(
                tieneLogoServidor || tieneLogoNuevo
                    ? 'CAMBIAR LOGO'
                    : 'SUBIR LOGO',
                style: const TextStyle(
                    color: AppColors.button, letterSpacing: 1),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.button),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

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
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: const Text('GUARDAR LOGO'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.button,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],

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
    final modeloLunes = _horariosDia['lunes'] ?? const HorarioDia();

    return GlassCard(
      child: Column(
        children: [
          for (final dia in _kDias) _buildFilaDia(dia),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
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
                    borderRadius: BorderRadius.circular(10)),
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
          Semantics(
            label: '${dia.etiqueta} abierto',
            child: Switch.adaptive(
              value: horario.abierto,
              activeThumbColor: AppColors.button,
              activeTrackColor: AppColors.button.withValues(alpha: 0.5),
              onChanged: (v) {
                setState(() {
                  _horariosDia[dia.clave] = horario.copyWith(abierto: v);
                });
              },
            ),
          ),
          if (horario.abierto) ...[
            const SizedBox(width: 8),
            SelectorHora(
              hora: horario.apertura,
              tooltip: 'Hora de apertura del ${dia.etiqueta}',
              onTap: () async {
                final nueva = await _elegirHora(context, horario.apertura);
                if (nueva != null) {
                  setState(() {
                    _horariosDia[dia.clave] =
                        horario.copyWith(apertura: nueva);
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
                    _horariosDia[dia.clave] =
                        horario.copyWith(cierre: nueva);
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
              if (v == null || v.trim().isEmpty) return null;
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
                      ? AppColors.button.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: activo
                        ? AppColors.button
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
                      color: activo ? AppColors.button : Colors.white54,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      m.etiqueta,
                      style: TextStyle(
                        color: activo ? Colors.white : Colors.white54,
                        fontSize: 13,
                        fontWeight:
                            activo ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    if (activo) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: AppColors.button,
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
          backgroundColor: AppColors.button,
          foregroundColor: Colors.white,
          shape:
              const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          elevation: 0,
        ),
        onPressed: _guardando ? null : _guardar,
        child: _guardando
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
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
}
