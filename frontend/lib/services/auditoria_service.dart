import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_session.dart';

class EventoAuditoria {
  final String fecha;
  final String evento;
  final String proveedor;
  final String estado;
  final String ip;
  final double? importe;
  final String? moneda;
  final String? referencia;
  final String? detalle;

  EventoAuditoria({
    required this.fecha,
    required this.evento,
    required this.proveedor,
    required this.estado,
    required this.ip,
    this.importe,
    this.moneda,
    this.referencia,
    this.detalle,
  });

  factory EventoAuditoria.fromJson(Map<String, dynamic> json) {
    return EventoAuditoria(
      fecha: json['fecha'] ?? '',
      evento: json['evento'] ?? '',
      proveedor: json['proveedor'] ?? '',
      estado: json['estado'] ?? '',
      ip: json['ip'] ?? '',
      importe: json['importe'] != null
          ? (json['importe'] as num).toDouble()
          : null,
      moneda: json['moneda'],
      referencia: json['referencia'],
      detalle: json['detalle'],
    );
  }
}

class AuditoriaService {
  static Future<List<EventoAuditoria>> obtenerEventos({
    String? proveedor,
    String? estado,
    int limite = 100,
  }) async {
    final params = <String, String>{'limite': '$limite'};
    if (proveedor != null && proveedor.isNotEmpty) {
      params['proveedor'] = proveedor;
    }
    if (estado != null && estado.isNotEmpty) params['estado'] = estado;

    final uri = Uri.parse(
      '$baseUrl/payments/audit',
    ).replace(queryParameters: params);
    final response = await http.get(
      uri,
      headers: AuthSession.headers(extra: {'Accept': 'application/json'}),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((j) => EventoAuditoria.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Error al cargar auditoría (${response.statusCode})');
  }
}

class EventoGeneral {
  final String fecha;
  final String accion;
  final String? actor;
  final String? objetivo;
  final String? detalle;

  EventoGeneral({
    required this.fecha,
    required this.accion,
    this.actor,
    this.objetivo,
    this.detalle,
  });

  factory EventoGeneral.fromJson(Map<String, dynamic> json) {
    return EventoGeneral(
      fecha: json['fecha'] ?? '',
      accion: json['accion'] ?? '',
      actor: json['actor'],
      objetivo: json['objetivo'],
      detalle: json['detalle'],
    );
  }
}

class AuditoriaGeneralService {
  static Future<List<EventoGeneral>> obtenerEventosGenerales({
    String? accion,
    int limite = 100,
  }) async {
    final params = <String, String>{'limite': '$limite'};
    if (accion != null && accion.isNotEmpty) params['accion'] = accion;

    final uri = Uri.parse(
      '$baseUrl/usuarios/auditoria',
    ).replace(queryParameters: params);
    final response = await http.get(
      uri,
      headers: AuthSession.headers(extra: {'Accept': 'application/json'}),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((j) => EventoGeneral.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    throw Exception(
      'Error al cargar eventos de usuarios (${response.statusCode})',
    );
  }
}
