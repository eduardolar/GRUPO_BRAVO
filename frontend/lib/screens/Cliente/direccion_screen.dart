import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_typeahead/flutter_typeahead.dart';

// TUS COMPONENTES Y SERVICIOS
import '../../core/colors_style.dart';
import '../../providers/auth_provider.dart';
import '../../services/usuario_service.dart';
import '../../services/location_service.dart';
import '../../components/Cliente/auth_scaffold.dart';
import '../../components/Cliente/auth_header.dart';
import '../../components/Cliente/entrada_texto.dart';
import '../../components/Cliente/primary_button.dart';

class DireccionScreen extends StatefulWidget {
  final bool soloSeleccionar;
  const DireccionScreen({super.key, this.soloSeleccionar = false});

  @override
  State<DireccionScreen> createState() => _DireccionScreenState();
}

class _DireccionScreenState extends State<DireccionScreen> {
  // --- CONTROLADORES Y ESTADO ---
  final MapController _mapController = MapController();
  final TextEditingController _pisoPuertaController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  LatLng _puntoActual = const LatLng(41.6488, -0.8891); // Zaragoza por defecto
  String _direccionTexto = "Cargando...";
  bool _cargando = false;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _pisoPuertaController.dispose();
    _direccionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- LÓGICA 1: OBTENER DIRECCIÓN DESDE COORDENADAS (Nominatim) ---
  Future<void> _obtenerDireccionDesdeCoords(LatLng coords) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=json&lat=${coords.latitude}&lon=${coords.longitude}',
    );

    try {
      final response = await http.get(url, headers: {'User-Agent': 'BravoApp'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final addr = data['address'];

        if (addr != null) {
          String calle =
              addr['road'] ??
              addr['pedestrian'] ??
              addr['path'] ??
              "Calle sin nombre";
          String numero = addr['house_number'] ?? "s/n";
          String ciudad = addr['city'] ?? addr['town'] ?? addr['village'] ?? "";
          String cp = addr['postcode'] ?? "";

          setState(() {
            _direccionTexto = "$calle $numero, $cp $ciudad";
            _direccionController.text =
                _direccionTexto; // Actualiza la caja visual
          });
        }
      } else {
        _setDireccionError();
      }
    } catch (e) {
      _setDireccionError();
    }
  }

  void _setDireccionError() {
    setState(() {
      _direccionTexto = "Ubicación no disponible";
      _direccionController.text = _direccionTexto;
    });
  }

  // --- LÓGICA 2: MOVIMIENTO Y GPS ---
  void _moverMapa(LatLng destino) {
    _mapController.move(destino, 17);
    setState(() => _puntoActual = destino);
    _obtenerDireccionDesdeCoords(destino);
  }

  Future<void> _obtenerUbicacionGPS() async {
    final locationService = LocationService();
    try {
      Position? position = await locationService.obtenerUbicacionActual();
      if (position != null) {
        _moverMapa(LatLng(position.latitude, position.longitude));
      }
    } catch (e) {
      _mostrarError("Error de GPS: $e");
    }
  }

  // --- LÓGICA 3: GUARDADO SEGURO (Protección MongoDB) ---
  Future<void> _confirmarYGuardar() async {
    if (_direccionTexto.contains("no disponible") ||
        _direccionTexto == "Cargando...") {
      _mostrarError("Por favor, selecciona una ubicación válida.");
      return;
    }

    setState(() => _cargando = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final usuarioService = UsuarioService();

      String detalles = _pisoPuertaController.text.trim();
      String direccionFinal = detalles.isNotEmpty
          ? "$_direccionTexto, $detalles"
          : _direccionTexto;

      if (widget.soloSeleccionar) {
        Navigator.pop(context, {
          'direccion': direccionFinal,
          'latitud': _puntoActual.latitude,
          'longitud': _puntoActual.longitude,
        });
        return;
      }

      final userId = auth.usuarioActual?.id;
      if (userId == null) throw "Sesión no válida";

      bool exito = await usuarioService.actualizarDireccion(
        userId: userId,
        direccion: direccionFinal,
        latitud: _puntoActual.latitude,
        longitud: _puntoActual.longitude,
      );

      if (exito && mounted) {
        auth.actualizarDireccionLocal(
          nuevaDir: direccionFinal,
          nuevaLat: _puntoActual.latitude,
          nuevaLon: _puntoActual.longitude,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("¡Dirección guardada!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _mostrarError("Error: $e");
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  // --- DISEÑO ---
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return ClienteAuthScaffold(
      maxWidth: double.infinity,
      padding: EdgeInsets.zero, // Mapa de borde a borde
      child: Column(
        children: [
          // 1. MAPA (45% del alto de pantalla)
          SizedBox(
            height: size.height * 0.45,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _puntoActual,
                    initialZoom: 17,
                    onPositionChanged: (pos, hasGesture) {
                      setState(() => _puntoActual = pos.center);
                      if (hasGesture) {
                        _debounceTimer?.cancel();
                        _debounceTimer = Timer(
                          const Duration(milliseconds: 500),
                          () {
                            _obtenerDireccionDesdeCoords(pos.center);
                          },
                        );
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _puntoActual,
                          width: 50,
                          height: 50,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 45,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Barra de búsqueda flotante
                Positioned(
                  top: 10,
                  left: 15,
                  right: 15,
                  child: _buildBarraBusqueda(),
                ),
              ],
            ),
          ),

          // 2. FORMULARIO (Padding lateral para textos)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 25),
            child: Column(
              children: [
                const AuthHeader(
                  titulo: 'Tu Dirección',
                  subtitulo: 'Confirma dónde enviaremos tu pedido',
                ),
                const SizedBox(height: 25),

                // Caja de Dirección Detectada (SOLO LECTURA)
                EntradaTexto(
                  etiqueta: 'Dirección actual',
                  icono: Icons.map_outlined,
                  controlador: _direccionController,
                  readOnly: true, // El cambio que hicimos en el componente
                ),

                const SizedBox(height: 15),

                // Caja de Piso/Puerta (EDITABLE)
                EntradaTexto(
                  etiqueta: 'Piso, Puerta, Bloque...',
                  icono: Icons.apartment,
                  controlador: _pisoPuertaController,
                ),

                const SizedBox(height: 15),

                // Botón GPS
                TextButton.icon(
                  onPressed: _cargando ? null : _obtenerUbicacionGPS,
                  icon: const Icon(
                    Icons.my_location,
                    color: AppColors.button,
                    size: 18,
                  ),
                  label: const Text(
                    "USAR MI UBICACIÓN ACTUAL",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                // Botón Principal
                PrimaryButton(
                  label: 'CONFIRMAR Y GUARDAR',
                  isLoading: _cargando,
                  onPressed:
                      (_direccionTexto.contains("no disponible") ||
                          _direccionTexto == "Cargando...")
                      ? null
                      : _confirmarYGuardar,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- BUSCADOR (Sugerencias) ---
  Widget _buildBarraBusqueda() {
    // 1. AÑADIMOS EL TIPO AQUÍ <Map<String, dynamic>>
    return TypeAheadField<Map<String, dynamic>>(
      builder: (context, controller, focusNode) => TextField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(
          hintText: "Escribe tu calle...",
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),

      suggestionsCallback: (search) async {
        if (search.length < 3) return [];
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=json&q=$search&limit=5',
        );
        final response = await http.get(
          url,
          headers: {'User-Agent': 'BravoApp'},
        );

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          // Convertimos explícitamente a una lista de Mapas
          return data.map((item) => item as Map<String, dynamic>).toList();
        }
        return [];
      },

      // 2. AQUÍ TAMBIÉN ESPECIFICAMOS EL MAPA
      itemBuilder: (context, Map<String, dynamic> suggestion) {
        return ListTile(
          title: Text(
            suggestion['display_name']?.toString() ?? "Dirección sin nombre",
            style: const TextStyle(fontSize: 12),
          ),
        );
      },

      // 3. Y AQUÍ TAMBIÉN
      onSelected: (Map<String, dynamic> suggestion) {
        _moverMapa(
          LatLng(
            double.parse(suggestion['lat'].toString()),
            double.parse(suggestion['lon'].toString()),
          ),
        );
        _searchController.clear();
      },
    );
  }
}
