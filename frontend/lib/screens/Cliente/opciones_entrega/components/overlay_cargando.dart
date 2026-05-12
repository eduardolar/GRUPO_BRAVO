import 'package:flutter/material.dart';

class OverlayCargando extends StatelessWidget {
  const OverlayCargando({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0x8C000000),
      child: SizedBox.expand(
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
    );
  }
}
