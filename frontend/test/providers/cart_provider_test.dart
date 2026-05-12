// Tests unitarios para CartProvider.
//
// No hay red, SharedPreferences ni dependencias externas que mockear:
// CartProvider es puro ChangeNotifier en memoria.
//
// Convención de nombres: test_<acción>_<condición>_<resultado>

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/providers/cart_provider.dart';
import 'package:frontend/models/producto_model.dart';

// ---------------------------------------------------------------------------
// Helpers de fixture
// ---------------------------------------------------------------------------

/// Producto de prueba con valores mínimos válidos.
Producto _producto({
  String id = 'prod-1',
  String nombre = 'Hamburguesa',
  double precio = 10.0,
  String? restauranteId,
}) {
  return Producto(
    id: id,
    nombre: nombre,
    descripcion: '',
    precio: precio,
    categoria: 'Test',
    restauranteId: restauranteId,
  );
}

/// Crea un CartProvider limpio y registra cuántas veces notifica.
({CartProvider provider, int Function() notifyCount}) _providerConContador() {
  final provider = CartProvider();
  var count = 0;
  provider.addListener(() => count++);
  return (provider: provider, notifyCount: () => count);
}

// ---------------------------------------------------------------------------
// Suite principal
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // 1. Estado inicial
  // -------------------------------------------------------------------------
  group('Estado inicial', () {
    late CartProvider cart;

    setUp(() => cart = CartProvider());

    test('carrito vacío', () {
      expect(cart.items, isEmpty);
    });

    test('itemCount es 0', () {
      expect(cart.itemCount, 0);
    });

    test('totalQuantity es 0', () {
      expect(cart.totalQuantity, 0);
    });

    test('totalPrice es 0.0', () {
      expect(cart.totalPrice, 0.0);
    });

    test('restauranteId es null', () {
      expect(cart.restauranteId, isNull);
    });

    test('restauranteNombre es null', () {
      expect(cart.restauranteNombre, isNull);
    });

    test('mesaId es null', () {
      expect(cart.mesaId, isNull);
    });

    test('numeroMesa es null', () {
      expect(cart.numeroMesa, isNull);
    });

    test('tienemesa es false', () {
      expect(cart.tienemesa, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // 2. addItem — camino feliz
  // -------------------------------------------------------------------------
  group('addItem — camino feliz', () {
    late CartProvider cart;

    setUp(() => cart = CartProvider());

    test('añadir_producto_nuevo_incrementa_itemCount', () {
      cart.addItem(_producto());
      expect(cart.itemCount, 1);
    });

    test('añadir_producto_nuevo_incrementa_totalQuantity', () {
      cart.addItem(_producto());
      expect(cart.totalQuantity, 1);
    });

    test('añadir_producto_nuevo_recalcula_totalPrice', () {
      cart.addItem(_producto(precio: 10.0));
      expect(cart.totalPrice, closeTo(10.0, 0.001));
    });

    test('añadir_dos_productos_distintos_suma_ambos_totales', () {
      cart.addItem(_producto(id: 'a', precio: 5.0));
      cart.addItem(_producto(id: 'b', precio: 3.0));
      expect(cart.totalPrice, closeTo(8.0, 0.001));
      expect(cart.itemCount, 2);
    });

    test('añadir_con_cantidad_mayor_que_1_recalcula_total_correctamente', () {
      cart.addItem(_producto(precio: 4.0), cantidad: 3);
      expect(cart.totalPrice, closeTo(12.0, 0.001));
      expect(cart.totalQuantity, 3);
      expect(cart.itemCount, 1); // una entrada, 3 unidades
    });
  });

  // -------------------------------------------------------------------------
  // 3. addItem — idempotencia / producto duplicado
  // -------------------------------------------------------------------------
  group('addItem — mismo producto dos veces', () {
    late CartProvider cart;

    setUp(() => cart = CartProvider());

    test('añadir_mismo_producto_dos_veces_no_duplica_entrada_del_mapa', () {
      final p = _producto();
      cart.addItem(p);
      cart.addItem(p);
      expect(cart.itemCount, 1); // sigue siendo una sola clave
    });

    test('añadir_mismo_producto_dos_veces_acumula_cantidad', () {
      final p = _producto();
      cart.addItem(p);
      cart.addItem(p);
      expect(cart.totalQuantity, 2);
    });

    test('añadir_mismo_producto_dos_veces_acumula_precio', () {
      final p = _producto(precio: 7.0);
      cart.addItem(p);
      cart.addItem(p);
      expect(cart.totalPrice, closeTo(14.0, 0.001));
    });

    test('getQuantity_refleja_acumulacion', () {
      final p = _producto(id: 'x');
      cart.addItem(p);
      cart.addItem(p);
      expect(cart.getQuantity('x'), 2);
    });
  });

  // -------------------------------------------------------------------------
  // 4. addItem — personalizaciones (ingredientes excluidos)
  // -------------------------------------------------------------------------
  group('addItem — ingredientes excluidos', () {
    late CartProvider cart;

    setUp(() => cart = CartProvider());

    test(
      'mismo_producto_con_distintas_exclusiones_genera_entradas_separadas',
      () {
        final p = _producto(id: 'p1');
        cart.addItem(p, ingredientesExcluidos: ['cebolla']);
        cart.addItem(p, ingredientesExcluidos: ['tomate']);
        expect(cart.itemCount, 2);
      },
    );

    test(
      'mismo_producto_con_mismas_exclusiones_acumula_cantidad',
      () {
        final p = _producto(id: 'p1');
        cart.addItem(p, ingredientesExcluidos: ['cebolla']);
        cart.addItem(p, ingredientesExcluidos: ['cebolla']);
        expect(cart.itemCount, 1);
        expect(cart.totalQuantity, 2);
      },
    );

    test(
      'orden_de_exclusiones_no_afecta_la_clave_agrupacion',
      () {
        final p = _producto(id: 'p1');
        cart.addItem(p, ingredientesExcluidos: ['cebolla', 'tomate']);
        cart.addItem(p, ingredientesExcluidos: ['tomate', 'cebolla']);
        // La clave ordena las exclusiones → misma clave → misma entrada
        expect(cart.itemCount, 1);
        expect(cart.totalQuantity, 2);
      },
    );

    test(
      'producto_sin_exclusiones_y_con_exclusiones_generan_entradas_separadas',
      () {
        final p = _producto(id: 'p1');
        cart.addItem(p); // sin exclusiones
        cart.addItem(p, ingredientesExcluidos: ['cebolla']);
        expect(cart.itemCount, 2);
      },
    );
  });

  // -------------------------------------------------------------------------
  // 5. addItem — producto de otro restaurante
  //    El provider NO valida restauranteId al añadir ítems; simplemente los
  //    acepta todos. Este test documenta el comportamiento real.
  // -------------------------------------------------------------------------
  group('addItem — productos de distintos restaurantes', () {
    late CartProvider cart;

    setUp(() => cart = CartProvider());

    test(
      'provider_acepta_productos_de_restaurantes_distintos_sin_bloquear',
      () {
        final p1 = _producto(id: 'a', restauranteId: 'rest-1');
        final p2 = _producto(id: 'b', restauranteId: 'rest-2');
        cart.addItem(p1);
        cart.addItem(p2);
        // No lanza excepción y ambos están presentes.
        expect(cart.itemCount, 2);
      },
    );

    test(
      'productos_de_restaurantes_distintos_suman_sus_totales',
      () {
        final p1 = _producto(id: 'a', precio: 5.0, restauranteId: 'rest-1');
        final p2 = _producto(id: 'b', precio: 8.0, restauranteId: 'rest-2');
        cart.addItem(p1);
        cart.addItem(p2);
        expect(cart.totalPrice, closeTo(13.0, 0.001));
      },
    );
  });

  // -------------------------------------------------------------------------
  // 6. removeItem — decrementa o elimina
  // -------------------------------------------------------------------------
  group('removeItem', () {
    late CartProvider cart;

    setUp(() {
      cart = CartProvider();
      cart.addItem(_producto(id: 'p1', precio: 10.0), cantidad: 3);
    });

    test('removeItem_con_cantidad_mayor_que_1_decrementa', () {
      cart.removeItem('p1');
      expect(cart.getQuantity('p1'), 2);
    });

    test('removeItem_actualiza_totalQuantity', () {
      cart.removeItem('p1');
      expect(cart.totalQuantity, 2);
    });

    test('removeItem_actualiza_totalPrice', () {
      cart.removeItem('p1');
      expect(cart.totalPrice, closeTo(20.0, 0.001));
    });

    test('removeItem_con_cantidad_1_elimina_la_entrada', () {
      // Dejamos cantidad en 1 quitando dos veces más
      cart.removeItem('p1');
      cart.removeItem('p1');
      // Ahora cantidad == 1
      cart.removeItem('p1');
      expect(cart.isInCart('p1'), isFalse);
      expect(cart.itemCount, 0);
    });

    test('removeItem_sobre_clave_inexistente_no_lanza_error', () {
      expect(() => cart.removeItem('no-existe'), returnsNormally);
    });

    test('removeItem_sobre_clave_inexistente_no_dispara_notifyListeners', () {
      final (:provider, :notifyCount) = _providerConContador();
      provider.addItem(_producto(id: 'p1'), cantidad: 1);
      final antes = notifyCount();
      provider.removeItem('no-existe');
      expect(notifyCount(), antes); // sin notificaciones adicionales
    });
  });

  // -------------------------------------------------------------------------
  // 7. removeProduct — elimina la entrada completa
  // -------------------------------------------------------------------------
  group('removeProduct', () {
    late CartProvider cart;

    setUp(() {
      cart = CartProvider();
      cart.addItem(_producto(id: 'p1', precio: 10.0), cantidad: 5);
    });

    test('removeProduct_elimina_entrada_independientemente_de_cantidad', () {
      cart.removeProduct('p1');
      expect(cart.isInCart('p1'), isFalse);
      expect(cart.itemCount, 0);
    });

    test('removeProduct_recalcula_totalPrice_a_cero', () {
      cart.removeProduct('p1');
      expect(cart.totalPrice, 0.0);
    });

    test('removeProduct_clave_inexistente_no_lanza_error', () {
      expect(() => cart.removeProduct('no-existe'), returnsNormally);
    });

    test(
      'removeProduct_producto_inexistente_no_dispara_notifyListeners',
      () {
        // Reproduce el bug: carrito vacío, listener registrado, llamar con id
        // que no existe → el contador debe quedarse en 0.
        final (:provider, :notifyCount) = _providerConContador();
        provider.removeProduct('producto_inexistente');
        expect(notifyCount(), 0);
      },
    );

    test(
      'removeProduct_elimina_todas_las_variantes_del_mismo_producto',
      () {
        final p = _producto(id: 'p1', precio: 10.0);
        cart.addItem(p); // clave: 'p1'
        cart.addItem(p, ingredientesExcluidos: ['cebolla']); // clave: 'p1_sin_cebolla'
        cart.addItem(p, ingredientesExcluidos: ['tomate']); // clave: 'p1_sin_tomate'
        cart.removeProduct('p1');
        expect(cart.itemCount, 0);
        expect(cart.totalPrice, 0.0);
      },
    );

    test(
      'removeProduct_con_variantes_dispara_notify_una_sola_vez',
      () {
        final (:provider, :notifyCount) = _providerConContador();
        final p = _producto(id: 'p1');
        provider.addItem(p);
        provider.addItem(p, ingredientesExcluidos: ['cebolla']);
        final antes = notifyCount();
        provider.removeProduct('p1');
        expect(notifyCount(), antes + 1); // exactamente una notificación
      },
    );
  });

  // -------------------------------------------------------------------------
  // 8. clearCart
  // -------------------------------------------------------------------------
  group('clearCart', () {
    late CartProvider cart;

    setUp(() {
      cart = CartProvider();
      cart.addItem(_producto(id: 'a'));
      cart.addItem(_producto(id: 'b'));
      cart.asignarMesa(mesaId: 'm1', numeroMesa: 3);
    });

    test('clearCart_vacia_items', () {
      cart.clearCart();
      expect(cart.items, isEmpty);
    });

    test('clearCart_resetea_mesaId', () {
      cart.clearCart();
      expect(cart.mesaId, isNull);
    });

    test('clearCart_resetea_numeroMesa', () {
      cart.clearCart();
      expect(cart.numeroMesa, isNull);
    });

    test('clearCart_no_toca_restauranteId', () {
      cart.seleccionarRestaurante(id: 'r1', nombre: 'El Toro');
      cart.clearCart();
      // El provider solo limpia mesa e ítems, no el restaurante.
      expect(cart.restauranteId, 'r1');
    });
  });

  // -------------------------------------------------------------------------
  // 9. limpiarRestaurante
  // -------------------------------------------------------------------------
  group('limpiarRestaurante', () {
    late CartProvider cart;

    setUp(() {
      cart = CartProvider();
      cart.seleccionarRestaurante(id: 'r1', nombre: 'El Toro');
      cart.addItem(_producto(id: 'a'));
      cart.asignarMesa(mesaId: 'm1', numeroMesa: 2);
    });

    test('limpiarRestaurante_vacia_items', () {
      cart.limpiarRestaurante();
      expect(cart.items, isEmpty);
    });

    test('limpiarRestaurante_resetea_restauranteId', () {
      cart.limpiarRestaurante();
      expect(cart.restauranteId, isNull);
    });

    test('limpiarRestaurante_resetea_restauranteNombre', () {
      cart.limpiarRestaurante();
      expect(cart.restauranteNombre, isNull);
    });

    test('limpiarRestaurante_resetea_mesaId', () {
      cart.limpiarRestaurante();
      expect(cart.mesaId, isNull);
    });

    test('limpiarRestaurante_resetea_numeroMesa', () {
      cart.limpiarRestaurante();
      expect(cart.numeroMesa, isNull);
    });

    test('limpiarRestaurante_todo_queda_como_estado_inicial', () {
      cart.limpiarRestaurante();
      expect(cart.totalPrice, 0.0);
      expect(cart.totalQuantity, 0);
      expect(cart.itemCount, 0);
      expect(cart.tienemesa, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // 10. seleccionarRestaurante y asignarMesa / desasignarMesa
  // -------------------------------------------------------------------------
  group('seleccionarRestaurante', () {
    late CartProvider cart;

    setUp(() => cart = CartProvider());

    test('guarda_id_y_nombre', () {
      cart.seleccionarRestaurante(id: 'r1', nombre: 'La Paella');
      expect(cart.restauranteId, 'r1');
      expect(cart.restauranteNombre, 'La Paella');
    });

    test('sobrescribir_restaurante_actualiza_ambos_campos', () {
      cart.seleccionarRestaurante(id: 'r1', nombre: 'A');
      cart.seleccionarRestaurante(id: 'r2', nombre: 'B');
      expect(cart.restauranteId, 'r2');
      expect(cart.restauranteNombre, 'B');
    });
  });

  group('asignarMesa y desasignarMesa', () {
    late CartProvider cart;

    setUp(() => cart = CartProvider());

    test('asignarMesa_actualiza_campos_y_tienemesa', () {
      cart.asignarMesa(mesaId: 'm5', numeroMesa: 5);
      expect(cart.mesaId, 'm5');
      expect(cart.numeroMesa, 5);
      expect(cart.tienemesa, isTrue);
    });

    test('desasignarMesa_limpia_mesa_pero_conserva_items', () {
      cart.addItem(_producto());
      cart.asignarMesa(mesaId: 'm5', numeroMesa: 5);
      cart.desasignarMesa();
      expect(cart.mesaId, isNull);
      expect(cart.numeroMesa, isNull);
      expect(cart.tienemesa, isFalse);
      expect(cart.itemCount, 1); // los ítems siguen ahí
    });
  });

  // -------------------------------------------------------------------------
  // 11. isInCart y getQuantity — consultas
  // -------------------------------------------------------------------------
  group('isInCart y getQuantity', () {
    late CartProvider cart;

    setUp(() => cart = CartProvider());

    test('isInCart_false_para_producto_no_añadido', () {
      expect(cart.isInCart('x'), isFalse);
    });

    test('isInCart_true_tras_addItem', () {
      cart.addItem(_producto(id: 'x'));
      expect(cart.isInCart('x'), isTrue);
    });

    test('getQuantity_devuelve_0_para_producto_ausente', () {
      expect(cart.getQuantity('no-existe'), 0);
    });

    test('getQuantity_refleja_cantidad_real', () {
      cart.addItem(_producto(id: 'x'), cantidad: 4);
      expect(cart.getQuantity('x'), 4);
    });
  });

  // -------------------------------------------------------------------------
  // 12. notifyListeners — contador de notificaciones
  // -------------------------------------------------------------------------
  group('notifyListeners se dispara en cada mutación', () {
    test('addItem_dispara_notify', () {
      final (:provider, :notifyCount) = _providerConContador();
      provider.addItem(_producto());
      expect(notifyCount(), 1);
    });

    test('addItem_dos_veces_dispara_notify_dos_veces', () {
      final (:provider, :notifyCount) = _providerConContador();
      provider.addItem(_producto());
      provider.addItem(_producto());
      expect(notifyCount(), 2);
    });

    test('removeItem_existente_dispara_notify', () {
      final (:provider, :notifyCount) = _providerConContador();
      provider.addItem(_producto(id: 'p1'));
      final antes = notifyCount();
      provider.removeItem('p1');
      expect(notifyCount(), antes + 1);
    });

    test('removeProduct_dispara_notify', () {
      final (:provider, :notifyCount) = _providerConContador();
      provider.addItem(_producto(id: 'p1'));
      final antes = notifyCount();
      provider.removeProduct('p1');
      expect(notifyCount(), antes + 1);
    });

    test('clearCart_dispara_notify', () {
      final (:provider, :notifyCount) = _providerConContador();
      provider.clearCart();
      expect(notifyCount(), 1);
    });

    test('limpiarRestaurante_dispara_notify', () {
      final (:provider, :notifyCount) = _providerConContador();
      provider.limpiarRestaurante();
      expect(notifyCount(), 1);
    });

    test('seleccionarRestaurante_dispara_notify', () {
      final (:provider, :notifyCount) = _providerConContador();
      provider.seleccionarRestaurante(id: 'r1', nombre: 'X');
      expect(notifyCount(), 1);
    });

    test('asignarMesa_dispara_notify', () {
      final (:provider, :notifyCount) = _providerConContador();
      provider.asignarMesa(mesaId: 'm1', numeroMesa: 1);
      expect(notifyCount(), 1);
    });

    test('desasignarMesa_dispara_notify', () {
      final (:provider, :notifyCount) = _providerConContador();
      provider.desasignarMesa();
      expect(notifyCount(), 1);
    });
  });

  // -------------------------------------------------------------------------
  // 13. Edge cases
  // -------------------------------------------------------------------------
  group('Edge cases', () {
    late CartProvider cart;

    setUp(() => cart = CartProvider());

    test('añadir_producto_con_precio_cero_no_falla_y_no_suma_al_total', () {
      cart.addItem(_producto(precio: 0.0));
      expect(cart.totalPrice, 0.0);
      expect(cart.itemCount, 1);
    });

    test('totalPrice_con_varios_productos_es_suma_exacta', () {
      cart.addItem(_producto(id: 'a', precio: 1.10), cantidad: 3);
      cart.addItem(_producto(id: 'b', precio: 2.20), cantidad: 2);
      // 3*1.10 + 2*2.20 = 3.30 + 4.40 = 7.70
      expect(cart.totalPrice, closeTo(7.70, 0.001));
    });

    test(
      'añadir_producto_con_cantidad_1_y_removeItem_elimina_la_entrada',
      () {
        cart.addItem(_producto(id: 'solo'), cantidad: 1);
        cart.removeItem('solo');
        expect(cart.isInCart('solo'), isFalse);
      },
    );

    test('clearCart_seguido_de_addItem_funciona_con_normalidad', () {
      cart.addItem(_producto(id: 'a'));
      cart.clearCart();
      cart.addItem(_producto(id: 'b', precio: 5.0));
      expect(cart.itemCount, 1);
      expect(cart.totalPrice, closeTo(5.0, 0.001));
    });

    test(
      'limpiarRestaurante_seguido_de_seleccionarRestaurante_funciona',
      () {
        cart.seleccionarRestaurante(id: 'r1', nombre: 'A');
        cart.limpiarRestaurante();
        cart.seleccionarRestaurante(id: 'r2', nombre: 'B');
        expect(cart.restauranteId, 'r2');
      },
    );

    test('removeItem_sobre_item_con_exclusiones_usa_clave_completa', () {
      final p = _producto(id: 'p1');
      cart.addItem(p, ingredientesExcluidos: ['cebolla']);
      // La clave generada NO es 'p1' sino 'p1_sin_cebolla'.
      // Intentar removeItem('p1') no debe afectar esa entrada.
      cart.removeItem('p1');
      expect(cart.itemCount, 1); // la entrada con exclusión sigue intacta
    });
  });
}
