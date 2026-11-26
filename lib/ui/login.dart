import 'dart:async';
import 'package:flutter/material.dart';
import '../estado/proveedor.dart';
import 'comunes.dart';

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});
  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final _u = TextEditingController();
  final _c = TextEditingController();
  String? _eu, _ec, _general;
  bool _ver = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _u.dispose();
    _c.dispose();
    super.dispose();
  }

  void _ingresar() {
    final s = Estado.de(context);
    setState(() {
      _eu = _u.text.trim().isEmpty ? 'Ingrese su usuario.' : null;
      _ec = _c.text.isEmpty ? 'Ingrese su contraseña.' : null;
      _general = null;
    });
    if (_eu != null || _ec != null) return;
    final r = s.iniciarSesion(_u.text, _c.text);
    if (r != null) setState(() => _general = r);
  }

  @override
  Widget build(BuildContext context) {
    final s = Estado.de(context);
    final bloq = s.bloqueoHasta != null && DateTime.now().isBefore(s.bloqueoHasta!);
    final seg = bloq ? s.bloqueoHasta!.difference(DateTime.now()).inSeconds + 1 : 0;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colores.navy, Colores.navy2, Colores.teal])),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: 420,
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Container(width: 42, height: 42, decoration: BoxDecoration(color: Colores.navy, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.local_hospital, color: Colors.white)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Triaje Inteligente', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Colores.navy)),
                      Text('Prototipo académico APF3 · datos ficticios', style: TextStyle(color: Colores.tenue)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 20),
                Campo(_u, 'Usuario', requerido: true, error: _eu, maxLength: 40, alCambiar: (_) => setState(() => _eu = null)),
                Campo(_c, 'Contraseña', requerido: true, error: _ec, oculto: !_ver, maxLength: 40, alCambiar: (_) => setState(() => _ec = null),
                    sufijo: IconButton(tooltip: _ver ? 'Ocultar' : 'Mostrar', icon: Icon(_ver ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _ver = !_ver))),
                if (bloq) Aviso.texto(TipoAviso.error, 'Acceso bloqueado por 3 intentos fallidos. Espere $seg s.') else if (_general != null) Aviso.texto(TipoAviso.error, _general!),
                const SizedBox(height: 6),
                FilledButton(onPressed: bloq ? null : _ingresar, child: const Text('Ingresar')),
                const SizedBox(height: 14),
                const Text('Usuarios de prueba: enfermera1 / Triaje2026! · medico.jefe / Jefe2026! · comite / Comite2026!', style: TextStyle(color: Colores.tenue, fontSize: 12.5)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
