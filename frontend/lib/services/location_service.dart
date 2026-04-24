import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationService {
  Future<Position?> obtenerUbicacionActual() async {
    bool servicioHabilitado;
    LocationPermission permiso;

    // Verificar si el servicio de ubicación está habilitado
    servicioHabilitado = await Geolocator.isLocationServiceEnabled();
    if (!servicioHabilitado) {
      return Future.error('El GPS está desactivado'); // El servicio de ubicación no está habilitado
    }

    // pedir permisos de ubicación
    permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied) {
        return Future.error('Permisos de ubicación denegados'); 
      }
    }

    if (permiso == LocationPermission.deniedForever) {
      return Future.error('Permisos de ubicación denegados permanentemente'); 
    }

    //si todo está ok, obtenemos la ubicación actual
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<Map<String, dynamic>?> obtenerDireccionDesdeCoordenadas(double latitud, double longitud) async {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=40.4167&lon=-3.7037&zoom=18&addressdetails=1');

        try {
          final response = await http.get(url, headers: {
            'User-Agent': 'RestauranteBravoApp', // Nominatim requiere un User-Agent personalizado
          });

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            return data; //aqui extraemos la dirección del JSON: calle, ciudad, etc.
            } 
             }catch (e) {
              print('Error al obtener dirección: $e');
             }
              return null;
             }
  }