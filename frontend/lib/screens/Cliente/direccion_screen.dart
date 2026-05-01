import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart'; // Para 'Position'
import '../../core/colors_style.dart';
import '../../services/location_service.dart'; // Para 'LocationService'
import 'package:provider/provider.dart';
import '../../services/usuario_service.dart'; // Para 'UsuarioService' y actualizar la dirección del usuario
import '../../providers/auth_provider.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'dart:async'; // Para 'Timer' y evitar llamadas excesivas a la API
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
  // VARIABLES INICIALES
  LatLng _puntoActual = const LatLng(40.416775, -3.703790); // Madrid
  String _direccionTexto = "Cargando...";
  bool _cargando = false;
  Timer? _debounceTimer;

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _pisoPuertaController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _obtenerDireccionDesdeCoords(_puntoActual);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _pisoPuertaController.dispose();
    _direccionController.dispose();
    super.dispose();
  }

  // 1. TRADUCIR COORDENADAS A TEXTO
  Future<void> _obtenerDireccionDesdeCoords(LatLng coords) async {
    setState(() => _cargando = true);

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=json&lat=${coords.latitude}&lon=${coords.longitude}&zoom=18&addressdetails=1',
    );

    try {
      final response = await http.get(url, headers: {'User-Agent': 'BravoApp'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final addr = data['address'];

        // validacion CLAVE
        if (addr != null) {
          setState(() {
            // ordenar los componentes de la dirección de forma lógica
            String calle =
                addr['road'] ??
                addr['pedestrian'] ??
                addr['path'] ??
                "Calle sin nombre";
            String numero = addr['house_number'] ?? "s/n";
            String ciudad =
                addr['city'] ?? addr['town'] ?? addr['village'] ?? "";
            String cp = addr['postcode'] ?? "";
            // orden lógico: calle + número...
            _direccionTexto = "$calle $numero, $cp $ciudad";
            _direccionController.text = _direccionTexto;
          });
        }
      } else {
        setState(() => _direccionController.text = "Ubicación no disponible");
      }
    } catch (e) {
      setState(() => _direccionController.text = "Ubicación no disponible");
    } finally {
      setState(() => _cargando = false);
    }
  }

  // --- 2. MOVER EL MAPA
  void _moverMapa(LatLng destino) {
    _mapController.move(destino, 17);
    _obtenerDireccionDesdeCoords(destino);
  }

  // --- 3. BUSCAR POR TEXTO ---
  Future<void> _buscarDireccionEscrita(String texto) async {
    if (texto.isEmpty) return;
    setState(() => _cargando = true);

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(texto)}&format=json&limit=1',
    );

    try {
      final response = await http.get(url, headers: {'User-Agent': 'BravoApp'});
      final data = json.decode(response.body);

      if (data.isNotEmpty) {
        double lat = double.parse(data[0]['lat']);
        double lon = double.parse(data[0]['lon']);
        _moverMapa(LatLng(lat, lon));
        _searchController.clear();
      }
    } catch (e) {
      debugPrint("Error buscando: $e");
    } finally {
      setState(() => _cargando = false);
    }
  }

  //
  Future<List<dynamic>> _obtenerSugerencias(String query) async {
    if (query.length < 3)
      return []; // Evitar consultas con muy pocos caracteres

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&addressdetails=1',
    );

    try {
      final response = await http.get(url, headers: {'User-Agent': 'BravoApp'});
      if (response.statusCode == 200) {
        return json.decode(response.body) as List;
      }
    } catch (e) {
      debugPrint("Error obteniendo sugerencias: $e");
    }
    return [];
  }

  // --- LÓGICA 2: GPS
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

  // --- LÓGICA 3: GUARDADO (Protección MongoDB contra errores) ---
  Future<void> _confirmarYGuardar() async {
    // Bloqueo de seguridad: No guardamos basura en la BD
    if (_direccionTexto.contains("no disponible") ||
        _direccionTexto == "Cargando...") {
      _mostrarError("Selecciona una ubicación válida antes de guardar.");
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
          'lat': _puntoActual.latitude,
          'lng': _puntoActual.longitude,
        });
        return;
      }

      final userId = auth.usuarioActual?.id;
      if (userId == null) throw "Sesión expirada";

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
        Navigator.pop(context);
      }
    } catch (e) {
      _mostrarError("Error al guardar: $e");
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return ClienteAuthScaffold(
      maxWidth: double.infinity,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // SECCIÓN MAPA (Tamaño fijo para evitar errores de renderizado)
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
                      setState(
                        () => _puntoActual = pos.center!,
                      ); // Movimiento visual fluido
                      if (hasGesture) {
                        _debounceTimer?.cancel();
                        _debounceTimer = Timer(
                          const Duration(milliseconds: 500),
                          () {
                            _obtenerDireccionDesdeCoords(
                              pos.center!,
                            ); // Llamada a API con retraso
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
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Barra de búsqueda (Estilo Login)
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: _buildBarraBusqueda(),
                ),
              ],
            ),
          ),

          // SECCIÓN FORMULARIO (Diseño idéntico al Login)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
            child: Column(
              children: [
                const AuthHeader(
                  titulo: 'Tu dirección de entrega es:',
                  // subtitulo: 'Confirma dónde enviaremos tu pedido',
                ),
                const SizedBox(height: 20),

                EntradaTexto(
                  etiqueta: 'Dirección detectada',
                  icono: Icons.map_outlined,
                  controlador: _direccionController,
                  readOnly: true,
                ),
                const SizedBox(height: 15),

                EntradaTexto(
                  etiqueta: 'Piso, Puerta, Bloque...',
                  icono: Icons.apartment,
                  controlador: _pisoPuertaController,
                ),

                const SizedBox(height: 15),

                // Botón GPS sutil
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

                const SizedBox(height: 30),

                PrimaryButton(
                  label: 'CONFIRMAR Y GUARDAR',
                  isLoading: _cargando,
                  // El botón se desactiva solo si la dirección es inválida
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

  Widget _buildBarraBusqueda() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      child: TypeAheadField(
        // --- NUEVO: TypeAheadField para autocompletar direcciones
        builder: (context, controller, focusNode) {
          return TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: false,
            decoration: InputDecoration(
              hintText: "Escribe tu calle...",
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 15,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
            ),
          );
        },

        //llama a la API mientras se escribe
        suggestionsCallback: (search) => _obtenerSugerencias(search),
        itemBuilder: (context, suggestion) {
          return ListTile(
            leading: const Icon(Icons.location_on_outlined, color: Colors.grey),
            title: Text(
              suggestion['display_name'],
              style: const TextStyle(fontSize: 13),
            ),
          );
        },
        // lo que pasa al seleccionar una sugerencia
        onSelected: (suggestion) {
          double lat = double.parse(suggestion['lat']);
          double lon = double.parse(suggestion['lon']);
          LatLng nuevaUbicacion = LatLng(lat, lon);

          // Mover el mapa a la posición seleccionada
          _moverMapa(nuevaUbicacion);
          // Limpiar el campo de búsqueda
          _searchController.clear();
        },
        emptyBuilder: (context) => const Padding(
          padding: EdgeInsets.all(16),
          child: Text("No se encontraron direcciones"),
        ),
      ),
    );
  }
}
