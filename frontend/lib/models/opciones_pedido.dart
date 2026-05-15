// ============================================================================
// frontend/lib/models/opciones_pedido.dart
// ----------------------------------------------------------------------------
// Enums de la pantalla de "opciones de entrega": dónde, cómo se paga y
// qué dirección usar (la guardada en el perfil o una alternativa puntual).
// ============================================================================
enum OpcionEntrega { domicilio, recoger, enMesa }

enum MetodoPago { efectivo, tarjeta, googlePay, paypal, applePay }

enum OpcionDireccion { registrada, alternativa }
