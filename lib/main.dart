// Triaje Inteligente · APF3 — prototipo académico con datos ficticios.
// Servicio de Emergencia. La decisión final siempre es del profesional de salud.

import 'package:flutter/material.dart';
import 'estado/app_state.dart';
import 'estado/proveedor.dart';
import 'ui/comunes.dart';
import 'ui/inicio.dart';
import 'ui/login.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final estado = AppState();
  await estado.cargar();
  runApp(TriajeApp(estado: estado));
}

class TriajeApp extends StatelessWidget {
  final AppState estado;
  const TriajeApp({super.key, required this.estado});
  @override
  Widget build(BuildContext context) {
    return Estado(
      estado: estado,
      child: MaterialApp(
        title: 'Triaje Inteligente APF3',
        debugShowCheckedModeBanner: false,
        theme: temaApp(),
        home: const Raiz(),
      ),
    );
  }
}

class Raiz extends StatelessWidget {
  const Raiz({super.key});
  @override
  Widget build(BuildContext context) {
    final s = Estado.de(context);
    return s.usuario == null ? const PantallaLogin() : const PantallaInicio();
  }
}
