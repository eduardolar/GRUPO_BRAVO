/// Helpers puros de la lógica de comanda del trabajador.
///
/// Extraídos de [CrearComanda] para permitir tests unitarios sin necesidad
/// de montar el árbol de widgets completo.
///
/// NOTA: No importar Flutter/widgets aquí — estos helpers son lógica pura
/// sin dependencia de contexto ni de la capa de presentación.
library;

import 'package:frontend/models/producto_model.dart';

/// Resultado del merge de un carrito en el mapa de items acumulados.
///
/// [acumulados] — mapa actualizado (puede ser el mismo objeto mutado).
/// [totalAcumulado] — nuevo total acumulado.
({
  Map<String, Map<String, dynamic>> acumulados,
  double totalAcumulado,
}) mergearCarritoEnAcumulado({
  required Map<String, Map<String, dynamic>> acumulados,
  required Map<Producto, int> carrito,
  required double totalAcumuladoPrevio,
}) {
  final resultado = Map<String, Map<String, dynamic>>.from(
    acumulados.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v))),
  );

  double incremento = 0.0;
  for (final entry in carrito.entries) {
    final producto = entry.key;
    final cantidad = entry.value;
    final id = producto.id;

    if (resultado.containsKey(id)) {
      resultado[id]!['cantidad'] =
          (resultado[id]!['cantidad'] as int) + cantidad;
    } else {
      resultado[id] = {
        'producto_id': id,
        'nombre': producto.nombre,
        'cantidad': cantidad,
        'precio': producto.precio,
      };
    }
    incremento += producto.precio * cantidad;
  }

  return (
    acumulados: resultado,
    totalAcumulado: totalAcumuladoPrevio + incremento,
  );
}

/// Deshace el merge de un carrito en el mapa de items acumulados
/// (rollback en caso de fallo de red).
///
/// Devuelve el mapa acumulado restaurado y el total restaurado.
({
  Map<String, Map<String, dynamic>> acumulados,
  double totalAcumulado,
}) rollbackCarrito({
  required Map<String, Map<String, dynamic>> acumulados,
  required Map<Producto, int> carrito,
  required double totalAcumuladoConError,
}) {
  final resultado = Map<String, Map<String, dynamic>>.from(
    acumulados.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v))),
  );

  double decremento = 0.0;
  for (final entry in carrito.entries) {
    final producto = entry.key;
    final cantidad = entry.value;
    final id = producto.id;

    decremento += producto.precio * cantidad;

    final item = resultado[id];
    if (item != null) {
      final nuevaCantidad = (item['cantidad'] as int) - cantidad;
      if (nuevaCantidad <= 0) {
        resultado.remove(id);
      } else {
        resultado[id] = Map<String, dynamic>.from(item)
          ..['cantidad'] = nuevaCantidad;
      }
    }
  }

  return (
    acumulados: resultado,
    totalAcumulado: totalAcumuladoConError - decremento,
  );
}

/// Calcula el total de precio de un carrito (precio × cantidad).
double calcularTotalCarrito(Map<Producto, int> carrito) {
  return carrito.entries.fold(
    0.0,
    (sum, e) => sum + e.key.precio * e.value,
  );
}

/// Formatea un precio en euros con dos decimales y coma decimal.
/// Ejemplo: 12.5 → "12,50 €"
String formatearPrecioEuros(double precio) {
  return '${precio.toStringAsFixed(2).replaceAll('.', ',')} €';
}

/// Genera el código QR automático para una mesa según su número y ubicación.
/// Interior: "Mesa_01", "Mesa_13"
/// Terraza:  "Terraza_01", "Terraza_13"
String generarCodigoQr(int numero, String ubicacion) {
  final prefijo = ubicacion == 'interior' ? 'Mesa' : 'Terraza';
  return '${prefijo}_${numero.toString().padLeft(2, '0')}';
}

/// Valida el número de mesa introducido por el usuario (String → int?).
/// Devuelve el número si es válido (> 0), o null si no.
int? validarNumeroMesa(String texto) {
  final n = int.tryParse(texto.trim());
  if (n == null || n <= 0) return null;
  return n;
}
