import 'package:flutter/material.dart';

class MyWidget extends StatefulWidget {
  const MyWidget({super.key});

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Spacer(),
        TextField(decoration: InputDecoration(hintText: "Introduce tu email"),),
        TextField(obscureText: true, decoration: InputDecoration(hintText: "Introduce tu contraseña")),
        Spacer(),
        FloatingActionButton(onPressed: (){})
      ],
    );
  }
}