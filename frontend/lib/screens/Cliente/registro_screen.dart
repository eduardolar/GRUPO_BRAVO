import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/Cliente/auth_header.dart';
import '../../components/Cliente/auth_scaffold.dart';
import '../../components/Cliente/entrada_texto.dart';
import '../../components/Cliente/primary_button.dart';
import '../../core/app_snackbar.dart';
import '../../core/colors_style.dart';
import '../../models/destino_login.dart';
import '../../providers/auth_provider.dart';
import 'login_screen.dart';
import 'verificacion_screen.dart';

// ── Constantes de layout ────────────────────────────────────────────────────

const double _kCircleSize = 32;
const Duration _kStepAnim = Duration(milliseconds: 300);

// ── Controller del formulario multipaso ─────────────────────────────────────

/// Mantiene todos los [TextEditingController] y el índice de paso en memoria
/// durante todo el flujo de registro. Se pasa como argumento descendente para
/// que los subwidgets de cada paso puedan leerlo sin setState extra en el padre.
class _RegistroController extends ChangeNotifier {
  int paso = 0; // 0, 1 o 2

  final nombreCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final telefonoCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  bool ocultarPass = true;
  bool ocultarConfirm = true;

  void avanzar() {
    if (paso < 2) {
      paso++;
      notifyListeners();
    }
  }

  void retroceder() {
    if (paso > 0) {
      paso--;
      notifyListeners();
    }
  }

  void togglePass() {
    ocultarPass = !ocultarPass;
    notifyListeners();
  }

  void toggleConfirm() {
    ocultarConfirm = !ocultarConfirm;
    notifyListeners();
  }

  @override
  void dispose() {
    nombreCtrl.dispose();
    emailCtrl.dispose();
    telefonoCtrl.dispose();
    passwordCtrl.dispose();
    confirmCtrl.dispose();
    super.dispose();
  }
}

// ── Pantalla principal ───────────────────────────────────────────────────────

/// Pantalla de registro de un cliente nuevo con flujo de 3 pasos.
///
/// **Paso 1:** Nombre y correo.
/// **Paso 2:** Teléfono, contraseña y confirmación.
/// **Paso 3:** Resumen de datos + consentimiento RGPD + CTA "CREAR CUENTA".
///
/// Tras registro exitoso navega a [VerificacionScreen] para que el cliente
/// valide su correo mediante el código OTP enviado por el backend.
class RegistroScreen extends StatefulWidget {
  /// Destino post-verificación de email para conservar la intención original
  /// del cliente (ver carta vs. reservar mesa).
  final DestinoLogin destino;

  const RegistroScreen({super.key, this.destino = DestinoLogin.menu});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  // Un GlobalKey por cada paso para validar solo los campos del paso activo.
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();

  final _ctrl = _RegistroController();
  final _pageController = PageController();

  bool _isLoading = false;
  bool _aceptaPrivacidad = false;
  bool _privacidadError = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ── Validadores ────────────────────────────────────────────────────────────

  String? _validarNombre(String? v) {
    if (v == null || v.trim().isEmpty) return 'Introduce tu nombre';
    return null;
  }

