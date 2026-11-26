// Entidades del dominio con serialización JSON para la persistencia local.

import '../core/datos.dart';
import '../core/modelo.dart';

DateTime _dt(dynamic s) => DateTime.parse(s as String);
DateTime? _dtn(dynamic s) => s == null ? null : DateTime.parse(s as String);
Map<String, dynamic> _m(dynamic x) => Map<String, dynamic>.from(x as Map);

class Acompanante {
  final String nombre;
  final String parentesco;
  final String celular;
  const Acompanante(this.nombre, this.parentesco, this.celular);
  Map<String, dynamic> toJson() => {'n': nombre, 'p': parentesco, 'c': celular};
  factory Acompanante.fromJson(Map<String, dynamic> j) => Acompanante(j['n'] as String, j['p'] as String, j['c'] as String);
}

class Decision {
  int prior; // prioridad vigente (puede cambiar por revaloración)
  final int priorInicial; // la que se compara con el modelo
  final int? sugeridaVisible; // sugerencia mostrada (null en modo sombra)
  final bool aceptada;
  final String? motivoCat;
  final String? motivoTxt;
  final String usuario;
  final String profesional;
  final DateTime ts;
  final String modo; // 'piloto' | 'sombra'
  Decision({required this.prior, required this.priorInicial, this.sugeridaVisible, required this.aceptada, this.motivoCat, this.motivoTxt, required this.usuario, required this.profesional, required this.ts, required this.modo});
  Map<String, dynamic> toJson() => {
        'prior': prior,
        'ini': priorInicial,
        'sug': sugeridaVisible,
        'ac': aceptada,
        'mc': motivoCat,
        'mt': motivoTxt,
        'u': usuario,
        'pf': profesional,
        'ts': ts.toIso8601String(),
        'modo': modo,
      };
  factory Decision.fromJson(Map<String, dynamic> j) => Decision(
        prior: (j['prior'] as num).toInt(),
        priorInicial: (j['ini'] as num).toInt(),
        sugeridaVisible: (j['sug'] as num?)?.toInt(),
        aceptada: j['ac'] as bool,
        motivoCat: j['mc'] as String?,
        motivoTxt: j['mt'] as String?,
        usuario: j['u'] as String,
        profesional: j['pf'] as String,
        ts: _dt(j['ts']),
        modo: j['modo'] as String,
      );
}

class Revaloracion {
  final DateTime ts;
  final int de;
  final int a;
  final String motivo;
  final String usuario;
  const Revaloracion(this.ts, this.de, this.a, this.motivo, this.usuario);
  Map<String, dynamic> toJson() => {'ts': ts.toIso8601String(), 'de': de, 'a': a, 'm': motivo, 'u': usuario};
  factory Revaloracion.fromJson(Map<String, dynamic> j) => Revaloracion(_dt(j['ts']), (j['de'] as num).toInt(), (j['a'] as num).toInt(), j['m'] as String, j['u'] as String);
}

class Desenlace {
  final String tipo;
  final DateTime ts;
  final bool critico;
  const Desenlace(this.tipo, this.ts, this.critico);
  Map<String, dynamic> toJson() => {'t': tipo, 'ts': ts.toIso8601String(), 'c': critico};
  factory Desenlace.fromJson(Map<String, dynamic> j) => Desenlace(j['t'] as String, _dt(j['ts']), j['c'] as bool);
}

class Paciente {
  final String id;
  final String seudo;
  final TipoDoc tipo;
  final String docNum;
  final String? dv;
  final String? nombres, ap1, ap2;
  final String sexo;
  final DateTime? fnac;
  final int? edad;
  final int? edadAprox;
  final String seguro;
  final String? nacionalidad;
  final String? senas;
  final bool sintetico;
  final HistoriaClinica? hc;
  final Acompanante? acompanante;
  final String llegada;
  final DateTime llegadaTs;
  final DateTime registroTs;
  String estado; // registrado | clasificado | en_atencion | atendido | anulado
  String? motivo;
  String? motivoFiltrado;
  String? gestante;
  Map<String, double?> vit;
  Map<String, String> noMedido;
  Map<String, String> vitRaw;
  Map<String, Prediccion> preds; // versión → predicción
  Decision? decision;
  DateTime? prioridadTs;
  String? topico;
  DateTime? inicioTs, finTs;
  String? comprension;
  DateTime? comprensionTs;
  Desenlace? desenlace;
  List<Revaloracion> revaloraciones;
  String? anulacion;

