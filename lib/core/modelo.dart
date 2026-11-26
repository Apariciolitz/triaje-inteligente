// Modelo de DEMOSTRACIÓN: logit con pesos ilustrativos (no entrenados) +
// reglas de seguridad clínica. Dos versiones, como en el ciclo DevOps:
//  - v0.2.0: solo variables estructuradas (signos, edad, llegada).
//  - v0.3.0: añade historia clínica, PLN del motivo de consulta y faltantes informativos.
// El modelo real (XGBoost + TF-IDF) se entrenará con datos autorizados (APF3, 3.4).

import 'dart:math' as math;
import 'datos.dart';
import 'validadores.dart';

class Contribucion {
  final String texto;
  final double peso;
  final String fuente;
  const Contribucion(this.texto, this.peso, this.fuente);
  Map<String, dynamic> toJson() => {'t': texto, 'w': peso, 'f': fuente};
  factory Contribucion.fromJson(Map<String, dynamic> j) => Contribucion(j['t'] as String, (j['w'] as num).toDouble(), j['f'] as String);
}

class ReglaSeguridad {
  final int minimo;
  final String motivo;
  const ReglaSeguridad(this.minimo, this.motivo);
  Map<String, dynamic> toJson() => {'min': minimo, 'm': motivo};
  factory ReglaSeguridad.fromJson(Map<String, dynamic> j) => ReglaSeguridad((j['min'] as num).toInt(), j['m'] as String);
}