  String? _validarEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Introduce tu correo';
    final regex = RegExp(r'^[\w.+\-]+@[\w\-]+\.[a-z]{2,}$', caseSensitive: false);
    if (!regex.hasMatch(v.trim())) return 'Correo electrónico no válido';
    return null;
  }

  String? _validarTelefono(String? v) {
    if (v == null || v.trim().isEmpty) return 'Campo requerido';
    final digits = v.trim().replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9) return 'Número de teléfono incompleto';
    return null;
  }

  String? _validarContrasena(String? v) {
    if (v == null || v.isEmpty) return 'Campo requerido';
    if (v.length < 8) return 'Mínimo 8 caracteres';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Debe incluir una mayúscula';
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Debe incluir un número';
    return null;
  }

  String? _validarConfirmar(String? v) {
    if (v == null || v.isEmpty) return 'Campo requerido';
    if (v != _ctrl.passwordCtrl.text) return 'Las contraseñas no coinciden';
    return null;
  }

  // ── Navegación entre pasos ─────────────────────────────────────────────────

  void _siguiente(GlobalKey<FormState> formKey) {
    if (!formKey.currentState!.validate()) return;
    _ctrl.avanzar();
    _pageController.animateToPage(
      _ctrl.paso,
      duration: _kStepAnim,
      curve: Curves.easeInOut,
    );
    setState(() {});
  }

  void _volver() {
    _ctrl.retroceder();
    _pageController.animateToPage(
      _ctrl.paso,
      duration: _kStepAnim,
      curve: Curves.easeInOut,
    );
    setState(() {});
  }

  // ── Registro final ─────────────────────────────────────────────────────────

  Future<void> _crearCuenta() async {
    if (!_aceptaPrivacidad) {
      setState(() => _privacidadError = true);
      return;
    }
    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    try {
      await auth.registrarse(
        nombre: _ctrl.nombreCtrl.text.trim(),
        email: _ctrl.emailCtrl.text.trim(),
        contrasena: _ctrl.passwordCtrl.text,
        telefono: _ctrl.telefonoCtrl.text.trim(),
        // Dirección eliminada del registro — se pedirá en OpcionesEntregaScreen.
        consentimientoRgpd: true,
      );
      if (!mounted) return;
      navigator.push(
        MaterialPageRoute(
          builder: (_) => VerificacionScreen(
            email: _ctrl.emailCtrl.text.trim(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      if (msg.contains('409') ||
          msg.contains('ya existe') ||
          msg.contains('duplicate') ||
          msg.contains('correo')) {
        showAppInfo(
          context,
          'Ya existe una cuenta con ese correo. ¿Quieres iniciar sesión?',
          action: SnackBarAction(
            label: 'IR AL LOGIN',
            textColor: Colors.white,
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => LoginScreen(destino: widget.destino),
              ),
            ),
          ),
        );
      } else if (msg.contains('socketexception') ||
          msg.contains('sin conexión') ||
          msg.contains('network')) {
        showAppError(
          context,
          'Sin conexión a internet. Comprueba tu red e inténtalo de nuevo.',
        );
      } else if (msg.contains('timeout') || msg.contains('timeoutexception')) {
        showAppError(
          context,
          'El servidor tardó demasiado. Inténtalo en un momento.',
        );
      } else {
        showAppError(context, 'No pudimos crear tu cuenta. Inténtalo de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // PopScope intercepta el botón físico atrás de Android/iOS:
    // - Paso 0: sale del flujo (comportamiento por defecto).
    // - Pasos 1-2: retrocede al paso anterior.
    return PopScope(
      canPop: _ctrl.paso == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _ctrl.paso > 0) _volver();
      },
      child: ClienteAuthScaffold(
        mostrarVolver: _ctrl.paso == 0,
        child: Column(
          children: [
            _IndicadorPasos(pasoActual: _ctrl.paso),
            const SizedBox(height: 24),
            SizedBox(
              // Altura fija para que el PageView no colapsen. Se usa un valor
              // grande y se deja que el scroll del padre gestione el overflow.
              height: MediaQuery.of(context).size.height * 0.78,
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _Paso1(
                    formKey: _formKey1,
                    ctrl: _ctrl,
                    validarNombre: _validarNombre,
                    validarEmail: _validarEmail,
                    onContinuar: () => _siguiente(_formKey1),
                    onLogin: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LoginScreen(destino: widget.destino),
                      ),
                    ),
                  ),
                  _Paso2(
                    formKey: _formKey2,
                    ctrl: _ctrl,
                    validarTelefono: _validarTelefono,
                    validarContrasena: _validarContrasena,
                    validarConfirmar: _validarConfirmar,
                    onContinuar: () => _siguiente(_formKey2),
                    onVolver: _volver,
                  ),
                  _Paso3(
                    ctrl: _ctrl,
                    aceptaPrivacidad: _aceptaPrivacidad,
                    privacidadError: _privacidadError,
                    isLoading: _isLoading,
                    onPrivacidadChange: (v) => setState(() {
                      _aceptaPrivacidad = v ?? false;
                      if (_aceptaPrivacidad) _privacidadError = false;
                    }),
                    onCrearCuenta: _crearCuenta,
                    onVolver: _volver,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Indicador de pasos ───────────────────────────────────────────────────────

/// Tres círculos conectados con línea horizontal. El activo usa [AppColors.button],
/// el completado muestra check sobre fondo burdeos, el pendiente usa [AppColors.line].
class _IndicadorPasos extends StatelessWidget {
  final int pasoActual;

  const _IndicadorPasos({required this.pasoActual});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Paso ${pasoActual + 1} de 3',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _circulo(0),
          _linea(0),
          _circulo(1),
          _linea(1),
          _circulo(2),
        ],
      ),
    );
  }

  Widget _circulo(int index) {
    final bool completado = index < pasoActual;
    final bool activo = index == pasoActual;
    final Color fondo = (completado || activo)
        ? AppColors.button
        : Colors.white.withValues(alpha: 0.2);

    return AnimatedContainer(
      duration: _kStepAnim,
      width: _kCircleSize,
      height: _kCircleSize,
      decoration: BoxDecoration(
        color: fondo,
        shape: BoxShape.circle,
        border: Border.all(
          color: activo ? AppColors.button : Colors.transparent,
          width: 2,
        ),
      ),
      child: Center(
        child: completado
            ? const Icon(Icons.check, color: Colors.white, size: 16)
            : Text(
                '${index + 1}',
                style: TextStyle(
                  color: activo
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.5),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
      ),
    );
  }

  Widget _linea(int index) {
    final bool completada = index < pasoActual;
    return AnimatedContainer(
      duration: _kStepAnim,
      width: 40,
      height: 2,
      color: completada
          ? AppColors.button
          : Colors.white.withValues(alpha: 0.2),
    );
  }
}

// ── Paso 1: Cuenta ───────────────────────────────────────────────────────────

class _Paso1 extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final _RegistroController ctrl;
  final String? Function(String?) validarNombre;
  final String? Function(String?) validarEmail;
  final VoidCallback onContinuar;
  final VoidCallback onLogin;

  const _Paso1({
    required this.formKey,
    required this.ctrl,
    required this.validarNombre,
    required this.validarEmail,
    required this.onContinuar,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuthHeader(
            titulo: 'Crea tu cuenta',
            subtitulo: 'Paso 1 de 3 · Datos personales',
          ),
          const SizedBox(height: 28),
          EntradaTexto(
            etiqueta: 'Nombre completo',
            icono: Icons.person_outline,
            autofillHints: const [AutofillHints.name],
            controlador: ctrl.nombreCtrl,
            validador: validarNombre,
          ),
          EntradaTexto(
            etiqueta: 'Correo electrónico',
            icono: Icons.email_outlined,
            tipoTeclado: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            controlador: ctrl.emailCtrl,
            validador: validarEmail,
          ),
          const SizedBox(height: 8),
          PrimaryButton(label: 'CONTINUAR', onPressed: onContinuar),
          _FooterLogin(onLogin: onLogin),
        ],
      ),
    );
  }
}

// ── Paso 2: Seguridad ────────────────────────────────────────────────────────

class _Paso2 extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final _RegistroController ctrl;
  final String? Function(String?) validarTelefono;
  final String? Function(String?) validarContrasena;
  final String? Function(String?) validarConfirmar;
  final VoidCallback onContinuar;
  final VoidCallback onVolver;

  const _Paso2({
    required this.formKey,
    required this.ctrl,
    required this.validarTelefono,
    required this.validarContrasena,
    required this.validarConfirmar,
    required this.onContinuar,
    required this.onVolver,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        return Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AuthHeader(
                titulo: 'Elige tu contraseña',
                subtitulo: 'Paso 2 de 3 · Solo tú la sabrás',
              ),
              const SizedBox(height: 28),
              EntradaTexto(
                etiqueta: 'Teléfono de contacto',
                icono: Icons.phone_android_outlined,
                tipoTeclado: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                controlador: ctrl.telefonoCtrl,
                validador: validarTelefono,
              ),
              EntradaTexto(
                etiqueta: 'Contraseña',
                icono: Icons.lock_outline,
                esContrasena: true,
                mostrarTexto: ctrl.ocultarPass,
                alPresionarIcono: ctrl.togglePass,
                autofillHints: const [AutofillHints.newPassword],
                controlador: ctrl.passwordCtrl,
                validador: validarContrasena,
              ),
              _PasswordStrengthBar(password: ctrl.passwordCtrl),
              Padding(
                padding: const EdgeInsets.only(bottom: 12, top: 2),
                child: Text(
                  'Mínimo 8 caracteres, una mayúscula y un número',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                  ),
                ),
              ),
              EntradaTexto(
                etiqueta: 'Repetir contraseña',
                icono: Icons.lock_outline,
                esContrasena: true,
                mostrarTexto: ctrl.ocultarConfirm,
                alPresionarIcono: ctrl.toggleConfirm,
                autofillHints: const [AutofillHints.newPassword],
                controlador: ctrl.confirmCtrl,
                validador: validarConfirmar,
              ),
              const SizedBox(height: 8),
              PrimaryButton(label: 'CONTINUAR', onPressed: onContinuar),
              const SizedBox(height: 12),
              _BotonVolver(onPressed: onVolver),
            ],
          ),
        );
      },
    );
  }
}

