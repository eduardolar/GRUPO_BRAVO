import 'package:flutter/material.dart';
import 'package:frontend/models/producto_model.dart';

class AdminEditarPlato extends StatefulWidget {

  final Producto producto;

  const AdminEditarPlato({super.key, required this.producto});

  @override
  State<AdminEditarPlato> createState() => _AdminEditarPlatoState();
}

class _AdminEditarPlatoState extends State<AdminEditarPlato> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}