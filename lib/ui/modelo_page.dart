// Capturas «DevOps – ciclo de entrega» y «Seguridad clínica – modo sombra»:
// versiones del modelo, aprobación del comité, métricas (Tabla XX), deriva y K-Means.

import 'package:flutter/material.dart';
import '../core/algoritmos.dart';
import '../core/datos.dart';
import '../core/modelo.dart';
import '../core/validadores.dart';
import '../estado/app_state.dart';
import '../estado/entidades.dart';
import '../estado/proveedor.dart';
import 'comunes.dart';

class _Paso {
  final String titulo;
  final String detalle;
  final IconData icono;
  final Color color;
  const _Paso(this.titulo, this.detalle, this.icono, this.color);
}

const _pasos = [
  _Paso('Código', 'Aplicación y modelo ML · Git', Icons.code, Color(0xFF2F6FBF)),
  _Paso('Pruebas', 'Funcionales, del modelo, seguridad y rendimiento', Icons.fact_check_outlined, Color(0xFF2E7D32)),
  _Paso('Contenedor', 'Docker: aplicación + modelo', Icons.inventory_2_outlined, Color(0xFF6A4FB3)),
  _Paso('Despliegue controlado', 'Entorno de pruebas/QA con datos autorizados', Icons.dns_outlined, Color(0xFFB8860B)),
  _Paso('Modo sombra', 'Predice en paralelo sin influir en la decisión', Icons.visibility_off_outlined, Color(0xFFC62828)),
  _Paso('Aprobación clínica y técnica', 'Comité revisa resultados y autoriza', Icons.groups_outlined, Color(0xFF6A4FB3)),
  _Paso('Producción', 'Uso asistido por el personal', Icons.cloud_done_outlined, Color(0xFF2E7D32)),
  _Paso('Monitoreo', 'Desempeño, errores, métricas y auditoría', Icons.monitor_heart_outlined, Color(0xFF2F6FBF)),
];

Set<int> _pasosDe(String estado) => switch (estado) {
      EstadoVersion.desarrollo => {0},
      EstadoVersion.qa => {1, 2, 3},
      EstadoVersion.sombra => {4},
      EstadoVersion.aprobada => {5},
      EstadoVersion.produccion => {6, 7},
      _ => <int>{},
    };

const Map<String, (double, double)> _ref = {'temp': (36.9, 0.7), 'fc': (88.0, 16.0), 'spo2': (96.0, 3.0), 'pas': (125.0, 20.0), 'fr': (18.0, 4.0)};

class PaginaModelo extends StatefulWidget {
  const PaginaModelo({super.key});
  @override
  State<PaginaModelo> createState() => _PaginaModeloState();
}

class _PaginaModeloState extends State<PaginaModelo> {
  String? _ver;
  int _k = 3;