// ── Paso 3: Legal ─────────────────────────────────────────────────────────────

class _Paso3 extends StatelessWidget {
  final _RegistroController ctrl;
  final bool aceptaPrivacidad;
  final bool privacidadError;
  final bool isLoading;
  final ValueChanged<bool?> onPrivacidadChange;
  final VoidCallback onCrearCuenta;
  final VoidCallback onVolver;

  const _Paso3({
    required this.ctrl,
    required this.aceptaPrivacidad,
    required this.privacidadError,
    required this.isLoading,
    required this.onPrivacidadChange,
    required this.onCrearCuenta,
    required this.onVolver,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AuthHeader(
          titulo: 'Casi listo',
          subtitulo: 'Paso 3 de 3 · Revisa y acepta',
        ),
        const SizedBox(height: 24),
        _TarjetaResumen(
          nombre: ctrl.nombreCtrl.text,
          email: ctrl.emailCtrl.text,
          telefono: ctrl.telefonoCtrl.text,
        ),
        const SizedBox(height: 20),
        _ConsentimientoRgpd(
          aceptado: aceptaPrivacidad,
          hayError: privacidadError,
          onChange: onPrivacidadChange,
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'CREAR CUENTA',
          isLoading: isLoading,
          onPressed: onCrearCuenta,
        ),
        const SizedBox(height: 12),
        _BotonVolver(onPressed: onVolver),
      ],
    );
  }
}

