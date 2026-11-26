import 'package:flutter/material.dart';
import '../core/datos.dart';
import '../core/validadores.dart';
import '../estado/app_state.dart';
import '../estado/entidades.dart';
import '../estado/proveedor.dart';
import 'comunes.dart';

class InfoEspera {
  final int delante;
  final String espera;
  final String frase;
  const InfoEspera(this.delante, this.espera, this.frase);
}

InfoEspera calcularEspera(AppState s, Paciente p) {
  if (p.estado == 'en_atencion') return const InfoEspera(0, 'En atención', 'Ya está siendo atendido.');
  final o = s.ordenCola();
  final idx = o.orden.indexWhere((x) => x.id == p.id);
  if (idx < 0) return const InfoEspera(0, '—', '');
  final ini = o.r.inicios.length > idx ? o.r.inicios[idx] : 0.0;
  final base = ini < 0 ? 0.0 : ini;
  final lo = ((base * 0.7) / 5).round() * 5;
  final hi = ((base * 1.3) / 5).round() * 5 + 5;
  if (p.decision!.prior == 1) return InfoEspera(idx, 'Inmediata', 'Lo atendemos de inmediato.');
  return InfoEspera(idx, '$lo a $hi min', 'Calculamos una espera de $lo a $hi min.');
}

class PaginaExplicacion extends StatefulWidget {
  const PaginaExplicacion({super.key});
  @override
  State<PaginaExplicacion> createState() => _PaginaExplicacionState();
}

class _PaginaExplicacionState extends State<PaginaExplicacion> {
  String? _id;
  String? _resp;
  String? _err;

  @override
  Widget build(BuildContext context) {
    final s = Estado.de(context);
    final cl = s.pacientes.where((p) => p.estado == 'clasificado' || p.estado == 'en_atencion').toList();
    if (_id != null && !cl.any((p) => p.id == _id)) _id = null;
    final p = s.porId(_id);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Encabezado('Explicación al paciente', 'Que el paciente entienda su prioridad', sub: 'El 71 % no recibió explicación y el 58 % no entendió su prioridad (encuestas del APF2).'),
        Tarjeta(
          child: Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(
              width: 360,
              child: Lista<String>('Paciente clasificado', valor: _id, opciones: cl.map((e) => e.id).toList(), texto: (id) {
                final x = s.porId(id)!;
                return '$id · Prioridad ${pr(x.decision!.prior).romano}';
              }, ayuda: cl.isEmpty ? 'No hay pacientes clasificados.' : null, alCambiar: (v) => setState(() {
                    _id = v;
                    _resp = null;
                    _err = null;
                  })),
            ),
            FilledButton.icon(
              onPressed: p == null
                  ? null
                  : () {
                      s.registrarEvento('Vista para el paciente mostrada', p: p);
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => VistaParaPaciente(p: p, info: calcularEspera(s, p))));
                    },
              icon: const Icon(Icons.fullscreen),
              label: const Text('Vista para el paciente'),
            ),
          ]),
        ),
        if (p != null) ...[
          BloqueExplicacion(p: p, info: calcularEspera(s, p)),
          Tarjeta(
            titulo: 'Guion breve para el personal',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('«Su prioridad es ${pr(p.decision!.prior).romano}: ${pr(p.decision!.prior).nombre.toLowerCase()}.»'),
              const SizedBox(height: 6),
              Text('«${pr(p.decision!.prior).paraPaciente}»'),
              const SizedBox(height: 6),
              Text('«${calcularEspera(s, p).frase} Si se siente peor, avíseme enseguida.»'),
            ]),
          ),
          if (s.rol != Rol.comite)
            Tarjeta(
              titulo: 'Comprensión del paciente (indicador H4)',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Después de explicar, pregunte: «¿Puede contarme con sus palabras qué prioridad tiene y por qué?»', style: TextStyle(color: Colores.tenue)),
                const SizedBox(height: 8),
                Lista<String>('¿El paciente explicó su prioridad con sus palabras?', requerido: true, valor: _resp ?? p.comprension, opciones: const ['Sí', 'No', 'No aplica (paciente no puede responder)'], texto: (x) => x, error: _err, alCambiar: (v) => setState(() {
                      _resp = v;
                      _err = null;
                    })),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () {
                      final r = _resp ?? p.comprension;
                      if (r == null) {
                        setState(() => _err = 'Seleccione una respuesta.');
                        return;
                      }
                      s.registrarComprension(p, r);
                      aviso(context, 'Respuesta registrada.');
                    },
                    child: const Text('Guardar'),
                  ),
                ),
                if (p.comprension != null) Text('Último registro: ${p.comprension} (${hhmm(p.comprensionTs!)}).', style: const TextStyle(color: Colores.tenue, fontSize: 12)),
              ]),
            ),
        ],
      ]),
    );
  }
}

class BloqueExplicacion extends StatelessWidget {
  final Paciente p;
  final InfoEspera info;
  final bool grande;
  const BloqueExplicacion({super.key, required this.p, required this.info, this.grande = false});
  @override
  Widget build(BuildContext context) {
    final d = p.decision!;
    final tam = grande ? 40.0 : 28.0;
    return Tarjeta(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Paciente ${p.id} · hora de llegada ${hhmm(p.llegadaTs)}', style: const TextStyle(color: Colores.tenue)),
        const SizedBox(height: 8),
        Wrap(spacing: 14, runSpacing: 14, children: [
          CajaPrioridad(d.prior, titulo: 'Su prioridad', ancho: grande ? 240 : 170),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Aviso(TipoAviso.info, Text.rich(TextSpan(style: TextStyle(fontSize: grande ? 22 : 15), children: [const TextSpan(text: '¿Qué significa? ', style: TextStyle(fontWeight: FontWeight.w800)), TextSpan(text: pr(d.prior).paraPaciente)]))),
              const SizedBox(height: 8),
              Wrap(spacing: 40, runSpacing: 10, children: [
                Column(children: [
                  Text('${info.delante}', style: TextStyle(fontSize: tam, fontWeight: FontWeight.w900, color: Colores.navy)),
                  const Text('personas serán atendidas antes que usted', style: TextStyle(color: Colores.tenue)),
                ]),
                Column(children: [
                  Text(info.espera, style: TextStyle(fontSize: tam, fontWeight: FontWeight.w900, color: Colores.navy)),
                  const Text('espera aproximada', style: TextStyle(color: Colores.tenue)),
                ]),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final n in [1, 2, 3, 4])
            Chip(
              visualDensity: VisualDensity.compact,
              side: BorderSide(color: n == d.prior ? pr(n).color : Colores.linea, width: n == d.prior ? 2 : 1),
              label: Text('${pr(n).romano} · ${pr(n).corto}', style: TextStyle(fontWeight: n == d.prior ? FontWeight.w800 : FontWeight.w400)),
            ),
        ]),
        Aviso.texto(TipoAviso.ok, '✓ Un profesional de salud revisó y confirmó esta prioridad.'),
        Aviso.texto(TipoAviso.alerta, '⚠ Si se siente peor, avise de inmediato al personal.'),
        const Text('La espera es una estimación y puede cambiar si llegan casos más graves.', style: TextStyle(color: Colores.tenue, fontSize: 12)),
      ]),
    );
  }
}

class VistaParaPaciente extends StatelessWidget {
  final Paciente p;
  final InfoEspera info;
  const VistaParaPaciente({super.key, required this.p, required this.info});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colores.navy, foregroundColor: Colors.white, title: const Text('Información para el paciente')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: BloqueExplicacion(p: p, info: info, grande: true)),
    );
  }
}
