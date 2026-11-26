// Estado global de la aplicación: pacientes, sesión, auditoría encadenada,
// ciclo de versiones del modelo (DevOps), cola de sincronización con la nube
// y persistencia local (shared_preferences).

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/algoritmos.dart';
import '../core/datos.dart';
import '../core/modelo.dart';
import '../core/validadores.dart';
import 'entidades.dart';

class AppState extends ChangeNotifier {
  static const _clave = 'triaje_apf3_flutter_v1';
  SharedPreferences? _prefs;

  // ---- datos persistidos ----
  int offsetMin = 0;
  int contador = 0;
  int contadorNN = 0;
  int? lineaBase;
  List<Paciente> pacientes = [];
  List<EventoAuditoria> auditoria = [];
  List<VersionModelo> versiones = [];
  List<String?> topicos = [null, null, null];
  List<ElementoSync> cola = [];
  int contadorSync = 0;
  bool enLinea = true;
  DateTime? autopruebasOk; // última ejecución 100 % correcta
  String? usuarioActual;
  int intentosFallidos = 0;
  DateTime? bloqueoHasta;

  // ---- sesión (no persistida) ----
  DateTime ultimaActividad = DateTime.now();

  DateTime get ahora => DateTime.now().add(Duration(minutes: offsetMin));
  Usuario? get usuario {
    for (final u in kUsuarios) {
      if (u.usuario == usuarioActual) return u;
    }
    return null;
  }

  Rol? get rol => usuario?.rol;