// ── Tarjeta resumen ──────────────────────────────────────────────────────────

/// Muestra nombre, email y teléfono en modo solo lectura antes de confirmar.
class _TarjetaResumen extends StatelessWidget {
  final String nombre;
  final String email;
  final String telefono;

  const _TarjetaResumen({
    required this.nombre,
    required this.email,
    required this.telefono,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          _fila(Icons.person_outline, nombre),
          const SizedBox(height: 12),
          _fila(Icons.email_outlined, email),
          const SizedBox(height: 12),
          _fila(Icons.phone_android_outlined, telefono),
        ],
      ),
    );
  }

  Widget _fila(IconData icono, String valor) {
    return Row(
      children: [
        Icon(icono, color: AppColors.button, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            valor,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Consentimiento RGPD ──────────────────────────────────────────────────────

/// Checkbox RGPD. "Política de Privacidad" abre un [DraggableScrollableSheet]
/// con el texto legal en lugar de navegar fuera.
class _ConsentimientoRgpd extends StatelessWidget {
  const _ConsentimientoRgpd({
    required this.aceptado,
    required this.hayError,
    required this.onChange,
  });

  final bool aceptado;
  final bool hayError;
  final ValueChanged<bool?> onChange;

  void _abrirPolitica(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PoliticaPrivacidadSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              value: aceptado,
              onChanged: onChange,
              activeColor: AppColors.button,
              checkColor: Colors.white,
              side: BorderSide(
                color: hayError ? AppColors.error : AppColors.line,
                width: 1.5,
              ),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                  children: [
                    const TextSpan(text: 'He leído y acepto la '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: GestureDetector(
                        onTap: () => _abrirPolitica(context),
                        child: const Text(
                          'Política de Privacidad',
                          style: TextStyle(
                            color: AppColors.button,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.button,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const TextSpan(
                      text:
                          ' y el tratamiento de mis datos conforme al RGPD.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (hayError)
          const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Text(
              'Debes aceptar la Política de Privacidad para continuar',
              style: TextStyle(color: AppColors.error, fontSize: 11),
            ),
          ),
      ],
    );
  }
}

// ── Bottom sheet Política de Privacidad ──────────────────────────────────────

class _PoliticaPrivacidadSheet extends StatelessWidget {
  const _PoliticaPrivacidadSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Política de Privacidad',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: const [
                    // TODO(legal): reemplazar con texto definitivo aprobado por asesoría jurídica.
                    Text(
                      'Responsable del tratamiento\n'
                      'Grupo Bravo, S.L. — CIF: B-XXXXXXXX\n'
                      'Dirección: Calle Ejemplo, 1 — 00000 Ciudad\n'
                      'Contacto DPD: privacidad@grupobravo.es\n\n'
                      'Finalidad\n'
                      'Los datos personales facilitados (nombre, correo electrónico y teléfono) '
                      'se utilizarán exclusivamente para gestionar su cuenta, procesar pedidos '
                      'y enviar comunicaciones relacionadas con el servicio.\n\n'
                      'Base jurídica\n'
                      'El tratamiento se basa en el consentimiento expreso del interesado '
                      '(art. 6.1.a RGPD) y en la ejecución del contrato de servicio '
                      '(art. 6.1.b RGPD).\n\n'
                      'Conservación\n'
                      'Los datos se conservarán mientras la cuenta esté activa y durante '
                      'los plazos legales exigibles tras su cancelación.\n\n'
                      'Destinatarios\n'
                      'No se cederán datos a terceros salvo obligación legal o proveedores '
                      'de infraestructura sujetos a cláusulas de encargado del tratamiento.\n\n'
                      'Derechos\n'
                      'Puede ejercer sus derechos de acceso, rectificación, supresión, '
                      'portabilidad y oposición escribiendo a privacidad@grupobravo.es.\n\n'
                      'Reclamaciones\n'
                      'Si considera que el tratamiento no es conforme, puede presentar '
                      'una reclamación ante la Agencia Española de Protección de Datos '
                      '(www.aepd.es).',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                    SizedBox(height: 24),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: PrimaryButton(
                  label: 'ENTENDIDO',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Barra de fortaleza de contraseña ─────────────────────────────────────────

/// Barra visual de 4 segmentos que escucha el [TextEditingController] de la
/// contraseña y actualiza el color y etiqueta según la puntuación calculada.
class _PasswordStrengthBar extends StatefulWidget {
  const _PasswordStrengthBar({required this.password});
  final TextEditingController password;

  @override
  State<_PasswordStrengthBar> createState() => _PasswordStrengthBarState();
}

class _PasswordStrengthBarState extends State<_PasswordStrengthBar> {
  int _score = 0;

  @override
  void initState() {
    super.initState();
    widget.password.addListener(_update);
  }

  void _update() => setState(() => _score = _calcScore(widget.password.text));

  @override
  void dispose() {
    widget.password.removeListener(_update);
    super.dispose();
  }

  int _calcScore(String v) {
    int s = 0;
    if (v.length >= 8) s++;
    if (RegExp(r'[A-Z]').hasMatch(v)) s++;
    if (RegExp(r'[0-9]').hasMatch(v)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(v)) s++;
    return s;
  }

  Color get _color {
    if (_score <= 1) return AppColors.error;
    if (_score == 2) return AppColors.noDisp;
    if (_score == 3) return const Color(0xFFD97706);
    return AppColors.disp;
  }

  String get _label {
    if (_score == 0) return '';
    if (_score <= 1) return 'Débil';
    if (_score == 2) return 'Regular';
    if (_score == 3) return 'Buena';
    return 'Segura';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.password.text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(4, (i) {
              final active = i < _score;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: active
                        ? _color
                        : Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 5),
          Text(
            _label,
            style: TextStyle(
              color: _color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Botón secundario "Volver" ─────────────────────────────────────────────────

class _BotonVolver extends StatelessWidget {
  final VoidCallback onPressed;

  const _BotonVolver({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onPressed,
        child: const Text(
          '← Volver',
          style: TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Footer "¿Ya tienes cuenta?" ───────────────────────────────────────────────

class _FooterLogin extends StatelessWidget {
  final VoidCallback onLogin;

  const _FooterLogin({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '¿Ya tienes cuenta?',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
          TextButton(
            onPressed: onLogin,
            child: const Text(
              'Inicia sesión',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