  @override
  Widget build(BuildContext context) {
    final s = Estado.de(context);
    final comite = s.rol == Rol.comite;
    final evaluables = s.versiones.where((v) => s.decididosCon(v.version).isNotEmpty || v.estado == EstadoVersion.sombra).toList();
    if (_ver == null || !s.versiones.any((v) => v.version == _ver)) {
      final sombra = s.versiones.where((v) => v.estado == EstadoVersion.sombra);
      _ver = sombra.isNotEmpty ? sombra.first.version : s.versiones.first.version;
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Encabezado('DevOps – ciclo de entrega', 'Del código al monitoreo continuo', sub: 'Ninguna versión llega directamente a producción.'),
        _pipeline(s),
        const FranjaClave('Código → pruebas → contenedor → despliegue controlado → modo sombra → aprobación → producción → monitoreo'),
        Tarjeta(
          titulo: 'Versiones del modelo',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (!comite) Aviso.texto(TipoAviso.info, 'Solo el comité de modelo puede cambiar el estado de una versión. Usted ve esta sección en modo lectura.'),
            for (final v in s.versiones) _tarjetaVersion(context, s, v, comite),
          ]),
        ),
        const Encabezado('Seguridad clínica – modo sombra', 'Ninguna versión llega directamente a producción'),
        _etapas(context, s),
        const FranjaClave('Regla del proyecto: no desplegar sin superar modo sombra y aprobación clínica-técnica.'),
        _metricas(s, evaluables),
        Wrap(spacing: 14, children: [
          SizedBox(width: 520, child: _deriva(s)),
          SizedBox(width: 520, child: _kmeans(s)),
        ]),
      ]),
    );
  }

  Widget _pipeline(AppState s) {
    final activos = <int, List<String>>{};
    for (final v in s.versiones) {
      for (final i in _pasosDe(v.estado)) {
        activos.putIfAbsent(i, () => []).add('v${v.version}');
      }
    }
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (var i = 0; i < _pasos.length; i++)
        Container(
          width: 150,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: activos.containsKey(i) ? _pasos[i].color.withAlpha(30) : Colors.white,
            border: Border.all(color: activos.containsKey(i) ? _pasos[i].color : Colores.linea, width: activos.containsKey(i) ? 2 : 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(radius: 12, backgroundColor: _pasos[i].color, child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
              const SizedBox(width: 6),
              Icon(_pasos[i].icono, size: 20, color: _pasos[i].color),
            ]),
            const SizedBox(height: 6),
            Text(_pasos[i].titulo, style: const TextStyle(fontWeight: FontWeight.w800, color: Colores.navy)),
            Text(_pasos[i].detalle, style: const TextStyle(fontSize: 11.5, color: Colores.tenue)),
            if (activos.containsKey(i)) Padding(padding: const EdgeInsets.only(top: 4), child: Text(activos[i]!.join(', '), style: TextStyle(fontWeight: FontWeight.w800, color: _pasos[i].color))),
          ]),
        ),
    ]);
  }

  Widget _tarjetaVersion(BuildContext context, AppState s, VersionModelo v, bool comite) {
    final spec = especDe(v.version);
    Color c;
    switch (v.estado) {
      case EstadoVersion.produccion:
        c = Colores.verde;
        break;
      case EstadoVersion.sombra:
        c = Colores.rojo;
        break;
      case EstadoVersion.aprobada:
        c = const Color(0xFF6A4FB3);
        break;
      case EstadoVersion.retirada:
      case EstadoVersion.rechazada:
        c = Colores.tenue;
        break;
      default:
        c = const Color(0xFF2F6FBF);
    }
    Future<void> ir(String nuevo, {String nota = ''}) async {
      final err = s.transicion(v, nuevo, nota: nota);
      if (err != null) {
        aviso(context, err, error: true);
      } else {
        aviso(context, 'v${v.version} → $nuevo');
      }
    }

    final acciones = <Widget>[];
    if (comite) {
      switch (v.estado) {
        case EstadoVersion.desarrollo:
          acciones.add(OutlinedButton(onPressed: () => ir(EstadoVersion.qa, nota: 'Autopruebas superadas; contenedor generado.'), child: const Text('Enviar a pruebas (QA)')));
          break;
        case EstadoVersion.qa:
          acciones.add(OutlinedButton(onPressed: () => ir(EstadoVersion.sombra, nota: 'Despliegue controlado en modo sombra.'), child: const Text('Desplegar en modo sombra')));
          break;
        case EstadoVersion.sombra:
          acciones.add(FilledButton(onPressed: () => _aprobar(context, s, v), child: const Text('Revisar y aprobar')));
          acciones.add(OutlinedButton(
              onPressed: () async {
                final m = await pedirTexto(context, 'Rechazar v${v.version}', 'Motivo del rechazo', (t) {
                  final r = validarTexto(t, 15, 300, 'el motivo');
                  return r.ok ? null : r.mensaje;
                });
                if (m != null) await ir(EstadoVersion.rechazada, nota: m);
              },
              child: const Text('Rechazar')));
          break;
        case EstadoVersion.aprobada:
          acciones.add(FilledButton(
              onPressed: () async {
                if (await confirmar(context, 'Pasar v${v.version} a producción', 'La versión pasará a piloto asistido y el personal verá sus sugerencias. ${s.versionProduccion == null ? '' : 'La versión v${s.versionProduccion!.version} se retirará.'}')) {
                  await ir(EstadoVersion.produccion, nota: 'Despliegue en producción.');
                }
              },
              child: const Text('Pasar a producción')));
          break;
        case EstadoVersion.produccion:
          acciones.add(OutlinedButton(
              onPressed: () async {
                final m = await pedirTexto(context, 'Devolver v${v.version} a modo sombra', 'Motivo (p. ej., deriva de datos)', (t) {
                  final r = validarTexto(t, 15, 300, 'el motivo');
                  return r.ok ? null : r.mensaje;
                }, descripcion: 'El personal dejará de ver sugerencias hasta que se apruebe una versión.');
                if (m != null) await ir(EstadoVersion.sombra, nota: m);
              },
              child: const Text('Devolver a modo sombra')));
          break;
      }
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: Colores.linea), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('v${v.version}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colores.navy)),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(99)), child: Text(v.estado, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))),
          ...acciones,
        ]),
        const SizedBox(height: 4),
        Text(spec.descripcion, style: const TextStyle(color: Colores.tenue)),
        Text('Umbrales: I ≥ ${fmt(spec.umbralI)} · II ≥ ${fmt(spec.umbralII)} · III ≥ ${fmt(spec.umbralIII)} · decisiones evaluadas: ${s.decididosCon(v.version).length}', style: const TextStyle(fontSize: 12.5)),
        const SizedBox(height: 4),
        for (final h in v.historial.reversed.take(4)) Text('• ${h.ts.day.toString().padLeft(2, '0')}/${h.ts.month.toString().padLeft(2, '0')} ${hhmm(h.ts)} · ${h.estado} · ${h.usuario}${h.nota.isEmpty ? '' : ': ${h.nota}'}', style: const TextStyle(fontSize: 12, color: Colores.tenue)),
      ]),
    );
  }

  Future<void> _aprobar(BuildContext context, AppState s, VersionModelo v) async {
    final m = s.metricas(v.version);
    final checks = <(String, double?, String, bool Function(double))>[
      ('Recall prioridad I–II', m.recall, '≥ 0,90', (x) => x >= 0.90),
      ('Precision prioridad I–II', m.precision, '≥ 0,75', (x) => x >= 0.75),
      ('F1-score macro', m.f1, '≥ 0,80', (x) => x >= 0.80),
      ('AUROC desenlace crítico', m.auroc, '≥ 0,85', (x) => x >= 0.85),
      ('Kappa de Cohen', m.kappa, '≥ 0,70', (x) => x >= 0.70),
    ];
    final fallan = checks.where((c) => c.$2 == null || !c.$4(c.$2!)).toList();
    if (m.n < 20) {
      aviso(context, 'No se puede aprobar: v${v.version} tiene ${m.n} decisiones evaluadas y se requieren al menos 20 (use «Datos históricos» o clasifique más pacientes).', error: true);
      return;
    }
    final just = TextEditingController();
    String? eJust;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text('Aprobación clínica y técnica · v${v.version}'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Lista de verificación (Tabla XX) · n = ${m.n} decisiones, ${m.nDes} con desenlace.'),
                const SizedBox(height: 8),
                for (final c in checks)
                  Row(children: [
                    Expanded(child: Text(c.$1)),
                    SizedBox(width: 60, child: Text(fmt(c.$2), textAlign: TextAlign.right)),
                    SizedBox(width: 70, child: Text(c.$3, textAlign: TextAlign.right, style: const TextStyle(color: Colores.tenue))),
                    SizedBox(width: 90, child: Align(alignment: Alignment.centerRight, child: cumple(c.$2 == null ? null : c.$4(c.$2!)))),
                  ]),
                const SizedBox(height: 10),
                if (fallan.isNotEmpty) ...[
                  Aviso.texto(TipoAviso.alerta, '${fallan.length} criterio(s) no se cumplen. Para aprobar igualmente, el comité debe dejar una justificación escrita (queda en la auditoría).'),
                  TextField(controller: just, minLines: 3, maxLines: 5, maxLength: 300, decoration: InputDecoration(labelText: 'Justificación del comité *', helperText: 'Entre 30 y 300 caracteres.', errorText: eJust)),
                ] else
                  Aviso.texto(TipoAviso.ok, 'Todos los criterios de aceptación se cumplen.'),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (fallan.isNotEmpty) {
                  final r = validarTexto(just.text, 30, 300, 'la justificación');
                  if (!r.ok) {
                    set(() => eJust = r.mensaje);
                    return;
                  }
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Aprobar versión'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      final nota = fallan.isEmpty ? 'Cumple todos los criterios (n = ${m.n}).' : 'Aprobada con ${fallan.length} criterio(s) sin cumplir. Justificación: ${just.text.trim()}';
      final err = s.transicion(v, EstadoVersion.aprobada, nota: nota);
      if (context.mounted) aviso(context, err ?? 'v${v.version} aprobada.', error: err != null);
    }
  }

  Widget _etapas(BuildContext context, AppState s) {
    final puedeCargar = s.rol == Rol.comite || s.rol == Rol.jefe;
    final sint = s.pacientes.where((p) => p.sintetico).length;
    Widget caja(String t, String d, {Widget? extra}) => Container(
          width: 250,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colores.navy, borderRadius: BorderRadius.circular(22)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 10),
            Text(d, style: const TextStyle(color: Color(0xFFD6E0F0))),
            if (extra != null) ...[const SizedBox(height: 10), extra],
          ]),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Wrap(spacing: 12, runSpacing: 12, children: [
        caja('DATOS HISTÓRICOS', 'Evaluación retrospectiva con datos autorizados. Aquí: 24 atenciones sintéticas ($sint cargadas).',
            extra: puedeCargar
                ? FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colores.teal),
                    onPressed: () async {
                      if (await confirmar(context, 'Cargar datos históricos sintéticos', 'Se agregarán 24 atenciones sintéticas ya finalizadas (con decisión y desenlace simulados) para evaluar las versiones. No afectan a la sala ni a los indicadores H1–H4.')) {
                        s.cargarEscenario();
                        if (context.mounted) aviso(context, 'Datos históricos sintéticos cargados.');
                      }
                    },
                    child: const Text('Cargar datos históricos'))
                : null),
        caja('MODO SOMBRA', 'Predice en paralelo, sin influir en la atención. Versión(es): ${s.versiones.where((v) => v.estado == EstadoVersion.sombra).map((v) => 'v${v.version}').join(', ').ifEmpty('ninguna')}.'),
        caja('REVISIÓN', 'El comité contrasta métricas y discrepancias (abajo) antes de aprobar.'),
        caja('PILOTO CONTROLADO', 'Uso asistido con validación humana y monitoreo. ${s.versionProduccion == null ? 'Sin versión en producción.' : 'Activo con v${s.versionProduccion!.version}.'}'),
      ]),
    );
  }

  Widget _metricas(AppState s, List<VersionModelo> evaluables) {
    final m = s.metricas(_ver!);
    final cm = matrizConfusion(m.pares);
    Widget fila(String n, double? v, String meta, bool Function(double) ok, String prop) => Row(children: [
          Expanded(flex: 3, child: Text(n)),
          Expanded(child: Text(fmt(v), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
          Expanded(child: Text(meta, textAlign: TextAlign.center, style: const TextStyle(color: Colores.tenue))),
          Expanded(flex: 2, child: cumple(v == null ? null : ok(v))),
          Expanded(flex: 4, child: Text(prop, style: const TextStyle(color: Colores.tenue, fontSize: 12))),
        ]);
    return Tarjeta(
      titulo: 'Revisión: métricas frente a los criterios de aceptación (Tabla XX)',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 320,
          child: Lista<String>('Versión evaluada', valor: _ver, opciones: s.versiones.map((v) => v.version).toList(), texto: (x) => 'v$x · ${s.versiones.firstWhere((v) => v.version == x).estado}', alCambiar: (v) => setState(() => _ver = v)),
        ),
        if (m.n == 0)
          Aviso.texto(TipoAviso.info, 'v$_ver aún no tiene decisiones evaluadas. Cargue los datos históricos o clasifique pacientes mientras la versión está en modo sombra o producción.')
        else ...[
          if (m.n < 20) Aviso.texto(TipoAviso.alerta, 'Solo hay ${m.n} decisiones: las métricas son ilustrativas y no alcanzan el mínimo de 20 para aprobar.'),
          fila('Recall prioridad I–II', m.recall, '≥ 0,90', (x) => x >= 0.90, 'Minimizar el sub-triaje en pacientes con riesgo vital'),
          fila('Precision prioridad I–II', m.precision, '≥ 0,75', (x) => x >= 0.75, 'Evitar saturación de tópicos y fatiga de alertas'),
          fila('F1-score macro', m.f1, '≥ 0,80', (x) => x >= 0.80, 'Equilibrio en las 4 categorías'),
          fila('AUROC (desenlace crítico 24 h)', m.auroc, '≥ 0,85', (x) => x >= 0.85, '${m.nDes} atenciones con desenlace registrado'),
          fila('Kappa de Cohen', m.kappa, '≥ 0,70', (x) => x >= 0.70, 'Concordancia con la valoración profesional'),
          const SizedBox(height: 12),
          const Text('MATRIZ DE CONFUSIÓN (filas: profesional · columnas: modelo)', style: TextStyle(fontWeight: FontWeight.w800, color: Colores.teal, fontSize: 12.5)),
          const SizedBox(height: 6),
          Table(
            defaultColumnWidth: const FixedColumnWidth(64),
            border: TableBorder.all(color: Colores.linea),
            children: [
              TableRow(children: [const SizedBox(), for (var j = 1; j <= 4; j++) Padding(padding: const EdgeInsets.all(6), child: Text(pr(j).romano, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)))]),
              for (var i = 0; i < 4; i++)
                TableRow(children: [
                  Padding(padding: const EdgeInsets.all(6), child: Text(pr(i + 1).romano, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800))),
                  for (var j = 0; j < 4; j++)
                    Container(
                      color: i == j ? Colores.verdeS : (j > i ? Colores.rojoS : null),
                      padding: const EdgeInsets.all(6),
                      child: Text('${cm[i][j]}', textAlign: TextAlign.center, style: TextStyle(fontWeight: i == j ? FontWeight.w800 : FontWeight.w400)),
                    ),
                ]),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Celdas rojas: el modelo sugirió una prioridad menos urgente que el profesional (sub-triaje del modelo).', style: TextStyle(color: Colores.tenue, fontSize: 12)),
        ],
      ]),
    );
  }

  List<Paciente> _conSignos(AppState s) => s.pacientes.where((p) => p.decision != null && p.vit.isNotEmpty).toList();

  Widget _deriva(AppState s) {
    final ps = _conSignos(s);
    final filas = <List<Widget>>[];
    var hay = false;
    _ref.forEach((v, r) {
      final xs = ps.map((p) => p.vit[v]).whereType<double>().toList();
      if (xs.length < 5) {
        filas.add([Text(vitalPorId(v).corto), Text('${xs.length}'), const Text('—'), Text(fmtNum(r.$1)), const Text('—'), const Text('n insuficiente', style: TextStyle(color: Colores.tenue))]);
        return;
      }
      final media = xs.reduce((a, b) => a + b) / xs.length;
      final d = (media - r.$1).abs() / r.$2;
      if (d > 0.5) hay = true;
      filas.add([Text(vitalPorId(v).corto), Text('${xs.length}'), Text(fmt(media, 1)), Text(fmtNum(r.$1)), Text(fmt(d)), d > 0.5 ? const Text('Deriva', style: TextStyle(color: Colores.rojo, fontWeight: FontWeight.w800)) : const Text('Estable', style: TextStyle(color: Colores.verde))]);
    });
    final fiebre = ps.isEmpty ? null : ps.where((p) => RegExp(r'fiebre|dengue').hasMatch(normalizar(p.motivo ?? ''))).length / ps.length;
    final brote = fiebre != null && ps.length >= 5 && fiebre > 0.30;
    if (brote) hay = true;
    filas.add([const Text('% fiebre/dengue'), Text('${ps.length}'), Text(pct(fiebre)), const Text('15 %'), const Text(''), brote ? const Text('Posible brote', style: TextStyle(color: Colores.rojo, fontWeight: FontWeight.w800)) : const Text('')]);
    return Tarjeta(
      titulo: 'Monitoreo: deriva de datos',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Diferencia estandarizada de medias frente a la referencia de entrenamiento (ficticia). Alerta si > 0,5 con n ≥ 5.', style: TextStyle(color: Colores.tenue, fontSize: 12.5)),
        Tabla(['Variable', 'n', 'Media', 'Ref.', 'Dif.', ''], filas),
        if (hay) Aviso.texto(TipoAviso.alerta, 'Cambio en la población atendida: notificar al comité para evaluar el desempeño antes de mantener el modelo en operación.'),
      ]),
    );
  }

  Widget _kmeans(AppState s) {
    final vars = _ref.keys.toList();
    final ps = _conSignos(s).where((p) => vars.every((v) => p.vit[v] != null)).toList();
    final minimo = _k + 3 > 6 ? _k + 3 : 6;
    Widget cuerpo;
    if (ps.length < minimo) {
      cuerpo = Text('Se necesitan al menos $minimo atenciones con todos los signos (hay ${ps.length}). Cargue los datos históricos.', style: const TextStyle(color: Colores.tenue));
    } else {
      final x = ps.map((p) => vars.map((v) => (p.vit[v]! - _ref[v]!.$1) / _ref[v]!.$2).toList()).toList();
      final lab = kmeans(x, _k)!;
      final sil = silueta(x, lab);
      final filas = <List<Widget>>[];
      for (var g = 0; g < _k; g++) {
        final m = <Paciente>[];
        for (var i = 0; i < ps.length; i++) {
          if (lab[i] == g) m.add(ps[i]);
        }
        if (m.isEmpty) continue;
        double media(String v) => m.fold<double>(0, (a, p) => a + p.vit[v]!) / m.length;
        final t = media('temp'), sp = media('spo2'), fc = media('fc');
        final lectura = t >= 38 ? 'Cuadro febril' : (sp < 93 ? 'Respiratorio / hipoxemia' : (fc > 105 ? 'Taquicardia / descompensación' : 'Estable'));
        filas.add([Text('${g + 1}'), Text('${m.length}'), Text(fmt(t, 1)), Text(fmt(sp, 0)), Text(fmt(fc, 0)), Text(lectura)]);
      }
      cuerpo = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [Text('Coeficiente de silueta: ${fmt(sil)} · meta ≥ 0,45  ', style: const TextStyle(fontWeight: FontWeight.w700)), cumple(sil == null ? null : sil >= 0.45)]),
        Tabla(['Grupo', 'n', 'T°', 'SpO₂', 'FC', 'Lectura sugerida'], filas),
        const Text('Un grupo estadístico no es un perfil clínico hasta que lo valide el personal.', style: TextStyle(color: Colores.tenue, fontSize: 12)),
      ]);
    }
    return Tarjeta(
      titulo: 'Perfiles de demanda · K-Means',
      accion: DropdownButton<int>(value: _k, items: const [DropdownMenuItem(value: 2, child: Text('k = 2')), DropdownMenuItem(value: 3, child: Text('k = 3')), DropdownMenuItem(value: 4, child: Text('k = 4'))], onChanged: (v) => setState(() => _k = v ?? 3)),
      child: cuerpo,
    );
  }
}

extension on String {
  String ifEmpty(String alt) => isEmpty ? alt : this;
}
