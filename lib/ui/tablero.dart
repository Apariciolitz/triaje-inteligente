import 'package:flutter/material.dart';
import '../core/datos.dart';
import '../core/algoritmos.dart';
import '../core/validadores.dart';
import '../estado/proveedor.dart';
import 'comunes.dart';
import 'triaje.dart' show enviarATopico;

class PaginaTablero extends StatefulWidget {
  const PaginaTablero({super.key});
  @override
  State<PaginaTablero> createState() => _PaginaTableroState();
}

class _PaginaTableroState extends State<PaginaTablero> {
  final _lb = TextEditingController();
  String? _eLb;

  @override
  void dispose() {
    _lb.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = Estado.de(context);
    if (_lb.text.isEmpty && s.lineaBase != null) _lb.text = '${s.lineaBase}';
    final reales = s.pacientes.where((p) => p.decision != null && !p.sintetico).toList();
    final tiempos = reales.map((p) => p.decision!.ts.difference(p.llegadaTs).inMinutes).toList();
    final h1 = tiempos.isEmpty ? null : tiempos.reduce((a, b) => a + b) / tiempos.length;
    final red = (s.lineaBase != null && h1 != null) ? 1 - h1 / s.lineaBase! : null;
    final prod = s.versionProduccion;
    final pares = prod == null ? <Par>[] : reales.where((p) => p.preds.containsKey(prod.version)).map((p) => Par(p.decision!.priorInicial, p.preds[prod.version]!.prioridad)).toList();
    final conc = pares.isEmpty ? null : pares.where((x) => x.ref == x.pred).length / pares.length;
    final k = kappa(pares);
    final h3 = reales.isEmpty ? null : reales.where((p) => p.decision!.modo == 'piloto').length / reales.length;
    final comp = s.pacientes.where((p) => p.comprension != null && !p.comprension!.startsWith('No aplica')).toList();
    final h4 = comp.isEmpty ? null : comp.where((p) => p.comprension == 'Sí').length / comp.length;
    final bajo = reales.where((p) => p.decision!.sugeridaVisible != null && p.decision!.priorInicial > p.decision!.sugeridaVisible!).length;
    final sala = s.enSala;
    final dist = [1, 2, 3, 4].map((n) => sala.where((p) => p.decision?.prior == n).length).toList();
    final mx = dist.fold<int>(1, (a, b) => b > a ? b : a);
    final o = s.ordenCola();

    Widget kpi(String et, String val, String nota, {Widget? extra}) => Container(
          width: 230,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: Colores.linea), borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(et.toUpperCase(), style: const TextStyle(fontSize: 11.5, color: Color(0xFF46536A), fontWeight: FontWeight.w700)),
            Text(val, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colores.navy)),
            Text(nota, style: const TextStyle(color: Colores.tenue, fontSize: 12)),
            if (extra != null) extra,
          ]),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Encabezado('Tablero de la jefatura', 'Tiempos, ocupación e hipótesis del MVP',
            sub: 'Indicadores H1 a H4 (Tabla X). Solo atenciones reales, no sintéticas.',
            accion: Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton(onPressed: () => s.avanzarReloj(5), child: const Text('Avanzar reloj 5 min')),
              OutlinedButton(onPressed: () => s.avanzarReloj(10), child: const Text('Avanzar reloj 10 min')),
            ])),
        Wrap(spacing: 12, runSpacing: 12, children: [
          kpi('Pacientes en sala', '${sala.length}', '${sala.where((p) => p.estado == 'registrado').length} sin clasificar · ${s.topicos.where((t) => t != null).length}/${s.topicos.length} tópicos ocupados'),
          kpi('H1 · Llegada → prioridad', h1 == null ? '—' : '${h1.round()} min', s.lineaBase == null ? 'Línea base por levantar' : 'Línea base ${s.lineaBase} min · reducción ${red == null ? '—' : '${(red * 100).round()} %'}',
              extra: red == null ? null : cumple(red >= 0.30, si: '✓ meta ≥ 30 %', no: red < 0.10 ? '✗ umbral de pivote (< 10 %)' : 'entre umbrales: ajustar')),
          kpi('H2 · Concordancia', pct(conc), 'kappa ${k == null ? '— (n < 2)' : fmt(k)} · meta ≥ 0,70', extra: k == null ? null : cumple(k >= 0.70)),
          kpi('H3 · Atenciones con apoyo', pct(h3), 'Meta ≥ 60 % en el piloto', extra: h3 == null ? null : cumple(h3 >= 0.60, no: h3 < 0.30 ? '✗ < 30 %: pivotar canal' : '✗ por debajo de la meta')),
          kpi('H4 · Entiende su prioridad', pct(h4), '${comp.length} registro(s) · meta ≥ 50 % (hoy 17 %)', extra: h4 == null ? null : cumple(h4 >= 0.50)),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 14, runSpacing: 0, children: [
          SizedBox(
            width: 460,
            child: Tarjeta(
              titulo: 'Pacientes en sala por prioridad',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(
                  height: 150,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    for (var i = 0; i < 4; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                            Text('${dist[i]}', style: const TextStyle(fontWeight: FontWeight.w800)),
                            Container(height: 3 + 100.0 * dist[i] / mx, decoration: BoxDecoration(color: pr(i + 1).color, borderRadius: const BorderRadius.vertical(top: Radius.circular(8)))),
                            Text(pr(i + 1).romano),
                          ]),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 8),
                Text('Decisiones menos urgentes que la sugerencia (posible sub-triaje): $bajo', style: const TextStyle(color: Colores.tenue)),
              ]),
            ),
          ),
          SizedBox(
            width: 460,
            child: Tarjeta(
              titulo: 'Línea base para H1',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Campo(_lb, 'Tiempo promedio actual hasta la priorización (min)', error: _eLb, habilitado: s.rol == Rol.jefe, teclado: TextInputType.number, formatos: [Formatos.digitos, Formatos.largo(3)], pista: 'Por levantar en el diagnóstico de campo', ayuda: 'Entero de 1 a 600. Solo el médico jefe puede registrarla.'),
                if (s.rol == Rol.jefe)
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () {
                        final r = validarEnteroRango(_lb.text, 1, 600, 'la línea base');
                        setState(() => _eLb = r.ok ? null : r.mensaje);
                        if (r.ok) {
                          s.guardarLineaBase(r.valor!);
                          aviso(context, 'Línea base guardada.');
                        }
                      },
                      child: const Text('Guardar'),
                    ),
                  ),
              ]),
            ),
          ),
        ]),
        Tarjeta(
          titulo: 'Orden de atención sugerido · búsqueda A*',
          child: o.orden.isEmpty
              ? const Text('No hay pacientes clasificados en espera.', style: TextStyle(color: Colores.tenue))
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('f(n) = g(n) + h(n). g: espera ponderada por prioridad (pesos ${kPesoEspera.values.join('/')}) con penalidad por superar el tiempo de referencia; h: cota inferior del costo de los pendientes. Prioridad I siempre primero. Método: ${o.r.metodo} · nodos expandidos: ${o.r.expandidos}.', style: const TextStyle(color: Colores.tenue, fontSize: 12.5)),
                  const SizedBox(height: 6),
                  Text('Costo A*: ${o.r.costo.round()} · si se atiende por orden de llegada: ${o.costoLlegada.round()}${o.costoLlegada > 0 ? ' (${((1 - o.r.costo / o.costoLlegada) * 100).round()} % menos)' : ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Tabla(['#', 'Código', 'Prioridad', 'Espera', 'Inicio estimado', 'Estado'], [
                    for (var i = 0; i < o.orden.length; i++)
                      () {
                        final p = o.orden[i];
                        final esp = s.ahora.difference(p.prioridadTs!).inMinutes;
                        final lim = pr(p.decision!.prior).limiteMin;
                        final ini = o.r.inicios.length > i ? o.r.inicios[i] : 0.0;
                        return <Widget>[
                          Text('${i + 1}'),
                          Text(p.id),
                          InsigniaPrioridad(p.decision!.prior),
                          Text('$esp min'),
                          Text(ini <= 0 ? 'ahora' : 'en ~${ini.round()} min'),
                          (esp > lim && p.decision!.prior > 1) ? const Text('Revaluar ahora', style: TextStyle(color: Colores.rojo, fontWeight: FontWeight.w800)) : const Text('En espera'),
                        ];
                      }(),
                  ]),
                  if (s.rol != Rol.comite && s.topicoLibre() != null)
                    Align(alignment: Alignment.centerLeft, child: FilledButton.icon(onPressed: () => enviarATopico(context, s, o.orden.first), icon: const Icon(Icons.meeting_room_outlined), label: Text('Enviar ${o.orden.first.id} al tópico libre'))),
                  const SizedBox(height: 6),
                  Text('Tiempos de referencia: I inmediato, II ≤ 10 min, III ≤ 20 min (norma técnica); IV 60 min (parámetro de demostración). Duraciones de atención (demo): ${kDuracionAtencion.entries.map((e) => '${pr(e.key).romano} ${e.value} min').join(', ')}. El orden es una sugerencia: decide el personal.', style: const TextStyle(color: Colores.tenue, fontSize: 12)),
                ]),
        ),
        Tarjeta(
          titulo: 'Tópicos',
          child: Wrap(spacing: 10, runSpacing: 10, children: [
            for (var i = 0; i < s.topicos.length; i++)
              () {
                final q = s.porId(s.topicos[i]);
                return Container(
                  width: 220,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(border: Border.all(color: Colores.linea), borderRadius: BorderRadius.circular(12), color: q == null ? Colores.menta : Colors.white),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('T${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800, color: Colores.teal)),
                    if (q == null) const Text('Libre') else Row(children: [Text('${q.id} '), InsigniaPrioridad(q.decision!.prior)]),
                    if (q != null) Text('desde ${hhmm(q.inicioTs!)} (${s.ahora.difference(q.inicioTs!).inMinutes} min)', style: const TextStyle(color: Colores.tenue, fontSize: 12)),
                  ]),
                );
              }(),
          ]),
        ),
      ]),
    );
  }
}
