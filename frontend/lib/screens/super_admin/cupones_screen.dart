import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../components/bravo_app_bar.dart';
import '../../models/cupon_model.dart';
import '../../services/cupon_service.dart';
import '../../core/colors_style.dart';

// ─── Colores ─────────────────────────────────────────────────────────────────
const _kBg = Color(0xFF0F0F0F);
const _kCard = Color(0xFF1C1C1E);
const _kBorder = Color(0xFF2C2C2E);
const _kText = Color(0xFFEAEAEA);
const _kSub = Color(0xFF8E8E93);
const _kGreen = Color(0xFF34C759);
const _kOrange = Color(0xFFFF9500);
const _kRed = Color(0xFFFF3B30);
const _kBlue = Color(0xFF0A84FF);
const _kAccent = AppColors.button;

class CuponesScreen extends StatefulWidget {
  const CuponesScreen({super.key});

  @override
  State<CuponesScreen> createState() => _CuponesScreenState();
}

class _CuponesScreenState extends State<CuponesScreen>
    with SingleTickerProviderStateMixin {
  List<Cupon> _cupones = [];
  bool _cargando = true;
  String? _error;

  String _filtro = 'todos';
  String _busqueda = '';
  String _orden = 'recientes';

  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        setState(() {
          _filtro = ['todos', 'activos', 'inactivos'][_tabCtrl.index];
        });
      }
    });
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
    });
    try {
      final lista = await CuponService.listar();
      setState(() {
        _cupones = lista;
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  List<Cupon> get _filtrados {
    var lista = _cupones;

    if (_filtro == 'activos') {
      lista = lista.where((c) => c.activo).toList();
    } else if (_filtro == 'inactivos') {
      lista = lista.where((c) => !c.activo).toList();
    }

    if (_busqueda.isNotEmpty) {
      final q = _busqueda.toLowerCase();
      lista = lista
          .where(
            (c) =>
                c.codigo.toLowerCase().contains(q) ||
                c.descripcion.toLowerCase().contains(q),
          )
          .toList();
    }

    if (_orden == 'usados') {
      lista.sort((a, b) => b.usosActuales.compareTo(a.usosActuales));
    } else {
      lista.sort((a, b) => b.id.compareTo(a.id));
    }

    return lista;
  }

  Future<void> _duplicar(Cupon c) async {
    await CuponService.crear(
      codigo: "${c.codigo}_COPY",
      tipo: c.tipo,
      valor: c.valor,
      descripcion: c.descripcion,
      usosMaximos: c.usosMaximos,
      fechaInicio: c.fechaInicio,
      fechaFin: c.fechaFin,
    );
    _cargar();
  }

  void _mostrarQR(Cupon c) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                c.codigo,
                style: const TextStyle(
                  color: _kText,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 20),
              QrImageView(
                data: c.codigo,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _expirado(Cupon c) {
    if (c.fechaFin == null) return false;
    return DateTime.tryParse(c.fechaFin!)?.isBefore(DateTime.now()) == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const BravoAppBar(title: 'CUPONES'),
      body: Column(
        children: [
          // 🔍 BUSCADOR
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => _busqueda = v),
              style: const TextStyle(color: _kText),
              decoration: InputDecoration(
                hintText: 'Buscar...',
                hintStyle: const TextStyle(color: _kSub),
                prefixIcon: const Icon(Icons.search, color: _kSub),
                filled: true,
                fillColor: _kCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: _filtrados.length,
              itemBuilder: (_, i) {
                final c = _filtrados[i];
                final exp = _expirado(c);

                return Card(
                  color: _kCard,
                  child: ListTile(
                    title: Text(
                      c.codigo,
                      style: const TextStyle(color: _kText),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.descripcion,
                          style: const TextStyle(color: _kSub),
                        ),
                        if (exp)
                          const Text(
                            'EXPIRADO',
                            style: TextStyle(color: _kRed),
                          ),
                        Text(
                          "Usos: ${c.usosActuales}",
                          style: const TextStyle(color: _kSub),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.qr_code, color: _kAccent),
                          onPressed: () => _mostrarQR(c),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, color: _kBlue),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: c.codigo));
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_all, color: _kGreen),
                          onPressed: () => _duplicar(c),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