  Paciente({
    required this.id,
    required this.seudo,
    required this.tipo,
    required this.docNum,
    this.dv,
    this.nombres,
    this.ap1,
    this.ap2,
    required this.sexo,
    this.fnac,
    this.edad,
    this.edadAprox,
    required this.seguro,
    this.nacionalidad,
    this.senas,
    this.sintetico = false,
    this.hc,
    this.acompanante,
    required this.llegada,
    required this.llegadaTs,
    required this.registroTs,
    this.estado = 'registrado',
    this.motivo,
    this.motivoFiltrado,
    this.gestante,
    Map<String, double?>? vit,
    Map<String, String>? noMedido,
    Map<String, String>? vitRaw,
    Map<String, Prediccion>? preds,
    this.decision,
    this.prioridadTs,
    this.topico,
    this.inicioTs,
    this.finTs,
    this.comprension,
    this.comprensionTs,
    this.desenlace,
    List<Revaloracion>? revaloraciones,
    this.anulacion,
  })  : vit = vit ?? {},
        noMedido = noMedido ?? {},
        vitRaw = vitRaw ?? {},
        preds = preds ?? {},
        revaloraciones = revaloraciones ?? [];

  int? get edadEfectiva => edad ?? edadAprox;
  String get nombreCompleto => [nombres, ap1, ap2].where((e) => e != null && e.isNotEmpty).join(' ');
  bool get enSala => estado == 'registrado' || estado == 'clasificado' || estado == 'en_atencion';
  bool get tieneClinico => motivo != null;
  List<String> get partesNombre => nombreCompleto.split(' ').where((e) => e.length >= 3).toList();

  Map<String, dynamic> toJson() => {
        'id': id,
        'seudo': seudo,
        'tipo': tipo.index,
        'doc': docNum,
        'dv': dv,
        'nom': nombres,
        'ap1': ap1,
        'ap2': ap2,
        'sexo': sexo,
        'fnac': fnac?.toIso8601String(),
        'edad': edad,
        'edadAprox': edadAprox,
        'seguro': seguro,
        'nac': nacionalidad,
        'senas': senas,
        'sint': sintetico,
        'hc': hc?.toJson(),
        'acomp': acompanante?.toJson(),
        'lleg': llegada,
        'llegTs': llegadaTs.toIso8601String(),
        'regTs': registroTs.toIso8601String(),
        'estado': estado,
        'motivo': motivo,
        'motivoF': motivoFiltrado,
        'gest': gestante,
        'vit': vit,
        'nm': noMedido,
        'vraw': vitRaw,
        'preds': preds.map((k, v) => MapEntry(k, v.toJson())),
        'dec': decision?.toJson(),
        'prTs': prioridadTs?.toIso8601String(),
        'top': topico,
        'iniTs': inicioTs?.toIso8601String(),
        'finTs': finTs?.toIso8601String(),
        'comp': comprension,
        'compTs': comprensionTs?.toIso8601String(),
        'des': desenlace?.toJson(),
        'reval': revaloraciones.map((e) => e.toJson()).toList(),
        'anul': anulacion,
      };

  factory Paciente.fromJson(Map<String, dynamic> j) => Paciente(
        id: j['id'] as String,
        seudo: j['seudo'] as String,
        tipo: TipoDoc.values[(j['tipo'] as num).toInt()],
        docNum: j['doc'] as String,
        dv: j['dv'] as String?,
        nombres: j['nom'] as String?,
        ap1: j['ap1'] as String?,
        ap2: j['ap2'] as String?,
        sexo: j['sexo'] as String,
        fnac: _dtn(j['fnac']),
        edad: (j['edad'] as num?)?.toInt(),
        edadAprox: (j['edadAprox'] as num?)?.toInt(),
        seguro: j['seguro'] as String,
        nacionalidad: j['nac'] as String?,
        senas: j['senas'] as String?,
        sintetico: j['sint'] as bool? ?? false,
        hc: j['hc'] == null ? null : HistoriaClinica.fromJson(_m(j['hc'])),
        acompanante: j['acomp'] == null ? null : Acompanante.fromJson(_m(j['acomp'])),
        llegada: j['lleg'] as String,
        llegadaTs: _dt(j['llegTs']),
        registroTs: _dt(j['regTs']),
        estado: j['estado'] as String,
        motivo: j['motivo'] as String?,
        motivoFiltrado: j['motivoF'] as String?,
        gestante: j['gest'] as String?,
        vit: _m(j['vit']).map((k, v) => MapEntry(k, (v as num?)?.toDouble())),
        noMedido: Map<String, String>.from(j['nm'] as Map),
        vitRaw: Map<String, String>.from(j['vraw'] as Map),
        preds: _m(j['preds']).map((k, v) => MapEntry(k, Prediccion.fromJson(_m(v)))),
        decision: j['dec'] == null ? null : Decision.fromJson(_m(j['dec'])),
        prioridadTs: _dtn(j['prTs']),
        topico: j['top'] as String?,
        inicioTs: _dtn(j['iniTs']),
        finTs: _dtn(j['finTs']),
        comprension: j['comp'] as String?,
        comprensionTs: _dtn(j['compTs']),
        desenlace: j['des'] == null ? null : Desenlace.fromJson(_m(j['des'])),
        revaloraciones: (j['reval'] as List).map((e) => Revaloracion.fromJson(_m(e))).toList(),
        anulacion: j['anul'] as String?,
      );
}

