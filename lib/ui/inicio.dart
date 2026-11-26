import 'dart:async';
import 'package:flutter/material.dart';
import '../core/datos.dart';
import '../core/validadores.dart';
import '../estado/proveedor.dart';
import 'comunes.dart';
import 'explicacion.dart';
import 'guia.dart';
import 'modelo_page.dart';
import 'registro.dart';
import 'reglas.dart';
import 'sincronizacion.dart';
import 'tablero.dart';
import 'triaje.dart';

class Seccion {
  final String id;
  final String titulo;
  final IconData icono;
  const Seccion(this.id, this.titulo, this.icono);
}

const _todas = [
  Seccion('triaje', 'Triaje', Icons.assignment_ind_outlined),
  Seccion('explicacion', 'Explicación', Icons.chat_bubble_outline),
  Seccion('tablero', 'Tablero', Icons.insights_outlined),
  Seccion('registro', 'Registro y auditoría', Icons.list_alt),
  Seccion('modelo', 'Modelo y DevOps', Icons.memory),
  Seccion('nube', 'Nube y sincronización', Icons.cloud_outlined),
  Seccion('reglas', 'Reglas y pruebas', Icons.rule),
  Seccion('guia', 'Guía', Icons.info_outline),
];

List<String> seccionesDe(Rol r) => switch (r) {
      Rol.enfermera => ['triaje', 'explicacion', 'tablero', 'registro', 'nube', 'reglas', 'guia'],
      Rol.jefe => ['triaje', 'explicacion', 'tablero', 'registro', 'modelo', 'nube', 'reglas', 'guia'],
      Rol.comite => ['modelo', 'tablero', 'registro', 'nube', 'reglas', 'guia'],
    };

class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});
  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  String? _sec;
  Timer? _t;
  static const _inactividadMin = 15;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      final s = Estado.de(context);
      if (s.usuario != null && DateTime.now().difference(s.ultimaActividad).inMinutes >= _inactividadMin) {
        s.cerrarSesion(inactividad: true);
      } else {
        setState(() {}); // refresca el reloj y las esperas
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void irA(String id) => setState(() => _sec = id);

  @override
  Widget build(BuildContext context) {
    final s = Estado.de(context);
    final u = s.usuario!;
    final permit = seccionesDe(u.rol);
    final sec = (_sec != null && permit.contains(_sec)) ? _sec! : permit.first;
    Widget pagina;
    switch (sec) {
      case 'triaje':
        pagina = const PaginaTriaje();
        break;
      case 'explicacion':
        pagina = const PaginaExplicacion();
        break;
      case 'tablero':
        pagina = const PaginaTablero();
        break;
      case 'registro':
        pagina = const PaginaRegistro();
        break;
      case 'modelo':
        pagina = const PaginaModelo();
        break;
      case 'nube':
        pagina = const PaginaNube();
        break;
      case 'reglas':
        pagina = const PaginaReglas();
        break;
      default:
        pagina = const PaginaGuia();
    }
    return Listener(
      onPointerDown: (_) => s.ultimaActividad = DateTime.now(),
      child: Scaffold(
        body: Column(children: [
          _cabecera(context),
          _banner(context),
          Container(
            color: Colores.fondo,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final x in _todas.where((x) => permit.contains(x.id)))
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                      onTap: () => irA(x.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: sec == x.id ? Colors.white : const Color(0xFFE3E9F1),
                          border: Border.all(color: Colores.linea),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                        ),
                        child: Row(children: [
                          Icon(x.icono, size: 18, color: sec == x.id ? Colores.teal : Colores.tenue),
                          const SizedBox(width: 6),
                          Text(x.titulo, style: TextStyle(fontWeight: FontWeight.w700, color: sec == x.id ? Colores.navy : const Color(0xFF33415A))),
                        ]),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              width: double.infinity,
              child: KeyedSubtree(key: ValueKey(sec), child: pagina),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _chip(String t, {IconData? icono, Color? color, VoidCallback? onTap, String? tooltip}) {
    final w = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color ?? const Color(0x1FFFFFFF), border: Border.all(color: Colors.white38), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icono != null) ...[Icon(icono, size: 15, color: Colors.white), const SizedBox(width: 5)],
        Text(t, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ]),
    );
    final c = onTap == null ? w : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(999), child: w);
    return tooltip == null ? c : Tooltip(message: tooltip, child: c);
  }

  Widget _cabecera(BuildContext context) {
    final s = Estado.de(context);
    final u = s.usuario!;
    return Container(
      color: Colores.navy,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SafeArea(
        bottom: false,
        child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.local_hospital, color: Colores.navy)),
            const SizedBox(width: 10),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Triaje Inteligente · APF3', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
              Text('Servicio de Emergencia · prototipo académico', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
            const SizedBox(width: 12),
          ]),
          _chip(s.modoTexto, icono: s.modoPiloto ? Icons.visibility : Icons.visibility_off, color: s.modoPiloto ? Colores.teal : const Color(0xFF6B4E16), tooltip: 'El modo depende del estado de la versión del modelo (ciclo DevOps)'),
          _chip(s.resumenVersiones, icono: Icons.memory),
          _chip(s.enLinea ? 'En línea' : 'Sin conexión · ${s.pendientesSync} pendientes', icono: s.enLinea ? Icons.cloud_done : Icons.cloud_off, color: s.enLinea ? null : const Color(0xFF8E3B00), onTap: () => irA('nube'), tooltip: 'Conectividad segura y controlada con la nube'),
          _chip('Hora ${hhmm(s.ahora)}', icono: Icons.schedule, tooltip: 'Hora simulada del turno'),
          _chip('+10 min', icono: Icons.fast_forward, onTap: () => s.avanzarReloj(10), tooltip: 'Simula el paso del tiempo para probar esperas y revaloraciones'),
          _chip('${u.nombre} · ${rolTexto(u.rol)}', icono: Icons.person),
          if (u.rol == Rol.jefe)
            _chip('Reiniciar demo', icono: Icons.restart_alt, onTap: () async {
              if (await confirmar(context, 'Reiniciar demostración', 'Se borrarán todos los pacientes, decisiones, la cola de sincronización y la auditoría de este dispositivo.', palabra: 'REINICIAR')) {
                await s.reiniciar();
                if (context.mounted) aviso(context, 'Demostración reiniciada.');
              }
            }),
          _chip('Cerrar sesión', icono: Icons.logout, onTap: () => s.cerrarSesion()),
        ]),
      ),
    );
  }

  Widget _banner(BuildContext context) {
    final s = Estado.de(context);
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF6D6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text.rich(TextSpan(style: const TextStyle(fontSize: 12.5, color: Color(0xFF4A3B00)), children: [
        const TextSpan(text: 'Prototipo con datos ficticios. ', style: TextStyle(fontWeight: FontWeight.w800)),
        const TextSpan(text: 'El padrón simula RENIEC y la historia clínica; el modelo usa pesos ilustrativos (no entrenados). '),
        const TextSpan(text: 'La decisión final siempre es del profesional.', style: TextStyle(fontWeight: FontWeight.w800)),
        if (!s.modoPiloto) const TextSpan(text: '\nMODO SOMBRA: no hay versión aprobada en producción; el personal clasifica sin ver la sugerencia.', style: TextStyle(fontWeight: FontWeight.w800)),
      ])),
    );
  }
}