class Prediccion {
  final String version;
  final double prob;
  final int prioridadModelo;
  final int prioridad;
  final List<ReglaSeguridad> reglas;
  final List<Contribucion> contribuciones;
  const Prediccion(this.version, this.prob, this.prioridadModelo, this.prioridad, this.reglas, this.contribuciones);
  Map<String, dynamic> toJson() => {
        'v': version,
        'p': prob,
        'pm': prioridadModelo,
        'pr': prioridad,
        'r': reglas.map((e) => e.toJson()).toList(),
        'c': contribuciones.map((e) => e.toJson()).toList(),
      };
  factory Prediccion.fromJson(Map<String, dynamic> j) => Prediccion(
        j['v'] as String,
        (j['p'] as num).toDouble(),
        (j['pm'] as num).toInt(),
        (j['pr'] as num).toInt(),
        (j['r'] as List).map((e) => ReglaSeguridad.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        (j['c'] as List).map((e) => Contribucion.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      );
}

class EspecModelo {
  final String version;
  final String descripcion;
  final bool usaTexto;
  final bool usaHistoria;
  final bool usaFaltantes;
  final double intercepto;
  final double umbralI, umbralII, umbralIII;
  const EspecModelo(this.version, this.descripcion, {required this.usaTexto, required this.usaHistoria, required this.usaFaltantes, required this.intercepto, this.umbralI = 0.80, this.umbralII = 0.35, this.umbralIII = 0.12});
}

const List<EspecModelo> kModelos = [
  EspecModelo('0.2.0', 'Variables estructuradas: signos vitales, edad y forma de llegada (versión del APF2).', usaTexto: false, usaHistoria: false, usaFaltantes: false, intercepto: -4.2),
  EspecModelo('0.3.0', 'Añade historia clínica, PLN del motivo de consulta y faltantes informativos (APF3).', usaTexto: true, usaHistoria: true, usaFaltantes: true, intercepto: -4.6),
  EspecModelo('0.4.0', 'Candidata: mismas variables que 0.3.0 con umbral de Prioridad II más sensible (0,30) para reducir sub-triaje.', usaTexto: true, usaHistoria: true, usaFaltantes: true, intercepto: -4.6, umbralII: 0.30),
];

EspecModelo especDe(String version) => kModelos.firstWhere((m) => m.version == version);

/* ---------------- PLN del motivo de consulta ---------------- */
const Map<String, String> kAbreviaturas = {
  'dif resp': 'dificultad respiratoria',
  'dolor tx': 'dolor toracico',
  'dpt': 'dolor toracico',
  'perd conc': 'perdida de conciencia',
  'pdc': 'perdida de conciencia',
  'tec': 'traumatismo encefalocraneano',
  'acv': 'accidente cerebrovascular',
  'sat baja': 'saturacion baja',
  'dabd': 'dolor abdominal',
  'cv': 'convulsion',
  'fx': 'fractura',
};

class GrupoTermino {
  final List<String> terminos;
  final double peso;
  final String categoria;
  final int? minimo; // prioridad mínima por regla de seguridad
  const GrupoTermino(this.terminos, this.peso, this.categoria, [this.minimo]);
}

const List<GrupoTermino> kTerminos = [
  GrupoTermino(['dolor toracico', 'dolor en el pecho', 'dolor de pecho', 'opresion en el pecho'], 1.2, 'Dolor torácico', 2),
  GrupoTermino(['dificultad respiratoria', 'falta de aire', 'disnea', 'no puede respirar', 'ahogo', 'saturacion baja'], 1.0, 'Dificultad respiratoria'),
  GrupoTermino(['silbido', 'silbidos', 'sibilancias'], 0.5, 'Sibilancias'),
  GrupoTermino(['perdida de conciencia', 'desmayo', 'sincope', 'inconsciente', 'no responde'], 1.2, 'Alteración de conciencia', 2),
  GrupoTermino(['convulsion', 'convulsiones', 'convulsiona', 'convulsionando'], 1.4, 'Convulsión', 2),
  GrupoTermino(['hemiparesia', 'debilidad en un lado', 'desviacion de boca', 'boca desviada', 'no puede hablar', 'accidente cerebrovascular', 'derrame cerebral'], 1.6, 'Signos de ACV', 2),
  GrupoTermino(['vomito con sangre', 'vomita sangre', 'hematemesis', 'heces negras', 'melena'], 1.3, 'Sangrado digestivo', 2),
  GrupoTermino(['sangrado', 'hemorragia', 'sangra'], 1.0, 'Sangrado'),
  GrupoTermino(['petequias', 'sangrado de encias', 'dolor abdominal intenso', 'vomitos persistentes', 'manchas rojas'], 1.8, 'Signos de alarma de dengue', 2),
  GrupoTermino(['dengue', 'fiebre'], 0.3, 'Fiebre / sospecha de dengue'),
  GrupoTermino(['traumatismo encefalocraneano'], 0.9, 'Trauma de cráneo'),
  GrupoTermino(['traumatismo', 'accidente', 'caida', 'golpe', 'choque', 'fractura'], 0.5, 'Trauma'),
  GrupoTermino(['quemadura', 'quemado'], 0.6, 'Quemadura'),
  GrupoTermino(['intoxicacion', 'veneno', 'ingirio', 'sobredosis', 'organofosforado'], 1.0, 'Intoxicación', 2),
  GrupoTermino(['intento suicida', 'intento de suicidio', 'autolesion', 'quiere matarse'], 1.5, 'Riesgo autolesivo', 2),
  GrupoTermino(['cefalea subita', 'peor dolor de cabeza', 'dolor de cabeza subito'], 0.9, 'Cefalea súbita', 2),
  GrupoTermino(['dolor abdominal', 'dolor de barriga', 'dolor de estomago'], 0.3, 'Dolor abdominal'),
  GrupoTermino(['diarrea', 'vomitos', 'vomito'], 0.2, 'Síntomas digestivos'),
  GrupoTermino(['dolor de garganta', 'resfrio', 'resfriado', 'tos leve', 'receta', 'control', 'certificado', 'chequeo'], -0.6, 'Consulta de baja complejidad'),
];

class TerminoDetectado {
  final String termino;
  final GrupoTermino grupo;
  const TerminoDetectado(this.termino, this.grupo);
}

String expandirAbreviaturas(String txt) {
  var n = ' ${normalizar(txt)} ';
  kAbreviaturas.forEach((a, b) {
    n = n.replaceAll(' ${normalizar(a)} ', ' $b ');
  });
  return n.trim();
}

List<TerminoDetectado> analizarTexto(String txt) {
  final n = ' ${expandirAbreviaturas(txt)} ';
  final out = <TerminoDetectado>[];
  for (final g in kTerminos) {
    for (final t in g.terminos) {
      if (n.contains(' $t')) {
        out.add(TerminoDetectado(t, g));
        break;
      }
    }
  }
  return out;
}

/* ---------------- Entrada del modelo ---------------- */
class EntradaModelo {
  final int? edad;
  final String sexo;
  final String llegada;
  final String? gestante;
  final Map<String, double?> vit;
  final Map<String, String> noMedido;
  final HistoriaClinica? hc;
  final String motivo;
  const EntradaModelo({this.edad, this.sexo = '', this.llegada = '', this.gestante, required this.vit, this.noMedido = const {}, this.hc, this.motivo = ''});
}

double _sig(double x) => 1 / (1 + math.exp(-x));

Prediccion predecir(EntradaModelo e, {String version = '0.3.0'}) {
  final spec = especDe(version);
  final c = <Contribucion>[];
  void add(String t, double w, String f) {
    if (w != 0) c.add(Contribucion(t, (w * 100).round() / 100, f));
  }

  final v = e.vit;
  final spo2 = v['spo2'], pas = v['pas'], fc = v['fc'], fr = v['fr'], temp = v['temp'], gl = v['glasgow'], eva = v['eva'];
  String n(double x) => fmtNum(x);
  if (spo2 != null) {
    if (spo2 < 85) {
      add('Saturación de O₂ muy baja (${n(spo2)} %)', 3.0, 'vital');
    } else if (spo2 <= 91) {
      add('Saturación de O₂ baja (${n(spo2)} %)', 1.6, 'vital');
    } else if (spo2 <= 94) {
      add('Saturación de O₂ limítrofe (${n(spo2)} %)', 0.6, 'vital');
    }
  }
  if (pas != null) {
    if (pas < 80) {
      add('Presión sistólica muy baja (${n(pas)} mmHg)', 2.5, 'vital');
    } else if (pas < 90) {
      add('Presión sistólica baja (${n(pas)} mmHg)', 1.4, 'vital');
    } else if (pas >= 220) {
      add('Presión sistólica muy alta (${n(pas)} mmHg)', 1.5, 'vital');
    } else if (pas >= 180) {
      add('Presión sistólica alta (${n(pas)} mmHg)', 0.8, 'vital');
    }
  }
  if (fc != null) {
    if (fc > 150 || fc < 40) {
      add('Frecuencia cardiaca crítica (${n(fc)} lpm)', 2.0, 'vital');
    } else if (fc > 120 || fc < 50) {
      add('Frecuencia cardiaca alterada (${n(fc)} lpm)', 1.0, 'vital');
    } else if (fc > 100) {
      add('Frecuencia cardiaca elevada (${n(fc)} lpm)', 0.4, 'vital');
    }
  }
  if (fr != null) {
    if (fr > 35 || fr < 8) {
      add('Frecuencia respiratoria crítica (${n(fr)} rpm)', 2.2, 'vital');
    } else if (fr >= 25) {
      add('Frecuencia respiratoria alta (${n(fr)} rpm)', 1.1, 'vital');
    } else if (fr >= 21) {
      add('Frecuencia respiratoria algo elevada (${n(fr)} rpm)', 0.4, 'vital');
    }
  }
  if (temp != null) {
    if (temp >= 41 || temp < 34) {
      add('Temperatura crítica (${n(temp)} °C)', 1.8, 'vital');
    } else if (temp >= 39.5) {
      add('Fiebre alta (${n(temp)} °C)', 0.7, 'vital');
    } else if (temp >= 38) {
      add('Fiebre (${n(temp)} °C)', 0.3, 'vital');
    }
  }
  if (gl != null) {
    if (gl <= 8) {
      add('Glasgow ${n(gl)}: compromiso grave de conciencia', 3.0, 'vital');
    } else if (gl <= 13) {
      add('Glasgow ${n(gl)}: conciencia alterada', 1.6, 'vital');
    } else if (gl == 14) {
      add('Glasgow 14', 0.6, 'vital');
    }
  }
  if (eva != null) {
    if (eva >= 8) {
      add('Dolor intenso (EVA ${n(eva)}/10)', 0.6, 'vital');
    } else if (eva >= 5) {
      add('Dolor moderado (EVA ${n(eva)}/10)', 0.3, 'vital');
    }
  }
  if (spec.usaFaltantes) {
    final inest = e.noMedido.values.where((m) => m == kMotivosNoMedido[0]).length;
    if (inest > 0) add('Signos no medidos por inestabilidad ($inest)', 0.8, 'faltante');
  }
  final edad = e.edad;
  if (edad != null) {
    if (edad >= 80) {
      add('Edad $edad años', 0.9, 'demografía');
    } else if (edad >= 65) {
      add('Edad $edad años (65 o más)', 0.6, 'demografía');
    } else if (edad < 1) {
      add('Lactante menor de 1 año', 0.8, 'demografía');
    }
  }
  if (e.llegada == 'Ambulancia') add('Llegó en ambulancia', 0.6, 'llegada');
  if (e.gestante == 'Sí') add('Gestante', 0.5, 'demografía');
  if (spec.usaHistoria && e.hc != null) {
    final rel = e.hc!.diagnosticos.where((d) => d.relevante).toList();
    if (rel.isNotEmpty) add('Historia clínica: ${rel.map((d) => d.nombre).join(', ')}', math.min(0.75, 0.25 * rel.length), 'historia');
    if (e.hc!.hospAnio > 0) add('${e.hc!.hospAnio} hospitalización(es) en el último año', 0.3, 'historia');
    final ud = e.hc!.ultEmergDias;
    if (ud != null && ud <= 30) add('Reingreso a emergencia en menos de 30 días (hace $ud días)', 0.4, 'historia');
  }
  final terminos = analizarTexto(e.motivo);
  if (spec.usaTexto) {
    for (final t in terminos) {
      add('Motivo de consulta: «${t.termino}» (${t.grupo.categoria})', t.grupo.peso, 'texto');
    }
    if (e.gestante == 'Sí' && terminos.any((t) => t.grupo.categoria.startsWith('Sangrado') || t.grupo.categoria == 'Dolor abdominal')) {
      add('Gestante con sangrado o dolor abdominal', 1.0, 'texto');
    }
  }
  final z = spec.intercepto + c.fold<double>(0, (s, x) => s + x.peso);
  final prob = _sig(z);
  final prior = prob >= spec.umbralI
      ? 1
      : prob >= spec.umbralII
          ? 2
          : prob >= spec.umbralIII
              ? 3
              : 4;

  // Reglas de seguridad clínica: independientes del modelo y siempre activas.
  final reglas = <ReglaSeguridad>[];
  final criticos = <String>[];
  for (final d in kVitales) {
    final x = v[d.id];
    if (x != null && d.critico(x)) criticos.add('${d.nombre} en rango crítico (${fmtNum(x)} ${d.unidad})');
  }
  if (criticos.isNotEmpty) reglas.add(ReglaSeguridad(1, criticos.join('; ')));
  final alarmas = terminos.where((t) => t.grupo.minimo != null).map((t) => t.grupo.categoria).toList();
  if (alarmas.isNotEmpty) reglas.add(ReglaSeguridad(2, 'signo de alarma en el motivo de consulta: ${alarmas.join(', ')}'));
  var fin = prior;
  for (final r in reglas) {
    if (fin > r.minimo) fin = r.minimo;
  }
  c.sort((a, b) => b.peso.abs().compareTo(a.peso.abs()));
  return Prediccion(version, prob, prior, fin, reglas, c);
}
