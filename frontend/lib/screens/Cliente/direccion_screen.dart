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

class DireccionScreen extends StatefulWidget {
  const DireccionScreen({super.key});

  @override
  State<DireccionScreen> createState() => _DireccionScreenState();
}

class _DireccionScreenState extends State<DireccionScreen> {
  // VARIABLES INICIALES
  LatLng _puntoActual = const LatLng(40.416775, -3.703790); // Madrid
  String _direccionTexto = "Cargando...";
  bool _cargando = false;
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _obtenerDireccionDesdeCoords(_puntoActual);
  }

  // 1. TRADUCIR COORDENADAS A TEXTO
  Future<void> _obtenerDireccionDesdeCoords(LatLng coords) async {
    setState(() {
      _cargando = true;
      _puntoActual = coords;
    });

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=json&lat=${coords.latitude}&lon=${coords.longitude}&zoom=18'
    );

    try {
      final response = await http.get(url, headers: {'User-Agent': 'BravoApp'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _direccionTexto = data['display_name'] ?? "Dirección desconocida";
        });
      }
    } catch (e) {
      setState(() => _direccionTexto = "Error al obtener dirección");
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
      'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(texto)}&format=json&limit=1'
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Selecciona Ubicación"), backgroundColor: AppColors.backgroundButton),
      body: Column(
        children: [
          // PARTE SUPERIOR: EL MAPA
          Expanded(
            flex: 1,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _puntoActual,
                    initialZoom: 17,
                    onPositionChanged: (position, hasGesture) {
                      if (hasGesture) {
                        _obtenerDireccionDesdeCoords(position.center!);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _puntoActual,
                          width: 80,
                          height: 80,
                          child: const Icon(Icons.location_on, color: Colors.red, size: 45),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 10, left: 15, right: 15,
                  child: _buildBarraBusqueda(), 
                ),
              ],
            ),
          ),

          // PARTE INFERIOR: INFO Y ACCIONES
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: Colors.white,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const Icon(Icons.location_searching_rounded, size: 40, color: Colors.grey),
                  if (_cargando) const LinearProgressIndicator(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      _direccionTexto,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),

                  // BOTÓN GPS
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.my_location),
                      label: const Text("USAR MI UBICACIÓN ACTUAL"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blueAccent,
                        side: const BorderSide(color: Colors.blueAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: _cargando ? null : () async {
                        final LocationService locationService = LocationService();
                        try {
                          Position? position = await locationService.obtenerUbicacionActual();
                          if (position != null) {
                            _moverMapa(LatLng(position.latitude, position.longitude));
                          }
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Error de GPS: $e"))
                          );
                        }
                      },
                    ),
                  ),

                  // BOTÓN GUARDAR

  ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: AppColors.backgroundButton,
    minimumSize: const Size(double.infinity, 55),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
  ),
  onPressed: _cargando ? null : () async {
    setState(() => _cargando = true);

    // 1. Obtenemos los servicios y el usuario actual
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final usuarioService = UsuarioService();
    final userId = auth.usuarioActual?.id;

    if (userId == null) {
      _mostrarError("Sesión no válida. Vuelve a loguearte.");
      return;
    }

    try {
      // 2. GUARDAR EN MONGODB (Llamada a tu API Python)
      bool exito = await usuarioService.actualizarDireccion(
        userId: userId,
        direccion: _direccionTexto,
        latitud: _puntoActual.latitude,
        longitud: _puntoActual.longitude,
      );

      if (exito) {
        // 3. ACTUALIZAR MEMORIA LOCAL (Para que la pantalla de entrega se entere)
        // Nota: Asegúrate de tener esta función en tu AuthProvider (paso siguiente)
        auth.actualizarDireccionLocal(
          nuevaDir: _direccionTexto,
          nuevaLat: _puntoActual.latitude,
          nuevaLon: _puntoActual.longitude,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("¡Ubicación guardada con éxito!"), backgroundColor: Colors.green),
        );
        
        Navigator.pop(context); // Ahora sí, volvemos con los datos guardados
      } else {
        _mostrarError("El servidor no pudo guardar la dirección.");
      }
    } catch (e) {
      _mostrarError("Error de conexión: $e");
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  },
  child: const Text("CONFIRMAR Y GUARDAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
)
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
 
  Widget _buildBarraBusqueda() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black26)],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: "Buscar otra calle...",
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          border: InputBorder.none,
          suffixIcon: IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _buscarDireccionEscrita(_searchController.text),
          ),
        ),
        onSubmitted: _buscarDireccionEscrita,
      ),
    );
  }

  void _mostrarError(String mensaje) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(mensaje),
      backgroundColor: Colors.redAccent,
    ),
  );
  }
}