  /* ================= persistencia ================= */
  Future<void> cargar() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs!.getString(_clave);
      if (raw != null) {
        _desdeJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      } else {
        _inicial();
      }
    } catch (_) {
      _inicial();
    }
    notifyListeners();
  }

  void _inicial() {
    final t = DateTime.now();
    versiones = [
      VersionModelo('0.2.0', EstadoVersion.produccion, [
        HitoVersion(t.subtract(const Duration(days: 30)), EstadoVersion.sombra, 'comite', 'Modo sombra de 2 semanas (APF2).'),
        HitoVersion(t.subtract(const Duration(days: 14)), EstadoVersion.aprobada, 'comite', 'Aprobada por el comité de modelo.'),
        HitoVersion(t.subtract(const Duration(days: 13)), EstadoVersion.produccion, 'comite', 'Despliegue en producción (piloto asistido).'),
      ]),
      VersionModelo('0.3.0', EstadoVersion.sombra, [
        HitoVersion(t.subtract(const Duration(days: 5)), EstadoVersion.qa, 'comite', 'Pruebas funcionales y de seguridad superadas.'),
        HitoVersion(t.subtract(const Duration(days: 3)), EstadoVersion.sombra, 'comite', 'Predice en paralelo sin mostrarse al personal.'),
      ]),
      VersionModelo('0.4.0', EstadoVersion.desarrollo, [
        HitoVersion(t.subtract(const Duration(days: 1)), EstadoVersion.desarrollo, 'equipo', 'Ajuste de umbral de Prioridad II.'),
      ]),
    ];
  }

  Map<String, dynamic> _aJson() => {
        'offset': offsetMin,
        'cont': contador,
        'nn': contadorNN,
        'lb': lineaBase,
        'pac': pacientes.map((e) => e.toJson()).toList(),
        'aud': auditoria.map((e) => e.toJson()).toList(),
        'ver': versiones.map((e) => e.toJson()).toList(),
        'top': topicos,
        'cola': cola.map((e) => e.toJson()).toList(),
        'cs': contadorSync,
        'online': enLinea,
        'atok': autopruebasOk?.toIso8601String(),
        'user': usuarioActual,
        'int': intentosFallidos,
        'bloq': bloqueoHasta?.toIso8601String(),
      };

  void _desdeJson(Map<String, dynamic> j) {
    Map<String, dynamic> m(dynamic x) => Map<String, dynamic>.from(x as Map);
    offsetMin = (j['offset'] as num).toInt();
    contador = (j['cont'] as num).toInt();
    contadorNN = (j['nn'] as num).toInt();
    lineaBase = (j['lb'] as num?)?.toInt();
    pacientes = (j['pac'] as List).map((e) => Paciente.fromJson(m(e))).toList();
    auditoria = (j['aud'] as List).map((e) => EventoAuditoria.fromJson(m(e))).toList();
    versiones = (j['ver'] as List).map((e) => VersionModelo.fromJson(m(e))).toList();
    topicos = (j['top'] as List).map((e) => e as String?).toList();
    cola = (j['cola'] as List).map((e) => ElementoSync.fromJson(m(e))).toList();
    contadorSync = (j['cs'] as num).toInt();
    enLinea = j['online'] as bool;
    autopruebasOk = j['atok'] == null ? null : DateTime.parse(j['atok'] as String);
    usuarioActual = j['user'] as String?;
    intentosFallidos = (j['int'] as num).toInt();
    bloqueoHasta = j['bloq'] == null ? null : DateTime.parse(j['bloq'] as String);
  }

  Future<void> _guardar() async {
    try {
      await _prefs?.setString(_clave, jsonEncode(_aJson()));
    } catch (_) {/* sin almacenamiento */}
  }

  void _cambio() {
    notifyListeners();
    _guardar();
  }

  /* ================= versiones / modo ================= */
  VersionModelo? get versionProduccion {
    for (final v in versiones) {
      if (v.estado == EstadoVersion.produccion) return v;
    }
    return null;
  }

  List<VersionModelo> get versionesEvaluadas => versiones.where((v) => v.estado == EstadoVersion.sombra || v.estado == EstadoVersion.aprobada || v.estado == EstadoVersion.produccion).toList();

  /// Piloto asistido solo si hay una versión en producción; si no, todo es modo sombra.
  bool get modoPiloto => versionProduccion != null;
  String get modoTexto => modoPiloto ? 'Piloto asistido' : 'Modo sombra';
  String get resumenVersiones {
    final p = versionProduccion;
    final s = versiones.where((v) => v.estado == EstadoVersion.sombra).map((v) => 'v${v.version}').join(', ');
    return '${p == null ? 'Sin versión en producción' : 'Producción v${p.version}'}${s.isEmpty ? '' : ' · Sombra $s'}';
  }

  /* ================= auditoría ================= */
  void auditar(String accion, {Paciente? p, String detalle = ''}) {
    final u = usuario;
    final prev = auditoria.isEmpty ? '0' * 64 : auditoria.last.hash;
    final base = EventoAuditoria(auditoria.length + 1, ahora, u?.usuario ?? 'sistema', u == null ? '-' : rolTexto(u.rol), accion, p?.seudo ?? '-', p?.id ?? '-', resumenVersiones, detalle, prev, '');
    final hash = sha256Hex(prev + base.contenido);
    auditoria.add(EventoAuditoria(base.n, base.ts, base.usuario, base.rol, base.accion, base.ref, base.codigo, base.versiones, base.detalle, prev, hash));
  }

  /// Devuelve null si la cadena está íntegra, o el número del primer evento alterado.
  int? verificarCadena() {
    var prev = '0' * 64;
    for (final e in auditoria) {
      if (e.prev != prev) return e.n;
      if (sha256Hex(prev + e.contenido) != e.hash) return e.n;
      prev = e.hash;
    }
    return null;
  }

  /* ================= sincronización con la nube ================= */
  void _encolar(String tipo, Map<String, dynamic> carga) {
    contadorSync++;
    final e = ElementoSync(contadorSync, tipo, ahora, carga);
    if (enLinea) e.enviado = ahora;
    cola.add(e);
  }

  int get pendientesSync => cola.where((e) => e.enviado == null).length;

  void cambiarConexion(bool valor) {
    enLinea = valor;
    auditar(valor ? 'Conexión restablecida' : 'Pérdida de conexión (simulada)', detalle: valor ? 'Se sincronizan $pendientesSync registros pendientes' : 'El triaje sigue funcionando en el entorno local');
    if (valor) sincronizar(silencioso: true);
    _cambio();
  }

  void sincronizar({bool silencioso = false}) {
    if (!enLinea) return;
    final n = pendientesSync;
    for (final e in cola) {
      e.enviado ??= ahora;
    }
    if (!silencioso && n > 0) auditar('Sincronización con la nube', detalle: '$n registros seudonimizados enviados');
    _cambio();
  }

  Map<String, dynamic> _cargaClinica(Paciente p) => {
        'seudonimo': p.seudo,
        'edad': p.edadEfectiva,
        'sexo': p.sexo,
        'llegada': p.llegada,
        'motivo_filtrado': p.motivoFiltrado,
        'signos': p.vit,
        'no_medido': p.noMedido.keys.toList(),
        'predicciones': p.preds.map((k, v) => MapEntry('v$k', {'prioridad': v.prioridad, 'prob': double.parse(v.prob.toStringAsFixed(3))})),
      };

  /* ================= sesión ================= */
  String? iniciarSesion(String u, String c) {
    if (bloqueoHasta != null && DateTime.now().isBefore(bloqueoHasta!)) {
      return 'Acceso bloqueado por 3 intentos fallidos. Espere ${bloqueoHasta!.difference(DateTime.now()).inSeconds + 1} s.';
    }
    final r = validarLogin(u, c);
    if (!r.ok) {
      if (r.mensaje!.startsWith('Usuario o contraseña')) {
        intentosFallidos++;
        if (intentosFallidos >= 3) {
          intentosFallidos = 0;
          bloqueoHasta = DateTime.now().add(const Duration(seconds: 60));
          _cambio();
          return 'Acceso bloqueado por 3 intentos fallidos. Espere 60 s.';
        }
        _cambio();
        return '${r.mensaje} Intentos restantes: ${3 - intentosFallidos}.';
      }
      return r.mensaje;
    }
    intentosFallidos = 0;
    usuarioActual = r.valor!.usuario;
    ultimaActividad = DateTime.now();
    auditar('Inicio de sesión');
    _cambio();
    return null;
  }

  void cerrarSesion({bool inactividad = false}) {
    auditar(inactividad ? 'Cierre de sesión por inactividad' : 'Cierre de sesión');
    usuarioActual = null;
    _cambio();
  }

  void avanzarReloj(int min) {
    offsetMin += min;
    auditar('Reloj simulado', detalle: '+$min min');
    _cambio();
  }

  Future<void> reiniciar() async {
    final u = usuarioActual;
    offsetMin = 0;
    contador = 0;
    contadorNN = 0;
    lineaBase = null;
    pacientes = [];
    auditoria = [];
    topicos = [null, null, null];
    cola = [];
    contadorSync = 0;
    enLinea = true;
    autopruebasOk = null;
    _inicial();
    usuarioActual = u;
    auditar('Reinicio de la demostración');
    _cambio();
  }

  /* ================= pacientes ================= */
  Paciente? porId(String? id) {
    for (final p in pacientes) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<Paciente> get enSala => pacientes.where((p) => p.enSala).toList()..sort((a, b) => a.llegadaTs.compareTo(b.llegadaTs));

  bool documentoActivo(TipoDoc t, String num) => pacientes.any((p) => p.enSala && p.tipo == t && p.docNum == num);

  Paciente registrar({
    required TipoDoc tipo,
    String? docNum,
    String? dv,
    String? nombres,
    String? ap1,
    String? ap2,
    required String sexo,
    DateTime? fnac,
    int? edad,
    int? edadAprox,
    required String seguro,
    String? nacionalidad,
    String? senas,
    HistoriaClinica? hc,
    Acompanante? acompanante,
    required String llegada,
    required DateTime llegadaTs,
  }) {
    contador++;
    var num = docNum ?? '';
    if (tipo == TipoDoc.nn) {
      contadorNN++;
      final a = ahora;
      num = 'NN-${a.year}${a.month.toString().padLeft(2, '0')}${a.day.toString().padLeft(2, '0')}-${contadorNN.toString().padLeft(3, '0')}';
    }
    final p = Paciente(
      id: 'A-${contador.toString().padLeft(3, '0')}',
      seudo: seudonimo(tipoDocTexto(tipo), num),
      tipo: tipo,
      docNum: num,
      dv: dv,
      nombres: nombres,
      ap1: ap1,
      ap2: ap2,
      sexo: sexo,
      fnac: fnac,
      edad: edad,
      edadAprox: edadAprox,
      seguro: seguro,
      nacionalidad: nacionalidad,
      senas: senas,
      hc: hc,
      acompanante: acompanante,
      llegada: llegada,
      llegadaTs: llegadaTs,
      registroTs: ahora,
    );
    pacientes.add(p);
    auditar('Registro de paciente', p: p, detalle: '${tipoDocTexto(tipo)}${hc != null ? ' · historia clínica consultada' : ' · sin historia clínica vinculada'}${seguro == 'Inactivo' ? ' · no asegurado' : ''}');
    _encolar('Registro', {'seudonimo': p.seudo, 'tipo_documento': tipoDocTexto(tipo), 'edad': p.edadEfectiva, 'sexo': sexo, 'llegada': llegada});
    _cambio();
    return p;
  }

  /// Guarda motivo y signos, y calcula las predicciones de todas las versiones evaluadas.
  void guardarClinico(Paciente p, {required String motivo, String? gestante, required Map<String, double?> vit, required Map<String, String> noMedido, required Map<String, String> vitRaw}) {
    p.motivo = motivo;
    p.motivoFiltrado = filtrarTexto(motivo, p.partesNombre);
    p.gestante = gestante;
    p.vit = vit;
    p.noMedido = noMedido;
    p.vitRaw = vitRaw;
    final entrada = EntradaModelo(edad: p.edadEfectiva, sexo: p.sexo, llegada: p.llegada, gestante: gestante, vit: vit, noMedido: noMedido, hc: p.hc, motivo: motivo);
    p.preds = {for (final v in versionesEvaluadas) v.version: predecir(entrada, version: v.version)};
    final prod = versionProduccion;
    final pp = prod == null ? null : p.preds[prod.version];
    auditar(pp == null ? 'Consulta al modelo (solo modo sombra)' : 'Consulta al modelo', p: p, detalle: p.preds.entries.map((e) => 'v${e.key}: ${pr(e.value.prioridad).romano} (${(e.value.prob * 100).toStringAsFixed(1)} %)').join(' · '));
    _cambio();
  }

  Prediccion? sugerenciaVisible(Paciente p) {
    final prod = versionProduccion;
    if (prod == null) return null;
    return p.preds[prod.version];
  }

  void decidir(Paciente p, {required int prior, required bool aceptada, String? motivoCat, String? motivoTxt}) {
    if (p.estado != 'registrado') return;
    final u = usuario!;
    final sug = sugerenciaVisible(p);
    p.decision = Decision(prior: prior, priorInicial: prior, sugeridaVisible: sug?.prioridad, aceptada: aceptada, motivoCat: motivoCat, motivoTxt: motivoTxt, usuario: u.usuario, profesional: u.nombre, ts: ahora, modo: sug == null ? 'sombra' : 'piloto');
    p.estado = 'clasificado';
    p.prioridadTs = ahora;
    final txt = sug == null
        ? 'Modo sombra · profesional: ${pr(prior).romano}'
        : aceptada
            ? 'Acepta sugerencia: Prioridad ${pr(prior).romano}'
            : 'Modifica: ${pr(sug.prioridad).romano} → ${pr(prior).romano} · $motivoCat: $motivoTxt';
    auditar(sug == null ? 'Decisión profesional (modo sombra)' : (aceptada ? 'Decisión: acepta sugerencia' : 'Decisión: modifica prioridad'), p: p, detalle: txt);
    _encolar('Clasificación', {..._cargaClinica(p), 'prioridad_profesional': prior, 'modo': p.decision!.modo});
    _cambio();
  }

  void revalorar(Paciente p, int nueva, String motivo) {
    final d = p.decision!;
    p.revaloraciones.add(Revaloracion(ahora, d.prior, nueva, motivo, usuario!.usuario));
    auditar('Revaloración de prioridad', p: p, detalle: '${pr(d.prior).romano} → ${pr(nueva).romano}: $motivo');
    d.prior = nueva;
    p.prioridadTs = ahora;
    _cambio();
  }

  void anular(Paciente p, String motivo) {
    p.estado = 'anulado';
    p.anulacion = motivo;
    auditar('Anulación de registro', p: p, detalle: motivo);
    _cambio();
  }

  int? topicoLibre() {
    for (var i = 0; i < topicos.length; i++) {
      if (topicos[i] == null) return i;
    }
    return null;
  }

  List<Paciente> masUrgentesEsperando(Paciente p) => enSala.where((x) => x.estado == 'clasificado' && x.decision!.prior < p.decision!.prior).toList();

  void enviarATopico(Paciente p) {
    final i = topicoLibre();
    if (i == null || p.estado != 'clasificado') return;
    final adelantados = masUrgentesEsperando(p);
    topicos[i] = p.id;
    p.estado = 'en_atencion';
    p.topico = 'T${i + 1}';
    p.inicioTs = ahora;
    auditar('Ingreso a tópico', p: p, detalle: 'T${i + 1}${adelantados.isEmpty ? '' : ' · se adelantó a pacientes más urgentes: ${adelantados.map((e) => e.id).join(', ')}'}');
    _cambio();
  }

  void finalizarAtencion(Paciente p) {
    final i = topicos.indexOf(p.id);
    if (i >= 0) topicos[i] = null;
    p.estado = 'atendido';
    p.finTs = ahora;
    auditar('Fin de atención en tópico', p: p, detalle: p.topico ?? '');
    _cambio();
  }

  void registrarComprension(Paciente p, String r) {
    p.comprension = r;
    p.comprensionTs = ahora;
    auditar('Registro de comprensión (H4)', p: p, detalle: r);
    _cambio();
  }

  void registrarDesenlace(Paciente p, String tipo, DateTime ts) {
    final critico = kDesenlacesCriticos.contains(tipo) && ts.difference(p.decision!.ts).inHours < 24;
    p.desenlace = Desenlace(tipo, ts, critico);
    auditar('Registro de desenlace', p: p, detalle: '$tipo${critico ? ' (desenlace crítico a 24 h)' : ''}');
    _encolar('Desenlace', {'seudonimo': p.seudo, 'desenlace': tipo, 'critico_24h': critico});
    _cambio();
  }

  void guardarLineaBase(int v) {
    lineaBase = v;
    auditar('Registro de línea base H1', detalle: '$v min');
    _cambio();
  }

  void marcarAutopruebas(int ok, int total) {
    if (ok == total) autopruebasOk = ahora;
    auditar('Ejecución de autopruebas', detalle: '$ok/$total');
    _cambio();
  }

  void registrarEvento(String accion, {Paciente? p, String detalle = ''}) {
    auditar(accion, p: p, detalle: detalle);
    _cambio();
  }

  /* ================= cola A* ================= */
  ({List<Paciente> orden, ResultadoBusqueda r, double costoLlegada}) ordenCola() {
    final colaP = enSala.where((p) => p.estado == 'clasificado').toList();
    final t0 = ahora;
    final pacs = colaP.map((p) => PacienteCola(p.decision!.prior, p.prioridadTs!.difference(t0).inSeconds / 60)).toList();
    final libres = topicos.map((id) {
      if (id == null) return 0.0;
      final q = porId(id)!;
      final rest = kDuracionAtencion[q.decision!.prior]! - t0.difference(q.inicioTs!).inMinutes;
      return rest < 0 ? 0.0 : rest.toDouble();
    }).toList();
    final r = aEstrella(pacs, libres);
    final porLlegada = List<int>.generate(colaP.length, (i) => i)..sort((a, b) => colaP[a].llegadaTs.compareTo(colaP[b].llegadaTs));
    final f = simularOrden(pacs, porLlegada, libres);
    return (orden: r.orden.map((i) => colaP[i]).toList(), r: r, costoLlegada: f.costo);
  }

  /* ================= métricas del comité ================= */
  List<Paciente> decididosCon(String version) => pacientes.where((p) => p.decision != null && p.preds.containsKey(version)).toList();

  ({List<Par> pares, double? recall, double? precision, double? f1, double? auroc, double? kappa, int n, int nDes}) metricas(String version) {
    final ps = decididosCon(version);
    final pares = ps.map((p) => Par(p.decision!.priorInicial, p.preds[version]!.prioridad)).toList();
    final mc = metricasCriticas(pares);
    final des = ps.where((p) => p.desenlace != null).toList();
    return (
      pares: pares,
      recall: mc.recall,
      precision: mc.precision,
      f1: f1Macro(pares),
      auroc: auroc(des.map((p) => p.preds[version]!.prob).toList(), des.map((p) => p.desenlace!.critico).toList()),
      kappa: kappa(pares),
      n: pares.length,
      nDes: des.length,
    );
  }

  /* ================= ciclo de versiones (solo comité) ================= */
  String? transicion(VersionModelo v, String nuevo, {String nota = ''}) {
    if (rol != Rol.comite) return 'Solo el comité de modelo puede cambiar el estado de una versión.';
    final e = v.estado;
    bool permitido;
    switch (nuevo) {
      case EstadoVersion.qa:
        permitido = e == EstadoVersion.desarrollo;
        if (permitido && autopruebasOk == null) return 'Antes de pasar a QA ejecute las autopruebas con 100 % de casos correctos (pestaña «Reglas»).';
        break;
      case EstadoVersion.sombra:
        permitido = e == EstadoVersion.qa || e == EstadoVersion.produccion;
        if (permitido && e == EstadoVersion.qa && autopruebasOk == null) return 'Ejecute las autopruebas con 100 % de casos correctos antes del despliegue controlado.';
        break;
      case EstadoVersion.aprobada:
      case EstadoVersion.rechazada:
        permitido = e == EstadoVersion.sombra;
        break;
      case EstadoVersion.produccion:
        permitido = e == EstadoVersion.aprobada;
        break;
      default:
        permitido = false;
    }
    if (!permitido) return 'Transición no permitida: de «$e» a «$nuevo». El ciclo es Desarrollo → QA → Modo sombra → Aprobada → Producción.';
    if (nuevo == EstadoVersion.produccion) {
      final prev = versionProduccion;
      if (prev != null) {
        prev.estado = EstadoVersion.retirada;
        prev.historial.add(HitoVersion(ahora, EstadoVersion.retirada, usuario!.usuario, 'Reemplazada por v${v.version}.'));
      }
    }
    v.estado = nuevo;
    v.historial.add(HitoVersion(ahora, nuevo, usuario!.usuario, nota));
    if (nuevo == EstadoVersion.sombra && e == EstadoVersion.qa) {
      // Etapa «Datos históricos»: evaluación retrospectiva sobre las atenciones ya decididas.
      var n = 0;
      for (final p in pacientes) {
        if (p.decision == null || p.motivo == null || p.preds.containsKey(v.version)) continue;
        p.preds[v.version] = predecir(EntradaModelo(edad: p.edadEfectiva, sexo: p.sexo, llegada: p.llegada, gestante: p.gestante, vit: p.vit, noMedido: p.noMedido, hc: p.hc, motivo: p.motivo!), version: v.version);
        n++;
      }
      v.historial.add(HitoVersion(ahora, nuevo, 'sistema', 'Evaluación retrospectiva sobre $n atenciones históricas.'));
    }
    auditar('Ciclo de versión del modelo', detalle: 'v${v.version}: $e → $nuevo${nota.isEmpty ? '' : ' · $nota'}');
    _cambio();
    return null;
  }

  /* ================= escenario sintético ================= */
  void cargarEscenario() {
    const casos = <(String, int, String, Map<String, double>, String)>[
      ('M', 34, 'Fiebre y dolor de cabeza desde hace tres días', {'pas': 115.0, 'pad': 72.0, 'fc': 98.0, 'fr': 18.0, 'temp': 38.7, 'spo2': 97.0, 'glasgow': 15.0, 'eva': 5.0}, 'Alta'),
      ('F', 27, 'Fiebre con petequias y sangrado de encías', {'pas': 100.0, 'pad': 65.0, 'fc': 112.0, 'fr': 20.0, 'temp': 38.9, 'spo2': 96.0, 'glasgow': 15.0, 'eva': 6.0}, 'Hospitalización'),
      ('M', 71, 'Dolor en el pecho opresivo desde hace una hora', {'pas': 165.0, 'pad': 95.0, 'fc': 104.0, 'fr': 22.0, 'temp': 36.8, 'spo2': 93.0, 'glasgow': 15.0, 'eva': 8.0}, 'Ingreso a UCI'),
      ('F', 45, 'Fiebre y dolor abdominal intenso con vómitos persistentes', {'pas': 92.0, 'pad': 60.0, 'fc': 118.0, 'fr': 22.0, 'temp': 38.4, 'spo2': 95.0, 'glasgow': 15.0, 'eva': 8.0}, 'Hospitalización'),
      ('M', 22, 'Dolor de garganta y resfrío', {'pas': 120.0, 'pad': 78.0, 'fc': 82.0, 'fr': 16.0, 'temp': 37.4, 'spo2': 98.0, 'glasgow': 15.0, 'eva': 2.0}, 'Alta'),
      ('F', 83, 'Falta de aire y desmayo en casa', {'pas': 78.0, 'pad': 50.0, 'fc': 132.0, 'fr': 30.0, 'temp': 37.0, 'spo2': 84.0, 'glasgow': 13.0, 'eva': 4.0}, 'Fallecimiento'),
      ('M', 30, 'Caída de moto con golpe en la pierna', {'pas': 130.0, 'pad': 80.0, 'fc': 95.0, 'fr': 18.0, 'temp': 36.7, 'spo2': 98.0, 'glasgow': 15.0, 'eva': 7.0}, 'Alta'),
      ('F', 19, 'Fiebre y malestar general desde ayer', {'pas': 110.0, 'pad': 70.0, 'fc': 96.0, 'fr': 17.0, 'temp': 38.2, 'spo2': 98.0, 'glasgow': 15.0, 'eva': 3.0}, 'Alta'),
      ('M', 58, 'Debilidad en un lado del cuerpo y boca desviada', {'pas': 190.0, 'pad': 105.0, 'fc': 88.0, 'fr': 18.0, 'temp': 36.6, 'spo2': 96.0, 'glasgow': 14.0, 'eva': 2.0}, 'Ingreso a UCI'),
      ('F', 38, 'Fiebre alta y dolor de cuerpo, sospecha de dengue', {'pas': 112.0, 'pad': 70.0, 'fc': 104.0, 'fr': 19.0, 'temp': 39.6, 'spo2': 97.0, 'glasgow': 15.0, 'eva': 6.0}, 'Alta'),
      ('M', 64, 'Dolor abdominal y vómitos desde la mañana', {'pas': 135.0, 'pad': 85.0, 'fc': 90.0, 'fr': 18.0, 'temp': 37.2, 'spo2': 97.0, 'glasgow': 15.0, 'eva': 6.0}, 'Hospitalización'),
      ('F', 29, 'Control de presión y receta', {'pas': 125.0, 'pad': 82.0, 'fc': 76.0, 'fr': 15.0, 'temp': 36.6, 'spo2': 99.0, 'glasgow': 15.0, 'eva': 0.0}, 'Alta'),
      ('M', 41, 'Convulsión en la calle, llega somnoliento', {'pas': 140.0, 'pad': 88.0, 'fc': 110.0, 'fr': 22.0, 'temp': 37.5, 'spo2': 94.0, 'glasgow': 12.0, 'eva': 3.0}, 'Hospitalización'),
      ('F', 52, 'Fiebre y manchas rojas en la piel', {'pas': 105.0, 'pad': 68.0, 'fc': 108.0, 'fr': 20.0, 'temp': 38.8, 'spo2': 96.0, 'glasgow': 15.0, 'eva': 5.0}, 'Cirugía de emergencia'),
      ('M', 77, 'Dificultad respiratoria y silbidos', {'pas': 150.0, 'pad': 90.0, 'fc': 116.0, 'fr': 28.0, 'temp': 37.8, 'spo2': 89.0, 'glasgow': 15.0, 'eva': 4.0}, 'Ingreso a UCI'),
      ('F', 24, 'Diarrea y vómitos leves desde ayer', {'pas': 108.0, 'pad': 70.0, 'fc': 92.0, 'fr': 17.0, 'temp': 37.6, 'spo2': 98.0, 'glasgow': 15.0, 'eva': 3.0}, 'Alta'),
      ('M', 49, 'Dolor de cabeza leve y mareo', {'pas': 145.0, 'pad': 92.0, 'fc': 84.0, 'fr': 16.0, 'temp': 36.8, 'spo2': 98.0, 'glasgow': 15.0, 'eva': 4.0}, 'Alta'),
      ('F', 66, 'Fiebre y tos con flema desde hace 4 días', {'pas': 128.0, 'pad': 80.0, 'fc': 102.0, 'fr': 24.0, 'temp': 38.6, 'spo2': 92.0, 'glasgow': 15.0, 'eva': 3.0}, 'Hospitalización'),
      ('M', 35, 'Quemadura en la mano con aceite caliente', {'pas': 125.0, 'pad': 80.0, 'fc': 98.0, 'fr': 18.0, 'temp': 36.9, 'spo2': 99.0, 'glasgow': 15.0, 'eva': 8.0}, 'Alta'),
      ('F', 31, 'Ingirió veneno para ratas hace una hora', {'pas': 118.0, 'pad': 74.0, 'fc': 106.0, 'fr': 20.0, 'temp': 36.8, 'spo2': 97.0, 'glasgow': 15.0, 'eva': 2.0}, 'Ingreso a UCI'),
      ('M', 26, 'Corte en el dedo mientras cocinaba', {'pas': 122.0, 'pad': 78.0, 'fc': 84.0, 'fr': 16.0, 'temp': 36.7, 'spo2': 99.0, 'glasgow': 15.0, 'eva': 4.0}, 'Alta'),
      ('F', 72, 'Dolor abdominal intenso y fiebre', {'pas': 98.0, 'pad': 62.0, 'fc': 114.0, 'fr': 22.0, 'temp': 38.5, 'spo2': 95.0, 'glasgow': 15.0, 'eva': 9.0}, 'Cirugía de emergencia'),
      ('M', 18, 'Fiebre de dos días sin otros síntomas', {'pas': 116.0, 'pad': 72.0, 'fc': 94.0, 'fr': 17.0, 'temp': 38.1, 'spo2': 98.0, 'glasgow': 15.0, 'eva': 2.0}, 'Alta'),
      ('F', 55, 'Sangrado vaginal abundante desde la mañana', {'pas': 96.0, 'pad': 64.0, 'fc': 112.0, 'fr': 20.0, 'temp': 36.9, 'spo2': 97.0, 'glasgow': 15.0, 'eva': 6.0}, 'Hospitalización'),
    ];
    final base = ahora.subtract(const Duration(hours: 8));
    for (var i = 0; i < casos.length; i++) {
      final c = casos[i];
      final vit = Map<String, double?>.from(c.$4);
      final entrada = EntradaModelo(edad: c.$2, sexo: c.$1, llegada: 'Por sus propios medios', vit: vit, motivo: c.$3);
      final preds = {for (final v in versionesEvaluadas) v.version: predecir(entrada, version: v.version)};
      final ref = predecir(entrada, version: '0.3.0').prioridad;
      final prof = i % 6 == 3 ? (ref > 1 ? ref - 1 : ref) : (i % 8 == 7 ? (ref < 4 ? ref + 1 : ref) : ref);
      contador++;
      final lleg = base.add(Duration(minutes: i * 18));
      final dec = lleg.add(Duration(minutes: 6 + (i % 4) * 3));
      final p = Paciente(
        id: 'S-${contador.toString().padLeft(3, '0')}',
        seudo: seudonimo('SINT', 'SINT-$contador'),
        tipo: TipoDoc.nn,
        docNum: 'SINT-$contador',
        sexo: c.$1,
        edad: c.$2,
        seguro: 'Activo',
        sintetico: true,
        llegada: 'Por sus propios medios',
        llegadaTs: lleg,
        registroTs: lleg,
        estado: 'atendido',
        motivo: c.$3,
        motivoFiltrado: c.$3,
        vit: vit,
        preds: preds,
        decision: Decision(prior: prof, priorInicial: prof, aceptada: false, usuario: 'sintetico', profesional: 'Registro sintético', ts: dec, modo: 'sombra'),
        prioridadTs: dec,
        desenlace: Desenlace(c.$5, dec.add(const Duration(hours: 3)), kDesenlacesCriticos.contains(c.$5)),
      );
      pacientes.add(p);
    }
    auditar('Carga de escenario sintético (datos históricos)', detalle: '${casos.length} atenciones sintéticas para la evaluación retrospectiva');
    _cambio();
  }
}
