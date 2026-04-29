import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/colors_style.dart';
import '../../providers/auth_provider.dart';
import '../../components/Cliente/otp_fields.dart';

class _RecoveryCodesDialog extends StatelessWidget {
  final List<String> codigos;
  const _RecoveryCodesDialog({required this.codigos});

  @override
  Widget build(BuildContext context) {
    final todosJuntos = codigos.join('\n');
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.health_and_safety_outlined, color: AppColors.button, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Códigos de recuperación',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Guárdalos en un lugar seguro. Cada código solo puede usarse una vez si pierdes acceso a tu dispositivo.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: codigos
                    .map((c) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                            c,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'monospace',
                              fontSize: 14,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.copy_outlined, size: 16),
                label: const Text('Copiar todos'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: todosJuntos));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Códigos copiados al portapapeles'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'HE GUARDADO MIS CÓDIGOS',
            style: TextStyle(color: AppColors.button, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ),
      ],
    );
  }
}

class TotpSetupScreen extends StatefulWidget {
  const TotpSetupScreen({super.key});

  @override
  State<TotpSetupScreen> createState() => _TotpSetupScreenState();
}

class _TotpSetupScreenState extends State<TotpSetupScreen> {
  bool _cargandoSetup = true;
  bool _activando = false;
  String? _otpauthUri;
  String? _secret;

  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    _iniciarSetup();
  }

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  Future<void> _iniciarSetup() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final data = await auth.setup2fa();
      setState(() {
        _otpauthUri = data['otpauth_uri'] as String?;
        _secret = data['secret'] as String?;
        _cargandoSetup = false;
      });
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al iniciar configuración: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String get _codigoIngresado =>
      _controllers.map((c) => c.text).join();

  Future<void> _activar() async {
    final codigo = _codigoIngresado;
    if (codigo.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Introduce el código de 6 dígitos de Google Authenticator'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _activando = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final codigos = await auth.activar2fa(codigo);
      if (!mounted) return;
      setState(() => _activando = false);
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _RecoveryCodesDialog(codigos: codigos),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _activando = false);
      for (final c in _controllers) { c.clear(); }
      _focusNodes[0].requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/Bravo restaurante.jpg', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.88)),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: _cargandoSetup
                      ? const Center(child: CircularProgressIndicator(color: AppColors.button))
                      : _buildContenido(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'ACTIVAR 2FA',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.5,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildContenido() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                const Icon(Icons.security, color: AppColors.button, size: 32),
                const SizedBox(height: 12),
                const Text(
                  'Configura Google Authenticator',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Playfair Display',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Escanea este código QR con la app Google Authenticator para vincular tu cuenta.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // QR Code
          if (_otpauthUri != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: _otpauthUri!,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),

            // Clave manual
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.vpn_key_outlined, color: AppColors.button, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _secret ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        letterSpacing: 2,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_outlined, color: Colors.white38, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _secret ?? ''));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Clave copiada al portapapeles'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    tooltip: 'Copiar clave',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Usa esta clave si no puedes escanear el QR',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
            ),
          ],

          const SizedBox(height: 28),

          // Paso 2: Verificar
          Row(
            children: [
              Text(
                'VERIFICAR CÓDIGO',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Container(height: 1, color: Colors.white12)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Introduce el código de 6 dígitos que muestra Google Authenticator',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          OtpFields(
            controllers: _controllers,
            focusNodes: _focusNodes,
            onComplete: _activar,
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _activando ? null : _activar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.button,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white12,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                elevation: 0,
              ),
              child: _activando
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'ACTIVAR AUTENTICACIÓN',
                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 13),
                    ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