class EventoAuditoria {
  final int n;
  final DateTime ts;
  final String usuario;
  final String rol;
  final String accion;
  final String ref;
  final String codigo;
  final String versiones;
  final String detalle;
  final String prev;
  final String hash;
  const EventoAuditoria(this.n, this.ts, this.usuario, this.rol, this.accion, this.ref, this.codigo, this.versiones, this.detalle, this.prev, this.hash);

  String get contenido => [n, ts.toIso8601String(), usuario, rol, accion, ref, codigo, versiones, detalle].join('|');

  Map<String, dynamic> toJson() => {'n': n, 'ts': ts.toIso8601String(), 'u': usuario, 'r': rol, 'a': accion, 'ref': ref, 'c': codigo, 'v': versiones, 'd': detalle, 'p': prev, 'h': hash};
  factory EventoAuditoria.fromJson(Map<String, dynamic> j) => EventoAuditoria((j['n'] as num).toInt(), _dt(j['ts']), j['u'] as String, j['r'] as String, j['a'] as String, j['ref'] as String, j['c'] as String, j['v'] as String, j['d'] as String, j['p'] as String, j['h'] as String);
}

/// Estados del ciclo DevOps (captura «Ciclo de entrega DevOps»).
class EstadoVersion {
  static const desarrollo = 'Desarrollo';
  static const qa = 'Pruebas (QA)';
  static const sombra = 'Modo sombra';
  static const aprobada = 'Aprobada';
  static const produccion = 'Producción';
  static const retirada = 'Retirada';
  static const rechazada = 'Rechazada';
}

class HitoVersion {
  final DateTime ts;
  final String estado;
  final String usuario;
  final String nota;
  const HitoVersion(this.ts, this.estado, this.usuario, this.nota);
  Map<String, dynamic> toJson() => {'ts': ts.toIso8601String(), 'e': estado, 'u': usuario, 'n': nota};
  factory HitoVersion.fromJson(Map<String, dynamic> j) => HitoVersion(_dt(j['ts']), j['e'] as String, j['u'] as String, j['n'] as String);
}

class VersionModelo {
  final String version;
  String estado;
  final List<HitoVersion> historial;
  VersionModelo(this.version, this.estado, this.historial);
  Map<String, dynamic> toJson() => {'v': version, 'e': estado, 'h': historial.map((e) => e.toJson()).toList()};
  factory VersionModelo.fromJson(Map<String, dynamic> j) => VersionModelo(j['v'] as String, j['e'] as String, (j['h'] as List).map((e) => HitoVersion.fromJson(_m(e))).toList());
}

class ElementoSync {
  final int id;
  final String tipo;
  final DateTime creado;
  DateTime? enviado;
  final Map<String, dynamic> carga; // solo datos seudonimizados
  ElementoSync(this.id, this.tipo, this.creado, this.carga, {this.enviado});
  Map<String, dynamic> toJson() => {'id': id, 't': tipo, 'c': creado.toIso8601String(), 'e': enviado?.toIso8601String(), 'p': carga};
  factory ElementoSync.fromJson(Map<String, dynamic> j) => ElementoSync((j['id'] as num).toInt(), j['t'] as String, _dt(j['c']), _m(j['p']), enviado: _dtn(j['e']));
}
