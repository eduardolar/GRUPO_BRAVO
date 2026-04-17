import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/screens/Administrador/admin_contabilidad_screen.dart';
import 'package:frontend/screens/Administrador/admin_local_screen.dart';
import 'package:frontend/screens/Administrador/admin_menu_screen.dart';
import 'package:frontend/screens/Administrador/admin_mesas_screen.dart';
import 'package:frontend/screens/Administrador/admin_stock_screen.dart';
import 'package:frontend/screens/Administrador/admin_usuarios_screen.dart';

class MenuAdministrador extends StatefulWidget {
  const MenuAdministrador({super.key});

  @override
  State<MenuAdministrador> createState() => _MenuAdministradorState();
}

class _MenuAdministradorState extends State<MenuAdministrador> {
  @override
  Widget build(BuildContext context) {
    return  Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(centerTitle: true, title: Text("MENU ADMINISTRADOR"), backgroundColor: AppColors.background,),
      body: bodyMenuAdministrador(),
    );
  }
  
  Padding bodyMenuAdministrador() {

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Spacer(),
          rowMenuAdministrador("Stock", "Usuarios", () => AdminStockScreen(), () => AdminUsuariosScreen()),
          Spacer(),
          rowMenuAdministrador("Menú", "Administrar local", () => AdminMenuScreen(), () => AdminLocalScreen()),
          Spacer(),
          rowMenuAdministrador("Mesas", "Contabilidad", () => AdminMesasScreen(), () =>  AdminContabilidadScreen()),
          Spacer(),
        ],
      ),
    );
  }

  Row rowMenuAdministrador(String textoBoton1, textoBoton2, Widget Function() funcion1, funcion2) {
    return Row(
      children: [
        SizedBox(
          height: 170,
          width: 170,
          child: botonMenuAdmisnistrador(context, textoBoton1, funcion1),
        ),
        Spacer(),
        SizedBox(
          height: 170,
          width: 170,
          child: botonMenuAdmisnistrador(context, textoBoton2, funcion2),
        ),
      ],
    );
  }

  ElevatedButton botonMenuAdmisnistrador(BuildContext context, String textoBoton, Widget Function()  builder){
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.button,
        foregroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
      ),
      
      ), 
      onPressed: () { 
        Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => builder()));
       }, child: Text(textoBoton), 
    );
  }
}